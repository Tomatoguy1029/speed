## 竜の本体。候補選択は共通フロー、各技は開始・更新・取消の契約で接続する。
extends BossActor
signal presentation_event(event: Dictionary)
var phase := 1
var mode: StringName = &"idle"
var technique: StringName = &""
var _cooldown := 0.0
var clock := 0.0
var elapsed := 0.0
var aim := Vector2.ZERO
var direction := Vector2.RIGHT
var attack_hit := false
var placed_meteors: Array = []
var telegraph_points := PackedVector2Array()
var attack_points := PackedVector2Array()
var _driver: RefCounted
var selection_enabled := false
var action_rules: Resource
var flow_runner := preload("res://scripts/bosses/flow/runner.gd").new()
var flow_adapter: RefCounted
var _moves: Dictionary = {}
var body_rows: Array[int] = []
var body_ids: Array[int] = []
var _presentation: Node2D

func _on_bound() -> void:
	draws_self = true
	_presentation = load("res://scripts/bosses/draco_presentation.gd").new()
	add_child(_presentation)
	_presentation.actor = self
	presentation_event.connect(_presentation.on_event)
	for j in 12:
		var row := ctx.enemies.spawn_boss(&"draco", table.pos[body], 46.0, def.hp, def.armor, 0.0, 0.0, 0.0, 0.0, Color("#544475"))
		table.parent[row] = body
		table.parent_id[row] = body_id
		body_rows.append(row)
		body_ids.append(table.id[row])
	_update_body()
	if ResourceLoader.exists("res://.content/boss_draco.tres"):
		configure_flow(load("res://.content/boss_draco.tres"))
	selection_enabled = not run_state.lab_mode

func configure_flow(program: Resource) -> void:
	selection_enabled = true
	action_rules = program.data.rules
	_moves.clear()
	for move in action_rules.techniques: _moves[move.technique] = move
	flow_runner.configure(program.data.flow)
	flow_runner.selector.random = run_state.rng
	flow_adapter = preload("res://scripts/bosses/flow/single_actor_adapter.gd").new(self)

func body_points() -> PackedVector2Array:
	var points := PackedVector2Array([table.pos[body]])
	for j in 12:
		var t := float(j + 1) / 12.0
		points.append(table.pos[body] + Vector2(-t * 680.0, sin(t * TAU * 1.4 - clock) * 120.0 * t).rotated(table.facing[body]))
	return points

func _update_body() -> void:
	var points := body_points()
	for j in body_rows.size():
		if ctx.enemies.is_same(body_rows[j], body_ids[j]):
			table.pos[body_rows[j]] = points[j + 1]
			table.guard[body_rows[j]] = table.guard[body]

func damage_target(row: int) -> int:
	return body if row == body or row in body_rows else row

func _exit_tree() -> void:
	for j in body_rows.size():
		if ctx.enemies.is_same(body_rows[j], body_ids[j]): ctx.enemies.mark_dead(body_rows[j])

func rule() -> Dictionary:
	return _moves[technique].parameters if _moves.has(technique) else def.params

func start_attack(id: StringName) -> bool:
	if mode != &"idle" or not _moves.has(id): return false
	technique = id
	mode = &"windup"
	elapsed = 0.0
	attack_hit = false
	aim = run_state.enemy_aim
	direction = (aim - table.pos[body]).normalized()
	table.facing[body] = direction.angle()
	_driver = rule().driver.new() if rule().has("driver") else null
	if _driver != null: _driver.begin(self)
	return true

func attack_playing() -> bool:
	return mode != &"idle"

func sim_tick(_real_dt: float, dt: float) -> void:
	if dt <= 0.0 or not body_alive(): return
	clock += dt
	elapsed += dt
	if mode == &"windup" and _driver != null and _driver.has_method("windup"): _driver.windup(self,dt)
	if mode == &"windup" and elapsed >= float(rule().warn):
		mode = &"active"
		elapsed = 0.0
	elif mode == &"transition":
		if elapsed >= float(def.params.get("phase_time",1.0)):
			mode = &"idle"
			table.guard[body] = 0.0
	elif mode == &"active":
		if _driver != null: _driver.tick(self,dt)
		else:
			var tip := table.pos[body] + direction * float(rule().reach)
			hit_segment(PackedVector2Array([table.pos[body],tip]),float(rule().width))
		if elapsed >= float(rule().active):
			if _driver != null: _driver.end(self,false)
			_driver = null
			mode = &"recovery"
			elapsed = 0.0
	elif mode == &"recovery" and elapsed >= float(rule().recover):
		mode = &"idle"
		technique = &""
	_update_body()
	_presentation.queue_redraw()
	if selection_enabled and mode == &"idle" and flow_adapter != null:
		flow_runner.tick(dt, {"player": run_state.enemy_aim}, flow_adapter)

func cancel_attack() -> void:
	if _driver != null: _driver.end(self,true)
	_driver = null
	attack_points.clear()
	mode = &"idle"
	technique = &""
	elapsed = 0.0

func handle_body_defeat(_opts: Dictionary) -> bool:
	cancel_attack()
	return false

func selection_blocked() -> bool:
	return not body_alive() or mode in [&"transition", &"finale", &"deep"]
func can_begin_sequence() -> bool:
	return mode == &"idle"
func attack_failed() -> bool:
	return not body_alive()
func technique_ready(id: StringName, gate: Dictionary) -> bool:
	return mode == &"idle" and _moves.has(id) and phase >= int(gate.get("min_phase", 1)) and preload("res://scripts/bosses/flow/range_condition.gd").allows(gate, (run_state.enemy_aim-table.pos[body]).rotated(-table.facing[body]))

func on_body_damaged() -> void:
	var thresholds: Array = def.params.get("thresholds", [0.7, 0.4])
	if phase > thresholds.size(): return
	var floor_hp := table.max_hp[body] * float(thresholds[phase - 1])
	if table.hp[body] > floor_hp: return
	table.hp[body] = floor_hp
	cancel_attack()
	for rock: FieldSystem.Rock in placed_meteors:
		rock.destroyed = true
		if ctx.enemies.is_same(rock.row,rock.row_id): ctx.enemies.mark_dead(rock.row)
	placed_meteors.clear()
	phase += 1
	mode = &"transition"
	elapsed = 0.0
	table.guard[body] = 1.0
	_update_body()
	presentation_event.emit({"cue": &"phase_changed", "phase": phase})

func hit_segment(points: PackedVector2Array, width: float, prior := PackedVector2Array()) -> void:
	if attack_hit: return
	var radius := width + ctx.cfg.ship_radius
	var hit := Geometry2D.get_closest_point_to_segment(run_state.ship_pos,points[0],points[1]).distance_to(run_state.ship_pos) <= radius
	if prior.size() == 2:
		hit = hit or Geometry2D.is_point_in_polygon(run_state.ship_pos,PackedVector2Array([prior[0],prior[1],points[1],points[0]]))
	if hit:
		ctx.ship.damage(float(rule().damage) * ctx.cfg.atk_scale,0.0,technique,&"draco")
		attack_hit = true
