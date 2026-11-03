## 背後攻撃の値と動き。
@tool
extends BossTechnique

## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.2:
	set(value):
		active = value
		_values_dirty = true
## 背中から範囲の中心までの距離
@export_range(0,100000,0.01) var back_offset := 110.0:
	set(value):
		back_offset = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 4.0:
	set(value):
		cd = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 18.0:
	set(value):
		damage = value
		_values_dirty = true
## 攻撃範囲の半径
@export_range(0,100000,0.01) var range_radius := 140.0:
	set(value):
		range_radius = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.0:
	set(value):
		recover = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.4:
	set(value):
		warn = value
		_values_dirty = true

