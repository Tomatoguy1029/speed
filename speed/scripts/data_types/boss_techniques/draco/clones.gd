## 全身複製の値と動き。
@tool
extends BossTechnique

## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.2:
	set(value):
		warn = value
		_values_dirty = true
## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 7.5:
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
## 当たりの太さ（中心から片側）
@export_range(0,100000,0.01) var width := 50.0:
	set(value):
		width = value
		_values_dirty = true
## 複製体のHP
@export_range(0,100000,0.01) var clone_hp := 350.0:
	set(value):
		clone_hp = value
		_values_dirty = true
## 複製1体の星数（仮）
@export_range(0,100000,1) var clone_stars := 13:
	set(value):
		clone_stars = value
		_values_dirty = true
