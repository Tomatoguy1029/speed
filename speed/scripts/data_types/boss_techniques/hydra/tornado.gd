## 瓦礫竜巻の編集値。
@tool
extends HydraTechnique

## 再使用待ち（秒）
@export_range(0,100000,0.01) var cooldown := 12.0:
	set(value):
		cooldown = value
		_values_dirty = true
## lump_dmg
@export_range(0,100000,0.01) var lump_dmg := 16.0:
	set(value):
		lump_dmg = value
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
## 竜巻の予備動作
@export_range(0,100000,0.01) var tornado_charge := 1.2:
	set(value):
		tornado_charge = value
		_values_dirty = true
## 竜巻が残る時間
@export_range(0,100000,0.01) var tornado_life := 1.8:
	set(value):
		tornado_life = value
		_values_dirty = true
## 竜巻の速さ
@export_range(0,100000,0.01) var tornado_speed := 680.0:
	set(value):
		tornado_speed = value
		_values_dirty = true
## 竜巻の幅
@export_range(0,100000,0.01) var tornado_width := 210.0:
	set(value):
		tornado_width = value
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
