## 光の槍の公開値と段の進行。
@tool
extends BossTechnique

## 光を集めて槍の形にする時間（秒）
@export_range(0,100000,0.01) var warn := 1.4:
	set(value):
		warn = value
		_values_dirty = true

## 発進の何秒前に向きを固定するか（秒）
@export_range(0,100000,0.01) var lock_time := 0.25:
	set(value):
		lock_time = value
		_values_dirty = true

## 溜め中に自機へ向き直る速さ（度/秒）
@export_range(0,720,0.1,"radians_as_degrees") var aim_turn := 2.199114857512855:
	set(value):
		aim_turn = value
		_values_dirty = true

## 溜め中に後ろへ下がる速さ
@export_range(0,100000,0.01) var back_speed := 40.0:
	set(value):
		back_speed = value
		_values_dirty = true

## 穂先の長さ。角先からさらに伸びる分。当たりにも含む
@export_range(0,100000,0.01) var head_length := 60.0:
	set(value):
		head_length = value
		_values_dirty = true

## 槍の当たりの太さ
@export_range(0,100000,0.01) var width := 48.0:
	set(value):
		width = value
		_values_dirty = true

## 突き抜ける距離
@export_range(0,100000,0.01) var distance := 1250.0:
	set(value):
		distance = value
		_values_dirty = true

## 突き抜ける速さ
@export_range(0,100000,0.01) var speed := 3400.0:
	set(value):
		speed = value
		_values_dirty = true

## ソニックブームを出す間隔（秒）
@export_range(0,100000,0.01) var boom_interval := 0.045:
	set(value):
		boom_interval = value
		_values_dirty = true

## ソニックブームを出す位置。本体の中心から前への距離
@export_range(0,100000,0.01) var boom_ahead := 300.0:
	set(value):
		boom_ahead = value
		_values_dirty = true

## 突き抜けてから止まるまでの時間（秒）
@export_range(0,100000,0.01) var stop_time := 0.35:
	set(value):
		stop_time = value
		_values_dirty = true

## 止まるときの速さの減り方（1/秒）
@export_range(0,100000,0.01) var stop_decay := 9.0:
	set(value):
		stop_decay = value
		_values_dirty = true

## 止まり始めてから槍の光が砕けるまで（秒）
@export_range(0,100000,0.01) var shatter_time := 0.2:
	set(value):
		shatter_time = value
		_values_dirty = true

## ダメージ
@export_range(0,100000,0.01) var damage := 30.0:
	set(value):
		damage = value
		_values_dirty = true

## 止まったあとの隙（秒）
@export_range(0,100000,0.01) var recover := 2.0:
	set(value):
		recover = value
		_values_dirty = true

## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 10.0:
	set(value):
		cd = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

func attack_length() -> float:
	return warn + distance / maxf(speed, 0.001) + stop_time

func reach_limit(horn: float) -> float:
	return distance + horn + head_length

class Runner extends "res://scripts/bosses/monoceros/techniques/charge.gd".Runner:
	var stage: StringName
	var stage_time := 0.0
	var angle := 0.0
	var glow_level := 0.0
	var form := 0.0
	var traveled := 0.0
	var boom_time := 0.0
	var v := 0.0
	var shattered := false

	func kind() -> StringName:
		return &"lance"

	func sequenced() -> bool:
		return true

	func horn_angle(host: MonocerosBoss) -> float:
		return host.table.facing[host.body]

	func horn_points(host: MonocerosBoss, _sweep_fraction := -1.0) -> PackedVector2Array:
		var at := host.table.pos[host.body]
		var u := Vector2.from_angle(host.table.facing[host.body])
		return PackedVector2Array([at + u * host.table.r[host.body] * 0.65, at + u * (host.horn_length() + float(host.rule().head_length) * form)])

	func hit_width(host: MonocerosBoss) -> float:
		return float(host.rule().width)

	func glow(host: MonocerosBoss) -> float:
		return glow_level if host.mode in [&"windup", &"active"] else 0.0

	func booster(_host: MonocerosBoss) -> float:
		return 0.55 + 0.45 * form if stage == &"gather" else 3.5 if stage == &"run" else 1.0

	func _begin_pass(host: MonocerosBoss) -> void:
		host.timeline.stop()
		host.mode = &"windup"
		host.locked = false
		host.attack_hit = false
		host.table.vel[host.body] = Vector2.ZERO
		host.aim_point = host._strike_aim()
		host.direction = Vector2.from_angle(host.table.facing[host.body])
		angle = host.table.facing[host.body]
		_enter(&"gather")
		host._cue(&"telegraph")

	func _enter(next: StringName) -> void:
		stage = next
		stage_time = 0.0

	func _launch(host: MonocerosBoss) -> void:
		if host._path_blocked():
			begin_reposition(host)
			return
		host.direction = Vector2.from_angle(host.table.facing[host.body])
		host.attack_hit = false
		host.previous_horn = host.horn_points()
		host.mode = &"active"
		form = 1.0
		_enter(&"run")
		host._cue(&"attack_started")
		host._cue(&"lance_launch")

	func _stop(host: MonocerosBoss) -> void:
		v = float(host.rule().speed)
		_enter(&"stop")

	func advance_sequence(host: MonocerosBoss, dt: float) -> void:
		var r := host.rule()
		var prior := host.horn_points()
		stage_time += dt
		match stage:
			&"gather":
				if not host.locked:
					host.table.facing[host.body] = rotate_toward(host.table.facing[host.body], (host.run_state.ship_pos - host.table.pos[host.body]).angle(), float(r.aim_turn) * dt)
					host.aim_point = host.run_state.ship_pos
					if stage_time >= float(r.warn) - float(r.lock_time):
						host.locked = true
						host._cue(&"aim_locked")
				host.direction = Vector2.from_angle(host.table.facing[host.body])
				host._move_body(-host.direction * float(r.back_speed) * dt)
				var k := clampf(stage_time / maxf(float(r.warn), 0.001), 0.0, 1.0)
				form = 1.0 - (1.0 - k) * (1.0 - k)
				glow_level = form
				if stage_time >= float(r.warn): _launch(host)
			&"run":
				form = 1.0
				var step := host.direction * minf(float(r.speed) * dt, maxf(0.0, float(r.distance) - traveled))
				var outcome := advance_charge(host, dt, prior, step, false)
				if outcome == &"blocked":
					_stop(host)
					return
				traveled += step.length()
				boom_time += dt
				while boom_time >= maxf(float(r.boom_interval), 0.001):
					boom_time -= maxf(float(r.boom_interval), 0.001)
					host._cue(&"sonic_boom")
				if traveled >= float(r.distance): _stop(host)
			&"stop":
				v *= exp(-float(r.stop_decay) * dt)
				host._move_body(host.direction * v * dt)
				if not shattered and stage_time >= float(r.shatter_time):
					shattered = true
					form = 0.0
					glow_level = 0.0
					host._cue(&"lance_shatter")
				if stage_time >= float(r.stop_time): host.finish_sequence(float(r.recover))
