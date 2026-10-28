## 竜の本体。候補選択は共通フロー、各技は開始・更新・取消の契約で接続する。
extends BossActor
signal presentation_event(event: Dictionary)
var entrance: RefCounted
var finale: RefCounted
var cycle: RefCounted
var picaro: RefCounted
var phase := 1
var mode: StringName = &"idle"
var technique: StringName = &""
var _cooldown := 0.0
var attack_serial := 0
var attack_token := 0
var clock := 0.0
var elapsed := 0.0
var aim := Vector2.ZERO
var direction := Vector2.RIGHT
var attack_hit := false
var closing_walls: Array = []
var placed_meteors: Array = []
var telegraph_points := PackedVector2Array()
var attack_points := PackedVector2Array()
var body_override := PackedVector2Array()
var body_trail := PackedVector2Array()
var body_pose := PackedVector2Array()
## Combat dimensions are authored once. Poses change the spine, not the size of the animal.
var body_length := 1500.0
var body_width := 154.0
var head_scale := 1.35
var body_segments := 128
var perspective_scale := 1.0
var telegraph_paths: Array[PackedVector2Array] = []
var telegraph_widths: Array[float] = []
## 塗りで見せる予告の範囲。polygon（ワールド座標）を塗り、center から外へ広がる塗りで予告の進みを示す。
var telegraph_areas: Array[Dictionary] = []
var attack_width := 45.0
var mouth_open := 0.0
var cosmic_body := false
const FORM = preload("res://scripts/bosses/draco_form.gd")
var technique_visuals := preload("res://scripts/bosses/technique_visuals.gd").new()
var _driver: RefCounted
var selection_enabled := false
var action_rules: Resource
var flow_runner := preload("res://scripts/bosses/flow/runner.gd").new()
var flow_adapter: RefCounted
var _moves: Dictionary = {}
## 実験場で吸い込みを試すとき、吸い込んだことにする星の数。ゲーム中は吸い込んだピカロの星を数える。
var lab_inhale_stars := 12
var retained_fields: Array = []
var clone_damage_rows: Dictionary = {}
var body_rows: Array[int] = []
var body_ids: Array[int] = []
var _presentation: Node2D

func _on_bound() -> void:
	draws_self = true
	body_length = float(def.params.get("body_length",1500.0))
	body_width = float(def.params.get("body_width",154.0))
	head_scale = float(def.params.get("head_scale",1.35))
	body_segments = int(def.params.get("body_segments",128))
	entrance = preload("res://scripts/bosses/draco_entrance.gd").new(self)
	finale = preload("res://scripts/bosses/draco_finale.gd").new(self)
	cycle = preload("res://scripts/bosses/draco_cycle.gd").new(self)
	picaro = preload("res://scripts/bosses/draco_picaro.gd").new(self)
	_presentation = load("res://scenes/bosses/draco_presentation.tscn").instantiate()
	add_child(_presentation)
	_presentation.actor = self
	presentation_event.connect(_presentation.on_event)
	presentation_event.connect(technique_visuals.event)
	for j in body_segments:
		var row := ctx.enemies.spawn_boss(&"draco", table.pos[body], body_width*0.5, def.hp, def.armor, 0.0, 0.0, 0.0, 0.0, Color("#544475"))
		table.parent[row] = body
		table.parent_id[row] = body_id
		body_rows.append(row)
		body_ids.append(table.id[row])
	_update_body()
	if ResourceLoader.exists("res://.content/boss_draco.tres"):
		configure_flow(load("res://.content/boss_draco.tres"))
	selection_enabled = not run_state.lab_mode
	if not run_state.lab_mode: entrance.begin()

func configure_flow(program: Resource) -> void:
	selection_enabled = true
	action_rules = program.data.rules
	_moves.clear()
	for move in action_rules.techniques: _moves[move.technique] = move
	technique_visuals.configure(self, _moves)
	flow_runner.configure(program.data.flow)
	flow_runner.selector.random = run_state.rng
	flow_adapter = preload("res://scripts/bosses/flow/single_actor_adapter.gd").new(self)

