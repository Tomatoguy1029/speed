## 瓦礫の塊の編集値。
@tool
extends HydraTechnique

## 予備動作（秒）
@export_range(0,100000,0.01) var normal_charge := 0.6:
	set(value):
		normal_charge = value
		_values_dirty = true
## 攻撃後の停止（秒）
@export_range(0,100000,0.01) var normal_hold := 0.9:
	set(value):
		normal_hold = value
		_values_dirty = true
## 技後の待ち（秒）
@export_range(0,100000,0.01) var attack_cd := 3.0:
	set(value):
		attack_cd = value
		_values_dirty = true
## lump_r
@export_range(0,100000,0.01) var lump_r := 26.0:
	set(value):
		lump_r = value
		_values_dirty = true
## lump_speed
@export_range(0,100000,0.01) var lump_speed := 520.0:
	set(value):
		lump_speed = value
		_values_dirty = true
## lump_dmg
@export_range(0,100000,0.01) var lump_dmg := 16.0:
	set(value):
		lump_dmg = value
		_values_dirty = true

## 放つ攻撃の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/hydra_shape.tscn"):
	set(value):
		shot_visual = value
		_values_dirty = true
