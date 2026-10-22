## 本番ランを固定更新で実行する実験セッション。共有セーブ・設定を編集しない。
extends Node

signal changed
signal event_recorded(event: Dictionary)
signal seek_progress(value: float)

const FORMAT := preload("res://gyms/enemy_lab/lab_io.gd")
const RUN_SCENE := preload("res://scenes/run/run.tscn")
const DIRECTOR := preload("res://scripts/encounters/attack_director.gd")
const DT := 1.0 / 60.0

var scene: Node
var run: RunManager
var baseline: Dictionary = {}
var spec: Dictionary = {}
var history: Array[Dictionary] = []
var branches: Array[Dictionary] = []
var current_branch := ""
var branch_serial := 0
var events: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var edit_undo: Array[Dictionary] = []
var edit_redo: Array[Dictionary] = []
var revision := 0
var tick := 0
var furthest := 0
var playing := false
var seeking := false
var speed := 1.0
var _cursor := 0
var _epoch := 0
var _seek_serial := 0
var _state_key := ""
var _intent := Intent.new()
var _selected_row := -1
var _selected_id := -1
var selected: int:
	get:
		return _selected_row if is_instance_valid(run) and run.enemies.is_same(_selected_row, _selected_id) and not run.enemies.table.dead[_selected_row] else -1
	set(value):
		_selected_row = value
		_selected_id = run.enemies.table.id[value] if is_instance_valid(run) and value >= 0 and value < run.enemies.table.id.size() else -1
var schedule: Array = []
var _accumulator := 0.0
## 本番のランを映す表示枠。入っていれば、本番の描画・HUD・カメラ・入力をそのまま使う（作業用のセッションは空で、描画しない）
var viewport: SubViewport
## 試遊中の本番の入力を返す（試遊していなければ null）。記録して再生すると同じ展開になる
var live_input: Callable
var _last_input := {}
## 描いたルートを本番の描画で描いている途中（点の列・描き終えるまでの回数・進んだ回数）。空なら描いていない
var _route_play := {}
## 機体を固定している位置（固定していなければ null）。固定中は機体を動かさず、敵だけが動く
var pinned: Variant = null
## 最後に再生を始めた時刻（リセットで戻る所）
var play_start := 0
var _was_playing := false

func reset(settings := {}) -> void:
	playing = false
	_seek_serial += 1
	seeking = false
	for checkpoint in checkpoints:
		if is_instance_valid(checkpoint.scene): checkpoint.scene.queue_free()
	checkpoints.clear()
	history.clear()
	edit_undo.clear()
	edit_redo.clear()
	branches.clear()
	branch_serial = 0
	current_branch = tr("lab.initial_branch")
	spec = {"seed": 932, "empty": true, "stage": 1, "auto_spawn": false, "invincible": true}
	spec.merge(settings.duplicate(true), true)
	# 保存で本番の外観が変わっても、この実験の巻き戻しは開始時の値から再生する。
	if not spec.has("overrides"):
		spec["overrides"] = {}
	for type in ConfigManager.enemies:
		var id := String(type)
		if not spec.overrides.has(id):
			spec.overrides[id] = {}
		if not spec.overrides[id].has("visual_settings"):
			spec.overrides[id]["visual_settings"] = ConfigManager.enemies[type].visual_settings.duplicate(true)
	baseline = FORMAT.baseline()
	furthest = 0
	await _rebuild()
	changed.emit()

