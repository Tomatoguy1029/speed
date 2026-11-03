## 前脚の踏みつけの編集値。
@tool
extends BossTechnique

## 予告（秒）
@export_range(0, 100000, 0.01) var warn := 0.6:
	set(value):
		warn = value
		_values_dirty = true
## 扇の当たりが続く時間（秒）
@export_range(0, 100000, 0.01) var active := 0.15:
	set(value):
		active = value
		_values_dirty = true
## 扇の半径（距離）
@export_range(0, 100000, 0.01) var range_radius := 260.0:
	set(value):
		range_radius = value
		_values_dirty = true
## 正面から扇の端までの角度（度）
@export_range(0, 100000, 0.01) var half_angle := 50.0:
	set(value):
		half_angle = value
		_values_dirty = true
## ダメージ
@export_range(0, 100000, 0.01) var damage := 20.0:
	set(value):
		damage = value
		_values_dirty = true
## 攻撃後の硬直（秒）
@export_range(0, 100000, 0.01) var recover := 1.0:
	set(value):
		recover = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0, 100000, 0.01) var cd := 4.0:
	set(value):
		cd = value
		_values_dirty = true