func neutral_body_points(head: Vector2, angle: float) -> PackedVector2Array:
	var points := PackedVector2Array([head])
	for j in body_segments:
		var t := float(j+1)/float(body_segments)
		var wave := sin(t*TAU*1.25-clock*0.75)*float(def.params.get("body_wave",180.0))*sin(t*PI*0.8)
		points.append(head+Vector2(-t*body_length,wave).rotated(angle))
	var length := FORM.length(points)
	if length>0.001:
		for j in points.size(): points[j]=head+(points[j]-head)*(body_length/length)
	return points

func body_points() -> PackedVector2Array:
	var points := body_override.duplicate() if not body_override.is_empty() else (body_pose.duplicate() if not body_pose.is_empty() else neutral_body_points(table.pos[body],table.facing[body]))
	if not is_equal_approx(perspective_scale,1.0):
		var head: Vector2 = table.pos[body]
		for j in points.size(): points[j] = head+(points[j]-head)*perspective_scale
	return points

func aim_target(lead_seconds := 0.0) -> Vector2:
	if run_state.tracing:
		return run_state.enemy_aim
	var lead: Vector2 = run_state.ship_vel*maxf(0.0,lead_seconds)
	return run_state.ship_pos+lead.limit_length(float(def.params.get("aim_lead_cap",280.0)))

func mouth_pos() -> Vector2:
	return table.pos[body]+Vector2.from_angle(table.facing[body])*120.0*head_scale*perspective_scale

func mouth_position() -> Vector2:
	return mouth_pos()

func chest_pos() -> Vector2:
	return table.pos[body]-Vector2.from_angle(table.facing[body])*110.0*head_scale*perspective_scale

func apply_depth(depth: float, alpha := 1.0) -> void:
	perspective_scale = clampf(depth,0.1,1.0)
	_presentation.scale = Vector2.ONE
	_presentation.modulate.a = clampf(alpha,0.0,1.0)
	_update_body()

func reset_pose() -> void:
	if has_body() and is_equal_approx(perspective_scale,1.0):
		body_trail = body_override.duplicate() if not body_override.is_empty() else body_points()
	else:
		body_trail.clear()
	body_override.clear()
	body_pose.clear()
	body_width = float(def.params.get("body_width",154.0))
	head_scale = float(def.params.get("head_scale",1.35))
	perspective_scale = 1.0
	if _presentation != null:
		_presentation.scale = Vector2.ONE
		_presentation.modulate = Color.WHITE
		_presentation.visible = true
	if has_body(): _update_body()

func _update_body() -> void:
	if body_override.is_empty():
		var followed: Dictionary = FORM.follow_trail(body_trail if not body_trail.is_empty() else neutral_body_points(table.pos[body],table.facing[body]), table.pos[body], body_length, body_segments + 1)
		body_trail = followed.trail
		body_pose = followed.points
	position = table.pos[body]
	rotation = table.facing[body]
	var points := body_points()
	var row_points := FORM.samples_even(points, body_rows.size(), false)
	table.r[body] = def.radius*head_scale*perspective_scale
	for j in body_rows.size():
		if ctx.enemies.is_same(body_rows[j],body_ids[j]):
			var fraction := float(j+1)/float(body_rows.size())
			table.pos[body_rows[j]] = row_points[j]
			table.guard[body_rows[j]] = table.guard[body]
			table.r[body_rows[j]] = body_width*0.5*FORM.taper(fraction)*perspective_scale

func damage_target(row: int) -> int:
	if clone_damage_rows.has(row):
		var target: Dictionary=clone_damage_rows[row]
		if table.id[row]==int(target.part_id) and ctx.enemies.is_same(target.row,target.id): return int(target.row)
	return body if row==body or row in body_rows else row

func owns_damage_target(row: int) -> bool:
	if super.owns_damage_target(row): return true
	for target: Dictionary in clone_damage_rows.values():
		if int(target.row)==row and ctx.enemies.is_same(row,int(target.id)): return true
	return false

func _exit_tree() -> void:
	if _driver != null: _driver.end(self,true)
	if entrance != null: entrance.cancel()
	if finale != null: finale.dispose()
	if cycle != null: cycle.cancel()
	if picaro != null: picaro.dispose()
	for j in body_rows.size():
		if ctx.enemies.is_same(body_rows[j], body_ids[j]): ctx.enemies.mark_dead(body_rows[j])