func _rebuild() -> void:
	revision += 1
	_epoch += 1
	if is_instance_valid(scene):
		if scene.get_parent() != null:
			scene.get_parent().remove_child(scene)
		scene.queue_free()
	var cfg: GameConfig = ConfigManager.base.duplicate(true)
	for key in spec.get("config", {}):
		cfg.set(key, spec.config[key])
	var field_flags: Dictionary = spec.get("field", {})
	var terrain: bool = field_flags.get("terrain", not spec.get("empty", true))
	var rocks: bool = field_flags.get("rocks", not spec.get("empty", true))
	var gimmicks: bool = field_flags.get("gimmicks", not spec.get("empty", true))
	if not terrain: cfg.moon_count = 0
	if not rocks:
		cfg.meteor_count = 0
		cfg.iron_count = 0
		cfg.saw_count = 0
	if not gimmicks:
		cfg.dust_count = 0
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
				if key == "params":
					for param in spec.overrides[id][key]: def.params[param] = safe_parameter(param, spec.overrides[id][key][param])
				else: def.set(key, spec.overrides[id][key])
			defs[StringName(id)] = def
	scene = RUN_SCENE.instantiate()
	if viewport == null:
		scene.get_node("Hud").free()
		scene.get_node("Managers/RenderManager").free()
		scene.get_node("World/Camera2D").enabled = false
		scene.get_node("World").visible = false
	else:
		# 実験場の調整は実験場のパネルで行う。本番の調整パネル・性能表示は使わない
		scene.get_node("Hud/DebugPanel").free()
		scene.get_node("Hud/PerfOverlay").free()
	run = scene.get_node("Managers/RunManager")
	run.options = {"lab": true, "config": cfg, "stage_index": stage.index, "stage": stage,
		"endless": false, "seed": int(spec.get("seed", 932)), "enemies": defs, "auto_spawn": spec.get("auto_spawn", false),
		"view_size": Vector2(1280, 720), "meta": spec.get("meta", {})}
	if viewport != null:
		viewport.add_child(scene)
	else:
		add_child(scene)
	run.set_process(false)
	run.bosses.definitions = ConfigManager.bosses.duplicate()
	for id in spec.get("boss_overrides", {}):
		if ConfigManager.bosses.has(StringName(id)):
			var boss: BossDef = ConfigManager.bosses[StringName(id)].duplicate(true)
			for key in spec.boss_overrides[id]:
				if key == "params":
					for param in spec.boss_overrides[id][key]: boss.params[param] = safe_parameter(param, spec.boss_overrides[id][key][param])
				else: boss.set(key, spec.boss_overrides[id][key])
			run.bosses.definitions[StringName(id)] = boss
	var director = DIRECTOR.new()
	director.state = run.state
	director.projectiles = run.projectiles
	director.configure(spec.get("director", {}))
	run.projectiles.director = director
	if viewport == null:
		run.input.set_process_input(false)
		run.input.set_process_unhandled_input(false)
	run.input_source = func(): return _intent
	run.ship.invincible = spec.get("invincible", true)
	run.state.ship_pos = vector(spec.get("ship_pos", [0, 0])) if not terrain or spec.has("ship_pos") else run.state.ship_pos
	# 機体を置き直したので、カメラと敵の狙いも機体の位置から始める
	run.state.view_center = run.state.ship_pos
	run.state.enemy_aim = run.state.ship_pos
	run.state.time = float(spec.get("time", 0.0))
	run.state.gauge = float(spec.get("gauge", 1.0))
	if not rocks: run.field.rocks.clear()
	if not gimmicks: run.field.dust.clear()
	if not terrain:
		run.field.bodies.clear()
		run.field.moons.clear()
		run.field.planet.pos = Vector2(1e7, 1e7)
		run.field.planet.r = 0
		run.field._update_moons()
	if not spec.get("auto_boss", false):
		run.state.boss_spawned = true
	var weapon_ids: Array = spec.get("weapons", {}).keys()
	weapon_ids.sort()
	for id in weapon_ids:
		run.build.grant(&"weapon", StringName(id), int(spec.weapons[id]))
	var trait_ids: Array = spec.get("traits", {}).keys()
	trait_ids.sort()
	for id in trait_ids:
		run.build.grant(&"trait", StringName(id), int(spec.traits[id]))
	run.state.level = int(spec.get("level", 1))
	run.build.refresh_stats()
	run.state.hero_power = StringName(spec.get("hero", ""))
	tick = 0
	selected = -1
	_cursor = 0
	_state_key = ""
	_intent = Intent.new()
	_last_input = {}
	_route_play = {}
	pinned = null
	_accumulator = 0
	events.clear()
	schedule = spec.get("schedule", []).duplicate(true)
	_apply_recorded()
	run.combat.rebuild_grid()

func vector(value) -> Vector2:
	if value is Vector2:
		return value
	return Vector2(float(value[0]), float(value[1])) if value is Array and value.size() == 2 else Vector2.ZERO

