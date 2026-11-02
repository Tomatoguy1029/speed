## 後ろ蹴りの値と動き。
@tool
extends BossTechnique

## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.24:
	set(value):
		active = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 9.0:
	set(value):
		cd = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 18.0:
	set(value):
		damage = value
		_values_dirty = true
## 攻撃後の停止（秒）
@export_range(0,100000,0.01) var hold := 0.25:
	set(value):
		hold = value
		_values_dirty = true
## 到達距離
@export_range(0,100000,0.01) var reach := 210.0:
	set(value):
		reach = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.2:
	set(value):
		recover = value
		_values_dirty = true
## 正面へ戻る速さ（度/秒）
@export_range(0,360,0.1,"radians_as_degrees") var return_speed := 4.1887902047863905:
	set(value):
		return_speed = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.85:
	set(value):
		warn = value
		_values_dirty = true
