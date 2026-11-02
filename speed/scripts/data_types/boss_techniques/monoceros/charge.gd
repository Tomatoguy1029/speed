## 突進の値と動き。
@tool
extends BossTechnique

## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.85:
	set(value):
		active = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 3.0:
	set(value):
		cd = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 25.0:
	set(value):
		damage = value
		_values_dirty = true
## 移動距離
@export_range(0,100000,0.01) var distance := 1250.0:
	set(value):
		distance = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.5:
	set(value):
		recover = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.05:
	set(value):
		warn = value
		_values_dirty = true

## 第2形態の攻撃の継続時間（秒）。短いほど速い
@export_range(0,100000,0.01) var active_p2 := 0.71:
	set(value):
		active_p2 = value
		_values_dirty = true
