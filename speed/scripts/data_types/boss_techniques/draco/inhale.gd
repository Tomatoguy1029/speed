## 吸引と吐き出しの値と動き。
@tool
extends BossTechnique

## 吐き出す彗星弾の弧
@export var arcs: Array[Resource] = []:
	set(value):
		arcs = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.2:
	set(value):
		warn = value
		_values_dirty = true
## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 6.0:
	set(value):
		active = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.4:
	set(value):
		recover = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 40.0:
	set(value):
		damage = value
		_values_dirty = true
## 到達距離
@export_range(0,100000,0.01) var reach := 1800.0:
	set(value):
		reach = value
		_values_dirty = true
## 当たりの太さ（中心から片側）
@export_range(0,100000,0.01) var width := 120.0:
	set(value):
		width = value
		_values_dirty = true
## 吸い込み時間
@export_range(0,100000,0.01) var inhale_time := 3.0:
	set(value):
		inhale_time = value
		_values_dirty = true
## 引き寄せる範囲
@export_range(0,100000,0.01) var pull_range := 1500.0:
	set(value):
		pull_range = value
		_values_dirty = true
## 引き寄せる速さ
@export_range(0,100000,0.01) var pull_speed := 650.0:
	set(value):
		pull_speed = value
		_values_dirty = true
## 複製体の引き寄せ速度
@export_range(0,100000,0.01) var picaro_pull_speed := 900.0:
	set(value):
		picaro_pull_speed = value
		_values_dirty = true
## 口元の半径
@export_range(0,100000,0.01) var mouth_radius := 75.0:
	set(value):
		mouth_radius = value
		_values_dirty = true
## 噛みつきのダメージ
@export_range(0,100000,0.01) var bite_damage := 30.0:
	set(value):
		bite_damage = value
		_values_dirty = true
## 光を出す時間（秒）
@export_range(0,100000,0.01) var beam_time := 2.0:
	set(value):
		beam_time = value
		_values_dirty = true
## ビームが伸びきる時間（秒）
@export_range(0,100000,0.01) var beam_extend := 0.25:
	set(value):
		beam_extend = value
		_values_dirty = true
## ビームの予告
@export_range(0,100000,0.01) var beam_warn := 0.5:
	set(value):
		beam_warn = value
		_values_dirty = true
## 星ごとの彗星数
@export_range(0,100000,1) var comets_per_star := 2:
	set(value):
		comets_per_star = value
		_values_dirty = true
## 彗星の同時上限
@export_range(0,100000,1) var comet_cap := 24:
	set(value):
		comet_cap = value
		_values_dirty = true
## 彗星の速さ
@export_range(0,100000,0.01) var comet_speed := 480.0:
	set(value):
		comet_speed = value
		_values_dirty = true

## 撃つ弾の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/bolt.tscn"):
	set(value):
		shot_visual = value
		_values_dirty = true
## ビームの見た目
@export var beam_visual: PackedScene = preload("res://scenes/attacks/beam_draco.tscn"):
	set(value):
		beam_visual = value
		_values_dirty = true