func rule() -> Dictionary:
	return _moves[technique].values() if _moves.has(technique) else def.params

func start_attack(id: StringName) -> bool:
	if mode != &"idle" or not _moves.has(id):
		combat_trace.event("boss_action", {"step": "start_rejected", "requested_action": String(id), "reason": "busy" if mode != &"idle" else "unknown_technique", "origin": combat_origin, "action_id": null})
		return false
	if selection_enabled and ctx.projectiles.director != null:
		var director: RefCounted=ctx.projectiles.director
		var key := "draco:%d:%d" % [body_id,attack_serial]
		var p: Dictionary=_moves[id].values()
		if not director.request(key,["beam" if id in [&"breath",&"inhale"] else "aimed"],body,body_id,float(p.warn)+float(p.active)+float(p.recover),1.5,1.0):
			combat_trace.event("boss_action", {"step": "start_rejected", "requested_action": String(id), "reason": "attack_budget", "origin": combat_origin, "action_id": null})
			return false
		attack_token=director.token(key)
		ctx.projectiles.lab_context=attack_token
		attack_serial+=1
	if id != &"picaro_wall": picaro.pause(false)
	reset_pose()
	telegraph_points.clear()
	telegraph_paths.clear()
	telegraph_widths.clear()
	telegraph_areas.clear()
	combat_trace.begin(id, combat_origin)
	technique = id
	attack_width = float(rule().get("width",45.0))
	mode = &"windup"
	elapsed = 0.0
	attack_hit = false
	aim = aim_target()
	direction = Vector2.from_angle(table.facing[body]) if id == &"tail_sweep" else (aim - table.pos[body]).normalized()
	var screen_staged := id in [&"leap", &"charge", &"rifts"]
	if not screen_staged: table.facing[body] = direction.angle()
	_driver = _moves[id].make_runner()
	if _driver == null and rule().has("driver"): _driver = rule().driver.new()
	var prior_observer := ctx.bosses.recording_actor
	if combat_trace.enabled(): ctx.bosses.recording_actor = self
	if _driver != null: _driver.begin(self)
	ctx.bosses.recording_actor = prior_observer
	combat_trace.stage("reposition" if screen_staged else "telegraph")
	if not screen_staged and (_driver == null or not ("locked" in _driver)): combat_trace.stage("lock", {"scope": "initial_aim"})
	_update_body()
	_sync_technique_visuals()
	_presentation.queue_redraw()
	return true

func attack_playing() -> bool:
	return mode != &"idle"

