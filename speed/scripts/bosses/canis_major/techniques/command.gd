## 号令の値と動き。
@tool
extends BossTechnique

## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 7.0:
	set(value):
		cd = value
		_values_dirty = true
## 再使用待ち（秒）（第2形態）
@export_range(0,100000,0.01) var cd_p2 := 5.0:
	set(value):
		cd_p2 = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 12.0:
	set(value):
		damage = value
		_values_dirty = true
## 猟犬が飛び出す速さ
@export_range(0,100000,0.01) var lunge_speed := 1260.0:
	set(value):
		lunge_speed = value
		_values_dirty = true
## 猟犬が飛び出す速さ（第2形態）
@export_range(0,100000,0.01) var lunge_speed_p2 := 1500.0:
	set(value):
		lunge_speed_p2 = value
		_values_dirty = true
## 猟犬が飛び出す時間（秒）
@export_range(0,100000,0.01) var lunge_time := 0.55:
	set(value):
		lunge_time = value
		_values_dirty = true
## 号令に要る猟犬の数
@export_range(0,100000,1) var min_hounds := 3:
	set(value):
		min_hounds = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 0.6:
	set(value):
		recover = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.6:
	set(value):
		warn = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	pass

	func kind() -> StringName:
		return &"command"

	func execute(host: CanisMajorBoss) -> void:
		var r := host.rule()
		var hounds = host._hounds()
		host._cue(&"command")
		if hounds == null: return
		host.lunging = PackedInt32Array(Array(host.led).filter(func(i): return not host.ring.has(i)))
		var until := host.run_state.world_time + float(r.lunge_time)
		for i in host.lunging:
			var speed_scale := float(r.lunge_speed) / maxf(host.table.speed[i], 1.0)
			var toward := (host.run_state.ship_pos - host.table.pos[i]).normalized()
			hounds.follow(i, host.table.pos[i] + toward * float(r.lunge_speed) * (float(r.lunge_time) + 0.2), until, speed_scale)
			# 加速を待たず、最初から全速で飛び出す。
			host.table.vel[i] = toward * float(r.lunge_speed)

	func _active_tick(host: CanisMajorBoss, _dt: float) -> void:
		var r := host.rule()
		# 号令：飛び出した猟犬に触れたら1回だけ当たる。
		if host.attack_hit: return
		for i in host.lunging:
			if not host._alive_hound(i): continue
			if host._ship_touches(host.table.pos[i], host.table.pos[i], host.table.r[i]):
				host._hit_ship(float(r.damage))
				return

	func body_pose(host: CanisMajorBoss) -> Dictionary:
		return {"shout": host.mode == &"windup"}
