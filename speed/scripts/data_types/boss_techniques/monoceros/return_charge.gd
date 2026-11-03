## 連続突進の値と動き。
@tool
extends BossTechnique

## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.8:
	set(value):
		active = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 12.0:
	set(value):
		cd = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 25.0:
	set(value):
		damage = value
		_values_dirty = true
## 移動距離
@export_range(0,100000,0.01) var distance := 1150.0:
	set(value):
		distance = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 2.4:
	set(value):
		recover = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.0:
	set(value):
		warn = value
		_values_dirty = true

## 突進の回数
@export_range(1,100000,1) var passes := 3:
	set(value):
		passes = value
		_values_dirty = true

## 各回の突進で、自機の位置から先へ突き抜ける距離
@export_range(0,100000,0.01) var overshoot := 300.0:
	set(value):
		overshoot = value
		_values_dirty = true

## 突き抜けてから止まるまでの時間（秒）
@export_range(0,100000,0.01) var brake_time := 0.18:
	set(value):
		brake_time = value
		_values_dirty = true

## 止まり始めの速さ（突進の速さに対する割合）
@export_range(0,100000,0.01) var brake_speed_ratio := 0.5:
	set(value):
		brake_speed_ratio = value
		_values_dirty = true

## 2回目からの、止まってから発進までの時間（秒）
@export_range(0,100000,0.01) var turn_time := 0.4:
	set(value):
		turn_time = value
		_values_dirty = true

## 2回目からの、発進の何秒前に向きを固定するか（秒）
@export_range(0,100000,0.01) var turn_lock := 0.1:
	set(value):
		turn_lock = value
		_values_dirty = true

## 向き直りで、頭が体より先に自機を向く最大の角度（度）
@export_range(0,360,0.1,"radians_as_degrees") var head_lead := deg_to_rad(25.0):
	set(value):
		head_lead = value
		_values_dirty = true

## 第2形態の、1回の最大距離を進む時間（秒）。短いほど速い
@export_range(0,100000,0.01) var active_p2 := 0.67:
	set(value):
		active_p2 = value
		_values_dirty = true

## 第2形態の突進の回数
@export_range(1,100000,1) var passes_p2 := 4:
	set(value):
		passes_p2 = value
		_values_dirty = true

