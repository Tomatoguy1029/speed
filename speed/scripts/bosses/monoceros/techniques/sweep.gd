## 角の薙ぎ払いの値と動き。
@tool
extends BossTechnique

## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.5:
	set(value):
		active = value
		_values_dirty = true
## 薙ぐ角度（度）
@export_range(0,360,0.1,"radians_as_degrees") var arc := 1.15:
	set(value):
		arc = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 4.0:
	set(value):
		cd = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 20.0:
	set(value):
		damage = value
		_values_dirty = true
## 攻撃後の停止（秒）
@export_range(0,100000,0.01) var hold := 0.25:
	set(value):
		hold = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.3:
	set(value):
		recover = value
		_values_dirty = true
## 正面へ戻る速さ（度/秒）
@export_range(0,360,0.1,"radians_as_degrees") var return_speed := 3.141592653589793:
	set(value):
		return_speed = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.85:
	set(value):
		warn = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/monoceros/technique_runner.gd":
	func _tick_strike(host: MonocerosBoss, dt: float, prior: PackedVector2Array) -> void:
		# 頭の角度を小さく刻み、フレーム間の扇形も掃引する。
		var start := maxf(0.0, host.timeline.current_animation_position - float(host.rule().warn))
		var steps := maxi(1, ceili(dt / 0.008))
		for j in steps:
			var f := clampf((start + dt * float(j + 1) / steps) / float(host.rule().active), 0.0, 1.0)
			var next := host.horn_points(f)
			host._damage_shape(prior, next)
			prior = next
	var last_neck := 0.0
	func body_pose(host: MonocerosBoss, _parts: Node2D) -> Dictionary:
		var angle := 0.0
		if host.mode in [&"windup", &"active"]:
			var points := host.horn_points()
			angle = angle_difference(host.table.facing[host.body], (points[1] - host.table.pos[host.body]).angle())
			last_neck = angle
		elif host.mode == &"recovery": angle = lerpf(last_neck, 0.0, host.settle_progress())
		return {"neck": angle, "legs": []}

	func kind() -> StringName:
		return &"sweep"

	func horn_points(host: MonocerosBoss, sweep_fraction := -1.0) -> PackedVector2Array:
		var at := host.table.pos[host.body]
		var angle := host.table.facing[host.body]
		var reach := host.horn_length()
		var f := sweep_fraction
		if f < 0.0: f = clampf((host.timeline.current_animation_position - float(host.rule().warn)) / float(host.rule().active), 0.0, 1.0)
		angle += lerpf(-0.5, 0.5, f) * float(host.rule().arc)
		var direction := Vector2.from_angle(angle)
		return PackedVector2Array([at + direction * host.table.r[host.body] * 0.65, at + direction * reach])
