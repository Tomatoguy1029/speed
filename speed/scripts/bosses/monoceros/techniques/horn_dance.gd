## 光角の乱舞の公開値と段の進行。
@tool
extends BossTechnique

## 最初に自機を向いて角を光らせる時間（秒）
@export_range(0,100000,0.01) var aim_time := 0.5:
	set(value):
		aim_time = value
		_values_dirty = true

## 最初に自機へ向き直る速さ（度/秒）
@export_range(0,720,0.1,"radians_as_degrees") var aim_turn := 4.991641660703783:
	set(value):
		aim_turn = value
		_values_dirty = true

## 最初の発進の何秒前に向きを固定するか（秒）
@export_range(0,100000,0.01) var aim_lock := 0.15:
	set(value):
		aim_lock = value
		_values_dirty = true

## 突進の回数
@export_range(1,100000,1) var passes := 4:
	set(value):
		passes = value
		_values_dirty = true

## 突進の速さ
@export_range(0,100000,0.01) var speed := 2200.0:
	set(value):
		speed = value
		_values_dirty = true

## 各回の突進で、自機の位置から先へ突き抜ける距離
@export_range(0,100000,0.01) var overshoot := 280.0:
	set(value):
		overshoot = value
		_values_dirty = true

## 1回の突進の最短の距離
@export_range(0,100000,0.01) var min_run := 650.0:
	set(value):
		min_run = value
		_values_dirty = true

## 旋回で向きが変わる速さ（度/秒）。いつも左回り
@export_range(0,720,0.1,"radians_as_degrees") var circle_turn := 3.4033920413889427:
	set(value):
		circle_turn = value
		_values_dirty = true

## 旋回中の移動の速さ
@export_range(0,100000,0.01) var circle_speed := 900.0:
	set(value):
		circle_speed = value
		_values_dirty = true

## この時間旋回しても向きが合わないとき、旋回を小さくする（秒）
@export_range(0,100000,0.01) var circle_late_time := 1.2:
	set(value):
		circle_late_time = value
		_values_dirty = true

## 旋回を小さくしたときの移動の速さ
@export_range(0,100000,0.01) var circle_speed_late := 600.0:
	set(value):
		circle_speed_late = value
		_values_dirty = true

## 旋回に入るときの減速（毎秒あたりの速さの減り方）
@export_range(0,100000,0.01) var circle_decel := 6000.0:
	set(value):
		circle_decel = value
		_values_dirty = true

## 旋回中の加速（毎秒あたりの速さの増え方）
@export_range(0,100000,0.01) var circle_accel := 2200.0:
	set(value):
		circle_accel = value
		_values_dirty = true

## 機首が自機に向いたとみなす角度のずれ（度）
@export_range(0,720,0.1,"radians_as_degrees") var align_angle := 0.059341194567807204:
	set(value):
		align_angle = value
		_values_dirty = true

## 自機がこれより近いときは突っ込まずに旋回を続ける
@export_range(0,100000,0.01) var align_min_distance := 380.0:
	set(value):
		align_min_distance = value
		_values_dirty = true

## 旋回の最短の時間（秒）
@export_range(0,100000,0.01) var align_min_time := 0.25:
	set(value):
		align_min_time = value
		_values_dirty = true

## これだけ旋回しても向きが合わなければ技を終える（秒）
@export_range(0,100000,0.01) var circle_max_time := 3.0:
	set(value):
		circle_max_time = value
		_values_dirty = true

## 旋回中に頭が先に自機を向く最大の角度（度）
@export_range(0,720,0.1,"radians_as_degrees") var head_lead := 0.5061454830783556:
	set(value):
		head_lead = value
		_values_dirty = true

## 機首と自機の向きのずれがこれより小さいと角が光り始める（度）
@export_range(0,720,0.1,"radians_as_degrees") var glow_angle := 1.2042771838760873:
	set(value):
		glow_angle = value
		_values_dirty = true

## 最後に止まって角を掲げる時間（秒）
@export_range(0,100000,0.01) var end_time := 0.5:
	set(value):
		end_time = value
		_values_dirty = true

## 最後に止まるときの速さの減り方（1/秒）
@export_range(0,100000,0.01) var end_decay := 7.0:
	set(value):
		end_decay = value
		_values_dirty = true

## 突進1回のダメージ
@export_range(0,100000,0.01) var damage := 25.0:
	set(value):
		damage = value
		_values_dirty = true

## 角を掲げたあとの隙（秒）
@export_range(0,100000,0.01) var recover := 2.5:
	set(value):
		recover = value
		_values_dirty = true

## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 18.0:
	set(value):
		cd = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

func attack_length() -> float:
	return aim_time + passes * 0.6 + (passes - 1) * circle_late_time + end_time

func reach_limit(_horn: float) -> float:
	return INF