func _physics_process(delta: float) -> void:
	if playing and not _was_playing and not seeking:
		play_start = tick
	_was_playing = playing
	if not playing or seeking or not is_instance_valid(run):
		return
	_accumulator += delta * speed
	var budget := 0
	while _accumulator >= DT and budget < 20:
		_take_live_input()
		step()
		_accumulator -= DT
		budget += 1
	changed.emit()

## 試遊中は、本番の入力をその回の操作として記録してから進める。
## 記録済みの時刻を再生している間は記録どおりに進め、押す操作があったときだけ、そこから新しい分岐にする。
func _take_live_input() -> void:
	if not live_input.is_valid():
		return
	var it = live_input.call()
	if it == null:
		return
	var pressed: bool = it.press or it.alt_press or it.hero_press or it.pen_release
	if tick < furthest and not pressed:
		return
	var args := {"has_cursor": it.has_cursor, "cursor": [it.cursor.x, it.cursor.y], "pen": [it.pen.x, it.pen.y],
		"press": it.press, "alt_press": it.alt_press, "hero": it.hero_press, "release": it.pen_release, "touch": it.touch}
	if not pressed and args == _last_input:
		return
	_last_input = args
	perform("input", args)

## 描いたルートを、本番の描画と同じ処理で少しずつ描き、描き終えたら確定して駆け抜けさせる。
## 長さの上限・地形・角の補正は本番どおりにかかる。操作の履歴の "route" から始まるので、再生しても同じになる。
func _draw_route_step() -> void:
	if _route_play.is_empty():
		return
	var path: PackedVector2Array = _route_play.points
	var frames: int = _route_play.frames
	var n: int = _route_play.n
	var draw := run.draw
	if n == 0:
		if run.state.drawing or run.state.tracing or run.state.gauge < run.cfg.draw_min_charge:
			_route_play = {}
			return
		var it := Intent.new()
		it.press = true
		it.has_cursor = true
		it.pen = path[0]
		it.cursor = path[0]
		draw._start(it)
	if not run.state.drawing:
		_route_play = {}
		return
	var index := clampf(float(n + 1) / frames * (path.size() - 1), 0, path.size() - 1)
	var previous := float(n) / frames * (path.size() - 1)
	for k in range(ceili(previous), floori(index) + 1):
		if k > 0 and k < path.size():
			draw._extend(path[k])
	var lo := mini(floori(index), path.size() - 2)
	draw._extend(path[lo].lerp(path[lo + 1], index - lo))
	_route_play.n = n + 1
	if n + 1 >= frames:
		if run.state.drawing:
			draw._commit(Intent.new())
		_route_play = {}

## 一覧から置いたフィールドの要素を加える。惑星は動かない障害物、彗星は機体の方へまっすぐ横切る。
## 重力とワープホールは、現れたときと同じ大きさ・時間で置く。経験値の結晶はひとまとまりで散らす。
func _add_field(kind: String, at: Vector2, radius: float) -> void:
	var field := run.field
	var cfg := run.cfg
	match kind:
		"planet":
			var body := FieldSystem.Body.new()
			body.pos = at
			body.r = maxf(10.0, radius)
			body.is_planet = true
			field.bodies.append(body)
			field._update_moons()
			# 天体までの距離の覚えを捨てて、新しい惑星を確かめ直させる
			run.enemies.table.body_gap.fill(-1.0)
			run.projectiles.hostile_gap.fill(0.0)
		"comet":
			var rock := FieldSystem.Rock.new()
			rock.lab_manual = true
			rock.kind = &"comet"
			var u := (run.state.ship_pos - at).normalized()
			if u == Vector2.ZERO: u = Vector2.RIGHT
			rock.pos = at
			rock.vel = u * cfg.comet_speed
			rock.born = run.state.world_time
			rock.gone = rock.born + (at.distance_to(run.state.ship_pos) + 2500.0) / cfg.comet_speed
			rock.size = maxf(20.0, radius)
			rock.facing = u.angle()
			field.rocks.append(rock)
			field._stream_t = 0.0
		"gravity":
			field.add_well(at, cfg.gravity_life, cfg.gravity_radius, cfg.gravity_pull)
		"warp":
			field.warp_pos = at
			field.warp_gone = run.state.world_time + cfg.warp_life
		"gem":
			# 経験値の結晶を12個、半径 radius の中に散らす（からす座の回収を試す）
			for k in 12:
				var u := Vector2.from_angle(k * 2.399963) * sqrt((k + 0.5) / 12.0) * radius
				run.pickups.drop_gem(at + u, 1.0)

