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

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	pass

	func kind() -> StringName:
		return &"pounce"

	func execute(host: CanisMajorBoss) -> void:
		if not host.locked: host.lock_aim()
		host._cue(&"pounce")

	func _active_tick(host: CanisMajorBoss, dt: float) -> void:
		var r := host.rule()
		# 着地の時刻までに、残りの距離を等速で詰める。
		var from := host.table.pos[host.body]
		var left := float(r.warn) + float(r.active) - host.timeline.current_animation_position
		host._move_body((host.aim_point - from) * clampf(dt / maxf(left, dt), 0.0, 1.0), dt)
		host.table.facing[host.body] = host.direction.angle()
		if not host.attack_hit and host._ship_touches(from, host.table.pos[host.body], host.table.r[host.body]):
			host._hit_ship(float(r.damage))
		return

	func body_pose(host: CanisMajorBoss) -> Dictionary:
		var crouch: float = host.table.charge[host.body] if host.mode == &"windup" else 0.0
		return {"crouch": crouch, "stretch": 1.15 if host.mode == &"active" else 1.0 - crouch * 0.15}
