## 背後攻撃の値と動き。
@tool
extends BossTechnique

## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.2
## 背中から範囲の中心までの距離
@export_range(0,100000,0.01) var back_offset := 110.0
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 4.0
## ダメージ
@export_range(0,100000,0.01) var damage := 18.0
## 攻撃範囲の半径
@export_range(0,100000,0.01) var range_radius := 140.0
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.0
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.4

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/centaurus/technique_runner.gd":
	func strike_on(host: CentaurusBoss) -> void:
		if host.mode != &"windup": return
		host.mode = &"strike"
		host.attack_hit = false
		host._cue(&"strike")

	## 背後攻撃の範囲の中心。背中から back_offset だけ後ろ。

	func rear_center(host: CentaurusBoss, r: Dictionary) -> Vector2:
		return host.table.pos[host.body] - Vector2.from_angle(host.table.facing[host.body]) * float(r.back_offset)

	func _strike_tick(host: CentaurusBoss) -> void:
		if host.attack_hit: return
		var r := host.rule()
		var center := host.rear_center(r)
		var reach := float(r.range_radius) + host.ctx.cfg.ship_radius
		if Geometry2D.get_closest_point_to_segment(center, host._previous_ship, host.run_state.ship_pos).distance_to(center) <= reach:
			host.attack_hit = true
			host.ctx.ship.damage(float(r.damage) * host.ctx.cfg.atk_scale, 0.0, &"rear_attack", &"centaurus")

	## 背後攻撃を共通フローが今すぐ選べるか。選べる間は離脱より背後攻撃を優先する。
