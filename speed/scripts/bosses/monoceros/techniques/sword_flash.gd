## 光の剣の連撃の公開値と段の進行。
@tool
extends BossTechnique

## 斬る回数
@export_range(1,100000,1) var cuts := 3:
	set(value):
		cuts = value
		_values_dirty = true

## 1回目の溜めの時間（秒）
@export_range(0,100000,0.01) var first_windup := 0.6:
	set(value):
		first_windup = value
		_values_dirty = true

## 2回目からの溜めの時間（秒）
@export_range(0,100000,0.01) var windup := 0.42:
	set(value):
		windup = value
		_values_dirty = true

## 振り抜きの何秒前に向きと狙う位置を固定するか（秒）
@export_range(0,100000,0.01) var lock_time := 0.2:
	set(value):
		lock_time = value
		_values_dirty = true

## 溜め中に自機へ向き直る速さ（度/秒）
@export_range(0,720,0.1,"radians_as_degrees") var aim_turn := 7.993607974134029:
	set(value):
		aim_turn = value
		_values_dirty = true

## 角を引く角度（度）
@export_range(0,720,0.1,"radians_as_degrees") var pull := 0.7853981633974483:
	set(value):
		pull = value
		_values_dirty = true

## 振り抜く時間（秒）
@export_range(0,100000,0.01) var swing_time := 0.1:
	set(value):
		swing_time = value
		_values_dirty = true

## 振り抜きで前へ出る初めの速さ
@export_range(0,100000,0.01) var lunge_speed := 420.0:
	set(value):
		lunge_speed = value
		_values_dirty = true

## 前へ出る速さの減り方（1/秒）
@export_range(0,100000,0.01) var lunge_decay := 10.0:
	set(value):
		lunge_decay = value
		_values_dirty = true

## 斬撃の中心の、本体からの最短の距離
@export_range(0,100000,0.01) var slash_min := 260.0:
	set(value):
		slash_min = value
		_values_dirty = true

## 斬撃の中心の、本体からの最長の距離
@export_range(0,100000,0.01) var slash_max := 700.0:
	set(value):
		slash_max = value
		_values_dirty = true

## 斬撃の線の向き。正面から振る側への角度（度）。90 で真横
@export_range(0,720,0.1,"radians_as_degrees") var slash_angle := 1.2566370614359172:
	set(value):
		slash_angle = value
		_values_dirty = true

## 斬撃の長さ
@export_range(0,100000,0.01) var slash_length := 800.0:
	set(value):
		slash_length = value
		_values_dirty = true

## 斬撃の当たりの太さ
@export_range(0,100000,0.01) var slash_width := 24.0:
	set(value):
		slash_width = value
		_values_dirty = true

## 斬撃が当たる時間（秒）
@export_range(0,100000,0.01) var slash_hit_time := 0.06:
	set(value):
		slash_hit_time = value
		_values_dirty = true

## 1回の斬りと次の溜めの間（秒）
@export_range(0,100000,0.01) var cut_gap := 0.08:
	set(value):
		cut_gap = value
		_values_dirty = true

## 最後に角を正面へ戻す時間（秒）
@export_range(0,100000,0.01) var return_time := 0.3:
	set(value):
		return_time = value
		_values_dirty = true

## 斬撃1回のダメージ
@export_range(0,100000,0.01) var damage := 20.0:
	set(value):
		damage = value
		_values_dirty = true

## 戻したあとの隙（秒）
@export_range(0,100000,0.01) var recover := 1.4:
	set(value):
		recover = value
		_values_dirty = true

## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 7.0:
	set(value):
		cd = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

func attack_length() -> float:
	return first_windup + (cuts - 1) * windup + cuts * (swing_time + cut_gap) + return_time

func reach_limit(_horn: float) -> float:
	return slash_max + slash_length * 0.5