## 機体を固定している間は、毎回の更新の前後で機体を固定した位置に戻し、速度を0にする。
func _hold_ship() -> void:
	if pinned == null:
		return
	run.state.ship_pos = pinned
	run.state.ship_vel = Vector2.ZERO

func step() -> void:
	if not is_instance_valid(run):
		return
	_run_schedule()
	run.projectiles.director.advance(run.state.world_time, run.enemies)
	_draw_route_step()
	_hold_ship()
	run._play_tick(DT)
	_hold_ship()
	_intent.press = false
	_intent.alt_press = false
	_intent.hero_press = false
	_intent.pen_release = false
	var shown: Array[Dictionary] = []
	for item in run.state.events:
		var event: Dictionary = item.duplicate(true)
		event["tick"] = tick
		events.append(event)
		event_recorded.emit(event)
		shown.append(item)
	run.state.events.clear()
	# 本番の描画と HUD へ出来事を渡す（爆発・文字など）。早送りの間は渡さない
	if viewport != null and not seeking and not shown.is_empty():
		run.frame_events.emit(shown)
	revision += 1
	tick += 1
	furthest = maxi(furthest, tick)
	_apply_recorded()

func _apply_recorded() -> void:
	var old_cursor := _cursor
	while _cursor < history.size() and int(history[_cursor].tick) <= tick:
		_apply(String(history[_cursor].kind), history[_cursor].args)
		_cursor += 1
	if _state_key.is_empty() or old_cursor != _cursor:
		_state_key = _checkpoint_key(tick)

