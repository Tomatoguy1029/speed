## 強弓の値と動き。
@tool
extends BossTechnique

## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 7.0:
	set(value):
		cd = value
		_values_dirty = true
## 弾数
@export_range(0,100000,1) var count := 1:
	set(value):
		count = value
		_values_dirty = true
## 弾数（第2形態）
@export_range(0,100000,1) var count_p2 := 3:
	set(value):
		count_p2 = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 28.0:
	set(value):
		damage = value
		_values_dirty = true
## 発射前の警告（秒）
@export_range(0,100000,0.01) var alert := 0.4:
	set(value):
		alert = value
		_values_dirty = true
## 半径
@export_range(0,100000,0.01) var radius := 30.0:
	set(value):
		radius = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.5:
	set(value):
		recover = value
		_values_dirty = true
## 矢の速さ
@export_range(0,100000,0.01) var speed := 1800.0:
	set(value):
		speed = value
		_values_dirty = true
## 扇の角度（度）
@export_range(0,360,0.1,"radians_as_degrees") var spread := 0.22:
	set(value):
		spread = value
		_values_dirty = true
## 矢の射程
@export_range(0,100000,0.01) var travel := 1600.0:
	set(value):
		travel = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.4:
	set(value):
		warn = value
		_values_dirty = true

## 撃つ弾の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/light_arrow.tscn"):
	set(value):
		shot_visual = value
		_values_dirty = true

