## シリウスの光の公開値と動作。
@tool
extends BossTechnique

## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.8:
	set(value):
		warn = value
		_values_dirty = true
## 吐き続ける時間（秒）
@export_range(0,100000,0.01) var duration := 2.6:
	set(value):
		duration = value
		_values_dirty = true
## 毎秒出す炎の数
@export_range(0,100000,0.01) var emit_rate := 85.0:
	set(value):
		emit_rate = value
		_values_dirty = true
## 炎を出す広がり（度）
@export_range(0,100000,0.01) var spread := 15.0:
	set(value):
		spread = value
		_values_dirty = true
## 炎の粒の速さ
@export_range(0,100000,0.01) var particle_speed := 1150.0:
	set(value):
		particle_speed = value
		_values_dirty = true
## 炎の減速率（毎秒）
@export_range(0,100000,0.01) var drag := 1.2:
	set(value):
		drag = value
		_values_dirty = true
## 炎の粒の寿命（秒）
@export_range(0,100000,0.01) var life := 0.85:
	set(value):
		life = value
		_values_dirty = true
## 炎の始まりの半径
@export_range(0,100000,0.01) var r_start := 14.0:
	set(value):
		r_start = value
		_values_dirty = true
## 炎の終わりの半径
@export_range(0,100000,0.01) var r_end := 72.0:
	set(value):
		r_end = value
		_values_dirty = true
## 炎の半径に対する判定倍率
@export_range(0,100000,0.01) var hit_scale := 0.75:
	set(value):
		hit_scale = value
		_values_dirty = true
## 吐く間の旋回（ラジアン毎秒）
@export_range(0,100000,0.01) var turn := 1.8:
	set(value):
		turn = value
		_values_dirty = true
## 吐く間に進む速さ
@export_range(0,100000,0.01) var advance := 130.0:
	set(value):
		advance = value
		_values_dirty = true
## 接近を止める距離
@export_range(0,100000,0.01) var advance_until := 220.0:
	set(value):
		advance_until = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 18.0:
	set(value):
		damage = value
		_values_dirty = true
## 硬直（秒）
@export_range(0,100000,0.01) var recover := 1.0:
	set(value):
		recover = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 8.0:
	set(value):
		cd = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	var values: Dictionary
	var age := 0.0
	var emit_left := 0.0
	var started := false
	func kind() -> StringName: return &"sirius_flame"
	func _begin_windup(host: CanisMajorBoss, r: Dictionary, _length: float) -> void:
		manual = true
		values = r
		host.mode = &"windup"
		host.table.vel[host.body] = Vector2.ZERO
		host._cue(&"flame_windup")
	func manual_tick(host: CanisMajorBoss, dt: float) -> void:
		age += dt
		if not started:
			if host._moves[kind()].track_during_warn: host._face(host.run_state.enemy_aim, host.def.turn, dt)
			host.table.vel[host.body] = Vector2.ZERO
			emit_left += dt * 18.0
			while emit_left >= 1.0:
				emit_left -= 1.0
				host.sirius_effects.flame_particle(host.mouth(), host.table.facing[host.body], values, false)
			if age < float(values.warn): return
			started = true
			age = 0.0
			emit_left = 0.0
			host.mode = &"active"
			host._cue(&"flame_start")
		host._face(host.run_state.ship_pos, float(values.turn), dt)
		if host.table.pos[host.body].distance_to(host.run_state.ship_pos) > float(values.advance_until):
			host._move_body(Vector2.from_angle(host.table.facing[host.body]) * float(values.advance) * dt, dt)
		else: host.table.vel[host.body] = Vector2.ZERO
		emit_left += dt * float(values.emit_rate)
		while emit_left >= 1.0:
			emit_left -= 1.0
			host.sirius_effects.flame_particle(host.mouth(), host.table.facing[host.body], values, true)
		if age >= float(values.duration): finish(host, float(values.recover))
	func windup_progress(_host: CanisMajorBoss) -> float:
		return clampf(age / maxf(float(values.warn), 0.001), 0, 1) if not started else 1.0
	func body_pose(host: CanisMajorBoss) -> Dictionary:
		return {"flame": host.mode in [&"windup", &"active"], "glow": windup_progress(host) if host.mode in [&"windup", &"active"] else 0.0}
