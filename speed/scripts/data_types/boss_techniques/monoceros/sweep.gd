## 踏み込み薙ぎの値と、踏み込み・停止・振り抜き・戻し。
@tool
extends BossTechnique

## 踏み込みの初めの速さ
@export_range(0,100000,0.01) var approach_speed_start := 250.0:
	set(value):
		approach_speed_start = value
		_values_dirty = true

## 踏み込みの加速（毎秒あたりの速さの増え方）
@export_range(0,100000,0.01) var approach_accel := 2400.0:
	set(value):
		approach_accel = value
		_values_dirty = true

## 踏み込みの最高の速さ
@export_range(0,100000,0.01) var approach_speed_max := 1150.0:
	set(value):
		approach_speed_max = value
		_values_dirty = true

## 踏み込み中に自機へ向き直る速さ（度/秒）
@export_range(0,360,0.1,"radians_as_degrees") var approach_turn := 3.490658503988659:
	set(value):
		approach_turn = value
		_values_dirty = true

## 踏み込みの最短の時間（秒）
@export_range(0,100000,0.01) var approach_min := 0.3:
	set(value):
		approach_min = value
		_values_dirty = true

## 踏み込みの最長の時間（秒）。過ぎたら自機が遠くても止まって振る
@export_range(0,100000,0.01) var approach_max := 1.0:
	set(value):
		approach_max = value
		_values_dirty = true

## 自機がこの距離に入ったら止まって振る
@export_range(0,100000,0.01) var stop_range := 230.0:
	set(value):
		stop_range = value
		_values_dirty = true

## 踏み込みながら首を捻りきるまでの時間（秒）
@export_range(0,100000,0.01) var twist_time := 0.4:
	set(value):
		twist_time = value
		_values_dirty = true

## 踏み込み中の首の捻り（度）
@export_range(0,360,0.1,"radians_as_degrees") var twist := 1.3962634015954636:
	set(value):
		twist = value
		_values_dirty = true

## 止まって溜める時間（秒）
@export_range(0,100000,0.01) var stop_time := 0.22:
	set(value):
		stop_time = value
		_values_dirty = true

## 止まるときの減速（毎秒あたりの速さの減り方）
@export_range(0,100000,0.01) var stop_decel := 9000.0:
	set(value):
		stop_decel = value
		_values_dirty = true

## 溜めきった首の捻り（度）
@export_range(0,360,0.1,"radians_as_degrees") var windup_twist := 1.53588974175501:
	set(value):
		windup_twist = value
		_values_dirty = true

## 振り抜く角度（度）
@export_range(0,360,0.1,"radians_as_degrees") var arc := 3.0543261909900767:
	set(value):
		arc = value
		_values_dirty = true

## 振り抜く時間（秒）。当たりはこの間
@export_range(0,100000,0.01) var active := 0.13:
	set(value):
		active = value
		_values_dirty = true

## 振り切った姿勢で止まる時間（秒）
@export_range(0,100000,0.01) var hold := 0.35:
	set(value):
		hold = value
		_values_dirty = true

## 正面へ戻す時間（秒）
@export_range(0,100000,0.01) var return_time := 0.5:
	set(value):
		return_time = value
		_values_dirty = true

## 戻したあとの隙（秒）
@export_range(0,100000,0.01) var recover := 0.9:
	set(value):
		recover = value
		_values_dirty = true

## ダメージ
@export_range(0,100000,0.01) var damage := 20.0:
	set(value):
		damage = value
		_values_dirty = true

## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 4.0:
	set(value):
		cd = value
		_values_dirty = true
