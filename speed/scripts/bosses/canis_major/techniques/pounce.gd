## 飛びかかりの値と動き。
@tool
extends BossTechnique

## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.45:
	set(value):
		active = value
		_values_dirty = true
## 群れが少ないとみなす猟犬の数
@export_range(0,100000,1) var alone_hounds := 3:
	set(value):
		alone_hounds = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 4.0:
	set(value):
		cd = value
		_values_dirty = true
## 群れが少ないときの再使用待ち（秒）
@export_range(0,100000,0.01) var cd_alone := 2.0:
	set(value):
		cd_alone = value
		_values_dirty = true
## 群れが少ないときの再使用待ち（秒）（第2形態）
@export_range(0,100000,0.01) var cd_alone_p2 := 1.5:
	set(value):
		cd_alone_p2 = value
		_values_dirty = true
## 再使用待ち（秒）（第2形態）
@export_range(0,100000,0.01) var cd_p2 := 3.0:
	set(value):
		cd_p2 = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 24.0:
	set(value):
		damage = value
		_values_dirty = true
## 狙いを固定する時間（秒）
@export_range(0,100000,0.01) var lock := 0.2:
	set(value):
		lock = value
		_values_dirty = true
## 着地点の先までの距離
@export_range(0,100000,0.01) var overshoot := 80.0:
	set(value):
		overshoot = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.4:
	set(value):
		recover = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.7:
	set(value):
		warn = value
		_values_dirty = true
## 予告（秒）（第2形態）
@export_range(0,100000,0.01) var warn_p2 := 0.5:
	set(value):
		warn_p2 = value
		_values_dirty = true

## 着地点を先読みする追加時間（秒）
@export_range(0,100000,0.01) var lead_extra := 0.2:
	set(value):
		lead_extra = value
		_values_dirty = true
## 群れが少ないときの跳ぶ回数
@export_range(0,100000,1) var chain := 3:
	set(value):
		chain = value
		_values_dirty = true
## 2回目以降の予告（秒）
@export_range(0,100000,0.01) var chain_warn := 0.45:
	set(value):
		chain_warn = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	var values: Dictionary = {}
	var left := 1
	var stage_time := 0.0
	var warn_time := 0.0
	var jumping := false
	var done := false

	func kind() -> StringName: return &"pounce"

	func _begin_windup(host: CanisMajorBoss, r: Dictionary, _length: float) -> void:
		start_jump(host, r, int(r.chain) if host.led.size() < int(r.alone_hounds) else 1)

	func start_jump(host: CanisMajorBoss, r: Dictionary, count: int = 1) -> void:
		manual = true
		values = r
		left = count
		warn_time = float(r.warn)
		prepare(host)

	func prepare(host: CanisMajorBoss) -> void:
		stage_time = 0.0
		jumping = false
		host.mode = &"windup"
		host.locked = false
		host.attack_hit = false
		host.table.vel[host.body] = Vector2.ZERO
		_aim(host, 0.0)
		host._cue(&"telegraph")

	func _aim(host: CanisMajorBoss, dt: float) -> void:
		host.aim_point = host.run_state.ship_pos + host.run_state.ship_vel * (maxf(0, warn_time - stage_time) + float(values.lead_extra))
		host._face(host.aim_point, host.def.turn, dt)

	func lock_aim(host: CanisMajorBoss) -> void:
		host.locked = true
		var to := host.aim_point - host.table.pos[host.body]
		host.direction = to.normalized() if to.length_squared() > 1.0 else Vector2.from_angle(host.table.facing[host.body])
		host.aim_point += host.direction * float(values.overshoot)
		host._cue(&"aim_locked")

	func step(host: CanisMajorBoss, dt: float) -> bool:
		if done: return true
		if not jumping:
			if not host.locked and host._moves[&"pounce"].track_during_warn: _aim(host, dt)
			stage_time += dt
			if not host.locked and stage_time >= warn_time - float(values.lock): lock_aim(host)
			if stage_time < warn_time: return false
			if not host.locked: lock_aim(host)
			jumping = true
			stage_time = 0.0
			host.mode = &"active"
			host._cue(&"pounce")
			return false
		var from := host.table.pos[host.body]
		var step := (host.aim_point - from) * clampf(dt / maxf(float(values.active) - stage_time, dt), 0.0, 1.0)
		host._move_body(step, dt)
		host.table.facing[host.body] = host.direction.angle()
		if not host.attack_hit and _ship_touches(host, from, host.table.pos[host.body], host.table.r[host.body]):
			_hit_ship(host, float(values.damage))
		stage_time += dt
		var collision := host.table.pos[host.body].distance_squared_to(from + step) > 0.01
		if stage_time < float(values.active) and not collision: return false
		left -= 1
		if left > 0:
			warn_time = float(values.chain_warn)
			prepare(host)
			return false
		done = true
		return true

	func manual_tick(host: CanisMajorBoss, dt: float) -> void:
		if step(host, dt): finish(host, float(values.recover))

	func windup_progress(_host: CanisMajorBoss) -> float:
		return clampf(stage_time / maxf(warn_time, 0.001), 0, 1) if not jumping else 0.0

	func body_pose(host: CanisMajorBoss) -> Dictionary:
		if host.mode not in [&"windup", &"active"]: return {}
		var crouch := clampf(stage_time / maxf(warn_time, 0.001), 0, 1) if not jumping else 0.0
		return {"crouch": crouch, "stretch": 1.15 if jumping else 1.0 - crouch * 0.15}
