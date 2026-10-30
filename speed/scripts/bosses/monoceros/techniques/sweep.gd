## 踏み込み薙ぎの値と、踏み込み・停止・振り抜き・戻し。
@tool
extends BossTechnique

## 踏み込みの初めの速さ
@export_range(0,100000,0.01) var approach_speed_start := 250.0:
	set(value):
		approach_speed_start = value
		_values_dirty = true

## 踏み込みの加速（毎秒あたりの速さの増え方）
@export_range(0,100000,0.01) var approach_accel := 2400.0:
	set(value):
		approach_accel = value
		_values_dirty = true

## 踏み込みの最高の速さ
@export_range(0,100000,0.01) var approach_speed_max := 1150.0:
	set(value):
		approach_speed_max = value
		_values_dirty = true

## 踏み込み中に自機へ向き直る速さ（度/秒）
@export_range(0,360,0.1,"radians_as_degrees") var approach_turn := 3.490658503988659:
	set(value):
		approach_turn = value
		_values_dirty = true

## 踏み込みの最短の時間（秒）
@export_range(0,100000,0.01) var approach_min := 0.3:
	set(value):
		approach_min = value
		_values_dirty = true

## 踏み込みの最長の時間（秒）。過ぎたら自機が遠くても止まって振る
@export_range(0,100000,0.01) var approach_max := 1.0:
	set(value):
		approach_max = value
		_values_dirty = true

## 自機がこの距離に入ったら止まって振る
@export_range(0,100000,0.01) var stop_range := 230.0:
	set(value):
		stop_range = value
		_values_dirty = true

## 踏み込みながら首を捻りきるまでの時間（秒）
@export_range(0,100000,0.01) var twist_time := 0.4:
	set(value):
		twist_time = value
		_values_dirty = true

## 踏み込み中の首の捻り（度）
@export_range(0,360,0.1,"radians_as_degrees") var twist := 1.3962634015954636:
	set(value):
		twist = value
		_values_dirty = true

## 止まって溜める時間（秒）
@export_range(0,100000,0.01) var stop_time := 0.22:
	set(value):
		stop_time = value
		_values_dirty = true

## 止まるときの減速（毎秒あたりの速さの減り方）
@export_range(0,100000,0.01) var stop_decel := 9000.0:
	set(value):
		stop_decel = value
		_values_dirty = true

## 溜めきった首の捻り（度）
@export_range(0,360,0.1,"radians_as_degrees") var windup_twist := 1.53588974175501:
	set(value):
		windup_twist = value
		_values_dirty = true

## 振り抜く角度（度）
@export_range(0,360,0.1,"radians_as_degrees") var arc := 3.0543261909900767:
	set(value):
		arc = value
		_values_dirty = true

## 振り抜く時間（秒）。当たりはこの間
@export_range(0,100000,0.01) var active := 0.13:
	set(value):
		active = value
		_values_dirty = true

## 振り切った姿勢で止まる時間（秒）
@export_range(0,100000,0.01) var hold := 0.35:
	set(value):
		hold = value
		_values_dirty = true

## 正面へ戻す時間（秒）
@export_range(0,100000,0.01) var return_time := 0.5:
	set(value):
		return_time = value
		_values_dirty = true

## 戻したあとの隙（秒）
@export_range(0,100000,0.01) var recover := 0.9:
	set(value):
		recover = value
		_values_dirty = true

## ダメージ
@export_range(0,100000,0.01) var damage := 20.0:
	set(value):
		damage = value
		_values_dirty = true

## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 4.0:
	set(value):
		cd = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

func attack_length() -> float:
	return approach_max + stop_time + active + hold + return_time

func reach_limit(horn: float) -> float:
	var accelerated := minf(approach_max, maxf(0.0, approach_speed_max - approach_speed_start) / maxf(approach_accel, 0.001))
	return approach_speed_start * accelerated + 0.5 * approach_accel * accelerated * accelerated + approach_speed_max * maxf(0.0, approach_max - accelerated) + horn

