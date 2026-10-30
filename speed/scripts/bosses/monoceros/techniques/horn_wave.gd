## 角の衝撃波の値と、溜め・2回の振り抜き・戻し。
@tool
extends BossTechnique

## 最初に首を引いて溜める時間（秒）
@export_range(0,100000,0.01) var windup := 0.7:
	set(value):
		windup = value
		_values_dirty = true

## 溜め中に自機へ向き直る速さ（度/秒）
@export_range(0,360,0.1,"radians_as_degrees") var windup_turn := 2.007128639793479:
	set(value):
		windup_turn = value
		_values_dirty = true

## 首を引く角度（度）
@export_range(0,360,0.1,"radians_as_degrees") var pull := 1.3962634015954636:
	set(value):
		pull = value
		_values_dirty = true

## 1回の振り抜きの時間（秒）
@export_range(0,100000,0.01) var swing_time := 0.36:
	set(value):
		swing_time = value
		_values_dirty = true

## 振り抜き中に自機へ向き直る速さ（度/秒）
@export_range(0,360,0.1,"radians_as_degrees") var swing_turn := 1.5009831567151235:
	set(value):
		swing_turn = value
		_values_dirty = true

## 衝撃波を放つ向き。正面から振る側へずらす角度（度）
@export_range(0,360,0.1,"radians_as_degrees") var release_offset := 0.4363323129985824:
	set(value):
		release_offset = value
		_values_dirty = true

## 1発目と2発目の間の溜め直しの時間（秒）
@export_range(0,100000,0.01) var recharge := 0.45:
	set(value):
		recharge = value
		_values_dirty = true

## 2発目のあと正面へ戻す時間（秒）
@export_range(0,100000,0.01) var return_time := 0.4:
	set(value):
		return_time = value
		_values_dirty = true

## 衝撃波が広がる速さ
@export_range(0,100000,0.01) var wave_speed := 600.0:
	set(value):
		wave_speed = value
		_values_dirty = true

## 衝撃波が出る半径（本体の中心から）
@export_range(0,100000,0.01) var wave_start := 120.0:
	set(value):
		wave_start = value
		_values_dirty = true

## 衝撃波が消える半径
@export_range(0,100000,0.01) var wave_max := 1000.0:
	set(value):
		wave_max = value
		_values_dirty = true

## 衝撃波の弧の半分の角度（度）
@export_range(0,360,0.1,"radians_as_degrees") var wave_half_angle := 0.6108652381980153:
	set(value):
		wave_half_angle = value
		_values_dirty = true

## 衝撃波の帯の太さ。当たりの太さでもある
@export_range(0,100000,0.01) var wave_width := 20.0:
	set(value):
		wave_width = value
		_values_dirty = true

## 衝撃波1つのダメージ
@export_range(0,100000,0.01) var damage := 15.0:
	set(value):
		damage = value
		_values_dirty = true

## 戻したあとの隙（秒）
@export_range(0,100000,0.01) var recover := 0.9:
	set(value):
		recover = value
		_values_dirty = true

## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 6.0:
	set(value):
		cd = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

func attack_length() -> float:
	return windup + 2.0 * swing_time + recharge + return_time

func reach_limit(_horn: float) -> float:
	return wave_max

class Runner extends "res://scripts/bosses/monoceros/technique_runner.gd":
	var stage: StringName
	var stage_time := 0.0
	var angle := 0.0
	var glow_level := 0.0
	var dir := 1
	var released := false

	func kind() -> StringName:
		return &"horn_wave"

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
		angle = host.table.facing[host.body]
		_enter(&"windup")
		host._cue(&"telegraph")

	func _enter(next: StringName) -> void:
		stage = next
		stage_time = 0.0
		released = false

	func _face_target(host: MonocerosBoss, dt: float, turn: float) -> void:
		var target := host.run_state.enemy_aim if host._tracks_during_warn() else host.aim_point
		host.table.facing[host.body] = rotate_toward(host.table.facing[host.body], (target - host.table.pos[host.body]).angle(), turn * dt)

	func _swing(host: MonocerosBoss) -> void:
		host.mode = &"active"
		_enter(&"swing")
		host._cue(&"attack_started")

	func advance_sequence(host: MonocerosBoss, dt: float) -> void:
		var r := host.rule()
		stage_time += dt
		match stage:
			&"windup":
				_face_target(host, dt, float(r.windup_turn))
				var k := clampf(stage_time / maxf(float(r.windup), 0.001), 0.0, 1.0)
				glow_level = 1.0 - (1.0 - k) * (1.0 - k)
				angle = host.table.facing[host.body] - float(r.pull) * glow_level
				if stage_time >= float(r.windup): _swing(host)
			&"swing":
				_face_target(host, dt, float(r.swing_turn))
				var k := clampf(stage_time / maxf(float(r.swing_time), 0.001), 0.0, 1.0)
				var e := k * k * (3.0 - 2.0 * k)
				angle = host.table.facing[host.body] + dir * (-float(r.pull) + 2.0 * float(r.pull) * e)
				glow_level = 1.0 - e
				if not released and e >= (float(r.pull) + float(r.release_offset)) / maxf(2.0 * float(r.pull), 0.001):
					released = true
					host.horn_waves.append({"center": host.table.pos[host.body], "angle": angle, "radius": float(r.wave_start), "speed": float(r.wave_speed), "max": float(r.wave_max), "half": float(r.wave_half_angle), "width": float(r.wave_width), "damage": float(r.damage), "hit": false})
					host._cue(&"wave_release")
				if stage_time >= float(r.swing_time): _enter(&"recharge" if dir == 1 else &"return")
			&"recharge":
				var k := clampf(stage_time / maxf(float(r.recharge), 0.001), 0.0, 1.0)
				angle = host.table.facing[host.body] + float(r.pull)
				glow_level = k
				if stage_time >= float(r.recharge):
					dir = -1
					_swing(host)
			&"return":
				var k := clampf(stage_time / maxf(float(r.return_time), 0.001), 0.0, 1.0)
				angle = host.table.facing[host.body] - float(r.pull) * (1.0 - k * k * (3.0 - 2.0 * k))
				glow_level = 0.0
				if stage_time >= float(r.return_time): host.finish_sequence(float(r.recover))
