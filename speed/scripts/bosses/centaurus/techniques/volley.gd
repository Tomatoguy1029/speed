## 速射の値と動き。
@tool
extends BossTechnique

## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 3.0:
	set(value):
		cd = value
		_values_dirty = true
## 弾数
@export_range(0,100000,1) var count := 5:
	set(value):
		count = value
		_values_dirty = true
## 弾数（第2形態）
@export_range(0,100000,1) var count_p2 := 8:
	set(value):
		count_p2 = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 12.0:
	set(value):
		damage = value
		_values_dirty = true
## 矢の間隔（秒）
@export_range(0,100000,0.01) var interval := 0.18:
	set(value):
		interval = value
		_values_dirty = true
## 半径
@export_range(0,100000,0.01) var radius := 12.0:
	set(value):
		radius = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 0.8:
	set(value):
		recover = value
		_values_dirty = true
## 矢の速さ
@export_range(0,100000,0.01) var speed := 900.0:
	set(value):
		speed = value
		_values_dirty = true
## 矢の射程
@export_range(0,100000,0.01) var travel := 1400.0:
	set(value):
		travel = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.6:
	set(value):
		warn = value
		_values_dirty = true

## 撃つ弾の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/light_arrow.tscn"):
	set(value):
		shot_visual = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/centaurus/technique_runner.gd":
	pass

	func kind() -> StringName:
		return &"volley"
