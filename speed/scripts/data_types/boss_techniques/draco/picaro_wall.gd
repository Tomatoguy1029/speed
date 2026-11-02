## ピカロ隊列と光の矢の値と動き。
@tool
extends BossTechnique

## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.0:
	set(value):
		warn = value
		_values_dirty = true
## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 6.0:
	set(value):
		active = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.2:
	set(value):
		recover = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 28.0:
	set(value):
		damage = value
		_values_dirty = true
## 隊列に使う敵
@export var wall_candidates: Array[StringName] = []:
	set(value):
		wall_candidates = value
		_values_dirty = true
## 弾数
@export_range(0,100000,1) var count := 3:
	set(value):
		count = value
		_values_dirty = true
## 矢の数
@export_range(0,100000,1) var arrows := 5:
	set(value):
		arrows = value
		_values_dirty = true
## 矢の間隔（秒）
@export_range(0,100000,0.01) var interval := 0.45:
	set(value):
		interval = value
		_values_dirty = true
## 飛行時間
@export_range(0,100000,0.01) var flight := 0.75:
	set(value):
		flight = value
		_values_dirty = true
## 着弾の予告
@export_range(0,100000,0.01) var impact_warn := 1.0:
	set(value):
		impact_warn = value
		_values_dirty = true
## 半径
@export_range(0,100000,0.01) var radius := 85.0:
	set(value):
		radius = value
		_values_dirty = true

## 撃つ弾の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/cosmic_arrow.tscn"):
	set(value):
		shot_visual = value
		_values_dirty = true
## 着弾の見た目
@export var blast_visual: PackedScene = preload("res://scenes/attacks/zone.tscn"):
	set(value):
		blast_visual = value
		_values_dirty = true

