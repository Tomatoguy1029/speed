## 画面基準技は頭から全身を退場させ、不可視の間に入口へ姿勢を移す。
extends RefCounted
const FORM = preload("res://scripts/bosses/draco_form.gd")

static func begin(a: BossActor, side: float, enter_screen: bool, entry_height := 0.0) -> Dictionary:
	var points: PackedVector2Array = FORM.samples_even(a.body_points(), a.body_segments + 1)
	var away: Vector2 = points[0] - a.run_state.ship_pos
	if away.length_squared() < 1.0: away = Vector2.from_angle(a.table.facing[a.body])
	return {"phase": &"exit", "side": side, "enter": enter_screen, "height": entry_height,
		"trail": points, "points": points, "exit_angle": (points[0] - points[1]).angle(),
		"away_angle": away.angle(), "exit_time": 0.0, "entry_time": 0.0, "exited_all": false}

## true になったフレームから通常の予告時間を進める。
static func advance_full(a: BossActor, staging: Dictionary, dt: float) -> bool:
	if staging.phase == &"ready": return true
	a.elapsed = 0.0
	if staging.phase == &"exit":
		staging.exit_time += dt
		var angle: float = lerp_angle(float(staging.exit_angle), float(staging.away_angle),
			smoothstep(0.0, 0.45, float(staging.exit_time)))
		var speed: float = maxf((a.body_length + a.run_state.view_half.length() * 2.0 + a.body_width * 2.0) / 1.65,
			a.run_state.ship_vel.length() + 1000.0)
		_set_head(a, staging, a.table.pos[a.body] + Vector2.from_angle(angle) * speed * dt)
		if not _entire_body_offscreen(a, staging.points): return false
		staging.exited_all = true
		_place_outside(a, staging)
		if not bool(staging.enter):
			_finish(a, staging)
			return true
		return false
	staging.entry_time += dt
	var fraction: float = smoothstep(0.0, 0.42, float(staging.entry_time))
	_set_head(a, staging, (staging.entry_from as Vector2).lerp(staging.entry_to, fraction))
	if fraction < 1.0: return false
	_finish(a, staging)
	return true

static func _place_outside(a: BossActor, staging: Dictionary) -> void:
	var side: float = staging.side
	var half: Vector2 = a.run_state.view_half
	var camera: Vector2 = a.run_state.view_center
	var y: float = camera.y + half.y * float(staging.height)
	var outside := Vector2(camera.x + side * (half.x + a.table.r[a.body] + 120.0), y)
	var inside := Vector2(camera.x + side * minf(700.0, half.x * 0.68), y)
	staging.entry_from = outside
	staging.entry_to = inside
	staging.phase = &"enter" if staging.enter else &"ready"
	# 頭も尾も画面外にある間だけ履歴を入口側へ作り直す。
	var trail := PackedVector2Array()
	for j in a.body_segments + 1:
		trail.append(outside + Vector2(side * a.body_length * float(j) / float(a.body_segments), 0.0))
	staging.trail = trail
	staging.points = trail.duplicate()
	a.table.pos[a.body] = outside
	a.table.facing[a.body] = 0.0 if side < 0.0 else PI
	a.body_override = staging.points

static func _set_head(a: BossActor, staging: Dictionary, head: Vector2) -> void:
	var followed: Dictionary = FORM.follow_trail(staging.trail, head, a.body_length, a.body_segments + 1)
	staging.trail = followed.trail
	staging.points = followed.points
	a.table.pos[a.body] = staging.points[0]
	a.table.facing[a.body] = (staging.points[0] - staging.points[1]).angle()
	a.body_override = staging.points

static func _entire_body_offscreen(a: BossActor, points: PackedVector2Array) -> bool:
	var half: Vector2 = a.run_state.view_half
	var camera: Vector2 = a.run_state.view_center
	for j in points.size():
		var radius: float = a.table.r[a.body] if j == 0 else a.body_width * 0.5 * FORM.taper(float(j) / float(points.size() - 1))
		if Rect2(camera - half, half * 2.0).grow(radius).has_point(points[j]): return false
	return true

static func _finish(a: BossActor, staging: Dictionary) -> void:
	staging.phase = &"ready"
	a.body_trail = staging.trail
	a.body_override.clear()
	a.elapsed = 0.0

## 吸引大技の既存の短い構えは、この入口を引き続き使用する。
static func side_entry(a: BossActor, target: Vector2) -> Dictionary:
	var side := -1.0 if a.run_state.rng.randf() < 0.5 else 1.0
	var outside: Vector2 = a.run_state.view_center + Vector2(side * (a.run_state.view_half.x + a.table.r[a.body] + 100.0), 0)
	var inside: Vector2 = a.run_state.view_center + Vector2(side * minf(700.0, a.run_state.view_half.x * 0.72), 0)
	return capture(a, outside, inside, (target - inside).angle())

static func capture(a: BossActor, outside: Vector2, inside: Vector2, facing: float) -> Dictionary:
	return {"from":a.table.pos[a.body], "outside":outside, "inside":inside, "angle":a.table.facing[a.body], "facing":facing}

static func advance(a: BossActor, staging: Dictionary, progress: float) -> void:
	var point: Vector2
	if progress < 0.4:
		point = staging.from.lerp(staging.outside, smoothstep(0.0, 0.4, progress))
	else:
		point = staging.outside.lerp(staging.inside, smoothstep(0.4, 1.0, progress))
	a.table.pos[a.body] = point
	a.table.facing[a.body] = lerp_angle(float(staging.angle), float(staging.facing), smoothstep(0.0, 0.65, progress))
