## 本番ランを固定更新で実行する実験セッション。共有セーブ・設定を編集しない。
extends Node

signal changed
signal event_recorded(event: Dictionary)
signal seek_progress(value: float)

const RUN_SCENE := preload("res://scenes/run/run.tscn")
const DT := 1.0 / 60.0

var scene: Node
var run: RunManager
var spec: Dictionary = {}
var history: Array[Dictionary] = []
var branches: Array[Dictionary] = []
var events: Array[Dictionary] = []
var tick := 0
var furthest := 0
var playing := false
var seeking := false
var speed := 1.0
var _cursor := 0
var _epoch := 0
var _intent := Intent.new()
var selected := -1
var _accumulator := 0.0

func reset(settings := {}) -> void:
	playing = false
	history.clear()
	branches.clear()
	spec = {"seed": 932, "empty": true, "stage": 1, "auto_spawn": false, "invincible": true}
	spec.merge(settings.duplicate(true), true)
	furthest = 0
	await _rebuild()
	changed.emit()

func _rebuild() -> void:
	_epoch += 1
	var revision := _epoch
	if is_instance_valid(scene):
		scene.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	if revision != _epoch:
		return
	var cfg: GameConfig = ConfigManager.base.duplicate(true)
	for key in spec.get("config", {}):
		cfg.set(key, spec.config[key])
	if spec.get("empty", true):
		cfg.moon_count = 0
		cfg.dust_count = 0
		cfg.meteor_count = 0
		cfg.iron_count = 0
		cfg.saw_count = 0
		cfg.comet_interval_min = 1e8
		cfg.comet_interval_max = 1e8
		cfg.gravity_interval_min = 1e8
		cfg.gravity_interval_max = 1e8
	var stage: StageDef = ConfigManager.stage(int(spec.get("stage", 1))).duplicate(true)
	var defs: Dictionary = ConfigManager.enemies.duplicate()
	for id in spec.get("overrides", {}):
		if defs.has(StringName(id)):
			var def: EnemyDef = defs[StringName(id)].duplicate(true)
			for key in spec.overrides[id]:
				def.set(key, spec.overrides[id][key])
			defs[StringName(id)] = def
	scene = RUN_SCENE.instantiate()
	scene.get_node("Hud").free()
	scene.get_node("Managers/RenderManager").free()
	scene.get_node("World/Camera2D").enabled = false
	run = scene.get_node("Managers/RunManager")
	run.options = {"lab": true, "config": cfg, "stage_index": stage.index, "stage": stage,
		"seed": int(spec.get("seed", 932)), "enemies": defs, "auto_spawn": spec.get("auto_spawn", false),
		"view_size": Vector2(1280, 720), "meta": spec.get("meta", {})}
	add_child(scene)
	run.input.set_process_input(false)
	run.input.set_process_unhandled_input(false)
	run.input_source = func(): return _intent
	run.ship.invincible = spec.get("invincible", true)
	run.state.ship_pos = vector(spec.get("ship_pos", [0, 0])) if spec.get("empty", true) else run.state.ship_pos
	run.state.time = float(spec.get("time", 0.0))
	run.state.gauge = float(spec.get("gauge", 1.0))
	if spec.get("empty", true):
		run.field.bodies.clear()
		run.field.moons.clear()
		run.field.rocks.clear()
		run.field.dust.clear()
		run.field.planet.pos = Vector2(1e7, 1e7)
		run.field.planet.r = 0
		run.field._update_moons()
	if not spec.get("auto_boss", false):
		run.state.boss_spawned = true
	for id in spec.get("weapons", {}):
		run.build.grant(&"weapon", StringName(id), int(spec.weapons[id]))
	for id in spec.get("traits", {}):
		run.build.grant(&"trait", StringName(id), int(spec.traits[id]))
	run.state.level = int(spec.get("level", 1))
	run.build.refresh_stats()
	run.state.hero_power = StringName(spec.get("hero", ""))
	tick = 0
	_cursor = 0
	_intent = Intent.new()
	_accumulator = 0
	events.clear()
	_apply_recorded()
	run.combat.rebuild_grid()

func vector(value) -> Vector2:
	if value is Vector2:
		return value
	return Vector2(float(value[0]), float(value[1])) if value is Array and value.size() == 2 else Vector2.ZERO

func _physics_process(delta: float) -> void:
	if not playing or seeking or not is_instance_valid(run):
		return
	_accumulator += delta * speed
	var budget := 0
	while _accumulator >= DT and budget < 20:
		step()
		_accumulator -= DT
		budget += 1
	changed.emit()

func step() -> void:
	if not is_instance_valid(run):
		return
	_run_schedule()
	run._play_tick(DT)
	_intent.press = false
	_intent.alt_press = false
	_intent.hero_press = false
	for item in run.state.events:
		var event: Dictionary = item.duplicate(true)
		event["tick"] = tick
		events.append(event)
		event_recorded.emit(event)
	run.state.events.clear()
	tick += 1
	furthest = maxi(furthest, tick)
	_apply_recorded()

func _apply_recorded() -> void:
	while _cursor < history.size() and int(history[_cursor].tick) <= tick:
		_apply(String(history[_cursor].kind), history[_cursor].args)
		_cursor += 1

func perform(kind: String, args := {}) -> void:
	if seeking or not is_instance_valid(run):
		return
	if tick < furthest:
		branches.append({"name": "分岐 %d" % (branches.size() + 1), "history": history.duplicate(true), "end": furthest})
		history = history.filter(func(e): return int(e.tick) <= tick)
		furthest = tick
	history.append({"tick": tick, "kind": kind, "args": args.duplicate(true)})
	_cursor = history.size()
	_apply(kind, args)
	run.combat.rebuild_grid()
	changed.emit()

