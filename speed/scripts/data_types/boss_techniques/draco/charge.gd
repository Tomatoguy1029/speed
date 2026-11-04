## 突進の値と動き。
@tool
extends BossTechnique

## 標的の先読み上限
@export_range(0,100000,0.01) var lead_cap := 900.0:
	set(value):
		lead_cap = value
		_values_dirty = true
## 着地点の先までの距離
@export_range(0,100000,0.01) var overshoot := 260.0:
	set(value):
		overshoot = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.9:
	set(value):
		warn = value
		_values_dirty = true
## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.7:
	set(value):
		active = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.0:
	set(value):
		recover = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 35.0:
	set(value):
		damage = value
		_values_dirty = true
## 当たりの太さ（中心から片側）
@export_range(0,100000,0.01) var width := 96.0:
	set(value):
		width = value
		_values_dirty = true