func perform(kind: String, args := {}) -> void:
	if seeking or not is_instance_valid(run):
		return
	if kind != "input":
		edit_undo.append({"history": history.duplicate(true), "end": furthest, "tick": tick})
		if edit_undo.size() > 20: edit_undo.pop_front()
		edit_redo.clear()
	if tick < furthest:
		branches.append({"name": current_branch, "history": history.duplicate(true), "end": furthest})
		branch_serial += 1
		current_branch = TranslationServer.translate("lab.message_549e9c3c03") % branch_serial
		history = history.filter(func(e): return int(e.tick) <= tick)
		furthest = tick
	revision += 1
	history.append({"tick": tick, "kind": kind, "args": args.duplicate(true)})
	_cursor = history.size()
	_apply(kind, args)
	_state_key = _checkpoint_key(tick)
	# 入力は再生のときと同じく格子を作り直さない（作り直すと再生と展開がずれる）
	if kind != "input":
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
				var opts := {"facing": float(args.get("angle", 0)), "elite": args.get("elite", false)}
				if def.id in [&"meteor", &"iron", &"saw"]:
					var rock := FieldSystem.Rock.new()
					rock.lab_manual = true
					rock.kind = &"belt" if def.id == &"meteor" else def.id
					rock.pos = origin + offset
					rock.size = def.radius * run.cfg.character_scale
					rock.facing = float(opts.facing)
					opts.meteor_index = run.field.rocks.size()
					opts.size = rock.size
					run.field.rocks.append(rock)
				selected = run.enemies.spawn(def, origin + offset, opts)
				if opts.has("meteor_index"):
					var rock = run.field.rocks[opts.meteor_index]
					rock.row = selected
					rock.row_id = run.enemies.table.id[selected]
			run.state.emit(&"lab_spawn", {"pos": origin, "enemy_type": def.id})
		"formation":
			# 敵の組み合わせのシーンの配置と出現位置を選んで、機体のまわりに並べる
			var path := String(args.get("path", ""))
			if ResourceLoader.exists(path):
				var data := run.enemies.formation_data(load(path))
				run.enemies.spawn_formation(data, int(args.get("layout", 0)), int(args.get("entry", 0)))
				run.state.emit(&"lab_spawn", {"pos": run.state.ship_pos, "enemy_type": &"formation"})
		"edit_range":
			var row := row_for_id(int(args.get("id", -1)))
			if row >= 0:
				var definition := definition_for_row(row)
				var edit := {"type": String(run.enemies.table.type[row]), "key": "params." + String(args.get("key", "")), "value": maxf(0.01, float(args.get("length", 1)))}
				if definition is BossDef: _edit_boss_definition(edit)
				else: _edit_definition(edit)
				_apply("move", {"id": int(args.id), "pos": run.enemies.table.pos[row], "angle": float(args.get("angle", run.enemies.table.facing[row]))})
		"move":
			var row := row_for_id(int(args.get("id", -1)))
			if row >= 0:
				var t := run.enemies.table
				var origin := t.pos[row]
				var delta_angle := float(args.get("angle", t.facing[row])) - t.facing[row]
				var delta := vector(args.pos) - origin
				var family := [row]
				for n in range(0, t.parts[row].size(), 2):
					if run.enemies.is_same(t.parts[row][n], t.parts[row][n + 1]):
						family.append(t.parts[row][n])
				for child in family:
					if child != row:
						t.pos[child] = origin + (t.pos[child] - origin).rotated(delta_angle) + delta
						t.facing[child] += delta_angle
					for h in t.links[child]:
						if run.projectiles.owns_hazard(h, child, t.id[child]):
							var point := origin + (run.projectiles.hazard_pos[h] - origin).rotated(delta_angle) + delta
							run.projectiles.move_hazard(h, point, run.projectiles.hazard_angle[h] + delta_angle)
				run.enemies.table.pos[row] = vector(args.pos)
				if run.enemies.table.meteor_index[row] >= 0:
					run.field.rocks[run.enemies.table.meteor_index[row]].pos = vector(args.pos)
				run.enemies.table.facing[row] = float(args.get("angle", run.enemies.table.facing[row]))
		"individual":
			var row := row_for_id(int(args.get("id", -1)))
			if row >= 0 and run.enemies.table.def[row] != null:
				var t := run.enemies.table
				var ratio := t.hp[row] / maxf(0.001, t.max_hp[row])
				run.enemies.apply_scaling(row, t.def[row], {"elite": args.get("elite", t.elite[row] != 0), "size": maxf(0.1, float(args.get("size", t.def[row].radius)))})
				t.hp[row] = t.max_hp[row] * ratio
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
			for k in clampi(int(args.get("count", 1)), 1, 32):
				selected = run.bosses.spawn_lab(StringName(args.get("type", "hydra")), vector(args.get("pos", [0, 0])) + Vector2(k * 400, 0))
		"command":
			run.command(StringName(args.get("name", "")), args.get("args", {}))
		"input":
			var previous := _intent
			_intent = Intent.new()
			_intent.has_cursor = args.get("has_cursor", true)
			_intent.cursor = vector(args.get("cursor", [0, 0]))
			_intent.pen = vector(args.get("pen", args.get("cursor", [0, 0])))
			_intent.press = previous.press or args.get("press", false)
			_intent.hero_press = previous.hero_press or args.get("hero", false)
			_intent.alt_press = previous.alt_press or args.get("alt_press", false)
			_intent.touch = args.get("touch", false)
			_intent.pen_release = args.get("release", false)
		"route":
			var points := PackedVector2Array()
			for p in args.get("points", []):
				points.append(vector(p))
			if points.size() >= 2:
				_route_play = {"points": points, "n": 0,
					"frames": clampi(ceili(maxf(float(args.get("draw_seconds", 0.5)), run.cfg.draw_confirm_delay) / DT), 1, 1800)}
		"field":
			_add_field(String(args.get("kind", "")), vector(args.get("pos", [0, 0])), float(args.get("radius", 0)))
		"pin":
			pinned = vector(args.pos) if args.get("value", false) else null
			if pinned != null:
				run.state.ship_pos = pinned
				run.state.ship_vel = Vector2.ZERO
		"invincible":
			run.ship.invincible = args.get("value", true)
		"ship":
			run.state.ship_pos = vector(args.get("pos", [0, 0]))
			run.state.ship_vel = Vector2.ZERO
			run.state.gauge = float(args.get("gauge", run.state.gauge))
		"config":
			var key := String(args.get("key", ""))
			if key in ["base_attack", "base_max_speed", "draw_length", "draw_confirm_delay", "draw_time_scale", "trace_radius", "boss_hp", "boss_armor"] and typeof(args.get("value")) in [TYPE_INT, TYPE_FLOAT]:
				run.cfg.set(key, clampf(float(args.value), 0.001, 1.0) if key == "draw_time_scale" else maxf(0.01, float(args.value)))
				run.build.refresh_stats()
		"phase_set":
			var phases := []
			for id in args.get("ids", []):
				if ConfigManager.phases.has(StringName(id)): phases.append(ConfigManager.phases[StringName(id)])
			if not phases.is_empty(): run.state.stage.phases = phases
		"meta":
			run.state.meta_override[String(args.get("id", ""))] = clampi(int(args.get("level", 0)), 0, 100)
			run.build.refresh_stats()
		"time":
			run.state.time = maxf(0, float(args.get("value", 0)))
		"level":
			run.state.level = clampi(int(args.get("value", 1)), 1, 1000)
			run.build.refresh_stats()
		"hero":
			run.state.hero_power = StringName(args.get("id", ""))
			run.state.hero_active_t = 0
		"loadout":
			if args.get("reset", false):
				run.build.reset_loadout()
			else:
				run.build.grant(StringName(args.get("kind", "weapon")), StringName(args.get("id", "")), clampi(int(args.get("level", 1)), 1, 100))
		"schedule":
			schedule = args.get("entries", []).duplicate(true)
		"guard":
			run.projectiles.director.guard = args.duplicate(true)
		"director":
			run.projectiles.director.configure(args)
		"boss_parameter":
			_edit_boss_definition(args)
		"parameter":
			_edit_definition(args)

