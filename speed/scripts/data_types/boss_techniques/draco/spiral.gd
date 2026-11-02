## 螺旋収縮の値と動き。
@tool
extends BossTechnique

## 予告（秒）
@export_range(0,100000,0.01) var warn := 5.0:
	set(value):
		warn = value
		_values_dirty = true
## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 6.0:
	set(value):
		active = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.5:
	set(value):
		recover = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 35.0:
	set(value):
		damage = value
		_values_dirty = true
## 外周半径（画面長辺の倍率）
@export_range(0.5,1.5,0.01) var radius_factor := 0.8:
	set(value):
		radius_factor = value
		_values_dirty = true
## 外周の縦横比
@export_range(0.85,1.5,0.01) var aspect_ratio := 1.0:
	set(value):
		aspect_ratio = value
		_values_dirty = true
## 内周半径（画面長辺の倍率）
@export_range(0.05,1.5,0.01) var inner_radius_factor := 0.16:
	set(value):
		inner_radius_factor = value
		_values_dirty = true
## 渦を2周巻く時間（秒）
@export_range(0.5,3,0.01) var coil_time := 1.2:
	set(value):
		coil_time = value
		_values_dirty = true
## 逃げる時間（秒）
@export_range(0.8,3,0.01) var pause := 1.6:
	set(value):
		pause = value
		_values_dirty = true
## 頭と自機の距離
@export_range(200,1000,1) var head_offset := 320.0:
	set(value):
		head_offset = value
		_values_dirty = true
## 退場の時間（秒）
@export_range(0.6,3,0.01) var exit_duration := 1.8:
	set(value):
		exit_duration = value
		_values_dirty = true
## 渦を巻く間の体長（距離）
@export_range(0,20000,1) var spiral_length := 9000.0:
	set(value):
		spiral_length = value
		_values_dirty = true
## 直進して渦がほどける時間（秒）
@export_range(0,100000,0.01) var shrink_time := 2.0:
	set(value):
		shrink_time = value
		_values_dirty = true
## 胴に触れたあとの無敵（秒）
@export_range(0,100000,0.01) var touch_invuln := 1.5:
	set(value):
		touch_invuln = value
		_values_dirty = true

