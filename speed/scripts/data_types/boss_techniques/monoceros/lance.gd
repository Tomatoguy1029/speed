## 光の槍の公開値と段の進行。
@tool
extends BossTechnique

## 光を集めて槍の形にする時間（秒）
@export_range(0,100000,0.01) var warn := 1.4:
	set(value):
		warn = value
		_values_dirty = true

## 発進の何秒前に向きを固定するか（秒）
@export_range(0,100000,0.01) var lock_time := 0.25:
	set(value):
		lock_time = value
		_values_dirty = true

## 溜め中に自機へ向き直る速さ（度/秒）
@export_range(0,720,0.1,"radians_as_degrees") var aim_turn := 2.199114857512855:
	set(value):
		aim_turn = value
		_values_dirty = true

## 溜め中に後ろへ下がる速さ
@export_range(0,100000,0.01) var back_speed := 40.0:
	set(value):
		back_speed = value
		_values_dirty = true

## 穂先の長さ。角先からさらに伸びる分。当たりにも含む
@export_range(0,100000,0.01) var head_length := 60.0:
	set(value):
		head_length = value
		_values_dirty = true

## 槍の当たりの太さ
@export_range(0,100000,0.01) var width := 48.0:
	set(value):
		width = value
		_values_dirty = true

## 突き抜ける距離
@export_range(0,100000,0.01) var distance := 1250.0:
	set(value):
		distance = value
		_values_dirty = true

## 突き抜ける速さ
@export_range(0,100000,0.01) var speed := 3400.0:
	set(value):
		speed = value
		_values_dirty = true

## ソニックブームを出す間隔（秒）
@export_range(0,100000,0.01) var boom_interval := 0.045:
	set(value):
		boom_interval = value
		_values_dirty = true

## ソニックブームを出す位置。本体の中心から前への距離
@export_range(0,100000,0.01) var boom_ahead := 300.0:
	set(value):
		boom_ahead = value
		_values_dirty = true

## 突き抜けてから止まるまでの時間（秒）
@export_range(0,100000,0.01) var stop_time := 0.35:
	set(value):
		stop_time = value
		_values_dirty = true

## 止まるときの速さの減り方（1/秒）
@export_range(0,100000,0.01) var stop_decay := 9.0:
	set(value):
		stop_decay = value
		_values_dirty = true

## 止まり始めてから槍の光が砕けるまで（秒）
@export_range(0,100000,0.01) var shatter_time := 0.2:
	set(value):
		shatter_time = value
		_values_dirty = true

## ダメージ
@export_range(0,100000,0.01) var damage := 30.0:
	set(value):
		damage = value
		_values_dirty = true

## 止まったあとの隙（秒）
@export_range(0,100000,0.01) var recover := 2.0:
	set(value):
		recover = value
		_values_dirty = true

## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 10.0:
	set(value):
		cd = value
		_values_dirty = true

