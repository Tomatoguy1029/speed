## 瓦礫砕きの編集値。
@tool
extends HydraTechnique

## beam_dmg
@export_range(0,100000,0.01) var beam_dmg := 18.0:
	set(value):
		beam_dmg = value
		_values_dirty = true
## beam_len
@export_range(0,100000,0.01) var beam_len := 1400.0:
	set(value):
		beam_len = value
		_values_dirty = true
## 光の太さ
@export_range(0,100000,0.01) var beam_width := 40.0:
	set(value):
		beam_width = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cooldown := 12.0:
	set(value):
		cooldown = value
		_values_dirty = true
## 実行時間（秒）
@export_range(0,100000,0.01) var performance_time := 3.4:
	set(value):
		performance_time = value
		_values_dirty = true
## rubble_count
@export_range(0,100000,1) var rubble_count := 6:
	set(value):
		rubble_count = value
		_values_dirty = true
## shard_dmg
@export_range(0,100000,0.01) var shard_dmg := 10.0:
	set(value):
		shard_dmg = value
		_values_dirty = true
## shard_speed
@export_range(0,100000,0.01) var shard_speed := 420.0:
	set(value):
		shard_speed = value
		_values_dirty = true
## ビームの掃引角度（ラジアン）
@export_range(0,100000,0.01) var shatter_arc := 1.8:
	set(value):
		shatter_arc = value
		_values_dirty = true
## 破片を広げる時間
@export_range(0,100000,0.01) var shatter_deploy := 0.7:
	set(value):
		shatter_deploy = value
		_values_dirty = true
## 破片が残る時間
@export_range(0,100000,0.01) var shatter_time := 1.8:
	set(value):
		shatter_time = value
		_values_dirty = true
## 技後の全体待ち（秒）
@export_range(0,100000,0.01) var tech_recovery := 1.5:
	set(value):
		tech_recovery = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warning_time := 0.8:
	set(value):
		warning_time = value
		_values_dirty = true

## 放つ攻撃の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/hydra_shape.tscn"):
	set(value):
		shot_visual = value
		_values_dirty = true
