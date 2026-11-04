## 星弾の扇の値と動き。
@tool
extends BossTechnique

## 標的の先読み上限
@export_range(0,100000,0.01) var lead_cap := 1200.0:
	set(value):
		lead_cap = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.9:
	set(value):
		warn = value
		_values_dirty = true
## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.15:
	set(value):
		active = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 0.8:
	set(value):
		recover = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 18.0:
	set(value):
		damage = value
		_values_dirty = true
## 当たりの太さ（中心から片側）
@export_range(0,100000,0.01) var width := 9.0:
	set(value):
		width = value
		_values_dirty = true
## 弾数
@export_range(0,100000,1) var count := 9:
	set(value):
		count = value
		_values_dirty = true
## 薙ぐ角度（度）
@export_range(0,360,0.1,"radians_as_degrees") var arc := 1.134464:
	set(value):
		arc = value
		_values_dirty = true
## 半径
@export_range(0,100000,0.01) var radius := 260.0:
	set(value):
		radius = value
		_values_dirty = true
## 矢の速さ
@export_range(0,100000,0.01) var speed := 800.0:
	set(value):
		speed = value
		_values_dirty = true

## 撃つ弾の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/star_bolt.tscn"):
	set(value):
		shot_visual = value
		_values_dirty = true