class Runner extends "res://scripts/bosses/monoceros/technique_runner.gd":
	var stage: StringName
	var stage_time := 0.0
	var angle := 0.0
	var glow_level := 0.0
	var i := 0
	var side := 1
	var target := Vector2.ZERO
	var base := 0.0
	var v := 0.0
	var released := false
	var released_at := 0.0

	func kind() -> StringName:
		return &"sword_flash"

	func sequenced() -> bool:
		return true

	func horn_angle(_host: MonocerosBoss) -> float:
		return angle

	func glow(host: MonocerosBoss) -> float:
		return glow_level if host.mode in [&"windup", &"active"] else 0.0

	func body_pose(host: MonocerosBoss, _parts: Node2D) -> Dictionary:
		return {"neck": angle_difference(host.table.facing[host.body], angle), "legs": []}

	func _begin_pass(host: MonocerosBoss) -> void:
		host.timeline.stop()
		host.mode = &"windup"
		host.locked = false
		host.attack_hit = false
		host.table.vel[host.body] = Vector2.ZERO
		host.aim_point = host._strike_aim()
		host.direction = Vector2.from_angle(host.table.facing[host.body])
		target = host.run_state.ship_pos
		angle = host.table.facing[host.body]
		_enter(&"aim")
		host._cue(&"telegraph")

	func _enter(next: StringName) -> void:
		stage = next
		stage_time = 0.0

	func _release(host: MonocerosBoss) -> void:
		var r := host.rule()
		var center := host.table.pos[host.body] + Vector2.from_angle(base) * clampf(host.table.pos[host.body].distance_to(target), float(r.slash_min), float(r.slash_max))
		var u := Vector2.from_angle(base + side * float(r.slash_angle))
		host.last_slash = PackedVector2Array([center - u * float(r.slash_length) * 0.5, center + u * float(r.slash_length) * 0.5])
		host.attack_hit = false
		released = true
		released_at = stage_time
		glow_level = 0.0
		host._cue(&"slash_release")

	func _hit_slash(host: MonocerosBoss) -> void:
		if host.attack_hit: return
		var line := host.last_slash
		var ship := host.run_state.ship_pos
		var prior := host.previous_ship
		var radius := float(host.rule().slash_width) * 0.5 + host.ctx.cfg.ship_radius
		if Geometry2D.segment_intersects_segment(prior, ship, line[0], line[1]) != null:
			host._hit_ship()
		for pair in [[ship, line[0], line[1]], [prior, line[0], line[1]], [line[0], prior, ship], [line[1], prior, ship]]:
			if Geometry2D.get_closest_point_to_segment(pair[0], pair[1], pair[2]).distance_squared_to(pair[0]) <= radius * radius: host._hit_ship()

	func advance_sequence(host: MonocerosBoss, dt: float) -> void:
		var r := host.rule()
		stage_time += dt
		match stage:
			&"aim":
				var duration := float(r.first_windup) if i == 0 else float(r.windup)
				var k := clampf(stage_time / maxf(duration, 0.001), 0.0, 1.0)
				if not host.locked:
					host.table.facing[host.body] = rotate_toward(host.table.facing[host.body], (host.run_state.ship_pos - host.table.pos[host.body]).angle(), float(r.aim_turn) * dt)
					target = host.run_state.ship_pos
					if stage_time >= duration - float(r.lock_time):
						host.locked = true
						host._cue(&"aim_locked")
				glow_level = 1.0 - (1.0 - k) * (1.0 - k)
				angle = host.table.facing[host.body] - side * float(r.pull) * glow_level
				if stage_time >= duration:
					base = host.table.facing[host.body]
					v = float(r.lunge_speed)
					released = false
					host.mode = &"active"
					_enter(&"swing")
					host._cue(&"attack_started")
			&"swing":
				var k := clampf(stage_time / maxf(float(r.swing_time), 0.001), 0.0, 1.0)
				var e := k * k * (3.0 - 2.0 * k)
				angle = base + side * (-float(r.pull) + 2.0 * float(r.pull) * e)
				v *= exp(-float(r.lunge_decay) * dt)
				host._move_body(Vector2.from_angle(base) * v * dt)
				if not released and e >= 0.5: _release(host)
				if released and stage_time - released_at <= float(r.slash_hit_time): _hit_slash(host)
				if k >= 1.0 and released and stage_time - released_at >= float(r.slash_hit_time):
					host.table.vel[host.body] = Vector2.ZERO
					_enter(&"gap" if i + 1 < int(r.cuts) else &"return")
					if stage == &"gap": host.locked = false
			&"gap":
				if stage_time >= float(r.cut_gap):
					i += 1
					side = 1 if i % 2 == 0 else -1
					target = host.run_state.ship_pos
					_enter(&"aim")
			&"return":
				var k := clampf(stage_time / maxf(float(r.return_time), 0.001), 0.0, 1.0)
				angle = lerpf(base + side * float(r.pull), host.table.facing[host.body], k * k * (3.0 - 2.0 * k))
				if stage_time >= float(r.return_time): host.finish_sequence(float(r.recover))
