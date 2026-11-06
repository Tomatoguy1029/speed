## 格子ビームの値と動き。
@tool
extends HydraTechnique

## beam_dmg
@export_range(0,100000,0.01) var beam_dmg := 18.0:
	set(value):
		beam_dmg = value
		_values_dirty = true
## 光の太さ
@export_range(0,100000,0.01) var beam_width := 40.0:
	set(value):
		beam_width = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cooldown := 30.0:
	set(value):
		cooldown = value
		_values_dirty = true
## 予備動作（秒）
@export_range(0,100000,0.01) var normal_charge := 0.6:
	set(value):
		normal_charge = value
		_values_dirty = true
## 実行時間（秒）
@export_range(0,100000,0.01) var performance_time := 5.2:
	set(value):
		performance_time = value
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
