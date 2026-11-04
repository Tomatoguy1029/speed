## 矢の雨の値と動き。
@tool
extends BossTechnique

## 矢を落とす間隔（距離）
@export_range(0,100000,0.01) var arrow_gap := 44.0:
	set(value):
		arrow_gap = value
		_values_dirty = true
## 一度に落とす矢の数
@export_range(0,100000,1) var arrows_per_step := 1:
	set(value):
		arrows_per_step = value
		_values_dirty = true
## 第2形態で矢を落とす間隔（距離）
@export_range(0,100000,0.01) var arrow_gap_p2 := 22.0:
	set(value):
		arrow_gap_p2 = value
		_values_dirty = true
## 第2形態で一度に落とす矢の数
@export_range(0,100000,1) var arrows_per_step_p2 := 2:
	set(value):
		arrows_per_step_p2 = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 9.0:
	set(value):
		cd = value
		_values_dirty = true
## 円の半径
@export_range(0,100000,0.01) var circle_radius := 100.0:
	set(value):
		circle_radius = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 14.0:
	set(value):
		damage = value
		_values_dirty = true
## 円が通ってから矢を落とし始めるまで（秒）
@export_range(0,100000,0.01) var drop_delay := 0.4:
	set(value):
		drop_delay = value
		_values_dirty = true
## 矢が降りる高さ
@export_range(0,100000,0.01) var drop_height := 70.0:
	set(value):
		drop_height = value
		_values_dirty = true
## 矢が不透明になる時間（秒）
@export_range(0,100000,0.01) var fade := 0.3:
	set(value):
		fade = value
		_values_dirty = true
## 矢が降りる時間（秒）
@export_range(0,100000,0.01) var fall := 0.3:
	set(value):
		fall = value
		_values_dirty = true
## 前方への距離
@export_range(0,100000,0.01) var forward := 650.0:
	set(value):
		forward = value
		_values_dirty = true
## 刺さった矢が残る時間（秒）
@export_range(0,100000,0.01) var linger := 0.6:
	set(value):
		linger = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 0.8:
	set(value):
		recover = value
		_values_dirty = true
## 曲がり具合（度）
@export_range(0,360,0.1,"radians_as_degrees") var trace_bend := 1.2:
	set(value):
		trace_bend = value
		_values_dirty = true
## トレースの間隔（秒）
@export_range(0,100000,0.01) var trace_gap := 0.35:
	set(value):
		trace_gap = value
		_values_dirty = true
## トレースの長さ
@export_range(0,100000,0.01) var trace_length := 900.0:
	set(value):
		trace_length = value
		_values_dirty = true
## トレースの速さ
@export_range(0,100000,0.01) var trace_speed := 1200.0:
	set(value):
		trace_speed = value
		_values_dirty = true
## トレースの回数
@export_range(0,100000,1) var traces := 4:
	set(value):
		traces = value
		_values_dirty = true
## トレースの回数（第2形態）
@export_range(0,100000,1) var traces_p2 := 6:
	set(value):
		traces_p2 = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.8:
	set(value):
		warn = value
		_values_dirty = true

## 撃つ弾の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/light_arrow.tscn"):
	set(value):
		shot_visual = value
		_values_dirty = true