func _edit_definition(args: Dictionary) -> void:
	var type := StringName(args.get("type", ""))
	var def := run.enemies.def_of(type)
	if def == null:
		return
	def = def.duplicate(true)
	var key := String(args.get("key", ""))
	if not args.has("value") or typeof(args.value) not in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
		return
	if typeof(args.value) == TYPE_FLOAT and not is_finite(args.value):
		return
	if key.begins_with("visual."):
		var field := key.trim_prefix("visual.")
		if not EnemyDef.VISUAL_LIMITS.has(field):
			return
		var limits: Vector2 = EnemyDef.VISUAL_LIMITS[field]
		if args.get("inherit", false) == true:
			def.visual_settings.erase(field)
		else:
			def.visual_settings[field] = clampf(float(args.value), limits.x, limits.y)
	elif key.begins_with("params."):
		if not def.params.has(key.trim_prefix("params.")):
			return
		def.params[key.trim_prefix("params.")] = safe_parameter(key.trim_prefix("params."), args.value)
	else:
		if key not in ["hp", "toughness", "armor", "speed", "radius", "accel", "turn", "xp", "weak_arc", "attack_weight"]:
			return
		if key == "toughness":
			def.toughness = clampi(int(args.value), -1, 1)
		else:
			def.set(key, maxf(0.01 if key in ["hp", "radius"] else 0.0, float(args.value)))
	run.enemies.definitions[type] = def
	var t := run.enemies.table
	for i in t.alive.size():
		if not t.alive[i] or t.type[i] != type:
			continue
		var old: EnemyDef = t.def[i]
		if key == "hp" or key == "toughness":
			var ratio := t.hp[i] / maxf(0.001, t.max_hp[i])
			t.max_hp[i] *= def.base_hp(run.cfg) / maxf(old.base_hp(run.cfg), 0.001)
			t.hp[i] = t.max_hp[i] * ratio
		elif key == "armor":
			t.armor[i] *= def.armor / maxf(old.armor, 0.001)
		elif key == "speed":
			t.speed[i] *= def.speed / maxf(old.speed, 0.001)
		elif key == "radius":
			t.r[i] *= def.radius / maxf(old.radius, 0.001)
		elif key == "visual.scale":
			t.r[i] *= def.visual_value("scale", 1.0) / old.visual_value("scale", 1.0)
		t.def[i] = def

func row_for_id(id: int) -> int:
	var t := run.enemies.table
	for i in t.alive.size():
		if t.alive[i] and not t.dead[i] and t.id[i] == id:
			return i
	return -1

