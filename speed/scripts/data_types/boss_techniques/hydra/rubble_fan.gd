## 瓦礫の散弾の編集値。
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
## rubble_count
@export_range(0,100000,1) var rubble_count := 6:
	set(value):
		rubble_count = value
		_values_dirty = true
## 瓦礫の広がり角度（ラジアン）
@export_range(0,100000,0.01) var rubble_spread := 1.3:
	set(value):
		rubble_spread = value
		_values_dirty = true
## 小さい瓦礫の半径
@export_range(0,100000,0.01) var rubble_small_radius := 16.0:
	set(value):
		rubble_small_radius = value
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
