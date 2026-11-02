## 三本爪の亀裂の値と動き。
@tool
extends BossTechnique

## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.7:
	set(value):
		warn = value
		_values_dirty = true
## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 3.8:
	set(value):
		active = value
		_values_dirty = true
## 爪の開く角度（度）
@export_range(0,360,0.1,"radians_as_degrees") var claw_angle := 0.0666:
	set(value):
		claw_angle = value
		_values_dirty = true
## 片側の爪の数
@export_range(0,100000,1) var claw_count := 3:
	set(value):
		claw_count = value
		_values_dirty = true
## 爪の間隔
@export_range(0,100000,0.01) var claw_gap := 70.0:
	set(value):
		claw_gap = value
		_values_dirty = true
## 中心から最初の爪までの横のずれ
@export_range(0,100000,0.01) var claw_offset := 135.0:
	set(value):
		claw_offset = value
		_values_dirty = true
## 自機の先まで伸ばす長さ
@export_range(0,100000,0.01) var claw_overshoot := 125.0:
	set(value):
		claw_overshoot = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 0.7:
	set(value):
		recover = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 30.0:
	set(value):
		damage = value
		_values_dirty = true
## 到達距離
@export_range(0,100000,0.01) var reach := 1500.0:
	set(value):
		reach = value
		_values_dirty = true
## 当たりの太さ（中心から片側）
@export_range(0,100000,0.01) var width := 24.0:
	set(value):
		width = value
		_values_dirty = true
## 矢の間隔（秒）
@export_range(0,100000,0.01) var interval := 0.4:
	set(value):
		interval = value
		_values_dirty = true
## ひっかきの時間
@export_range(0,100000,0.01) var scratch_time := 0.32:
	set(value):
		scratch_time = value
		_values_dirty = true
## ひっかきの幅
@export_range(0,100000,0.01) var scratch_width := 30.0:
	set(value):
		scratch_width = value
		_values_dirty = true
