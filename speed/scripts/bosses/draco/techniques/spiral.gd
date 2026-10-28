## 螺旋収縮の値と動き。
@tool
extends BossTechnique

## 予告（秒）
@export_range(0,100000,0.01) var warn := 5.0
## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 6.0
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.5
## ダメージ
@export_range(0,100000,0.01) var damage := 35.0
## 外周半径（画面長辺の倍率）
@export_range(0.5,1.5,0.01) var radius_factor := 0.8
## 外周の縦横比
@export_range(0.85,1.5,0.01) var aspect_ratio := 1.0
## 内周半径（画面長辺の倍率）
@export_range(0.05,1.5,0.01) var inner_radius_factor := 0.16
## 渦を2周巻く時間（秒）
@export_range(0.5,3,0.01) var coil_time := 1.2
## 逃げる時間（秒）
@export_range(0.8,3,0.01) var pause := 1.6
## 頭と自機の距離
@export_range(200,1000,1) var head_offset := 320.0
## 退場の時間（秒）
@export_range(0.6,3,0.01) var exit_duration := 1.8
## 渦を巻く間の体長（距離）
@export_range(0,20000,1) var spiral_length := 9000.0
## 直進して渦がほどける時間（秒）
@export_range(0,100000,0.01) var shrink_time := 2.0
## 胴に触れたあとの無敵（秒）
@export_range(0,100000,0.01) var touch_invuln := 1.5

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends BossTechnique.Runner:
	const FORM = preload("res://scripts/bosses/draco_form.gd")
	const STATE = preload("res://scripts/bosses/draco_cinematic_state.gd")
	var staging: Dictionary
	var center := Vector2.ZERO
	var extent := 1000.0
	var horizontal_extent := 1000.0
	var spiral_length := 6200.0
	## 巻き終わりの内周半径の、外周半径に対する割合。2周かけて 1 からこの値まで縮める。
	var inner_ratio := 0.2
	var coil_time := 1.2
	var first_lap_time := 0.48
	var second_lap_time := 0.72
	var bend_time := 0.24
	var bend_radius := 220.0
	var launch_direction := Vector2.DOWN
	var pause_time := 1.6
	var shrink_time := 2.0
	var head_offset := 320.0
	var end_correction := Vector2.ZERO
	var locked := false
	var charging := false
	var camera_zoom_target := 1.0
	var camera_was_cinematic := false
	var points := PackedVector2Array()
	var trail := PackedVector2Array()
	var walls: Array[int] = []
	var trapped := false
	var trapped_hit := false
	## 巻いている途中の胴に触れて被弾したかを見分けるための、前の更新の機体HP。
	var _hp_before := INF
	var entry := PackedVector2Array()
	var recovery_head := Vector2.ZERO
	var departing := true
	var departure_time := 0.0
	var departure_angle := 0.0
	var holding_player := false
	var held_ship_pos := Vector2.ZERO
	var controls_before := false
	var protection_before := false
	func begin(a: BossActor) -> void:
		center = a.aim_target()
		camera_was_cinematic = a.run_state.cinematic_camera
		camera_zoom_target = a.run_state.camera_zoom * 0.82
		var p: Dictionary = a.rule()
		var filmed_half: Vector2 = a.run_state.view_half / 0.82
		var broad: float = maxf(filmed_half.x, filmed_half.y) * clampf(float(p.radius_factor),0.5,1.5)
		var aspect: float = clampf(float(p.get("aspect_ratio",1.0)),0.85,1.5)
		var narrow: float = broad / aspect
		if filmed_half.x >= filmed_half.y:
			horizontal_extent = maxf(a.body_width * 4.0, broad)
			extent = maxf(a.body_width * 4.0, narrow)
		else:
			horizontal_extent = maxf(a.body_width * 4.0, narrow)
			extent = maxf(a.body_width * 4.0, broad)
		# Keep a gap between the innermost body and the head's escape corridor.
		# This bound uses the same head/body/ship radii as their contact checks.
		var inner_clearance: float = a.table.r[a.body] + a.body_width * 0.5 + a.ctx.cfg.ship_radius * 2.0 + 40.0
		var minimum_extent: float = a.body_width * 3.0 + inner_clearance
		horizontal_extent = maxf(horizontal_extent, minimum_extent)
		extent = maxf(extent, minimum_extent)
		spiral_length = float(p.spiral_length)
		var short_extent: float = minf(extent, horizontal_extent)
		# 内周は頭の通り道を残し、隣の周とは胴幅1.5本分の間をあける。
		var smallest: float = minf(1.0, inner_clearance / short_extent)
		var largest: float = maxf(smallest, 1.0 - a.body_width * 3.0 / short_extent)
		inner_ratio = clampf(float(p.get("inner_radius_factor", 0.16)) / clampf(float(p.radius_factor),0.5,1.5), smallest, largest)
		var active_time: float = maxf(0.5,float(p.active))
		shrink_time = clampf(float(p.shrink_time),0.3,maxf(0.3,active_time*0.5))
		coil_time = clampf(float(p.get("coil_time",1.2)),0.5,minf(3.0,maxf(0.5,active_time-shrink_time-0.8)))
		pause_time = clampf(float(p.pause),0.8,minf(3.0,maxf(0.8,active_time-shrink_time-coil_time-0.15)))
		first_lap_time = coil_time*0.35
		second_lap_time = coil_time*0.45
		bend_time = coil_time*0.2
		var clearance: float = a.table.r[a.body]+a.ctx.cfg.ship_radius+60.0
		head_offset = clampf(float(p.get("head_offset",320.0)),clearance,maxf(clearance,extent*(1.0+inner_ratio)*0.5*0.8))
		bend_radius = minf(head_offset,minf(extent,horizontal_extent)*0.34)
		launch_direction = Vector2.DOWN
		locked = false
		charging = false
		end_correction = Vector2.ZERO
		departing = true
		departure_time = 0.0
		holding_player = false
		controls_before = a.run_state.controls_locked
		protection_before = a.run_state.encounter_protected
		a.run_state.cinematic_camera = true
		entry = FORM.samples_even(a.body_points(), a.body_segments + 1)
		departure_angle = (entry[0] - entry[1]).angle()
		a.table.facing[a.body] = departure_angle
		trail = entry.duplicate()
		points = entry.duplicate()
		walls.clear()
		a.picaro.pause(true)
		a.telegraph_points.clear()
		a.body_override = points
	func windup(a: BossActor, dt: float) -> void:
		_camera_tick(a, dt)
		if departing:
			departure_time += dt
			var turn := smoothstep(0.0, 0.55, departure_time)
			var direction := Vector2.from_angle(lerp_angle(departure_angle, -PI * 0.5, turn))
			var exit_duration: float = clampf(float(a.rule().get("exit_duration",1.8)),0.6,3.0)
			var speed: float = maxf((a.body_length + a.run_state.view_half.y * 2.0 + a.body_width * 2.0) / exit_duration,
				maxf(0.0,-a.run_state.ship_vel.y) + 1100.0)
			var head: Vector2 = a.table.pos[a.body] + direction * speed * dt
			_set_head(a, head, a.body_length)
			if _entire_body_offscreen(a):
				_begin_reentry(a)
			else:
				# The common attack clock may not start the spiral while any segment is visible.
				a.elapsed = minf(a.elapsed, float(a.rule().warn) - 1.01)
			return
		var shift := _follow_center(a, dt)
		for key in ["outside", "control", "inside"]: staging[key] += shift
		for j in trail.size(): trail[j] += shift
		var progress := clampf(a.elapsed - (float(a.rule().warn) - 1.0), 0.0, 1.0)
		var head: Vector2 = (staging.outside as Vector2).lerp(staging.control, progress).lerp((staging.control as Vector2).lerp(staging.inside, progress), progress)
		_set_head(a, head, spiral_length)
	func tick(a: BossActor, _dt: float) -> void:
		var p: Dictionary = a.rule()
		var wrap := coil_time
		var shrink_at := wrap + pause_time
		if a.elapsed < wrap:
			if not holding_player:
				held_ship_pos = a.run_state.ship_pos
				# The last quarter turn runs left from this point and ends above the
				# held player, already tangent to the inward launch direction.
				end_correction = held_ship_pos + Vector2(bend_radius,-head_offset-bend_radius) - (center + Vector2.UP*extent*inner_ratio)
				holding_player = true
				a.run_state.controls_locked = true
				a.run_state.encounter_protected = true
			a.run_state.ship_pos = held_ship_pos
			a.run_state.ship_vel = Vector2.ZERO
		elif holding_player:
			_release_player(a)
		if a.elapsed >= wrap and not charging:
			charging = true
			# The warning marks the committed aim. Keep the opened escape lane in
			# world space while the player moves during the pause.
			# 頭は自機の真上で巻き終わるので、真下へまっすぐ突っ込む。
			launch_direction = Vector2.DOWN
			locked = true
			a.combat_trace.stage("lock", {"scope": "spiral_departure"})
			a.run_state.emit(&"draco_roar", {"pos": center, "radius": minf(horizontal_extent, extent) * 0.8})
		if not locked and not holding_player:
			var shift := _follow_center(a, _dt)
			for j in trail.size(): trail[j] += shift
			for j in entry.size(): entry[j] += shift
		_camera_tick(a, _dt)
		a.telegraph_paths.clear()
		a.telegraph_widths.clear()
		if a.elapsed >= wrap and a.elapsed < shrink_at:
			a.telegraph_paths.append(PackedVector2Array([a.table.pos[a.body], a.table.pos[a.body] + launch_direction * extent * 2.0]))
			a.telegraph_widths.append(a.body_width * 0.5)
		var turns: float = a.elapsed / first_lap_time if a.elapsed < first_lap_time else 1.0 + (a.elapsed - first_lap_time) / second_lap_time
		turns = clampf(turns, 0.0, 2.0)
		var shrink := clampf((a.elapsed - shrink_at) / shrink_time, 0.0, 1.0)
		var angle := -PI * 0.5 - turns * TAU
		# 外周から内周まで、2周かけて半径を少しずつ縮める。
		var radius_scale := lerpf(1.0, inner_ratio, turns * 0.5)
		var coil_head := center + Vector2(cos(angle) * horizontal_extent, sin(angle) * extent) * radius_scale + end_correction*smoothstep(1.0,2.0,turns)
		var bend_progress := clampf((a.elapsed - first_lap_time - second_lap_time) / bend_time,0.0,1.0)
		var bend_angle := bend_progress * PI * 0.5
		coil_head += Vector2(-bend_radius*sin(bend_angle),bend_radius*(1.0-cos(bend_angle)))
		var exit_distance: float = extent * 2.0 + spiral_length
		var extra_exit := maxf(0.0, a.elapsed - shrink_at - shrink_time) * exit_distance / shrink_time
		var head := coil_head + launch_direction * (shrink * exit_distance + extra_exit)
		var followed: Dictionary = FORM.follow_trail(trail, head, spiral_length, a.body_segments + 1)
		trail = followed.trail
		points = followed.points
		var fractions: PackedFloat32Array = FORM.fractions(points)
		var touching := false
		for j in range(points.size() - 1):
			if Geometry2D.get_closest_point_to_segment(a.run_state.ship_pos, points[j], points[j + 1]).distance_to(a.run_state.ship_pos) <= a.body_width * 0.5 * FORM.taper((fractions[j] + fractions[j + 1]) * 0.5) + a.ctx.cfg.ship_radius:
				touching = true
				break
		if a.elapsed < shrink_at and touching and a.run_state.ship_hp < _hp_before:
			# 巻いている途中の胴に触れて被弾したら、離れて抜け出せるだけ長く無敵にする。
			a.run_state.ship_invuln = maxf(a.run_state.ship_invuln, float(p.get("touch_invuln", 0.0)))
		_hp_before = a.run_state.ship_hp
		if a.elapsed >= shrink_at:
			# 収縮中は共通hazardの反復ヒットを止め、接触を一度だけ受付する。
			for h in walls:
				if a.ctx.projectiles.owns_hazard(h, a.body, a.body_id): a.ctx.projectiles.hazard_dmg[h] = 0.0
			if not trapped_hit: a.combat_trace.evaluate()
			if not trapped_hit and touching:
				trapped = true
				trapped_hit = true
				a.combat_trace.damage(float(p.damage) * a.ctx.cfg.atk_scale, 0.0, &"spiral", &"draco")
				a.run_state.ship_invuln = maxf(a.run_state.ship_invuln, shrink_time * (1.0 - shrink) + 1.0)
		a.table.facing[a.body] = (points[0] - points[1]).angle()
		a.table.pos[a.body] = points[0]
		a.body_override = points
		while walls.size() < points.size() - 1:
			var damage: float = 0.0 if a.elapsed >= shrink_at else float(p.damage) * a.ctx.cfg.atk_scale
			var h := a.ctx.projectiles.fire_wall(center, 0.0, 1.0, a.body_width, 0.0, float(p.active) + 2.0, damage, Color("#7560d9"))
			a.ctx.projectiles.hazard_style[h] = ProjectileSystem.HazardStyle.TRAIL
			a.ctx.projectiles.hazard_block[h] = 1
			a.ctx.projectiles.attach_hazard(h, a.body)
			walls.append(h)
		for j in walls.size():
			var delta := points[j + 1] - points[j]
			a.ctx.projectiles.move_hazard(walls[j], points[j], delta.angle(), delta.length())
			a.ctx.projectiles.hazard_width[walls[j]] = a.body_width * FORM.taper((fractions[j] + fractions[j + 1]) * 0.5)
		if a.elapsed >= shrink_at: a.telegraph_points.clear()
	func end(a: BossActor, _cancelled: bool) -> void:
		if holding_player: _release_player(a)
		a.run_state.cinematic_camera = camera_was_cinematic
		a.picaro.pause(false)
		for h in walls:
			if a.ctx.projectiles.owns_hazard(h, a.body, a.body_id): a.ctx.projectiles.release_hazard(h)
		recovery_head = a.table.pos[a.body]
		a.telegraph_points.clear()
		a.telegraph_paths.clear()
		a.telegraph_widths.clear()
	func recover(a: BossActor, _dt: float) -> void:
		if trail.is_empty(): return
		var speed: float = (extent * 2.0 + spiral_length) / shrink_time
		var head: Vector2 = recovery_head + launch_direction * speed * a.elapsed
		var followed: Dictionary = FORM.follow_trail(trail, head, spiral_length, a.body_segments + 1)
		trail = followed.trail
		points = followed.points
		a.table.pos[a.body] = head
		a.table.facing[a.body] = launch_direction.angle()
		a.body_override = points

	func _follow_center(a: BossActor, dt: float) -> Vector2:
		var shift: Vector2 = (a.run_state.ship_pos - center) * (1.0 - exp(-1.4 * dt))
		shift = shift.limit_length(350.0 * dt)
		center += shift
		return shift

	func _camera_tick(a: BossActor, dt: float) -> void:
		var s = a.run_state
		var zoom := lerpf(s.camera_zoom, camera_zoom_target, 1.0 - exp(-3.0 * dt))
		var camera_center: Vector2 = s.view_center.lerp(s.ship_pos, 1.0 - exp(-5.0 * dt))
		STATE.frame(a, camera_center, zoom)

	func _set_head(a: BossActor, head: Vector2, length: float) -> void:
		var followed: Dictionary = FORM.follow_trail(trail, head, length, a.body_segments + 1)
		trail = followed.trail
		points = followed.points
		a.table.pos[a.body] = points[0]
		a.table.facing[a.body] = (points[0] - points[1]).angle()
		a.body_override = points

	func _entire_body_offscreen(a: BossActor) -> bool:
		var camera: Vector2 = a.run_state.view_center
		var half: Vector2 = a.run_state.view_half
		var head_radius: float = a.table.r[a.body]
		for j in points.size():
			var radius: float = head_radius if j == 0 else a.body_width * 0.5 * FORM.taper(float(j) / float(points.size() - 1))
			var relative: Vector2 = points[j] - camera
			if absf(relative.x) <= half.x + radius and absf(relative.y) <= half.y + radius: return false
		return true

	func _begin_reentry(a: BossActor) -> void:
		departing = false
		center = a.run_state.ship_pos
		var margin: float = a.table.r[a.body] + a.body_width + 100.0
		var outside := Vector2(maxf(center.x + horizontal_extent + margin,a.run_state.view_center.x + a.run_state.view_half.x + margin),
			minf(center.y - extent - margin,a.run_state.view_center.y - a.run_state.view_half.y - margin))
		staging = {"outside":outside,
			"control":center + Vector2(horizontal_extent * 0.52, -extent),
			"inside":center + Vector2(0.0, -extent)}
		# Only reset history after the whole animal is outside the filmed rectangle.
		trail.clear()
		for j in a.body_segments + 1:
			trail.append(staging.outside + Vector2.RIGHT * spiral_length * float(j) / float(a.body_segments))
		points = trail.duplicate()
		a.table.pos[a.body] = points[0]
		a.table.facing[a.body] = PI
		a.body_override = points
		a.elapsed = float(a.rule().warn) - 1.0

	func _release_player(a: BossActor) -> void:
		if not holding_player: return
		holding_player = false
		a.run_state.controls_locked = controls_before
		a.run_state.encounter_protected = protection_before
		a.run_state.ship_invuln = maxf(a.run_state.ship_invuln,0.35)

	func pose(a: BossActor) -> void:
		a.cosmic_body = true