class Runner extends "res://scripts/bosses/monoceros/technique_runner.gd":
	var stage: StringName
	var stage_time := 0.0
	var angle := 0.0
	var glow_level := 0.0
	var side := 1
	var base := 0.0
	var v := 0.0

	func kind() -> StringName:
		return &"sweep"

	func sequenced() -> bool:
		return true

	func horn_angle(_host: MonocerosBoss) -> float:
		return angle

	func glow(host: MonocerosBoss) -> float:
		return glow_level if host.mode in [&"windup", &"active"] else 0.0

	func booster(host: MonocerosBoss) -> float:
		return 0.55 + 1.95 * v / maxf(float(host.rule().approach_speed_max), 0.001) if stage == &"approach" else 0.3 if stage == &"stop" else 0.55

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
		side = host.sweep_side
		angle = host.table.facing[host.body]
		v = float(host.rule().approach_speed_start)
		_enter(&"approach")
		host._cue(&"telegraph")

	func _enter(next: StringName) -> void:
		stage = next
		stage_time = 0.0

	func advance_sequence(host: MonocerosBoss, dt: float) -> void:
		var r := host.rule()
		var prior := host.horn_points()
		var before := stage_time
		stage_time += dt
		match stage:
			&"approach":
				v = minf(float(r.approach_speed_max), v + float(r.approach_accel) * dt)
				var target := (host.run_state.ship_pos - host.table.pos[host.body]).angle()
				host.table.facing[host.body] = rotate_toward(host.table.facing[host.body], target, float(r.approach_turn) * dt)
				host.direction = Vector2.from_angle(host.table.facing[host.body])
				host._move_body(host.direction * v * dt)
				var k := clampf(stage_time / maxf(float(r.twist_time), 0.001), 0.0, 1.0)
				angle = host.table.facing[host.body] - side * float(r.twist) * (1.0 - (1.0 - k) * (1.0 - k))
				glow_level = k
				if (host.table.pos[host.body].distance_to(host.run_state.ship_pos) < float(r.stop_range) and stage_time > float(r.approach_min)) or stage_time > float(r.approach_max):
					base = host.table.facing[host.body]
					host.locked = true
					_enter(&"stop")
					host._cue(&"sweep_stop")
					host._cue(&"aim_locked")
			&"stop":
				var k := clampf(stage_time / maxf(float(r.stop_time), 0.001), 0.0, 1.0)
				v = maxf(0.0, v - float(r.stop_decel) * dt)
				host._move_body(Vector2.from_angle(base) * v * dt)
				host.table.facing[host.body] = base
				angle = base - side * lerpf(float(r.twist), float(r.windup_twist), 1.0 - (1.0 - k) * (1.0 - k))
				if stage_time >= float(r.stop_time):
					host.mode = &"active"
					host.attack_hit = false
					host.previous_horn = host.horn_points()
					host.table.vel[host.body] = Vector2.ZERO
					_enter(&"swing")
					host._cue(&"attack_started")
			&"swing":
				var steps := maxi(1, ceili(dt / 0.008))
				for j in steps:
					var k := clampf((before + dt * float(j + 1) / steps) / maxf(float(r.active), 0.001), 0.0, 1.0)
					angle = base + side * (-float(r.windup_twist) + float(r.arc) * k * k * (1.6 - 0.6 * k))
					var next := host.horn_points()
					host._damage_shape(prior, next)
					prior = next
				if stage_time >= float(r.active):
					_enter(&"hold")
					host._cue(&"swing_end")
			&"hold":
				if stage_time >= float(r.hold): _enter(&"return")
			&"return":
				var k := clampf(stage_time / maxf(float(r.return_time), 0.001), 0.0, 1.0)
				angle = lerpf(base + side * (-float(r.windup_twist) + float(r.arc)), base, k * k * (3.0 - 2.0 * k))
				if stage_time >= float(r.return_time):
					host.sweep_side = -side
					host.finish_sequence(float(r.recover))
