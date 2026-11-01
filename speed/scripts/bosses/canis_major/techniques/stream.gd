## 順番の号令の値と動き。
@tool
extends BossTechnique

## 吠える予告（秒）
@export_range(0,100000,0.01) var warn := 0.6:
	set(value):
		warn = value
		_values_dirty = true
## 猟犬を送り出す間隔（秒）
@export_range(0,100000,0.01) var interval := 0.2:
	set(value):
		interval = value
		_values_dirty = true
## 猟犬1体の白い予告（秒）
@export_range(0,100000,0.01) var each_warn := 0.3:
	set(value):
		each_warn = value
		_values_dirty = true
## 猟犬の突進速度
@export_range(0,100000,0.01) var lunge_speed := 1260.0:
	set(value):
		lunge_speed = value
		_values_dirty = true
## 猟犬の突進速度（第2形態）
@export_range(0,100000,0.01) var lunge_speed_p2 := 1500.0:
	set(value):
		lunge_speed_p2 = value
		_values_dirty = true
## 猟犬の突進時間（秒）
@export_range(0,100000,0.01) var lunge_time := 0.55:
	set(value):
		lunge_time = value
		_values_dirty = true
## 発動に必要な猟犬の数
@export_range(0,100000,1) var min_hounds := 5:
	set(value):
		min_hounds = value
		_values_dirty = true
## 猟犬1体のダメージ
@export_range(0,100000,0.01) var damage := 12.0:
	set(value):
		damage = value
		_values_dirty = true
## 攻撃後の硬直（秒）
@export_range(0,100000,0.01) var recover := 0.6:
	set(value):
		recover = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 7.0:
	set(value):
		cd = value
		_values_dirty = true
## 再使用待ち（第2形態・秒）
@export_range(0,100000,0.01) var cd_p2 := 5.0:
	set(value):
		cd_p2 = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	var started := 0.0
	var sent := false
	var values: Dictionary = {}

	func kind() -> StringName: return &"stream"

	func _begin_windup(host: CanisMajorBoss, r: Dictionary, _length: float) -> void:
		manual = true
		values = r
		started = host.clock
		host.mode = &"windup"
		host.table.vel[host.body] = Vector2.ZERO
		host._cue(&"stream_windup")

	func step(host: CanisMajorBoss, dt: float) -> bool:
		if not sent:
			host._face(host.run_state.enemy_aim, host.def.turn, dt)
			if host.clock - started < float(values.warn): return false
			sent = true
			begin_sequence(host, shuffled_pack(host), host.clock, float(values.interval), float(values.each_warn))
			host.mode = &"active"
		tick_sequence(host, values, "stream")
		tick_lunges(host)
		return host.clock >= last_launch + float(values.lunge_time)

	func manual_tick(host: CanisMajorBoss, dt: float) -> void:
		host.table.vel[host.body] = Vector2.ZERO
		if step(host, dt): finish(host, float(values.recover))

	func windup_progress(host: CanisMajorBoss) -> float:
		return clampf((host.clock - started) / maxf(float(values.warn), 0.001), 0, 1)

	func body_pose(host: CanisMajorBoss) -> Dictionary:
		return {"shout": host.mode == &"windup"}