func _apply(kind: String, args: Dictionary) -> void:
	match kind:
		"spawn":
			var def := run.enemies.def_of(StringName(args.get("type", "drifter")))
			if def == null:
				return
			var origin := vector(args.get("pos", [0, 0]))
			for k in clampi(int(args.get("count", 1)), 1, 10000):
				var offset := Vector2.from_angle(k * 2.399963) * sqrt(float(k)) * float(args.get("spacing", 60))
				selected = run.enemies.spawn(def, float(args.get("level", 1)), origin + offset,
					{"facing": float(args.get("angle", 0)), "elite": args.get("elite", false)})
		"move":
			var row := row_for_id(int(args.get("id", -1)))
			if row >= 0:
				run.enemies.table.pos[row] = vector(args.pos)
				run.enemies.table.facing[row] = float(args.get("angle", run.enemies.table.facing[row]))
		"delete":
			var row := row_for_id(int(args.get("id", -1)))
			if row >= 0:
				run.enemies.mark_dead(row)
				run.enemies.cleanup()
		"clear":
			run.bosses.remove_boss()
			run.enemies.clear_all()
			run.projectiles.clear_hostile()
		"boss":
			run.bosses.remove_boss()
			run.enemies.cleanup()
			run.state.boss_dead = false
			run.state.stage.boss_id = StringName(args.get("type", "hydra"))
			run.bosses.spawn()
			if args.has("pos"):
				run.enemies.table.pos[run.bosses.boss_row] = vector(args.pos)
			selected = run.bosses.boss_row
		"command":
			run.command(StringName(args.get("name", "")), args.get("args", {}))
		"input":
			_intent = Intent.new()
			_intent.has_cursor = args.get("has_cursor", true)
			_intent.cursor = vector(args.get("cursor", [0, 0]))
			_intent.pen = vector(args.get("pen", args.get("cursor", [0, 0])))
			_intent.press = args.get("press", false)
			_intent.hero_press = args.get("hero", false)
		"invincible":
			run.ship.invincible = args.get("value", true)
		"ship":
			run.state.ship_pos = vector(args.get("pos", [0, 0]))
			run.state.ship_vel = Vector2.ZERO
			run.state.gauge = float(args.get("gauge", run.state.gauge))
		"parameter":
			_edit_definition(args)

func _edit_definition(args: Dictionary) -> void:
	var type := StringName(args.get("type", ""))
	var def := run.enemies.def_of(type)
	if def == null:
		return
	def = def.duplicate(true)
	var key := String(args.get("key", ""))
	if key.begins_with("params."):
		def.params[key.trim_prefix("params.")] = args.value
	else:
		def.set(key, args.value)
	run.enemies.definitions[type] = def
	var t := run.enemies.table
	for i in t.alive.size():
		if not t.alive[i] or t.type[i] != type:
			continue
		var old: EnemyDef = t.def[i]
		if key == "hp":
			var ratio := t.hp[i] / maxf(0.001, t.max_hp[i])
			t.max_hp[i] *= def.hp / maxf(old.hp, 0.001)
			t.hp[i] = t.max_hp[i] * ratio
		elif key == "armor":
			t.armor[i] *= def.armor / maxf(old.armor, 0.001)
		elif key == "speed":
			t.speed[i] *= def.speed / maxf(old.speed, 0.001)
		elif key == "radius":
			t.r[i] *= def.radius / maxf(old.radius, 0.001)
		t.def[i] = def

func row_for_id(id: int) -> int:
	var t := run.enemies.table
	for i in t.alive.size():
		if t.alive[i] and not t.dead[i] and t.id[i] == id:
			return i
	return -1

func seek(target: int) -> void:
	playing = false
	seeking = true
	var end := furthest
	target = clampi(target, 0, end)
	await _rebuild()
	var epoch := _epoch
	while tick < target:
		for n in mini(120, target - tick):
			step()
		seek_progress.emit(float(tick) / maxf(1, target))
		await get_tree().process_frame
		if epoch != _epoch:
			return
	furthest = end
	seeking = false
	changed.emit()

func cancel_seek() -> void:
	_epoch += 1
	seeking = false
	playing = false

func _run_schedule() -> void:
	for entry in spec.get("schedule", []):
		if not entry.get("enabled", true):
			continue
		var start := roundi(float(entry.get("start", 0)) / DT)
		var interval := maxi(1, roundi(float(entry.get("interval", 1)) / DT))
		var end := roundi(float(entry.get("end", 600)) / DT)
		if tick >= start and tick <= end and (tick - start) % interval == 0:
			_apply("spawn", entry)

func digest() -> String:
	var t := run.enemies.table
	var enemies := []
	for i in t.alive.size():
		if t.alive[i] and not t.dead[i]:
			enemies.append([t.id[i], t.type[i], t.pos[i], t.vel[i], t.hp[i], t.facing[i], t.charge[i], t.fire_t[i]])
	var p := run.projectiles
	return str(hash(var_to_bytes([tick, run.state.ship_pos, run.state.ship_vel, run.state.ship_hp,
		run.state.gauge, run.state.rng.state, enemies, p.hostile_pos, p.hostile_alive,
		p.hazard_pos, p.hazard_t, run.state.time, run.state.world_time])))