class Runner extends "res://scripts/bosses/monoceros/techniques/charge.gd".Runner:
	var stage: StringName
	var stage_time := 0.0
	var angle := 0.0
	var glow_level := 0.0
	var run_speed := 0.0
	var travel := 0.0
	var traveled := 0.0
	var completed := 0
	var heading := 0.0
	var v := 0.0

	func kind() -> StringName:
		return &"horn_dance"

	func sequenced() -> bool:
		return true

	func horn_angle(_host: MonocerosBoss) -> float:
		return angle

	func glow(host: MonocerosBoss) -> float:
		return glow_level if host.mode in [&"windup", &"active"] else 0.0

	func booster(_host: MonocerosBoss) -> float:
		return 0.55 + 0.45 * glow_level if stage == &"aim" else 2.5 if stage == &"run" else 1.2 if stage == &"circle" else 0.55

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
		_enter(&"aim")
		host._cue(&"telegraph")

	func _enter(next: StringName) -> void:
		stage = next
		stage_time = 0.0

	func _path_blocked(host: MonocerosBoss) -> bool:
		# 乱舞は固定のdistanceを持たず、狙いまでの経路を各発進時に調べる。
		var at := host.table.pos[host.body]
		var distance := maxf(float(host.def.params.near_clearance), at.distance_to(host.aim_point))
		return host.ctx.field.first_body_hit(at, at + Vector2.from_angle(host.table.facing[host.body]) * distance, host.table.r[host.body]) != null

	func _launch(host: MonocerosBoss, speed: float, from_circle: bool) -> void:
		if host._path_blocked():
			begin_reposition(host)
			return
		if from_circle: host.table.facing[host.body] = (host.run_state.ship_pos - host.table.pos[host.body]).angle()
		host.direction = Vector2.from_angle(host.table.facing[host.body])
		var r := host.rule()
		travel = maxf(float(r.min_run), host.table.pos[host.body].distance_to(host.run_state.ship_pos) + float(r.overshoot))
		traveled = 0.0
		run_speed = speed
		host.attack_hit = false
		angle = host.table.facing[host.body]
		host.previous_horn = host.horn_points()
		glow_level = 0.0
		host.mode = &"active"
		_enter(&"run")
		host._cue(&"attack_started")

	func _end(host: MonocerosBoss) -> void:
		v = run_speed
		_enter(&"end")
		host._cue(&"dance_end")

	func advance_sequence(host: MonocerosBoss, dt: float) -> void:
		var r := host.rule()
		var prior := host.horn_points()
		stage_time += dt
		match stage:
			&"aim":
				if not host.locked:
					host.table.facing[host.body] = rotate_toward(host.table.facing[host.body], (host.run_state.ship_pos - host.table.pos[host.body]).angle(), float(r.aim_turn) * dt)
					host.aim_point = host.run_state.ship_pos
					if stage_time >= float(r.aim_time) - float(r.aim_lock):
						host.locked = true
						host._cue(&"aim_locked")
				angle = host.table.facing[host.body]
				glow_level = clampf(stage_time / maxf(float(r.aim_time), 0.001), 0.0, 1.0)
				if stage_time >= float(r.aim_time): _launch(host, float(r.speed), false)
			&"run":
				var step := host.direction * minf(run_speed * dt, maxf(0.0, travel - traveled))
				var outcome := advance_charge(host, dt, prior, step, true)
				if outcome == &"stuck": return
				if outcome == &"blocked":
					_end(host)
					return
				traveled += step.length()
				if traveled >= travel:
					completed += 1
					if completed >= int(r.passes):
						_end(host)
					else:
						heading = host.table.facing[host.body]
						v = run_speed
						_enter(&"circle")
						host._cue(&"dance_circle")
			&"circle":
				heading -= float(r.circle_turn) * dt
				var target_speed := float(r.circle_speed_late) if stage_time > float(r.circle_late_time) else float(r.circle_speed)
				v += clampf(target_speed - v, -float(r.circle_decel) * dt, float(r.circle_accel) * dt)
				host._move_body(Vector2.from_angle(heading) * v * dt)
				host.table.facing[host.body] = heading
				var target := host.run_state.ship_pos - host.table.pos[host.body]
				var off := wrapf(target.angle() - heading, -PI, PI)
				angle = heading + clampf(off, -float(r.head_lead), float(r.head_lead))
				glow_level = maxf(0.0, 1.0 - absf(off) / maxf(float(r.glow_angle), 0.001))
				if absf(off) < float(r.align_angle) and target.length() > float(r.align_min_distance) and stage_time > float(r.align_min_time):
					host.aim_point = host.run_state.ship_pos
					host._cue(&"aim_locked")
					_launch(host, maxf(float(r.speed), v), true)
				elif stage_time > float(r.circle_max_time): _end(host)
			&"end":
				v *= exp(-float(r.end_decay) * dt)
				host._move_body(host.direction * v * dt)
				angle = host.table.facing[host.body]
				glow_level = 0.6 * minf(1.0, stage_time / 0.3)
				if stage_time >= float(r.end_time): host.finish_sequence(float(r.recover))
