## 尻尾の叩きつけの値と動き。
@tool
extends BossTechnique

## 標的の先読み上限
@export_range(0,100000,0.01) var lead_cap := 600.0:
	set(value):
		lead_cap = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.75:
	set(value):
		warn = value
		_values_dirty = true
## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.35:
	set(value):
		active = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.0:
	set(value):
		recover = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 30.0:
	set(value):
		damage = value
		_values_dirty = true
## 到達距離
@export_range(0,100000,0.01) var reach := 1200.0:
	set(value):
		reach = value
		_values_dirty = true
## 半径
@export_range(0,100000,0.01) var radius := 110.0:
	set(value):
		radius = value
		_values_dirty = true
