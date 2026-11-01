## ケンタウルス座の技の値と実行処理。
@tool
extends BossTechnique

const PART_ANIMATION := preload("res://data/visuals/centaurus_animation.tres")
# 脚画像（23×52）の下端中央。右脚は画像の配置が左へ4ずれている。
const FOOT_CONTACTS := {"FrontLeftLeg": Vector2(11.5, 52.0), "FrontRightLeg": Vector2(7.5, 52.0)}

## 描画ノードを参照せず、保存された配置と現在の動作時刻から接地点を求める。
static func contact_center(animation: Resource, time: float) -> Vector2:
	var pose: Dictionary = animation.sample("stomp", time)
	var center := Vector2.ZERO
	for path: String in FOOT_CONTACTS:
		var entry: Dictionary = pose.get(path, animation.poses.get("neutral", {}).get(path, {}))
		var transform := Transform2D(float(entry.get("rotation", 0.0)), entry.get("scale", Vector2.ONE), float(entry.get("skew", 0.0)), entry.get("position", Vector2.ZERO))
		if animation.part_pivots.has(path) and entry.has("pivot_origin"):
			transform.origin = entry.pivot_origin - transform.basis_xform(animation.part_pivots[path])
		center += transform * FOOT_CONTACTS[path]
	return center * 0.5


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
		host.combat_trace.evaluate()
		var offset := host.run_state.ship_pos - host.stomp_center()
		if not hit and offset.length() <= float(r.range_radius) + host.ctx.cfg.ship_radius and absf(Geom.angle_diff(offset.angle(), host.table.facing[host.body])) <= deg_to_rad(float(r.half_angle)):
			hit = host.combat_trace.damage(float(r.damage) * host.ctx.cfg.atk_scale, 0.0, &"stomp", &"centaurus")
