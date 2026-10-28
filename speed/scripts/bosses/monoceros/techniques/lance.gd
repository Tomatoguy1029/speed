## 光の槍の値と動き。
@tool
extends BossTechnique

## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.38:
	set(value):
		active = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 10.0:
	set(value):
		cd = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 30.0:
	set(value):
		damage = value
		_values_dirty = true
## 移動距離
@export_range(0,100000,0.01) var distance := 340.0:
	set(value):
		distance = value
		_values_dirty = true
## 到達距離
@export_range(0,100000,0.01) var reach := 650.0:
	set(value):
		reach = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 2.2:
	set(value):
		recover = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.35:
	set(value):
		warn = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/monoceros/techniques/charge.gd".Runner:
	pass

	func kind() -> StringName:
		return &"lance"

	func horn_points(host: MonocerosBoss, sweep_fraction := -1.0) -> PackedVector2Array:
		var at := host.table.pos[host.body]
		var angle := host.table.facing[host.body]
		var reach := host.horn_length()
		reach = float(host.rule().reach)
		var direction := Vector2.from_angle(angle)
		return PackedVector2Array([at + direction * host.table.r[host.body] * 0.65, at + direction * reach])
