## 帆を張り、自機を中心とする弧を走りながら射る。
@tool
extends BossTechnique

## 予告の時間（秒）
@export_range(0, 100000, 0.01) var warn := 0.9:
	set(value):
		warn = value
		_values_dirty = true
## 予告中に弧の始点へ寄る速さ（距離毎秒）
@export_range(0, 100000, 0.01) var approach_speed := 900.0:
	set(value):
		approach_speed = value
		_values_dirty = true
## 弧の最小半径（距離）
@export_range(0, 100000, 0.01) var radius_min := 500.0:
	set(value):
		radius_min = value
		_values_dirty = true
## 弧の最大半径（距離）
@export_range(0, 100000, 0.01) var radius_max := 800.0:
	set(value):
		radius_max = value
		_values_dirty = true
## 走る弧の角度（度）
@export_range(0, 100000, 0.01) var arc := 288.0:
	set(value):
		arc = value
		_values_dirty = true
## 走る時間（秒）
@export_range(0, 100000, 0.01) var duration := 4.0:
	set(value):
		duration = value
		_values_dirty = true
## 矢を射る間隔（秒）
@export_range(0, 100000, 0.01) var interval := 0.2:
	set(value):
		interval = value
		_values_dirty = true
## 矢の速さ（距離毎秒）
@export_range(0, 100000, 0.01) var speed := 320.0:
	set(value):
		speed = value
		_values_dirty = true
## 矢の当たりの長さ（距離）
@export_range(0, 100000, 0.01) var length := 60.0:
	set(value):
		length = value
		_values_dirty = true
## 矢の飛距離
@export_range(0, 100000, 0.01) var travel := 1600.0:
	set(value):
		travel = value
		_values_dirty = true
## 矢の太さの半分
@export_range(0, 100000, 0.01) var radius := 6.0:
	set(value):
		radius = value
		_values_dirty = true
## 矢のダメージ
@export_range(0, 100000, 0.01) var damage := 12.0:
	set(value):
		damage = value
		_values_dirty = true
## 帆をたたむ硬直（秒）
@export_range(0, 100000, 0.01) var recover := 1.8:
	set(value):
		recover = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0, 100000, 0.01) var cd := 16.0:
	set(value):
		cd = value
		_values_dirty = true

## 矢の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/light_arrow.tscn"):
	set(value):
		shot_visual = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/centaurus/technique_runner.gd":
	var started_at := 0.0
	var center := Vector2.ZERO
	var radius := 0.0
	var angle := 0.0
	var side := 1.0
	var fired := 0

	func kind() -> StringName: return &"sail_run"

	func _begin_windup(host: CentaurusBoss, r: Dictionary, _length: float) -> void:
		host.timeline.stop()
		started_at = host.clock
		center = host.run_state.ship_pos
		var offset := host.table.pos[host.body] - center
		radius = clampf(offset.length(), float(r.radius_min), float(r.radius_max))
		angle = offset.angle()
		side = host.sail_side
		host.sail_side *= -1.0
		host.mode = &"windup"
		host._sail_guards(true)
		host._cue(&"sail_windup")

	func tick(actor: BossActor, dt: float) -> void:
		var host := actor as CentaurusBoss
		var r := host.rule()
		var elapsed := host.clock - started_at
		if elapsed < float(r.warn):
			var start := center + Vector2.from_angle(angle) * radius
			host._move_body((start - host.table.pos[host.body]).limit_length(float(r.approach_speed) * dt), dt)
			host._face(host.table.pos[host.body] + Vector2.from_angle(angle + side * PI * 0.5), host.def.turn, dt)
			return
		if host.mode != &"sail":
			host.mode = &"sail"
			host._cue(&"sail_run")
		var running := elapsed - float(r.warn)
		var duration := maxf(float(r.duration), 0.001)
		var theta := angle + side * deg_to_rad(float(r.arc)) * clampf(running / duration, 0.0, 1.0)
		host._move_body(center + Vector2.from_angle(theta) * radius - host.table.pos[host.body], dt)
		host.table.facing[host.body] = theta + side * PI * 0.5
		var interval := maxf(float(r.interval), 0.001)
		while fired * interval <= running and fired * interval < duration:
			var mouth := host.bow_mouth()
			var aim := (host.run_state.enemy_aim - mouth).angle()
			host.ctx.projectiles.emit_attack(&"light_arrow", [mouth, aim, float(r.speed), float(r.radius), float(r.travel), float(r.damage) * host.ctx.cfg.atk_scale, false, float(r.length)], r.get("shot_visual"))
			fired += 1
			host._cue(&"sail_shot")
		if running >= duration:
			host._sail_guards(false)
			host.finish_technique()
			host._cue(&"sail_folded")
