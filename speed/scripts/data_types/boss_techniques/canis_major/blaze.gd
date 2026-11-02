## 燃える猟犬の公開値と動作。
@tool
extends BossTechnique

## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.5:
	set(value):
		warn = value
		_values_dirty = true
## 使う猟犬の数
@export_range(0,100000,1) var count := 3:
	set(value):
		count = value
		_values_dirty = true
## 必要な猟犬の数
@export_range(0,100000,1) var min_hounds := 3:
	set(value):
		min_hounds = value
		_values_dirty = true
## 最初の点火時刻（秒）
@export_range(0,100000,0.01) var ignite_at := 0.5:
	set(value):
		ignite_at = value
		_values_dirty = true
## 点火の間隔（秒）
@export_range(0,100000,0.01) var ignite_step := 0.15:
	set(value):
		ignite_step = value
		_values_dirty = true
## 燃える猟犬の最高速
@export_range(0,100000,0.01) var run_speed := 430.0:
	set(value):
		run_speed = value
		_values_dirty = true
## 明滅へ移る距離
@export_range(0,100000,0.01) var stop_dist := 90.0:
	set(value):
		stop_dist = value
		_values_dirty = true
## 走る時間の上限（秒）
@export_range(0,100000,0.01) var max_run := 4.5:
	set(value):
		max_run = value
		_values_dirty = true
## 爆発前の明滅時間（秒）
@export_range(0,100000,0.01) var blink := 0.6:
	set(value):
		blink = value
		_values_dirty = true
## 爆発の半径
@export_range(0,100000,0.01) var explode_radius := 100.0:
	set(value):
		explode_radius = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 20.0:
	set(value):
		damage = value
		_values_dirty = true
## 硬直（秒）
@export_range(0,100000,0.01) var recover := 0.5:
	set(value):
		recover = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 12.0:
	set(value):
		cd = value
		_values_dirty = true

## 爆発のピクセル炎表示
@export var explosion_fire: PixelFireSettings = preload("res://data/visuals/canis_fire_burst.tres"):
	set(value):
		explosion_fire = value
		_values_dirty = true