func sim_tick(_real_dt: float, dt: float) -> void:
	if dt <= 0.0 or not body_alive(): return
	if attack_token>0: ctx.projectiles.lab_context=attack_token
	clock += dt
	if entrance.tick(dt):
		_update_body();_presentation.queue_redraw()
		return
	for host: Node in retained_fields.duplicate():
		host.attack_field.tick(dt)
		if host.attack_field.effects.is_empty():
			host.queue_free();retained_fields.erase(host)
	picaro.tick()
	_update_closing_walls(dt)
	if cycle.tick(dt):
		_update_body()
		_presentation.queue_redraw()
		return
	var prior_observer := ctx.bosses.recording_actor
	if combat_trace.enabled(): ctx.bosses.recording_actor = self
	elapsed += dt
	# なぞり中は予告の狙いを固定する。渦の中心移動は構図維持なので対象外。
	if mode == &"windup" and run_state.tracing and technique not in [&"spiral", &"charge", &"leap", &"rifts"] and _driver != null and "locked" in _driver and not _driver.locked:
		_driver.locked = true
		combat_trace.stage("lock", {"scope": "trace_aim"})
	if mode == &"windup" and _driver != null and _driver.has_method("windup"): _driver.windup(self,dt)
	# 予告の間に自機を追わない技は、画面外からの配置を終えて最初に狙った時点で固定する。渦の中心移動は構図維持なので対象外。
	if mode == &"windup" and technique != &"spiral" and _driver != null and "locked" in _driver and not _driver.locked \
			and _moves.has(technique) and not _moves[technique].track_during_warn \
			and (not "staging" in _driver or _driver.staging.is_empty() or _driver.staging.get("phase", &"ready") == &"ready"):
		_driver.locked = true
		combat_trace.stage("lock", {"scope": "warn_tracking_off"})
	if mode == &"windup" and elapsed >= float(rule().warn):
		mode = &"active"
		elapsed = 0.0
		combat_trace.stage("execute")
	elif mode == &"transition":
		if elapsed >= float(def.params.get("phase_time",1.0)):
			mode = &"idle"
			table.guard[body] = 0.0
			run_state.encounter_protected=false
	elif mode == &"active":
		if _driver != null: _driver.tick(self,dt)
		else:
			var tip := table.pos[body] + direction * float(rule().reach)
			hit_segment(PackedVector2Array([table.pos[body],tip]),float(rule().width))
		if elapsed >= float(rule().active):
			if _driver != null: _driver.end(self,false)
			mode = &"recovery"
			elapsed = 0.0
			combat_trace.stage("recovery")
	elif mode == &"recovery":
		if _driver != null and _driver.has_method("recover"): _driver.recover(self,dt)
		if elapsed >= float(rule().recover):
			combat_trace.finish()
			_driver = null
			mode = &"idle"
			technique = &""
			telegraph_points.clear();telegraph_paths.clear();telegraph_widths.clear();telegraph_areas.clear()
			attack_points.clear()
			reset_pose()
	ctx.bosses.recording_actor = prior_observer
	_update_body()
	_sync_technique_visuals()
	_presentation.queue_redraw()
	if selection_enabled and mode == &"idle" and flow_adapter != null:
		var delta := aim_target()-table.pos[body]
		if delta.length()>float(def.params.get("approach_distance",900.0)):
			table.pos[body]+=delta.normalized()*def.speed*dt
			table.facing[body]=delta.angle()
		flow_runner.tick(dt, {"player": run_state.ship_pos}, flow_adapter)

func _sync_technique_visuals() -> void:
	mouth_open = 0.0
	cosmic_body = false
	if _driver != null: _driver.pose(self)
	var key := "recover" if mode == &"recovery" else "warn" if mode == &"windup" else "active"
	technique_visuals.sync(technique, mode, elapsed, float(rule().get(key, 1.0)))

func cancel_attack() -> void:
	combat_trace.finish("interrupted", "cancelled")
	if _driver != null: _driver.end(self,true)
	_driver = null
	attack_points.clear()
	telegraph_points.clear();telegraph_paths.clear();telegraph_widths.clear();telegraph_areas.clear()
	reset_pose()
	mode = &"idle"
	technique = &""
	elapsed = 0.0
	_sync_technique_visuals()

func handle_body_defeat(_opts: Dictionary) -> bool:
	if mode != &"finale":
		combat_trace.finish("interrupted", "finale")
		combat_trace.stage("finale", {"origin": "scripted_finale"})
		finale.begin()
	return true
func advance_finale(real_dt: float, intent: Intent) -> void:
	finale.advance(real_dt,intent)

func selection_blocked() -> bool:
	return not body_alive() or mode in [&"transition", &"finale", &"deep"]
func can_begin_sequence() -> bool:
	return mode == &"idle" and closing_walls.is_empty()
func attack_failed() -> bool:
	return not body_alive()
func technique_ready(id: StringName, gate: Dictionary) -> bool:
	return technique_rejection(id, gate).is_empty()

func technique_rejection(id: StringName, gate: Dictionary) -> String:
	if mode != &"idle": return "busy"
	if not closing_walls.is_empty(): return "closing_walls"
	if not _moves.has(id): return "unknown_technique"
	if phase < int(gate.get("min_phase", 1)) or phase > int(gate.get("max_phase", 3)): return "phase"
	var relative := (run_state.ship_pos-table.pos[body]).rotated(-table.facing[body])
	if relative.length() < float(gate.get("min", 0.0)): return "distance_below_min"
	if relative.length() > float(gate.get("max", 100000.0)): return "distance_above_max"
	if not preload("res://scripts/bosses/flow/range_condition.gd").allows(gate, relative): return "direction_gate"
	return ""

