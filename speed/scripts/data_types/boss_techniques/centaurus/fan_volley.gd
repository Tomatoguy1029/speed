## 扇状連射の編集値。
@tool
extends BossTechnique

## 引き絞りの予告（秒）
@export_range(0, 100000, 0.01) var warn := 0.9:
	set(value):
		warn = value
		_values_dirty = true
## 射る回数
@export_range(0, 100000, 1) var shots := 3:
	set(value):
		shots = value
		_values_dirty = true
## 射る間隔（秒）
@export_range(0, 100000, 0.01) var interval := 0.8:
	set(value):
		interval = value
		_values_dirty = true
## 一度に射る本数
@export_range(0, 100000, 1) var count := 9:
	set(value):
		count = value
		_values_dirty = true
## 扇全体の角度（度）
@export_range(0, 100000, 0.01) var spread := 100.0:
	set(value):
		spread = value
		_values_dirty = true
## 矢の速さ（距離毎秒）
@export_range(0, 100000, 0.01) var speed := 380.0:
	set(value):
		speed = value
		_values_dirty = true
## 矢の先端から尾までの当たりの長さ
@export_range(0, 100000, 0.01) var length := 56.0:
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
## ダメージ
@export_range(0, 100000, 0.01) var damage := 14.0:
	set(value):
		damage = value
		_values_dirty = true
## 攻撃後の硬直（秒）
@export_range(0, 100000, 0.01) var recover := 1.6:
	set(value):
		recover = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0, 100000, 0.01) var cd := 14.0:
	set(value):
		cd = value
		_values_dirty = true

## 矢の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/light_arrow.tscn"):
	set(value):
		shot_visual = value
		_values_dirty = true

