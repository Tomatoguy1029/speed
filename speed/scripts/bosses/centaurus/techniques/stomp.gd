## ケンタウルス座の技の値と実行処理。
@tool
extends BossTechnique

## 予告（秒）
@export_range(0, 100000, 0.01) var warn := 0.6:
	set(value):
		warn = value
		_values_dirty = true
## 扇の当たりが続く時間（秒）
@export_range(0, 100000, 0.01) var active := 0.15:
	set(value):
		active = value
		_values_dirty = true
## 扇の半径（距離）
@export_range(0, 100000, 0.01) var range_radius := 260.0:
	set(value):
		range_radius = value
		_values_dirty = true
## 正面から扇の端までの角度（度）
@export_range(0, 100000, 0.01) var half_angle := 50.0:
	set(value):
		half_angle = value
		_values_dirty = true
## ダメージ
@export_range(0, 100000, 0.01) var damage := 20.0:
	set(value):
		damage = value
		_values_dirty = true
## 攻撃後の硬直（秒）
@export_range(0, 100000, 0.01) var recover := 1.0:
	set(value):
		recover = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0, 100000, 0.01) var cd := 4.0:
	set(value):
		cd = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/centaurus/technique_runner.gd":
	var started_at := 0.0
	var struck := false
	var hit := false

	func kind() -> StringName: return &"stomp"

	func _begin_windup(host: CentaurusBoss, _r: Dictionary, _length: float) -> void:
		host.timeline.stop()
		started_at = host.clock
		host.mode = &"windup"
		host._cue(&"stomp_windup")

	func tick(actor: BossActor, _dt: float) -> void:
		var host := actor as CentaurusBoss
		var r := host.rule()
		var elapsed := host.clock - started_at
		host.table.vel[host.body] = Vector2.ZERO
		if elapsed < float(r.warn): return
		if not struck:
			struck = true
			host.mode = &"strike"
			host._cue(&"stomp")
		if elapsed >= float(r.warn) + float(r.active):
			host.finish_technique()
			return
		var offset := host.run_state.ship_pos - host.table.pos[host.body]
		if not hit and offset.length() <= float(r.range_radius) + host.ctx.cfg.ship_radius and absf(Geom.angle_diff(offset.angle(), host.table.facing[host.body])) <= deg_to_rad(float(r.half_angle)):
			hit = host.ctx.ship.damage(float(r.damage) * host.ctx.cfg.atk_scale, 0.0, &"stomp", &"centaurus")