func seek(target: int) -> void:
	_seek_serial += 1
	var request := _seek_serial
	playing = false
	seeking = true
	var end := furthest
	target = clampi(target, 0, end)
	_cache_current()
	var nearest := -1
	for n in checkpoints.size():
		var item: Dictionary = checkpoints[n]
		if int(item.tick) <= target and item.key == _checkpoint_key(int(item.tick)) and (nearest < 0 or int(item.tick) > int(checkpoints[nearest].tick)):
			nearest = n
	if nearest >= 0:
		var item: Dictionary = checkpoints[nearest]
		checkpoints.remove_at(nearest)
		scene = item.scene
		run = item.run
		scene.process_mode = Node.PROCESS_MODE_INHERIT
		if viewport != null and scene.get_parent() == null:
			viewport.add_child(scene)
		tick = int(item.tick)
		selected = int(item.get("selected", -1))
		_cursor = int(item.cursor)
		_state_key = item.key
		_intent = item.intent
		_route_play = item.get("route_play", {}).duplicate(true)
		pinned = item.get("pinned")
		schedule = item.schedule.duplicate(true)
		events.assign(item.events.duplicate(true))
		revision += 1
	else:
		await _rebuild()
	if request != _seek_serial:
		return
	var epoch := _epoch
	while tick < target:
		for n in mini(120, target - tick):
			step()
		seek_progress.emit(float(tick) / maxf(1, target))
		await get_tree().process_frame
		if epoch != _epoch or request != _seek_serial:
			return
	furthest = end
	seeking = false
	changed.emit()

## 最後に再生を始めた時刻の状態に戻す（配置は残す）。それ以降の記録は分岐として残し、そこから新しく遊べるようにする。
## 再生を始めた時刻に記録した入力とルートの再生も取り除く（始める前の状態に戻すため）。
func back_to_play_start() -> void:
	if seeking or not is_instance_valid(run):
		return
	playing = false
	_was_playing = false
	var at := mini(play_start, furthest)
	if furthest > at or history.any(func(e): return int(e.tick) == at and String(e.kind) in ["input", "route"]):
		branches.append({"name": current_branch, "history": history.duplicate(true), "end": furthest})
		branch_serial += 1
		current_branch = TranslationServer.translate("lab.message_549e9c3c03") % branch_serial
		history = history.filter(func(e): return int(e.tick) < at or (int(e.tick) == at and String(e.kind) not in ["input", "route"]))
		furthest = at
		_cursor = 0
		# 今の場面は消した記録を含むので、保存せずに作り直す
		if is_instance_valid(scene):
			if scene.get_parent() != null:
				scene.get_parent().remove_child(scene)
			scene.queue_free()
		scene = null
		run = null
	await seek(at)

func cancel_seek() -> void:
	_seek_serial += 1
	seeking = false
	playing = false

func _run_schedule() -> void:
	if run.projectiles.director.guard_active():
		return
	for entry in schedule:
		if not entry.get("enabled", true):
			continue
		var start := roundi(float(entry.get("start", 0)) / DT)
		var interval := maxi(1, roundi(float(entry.get("interval", 1)) / DT))
		var end := roundi(float(entry.get("end", 600)) / DT)
		if tick >= start and tick <= end and (tick - start) % interval == 0:
			if run.state.rng.randf() > float(entry.get("probability", 1)): continue
			var at := vector(entry.get("pos", [0, 0])) + Vector2.from_angle(run.state.rng.randf() * TAU) * sqrt(run.state.rng.randf()) * float(entry.get("radius", 0))
			entry = entry.duplicate(true)
			entry.pos = [at.x, at.y]
			_apply("boss" if ConfigManager.bosses.has(StringName(entry.get("type", ""))) else "spawn", entry)

func digest() -> String:
	var actors := []
	for instance in run.bosses.lab_instances:
		if is_instance_valid(instance.actor):
			actors.append(_stable(instance.actor, 0))
	return str(hash(var_to_bytes([tick, baseline, _stable(run.enemies.definitions, 0), _stable(run.bosses.definitions, 0), _stable(run.state, 0), _stable(run.enemies.table, 0), _stable(run.enemies.corona, 0),
		_stable(run.projectiles, 0), _stable(run.draw, 0), _stable(run.field, 0), actors,
		run.projectiles.director.groups, run.projectiles.director.waiting, schedule])))

