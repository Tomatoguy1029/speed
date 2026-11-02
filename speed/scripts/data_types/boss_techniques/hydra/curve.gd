## 曲線ビームの値と動き。
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
@export_range(0,100000,0.01) var cooldown := 14.0:
	set(value):
		cooldown = value
		_values_dirty = true
## 曲線攻撃までの遅れ
@export_range(0,100000,0.01) var curve_delay := 0.8:
	set(value):
		curve_delay = value
		_values_dirty = true
## 曲線攻撃の軌跡差（ラジアン）
@export_range(0,100000,0.01) var curve_lag := 1.1:
	set(value):
		curve_lag = value
		_values_dirty = true
## 曲線攻撃の時間
@export_range(0,100000,0.01) var curve_time := 2.6:
	set(value):
		curve_time = value
		_values_dirty = true
## 曲線攻撃の回転速度（ラジアン/秒）
@export_range(0,100000,0.01) var curve_turn := 0.45:
	set(value):
		curve_turn = value
		_values_dirty = true
## 実行時間（秒）
@export_range(0,100000,0.01) var performance_time := 3.4:
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
