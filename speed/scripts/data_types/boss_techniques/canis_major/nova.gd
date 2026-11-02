## シリウスの閃光の公開値と動作。
@tool
extends BossTechnique

## 使う猟犬の数
@export_range(0,100000,1) var count := 6:
	set(value):
		count = value
		_values_dirty = true
## 必要な猟犬の数
@export_range(0,100000,1) var min_hounds := 6:
	set(value):
		min_hounds = value
		_values_dirty = true
## 口元から組までの距離
@export_range(0,100000,0.01) var pair_dist := 95.0:
	set(value):
		pair_dist = value
		_values_dirty = true
## 組の中心から左右への距離
@export_range(0,100000,0.01) var pair_side := 14.0:
	set(value):
		pair_side = value
		_values_dirty = true
## 組の持ち場へ向かう最高速
@export_range(0,100000,0.01) var gather_speed := 420.0:
	set(value):
		gather_speed = value
		_values_dirty = true
## 影を作る猟犬の体の半径
@export_range(0,100000,0.01) var body_radius := 12.0:
	set(value):
		body_radius = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.4:
	set(value):
		warn = value
		_values_dirty = true
## 光の輪の数
@export_range(0,100000,1) var rings := 2:
	set(value):
		rings = value
		_values_dirty = true
## 輪を出す間隔（秒）
@export_range(0,100000,0.01) var ring_gap := 0.35:
	set(value):
		ring_gap = value
		_values_dirty = true
## 輪が広がる速さ
@export_range(0,100000,0.01) var ring_speed := 560.0:
	set(value):
		ring_speed = value
		_values_dirty = true
## 輪の判定の半幅
@export_range(0,100000,0.01) var ring_band := 8.0:
	set(value):
		ring_band = value
		_values_dirty = true
## 輪が消える半径
@export_range(0,100000,0.01) var ring_end := 1400.0:
	set(value):
		ring_end = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 22.0:
	set(value):
		damage = value
		_values_dirty = true
## 光った後に猟犬を戻すまで（秒）
@export_range(0,100000,0.01) var after := 2.4:
	set(value):
		after = value
		_values_dirty = true
## 硬直（秒）
@export_range(0,100000,0.01) var recover := 1.6:
	set(value):
		recover = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 16.0:
	set(value):
		cd = value
		_values_dirty = true