func on_body_damaged() -> void:
	var thresholds: Array = def.params.get("thresholds", [0.7, 0.4])
	if phase > thresholds.size(): return
	var floor_hp := table.max_hp[body] * float(thresholds[phase - 1])
	if table.hp[body] > floor_hp: return
	table.hp[body] = floor_hp
	combat_trace.finish("interrupted", "phase_transition")
	cancel_attack()
	for rock: FieldSystem.Rock in placed_meteors:
		rock.destroyed = true
		if ctx.enemies.is_same(rock.row,rock.row_id): ctx.enemies.mark_dead(rock.row)
	placed_meteors.clear()
	cycle.cancel()
	picaro.pause(true)
	run_state.encounter_protected=true
	phase += 1
	combat_trace.event("boss_phase", {"reason": "hp_threshold"})
	mode = &"transition"
	elapsed = 0.0
	table.guard[body] = 1.0
	_update_body()
	if phase == 2: cycle.begin_initial()
	presentation_event.emit({"cue": &"phase_changed", "phase": phase})

func hit_segment(points: PackedVector2Array, width: float, prior := PackedVector2Array()) -> void:
	if attack_hit or points.size()<2: return
	combat_trace.evaluate()
	attack_width = width
	var radius := width + ctx.cfg.ship_radius
	var hit := Geometry2D.get_closest_point_to_segment(run_state.ship_pos,points[0],points[1]).distance_to(run_state.ship_pos) <= radius
	if prior.size() == 2:
		var sweep := PackedVector2Array([prior[0],prior[1],points[1],points[0]])
		hit = hit or Geometry2D.is_point_in_polygon(run_state.ship_pos,sweep)
		for j in sweep.size():
			if Geometry2D.get_closest_point_to_segment(run_state.ship_pos,sweep[j],sweep[(j+1)%sweep.size()]).distance_to(run_state.ship_pos)<=radius: hit=true
	if hit:
		attack_hit = combat_trace.damage(float(rule().damage) * ctx.cfg.atk_scale,0.0,technique,&"draco")

func contains_hit(point: Vector2, radius: float) -> bool:
	if table.guard[body]>=1.0: return false
	if super(point,radius): return true
	var points := body_points()
	var fractions := FORM.fractions(points)
	for j in range(points.size()-1):
		var nearest := Geometry2D.get_closest_point_to_segment(point,points[j],points[j+1])
		var segment := points[j].distance_to(points[j+1])
		var along := nearest.distance_to(points[j])/maxf(0.001,segment)
		var fraction := lerpf(fractions[j],fractions[j+1],along)
		var width := body_width*0.5*FORM.taper(fraction)*perspective_scale
		if nearest.distance_to(point)<=width+radius: return true
	return false

func close_wall(h: int, duration: float, delay := 0.0) -> void:
	var ps := ctx.projectiles
	if not ps.owns_hazard(h,body,body_id): return
	ps.hazard_dmg[h] = 0.0
	closing_walls.append({"h":h,"time":duration,"duration":duration,"delay":delay,"from":ps.hazard_pos[h],"length":ps.hazard_len[h],"width":ps.hazard_width[h],"angle":ps.hazard_angle[h]})

func _update_closing_walls(dt: float) -> void:
	var ps := ctx.projectiles
	for wall: Dictionary in closing_walls.duplicate():
		var h := int(wall.h)
		if float(wall.get("delay",0.0))>0.0:
			wall.delay = maxf(0.0,float(wall.delay)-dt)
			continue
		wall.time = float(wall.time)-dt
		if not ps.owns_hazard(h,body,body_id) or float(wall.time)<=0.0:
			if ps.owns_hazard(h,body,body_id): ps.release_hazard(h)
			closing_walls.erase(wall)
			continue
		var f := float(wall.time)/float(wall.duration)
		ps.hazard_len[h] = float(wall.length)*f
		ps.hazard_width[h] = float(wall.width)*f
		ps.hazard_pos[h] = wall.from+Vector2.from_angle(float(wall.angle))*float(wall.length)*(1.0-f)*0.5

func contains_additional_target(row: int, point: Vector2, radius: float) -> bool:
	for part: int in clone_damage_rows:
		var target: Dictionary=clone_damage_rows[part]
		if int(target.row)!=row or not ctx.enemies.is_same(row,target.id) or not ctx.enemies.is_same(part,target.part_id): continue
		if point.distance_to(table.pos[part])<=table.r[part]+radius:return true
	return false
