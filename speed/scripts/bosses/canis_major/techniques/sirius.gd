## シリウスの値と動き。
@tool
extends BossTechnique

## 光の長さ
@export_range(0,100000,0.01) var beam_length := 1400.0:
	set(value):
		beam_length = value
		_values_dirty = true
## 光を出す時間（秒）
@export_range(0,100000,0.01) var beam_time := 0.5:
	set(value):
		beam_time = value
		_values_dirty = true
## 光を出す時間（秒）（第2形態）
@export_range(0,100000,0.01) var beam_time_p2 := 0.8:
	set(value):
		beam_time_p2 = value
		_values_dirty = true
## 光の太さ
@export_range(0,100000,0.01) var beam_width := 50.0:
	set(value):
		beam_width = value
		_values_dirty = true
## 光の太さ（第2形態）
@export_range(0,100000,0.01) var beam_width_p2 := 80.0:
	set(value):
		beam_width_p2 = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 6.0:
	set(value):
		cd = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 26.0:
	set(value):
		damage = value
		_values_dirty = true
## 狙いを固定する時間（秒）
@export_range(0,100000,0.01) var lock := 0.3:
	set(value):
		lock = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.0:
	set(value):
		recover = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.0:
	set(value):
		warn = value
		_values_dirty = true

## ビームの見た目
@export var beam_visual: PackedScene = preload("res://scenes/attacks/beam.tscn"):
	set(value):
		beam_visual = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	func _fire_sirius(host: CanisMajorBoss) -> void:
		if not host.locked: host.lock_aim()
		var r := host.rule()
		var from := host.mouth()
		var length := float(r.beam_length)
		var hit = host.ctx.field.first_body_hit(from, from + host.direction * length, float(r.beam_width) * 0.5)
		if hit != null: length *= float(hit.t)
		var beam: int = host.ctx.projectiles.emit_attack(&"beam", [from, host.direction.angle(), length, float(r.beam_width), 0.0, float(r.beam_time),
			float(r.damage) * host.ctx.cfg.atk_scale, host.SIRIUS_COLOR], host.rule().get("beam_visual"))
		if beam >= 0:
			host.ctx.projectiles.hazard_style[beam] = ProjectileSystem.HazardStyle.TELESCOPE
			host.ctx.projectiles.attach_hazard(beam, host.body)
		host._cue(&"sirius")

	func kind() -> StringName:
		return &"sirius"

	func execute(host: CanisMajorBoss) -> void:
		host._fire_sirius()

	func body_pose(host: CanisMajorBoss) -> Dictionary:
		return {"gather": host.mode == &"windup"}
