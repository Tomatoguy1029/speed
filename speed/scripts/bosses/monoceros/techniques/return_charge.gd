## 往復突進の値と動き。
@tool
extends BossTechnique

## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.8:
	set(value):
		active = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 12.0:
	set(value):
		cd = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 25.0:
	set(value):
		damage = value
		_values_dirty = true
## 移動距離
@export_range(0,100000,0.01) var distance := 1150.0:
	set(value):
		distance = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 2.4:
	set(value):
		recover = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.0:
	set(value):
		warn = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/monoceros/techniques/charge.gd".Runner:
	pass

	func kind() -> StringName:
		return &"return_charge"
