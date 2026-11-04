## 帆を張り、自機を中心とする弧を走りながら射る。
@tool
extends BossTechnique

## 予告の時間（秒）
@export_range(0, 100000, 0.01) var warn := 0.9:
	set(value):
		warn = value
		_values_dirty = true
## 予告中に弧の始点へ寄る速さ（距離毎秒）
@export_range(0, 100000, 0.01) var approach_speed := 900.0:
	set(value):
		approach_speed = value
		_values_dirty = true
## 弧の最小半径（距離）
@export_range(0, 100000, 0.01) var radius_min := 500.0:
	set(value):
		radius_min = value
		_values_dirty = true
## 弧の最大半径（距離）
@export_range(0, 100000, 0.01) var radius_max := 800.0:
	set(value):
		radius_max = value
		_values_dirty = true
## 走る弧の角度（度）
@export_range(0, 100000, 0.01) var arc := 288.0:
	set(value):
		arc = value
		_values_dirty = true
## 走る時間（秒）
@export_range(0, 100000, 0.01) var duration := 4.0:
	set(value):
		duration = value
		_values_dirty = true
## 矢を射る間隔（秒）
@export_range(0, 100000, 0.01) var interval := 0.2:
	set(value):
		interval = value
		_values_dirty = true
## 矢の速さ（距離毎秒）
@export_range(0, 100000, 0.01) var speed := 320.0:
	set(value):
		speed = value
		_values_dirty = true
## 矢の当たりの長さ（距離）
@export_range(0, 100000, 0.01) var length := 60.0:
	set(value):
		length = value
		_values_dirty = true
## 矢の飛距離
@export_range(0, 100000, 0.01) var travel := 1600.0:
	set(value):
		travel = value
		_values_dirty = true
## 矢の太さの半分
@export_range(0, 100000, 0.01) var radius := 6.0:
	set(value):
		radius = value
		_values_dirty = true
## 矢のダメージ
@export_range(0, 100000, 0.01) var damage := 12.0:
	set(value):
		damage = value
		_values_dirty = true
## 帆をたたむ硬直（秒）
@export_range(0, 100000, 0.01) var recover := 1.8:
	set(value):
		recover = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0, 100000, 0.01) var cd := 16.0:
	set(value):
		cd = value
		_values_dirty = true

## 矢の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/light_arrow.tscn"):
	set(value):
		shot_visual = value
		_values_dirty = true