## オブジェクトのアドレスを比較せず、戦闘値・部位・攻撃タイマーを比較する。
func _stable(value, depth: int):
	if depth > 5: return null
	if value is RandomNumberGenerator: return [value.seed, value.state]
	if value is Dictionary:
		var out := {}
		for key in value: out[key] = _stable(value[key], depth + 1)
		return out
	if value is Array:
		var out := []
		for item in value: out.append(_stable(item, depth + 1))
		return out
	if value is Object:
		var out := {}
		for property in value.get_property_list():
			if not int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: continue
			var key: String = property.name
			var item = value.get(key)
			if item is Node or item is Callable or item is Signal or item is GDScript: continue
			if key in ["director", "manager", "combat", "field", "ship", "build", "enemies", "bosses", "projectiles", "definitions", "actor_parent", "slots", "friend_slots", "hostile_slots", "hazard_slots"]: continue
			out[key] = _stable(item, depth + 1)
		if value is BossActor and value.has_node("Timeline"):
			var timeline: AnimationPlayer = value.get_node("Timeline")
			out["timeline"] = [timeline.current_animation, timeline.current_animation_position if timeline.is_playing() else 0.0]
		return out
	return value

func _checkpoint_key(at: int) -> String:
	return str(hash(var_to_bytes([spec, history.filter(func(e): return int(e.tick) <= at)])))

## 状態をコピーせず、停止したシーン全体を保持する。HSM とタイムラインも同じ実体で復元する。
func _cache_current() -> void:
	if not is_instance_valid(scene) or not is_instance_valid(run): return
	checkpoints.append({"scene": scene, "run": run, "tick": tick, "cursor": _cursor, "intent": _intent, "route_play": _route_play.duplicate(true), "pinned": pinned,
		"schedule": schedule.duplicate(true), "events": events.duplicate(true), "selected": selected, "key": _state_key})
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	# 表示枠に残すと、保存した過去の場面も重なって描かれる
	if viewport != null and scene.get_parent() == viewport:
		viewport.remove_child(scene)
	scene = null
	run = null
	while checkpoints.size() > 3:
		var old: Dictionary = checkpoints.pop_front()
		if is_instance_valid(old.scene): old.scene.queue_free()

func definition_for_row(row: int) -> Resource:
	var t := run.enemies.table
	return run.bosses.definitions.get(t.type[row]) if t.is_boss[row] else t.def[row]

func _edit_boss_definition(args: Dictionary) -> void:
	var type := StringName(args.get("type", ""))
	var original: BossDef = run.bosses.definitions.get(type)
	if original == null or not args.has("value") or typeof(args.value) not in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]: return
	var def: BossDef = original.duplicate(true)
	var key := String(args.get("key", ""))
	if key.begins_with("params.") and def.params.has(key.trim_prefix("params.")):
		def.params[key.trim_prefix("params.")] = safe_parameter(key.trim_prefix("params."), args.value)
	elif key in ["speed", "radius", "accel", "turn", "xp", "weak_arc"]:
		def.set(key, maxf(0.01, float(args.value)))
	else:
		return
	run.bosses.definitions[type] = def
	for instance in run.bosses.lab_instances:
		if instance.has_boss() and instance.actor.def.id == type:
			instance.actor.def = def
			var row: int = instance.boss_row
			if key == "speed": run.enemies.table.speed[row] = def.speed
			if key == "radius": run.enemies.table.r[row] = def.radius * run.cfg.character_scale

static func safe_parameter(key: String, value):
	if value is bool: return value
	var number := float(value)
	if not is_finite(number): return 0.01
	if key in ["telegraph", "windup", "life", "recover"] or key.ends_with("_interval") or key.ends_with("_time") or key.ends_with("_delay") or key.ends_with("_cd"):
		number = clampf(number, 0.01, 100000)
	if key in ["volley", "layers", "strikes", "stars", "rubble_count", "shards", "lump_max", "throw_min", "death_split"]:
		number = clampf(number, 1, 512)
	return int(number) if value is int else number

func undo_edit() -> void:
	if edit_undo.is_empty() or seeking: return
	edit_redo.append({"history": history.duplicate(true), "end": furthest, "tick": tick})
	var item: Dictionary = edit_undo.pop_back()
	history.assign(item.history)
	furthest = int(item.end)
	await seek(int(item.tick))

func redo_edit() -> void:
	if edit_redo.is_empty() or seeking: return
	edit_undo.append({"history": history.duplicate(true), "end": furthest, "tick": tick})
	var item: Dictionary = edit_redo.pop_back()
	history.assign(item.history)
	furthest = int(item.end)
	await seek(int(item.tick))
