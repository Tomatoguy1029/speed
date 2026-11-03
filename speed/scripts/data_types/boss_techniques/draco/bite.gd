## 噛みつきの値と動き。
@tool
extends BossTechnique

## 標的の先読み上限
@export_range(0,100000,0.01) var lead_cap := 440.0:
	set(value):
		lead_cap = value
		_values_dirty = true
## 引き戻す時間
@export_range(0,100000,0.01) var retract := 110.0:
	set(value):
		retract = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.8:
	set(value):
		warn = value
		_values_dirty = true
## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.3:
	set(value):
		active = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 0.8:
	set(value):
		recover = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 30.0:
	set(value):
		damage = value
		_values_dirty = true
## 到達距離
@export_range(0,100000,0.01) var reach := 360.0:
	set(value):
		reach = value
		_values_dirty = true
## 当たりの太さ（中心から片側）
@export_range(0,100000,0.01) var width := 96.0:
	set(value):
		width = value
		_values_dirty = true
