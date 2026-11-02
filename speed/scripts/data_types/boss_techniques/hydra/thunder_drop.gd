## 落雷の値と動き。
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
## 雷の範囲
@export_range(0,100000,0.01) var thunder_radius := 150.0:
	set(value):
		thunder_radius = value
		_values_dirty = true
## 雷光の時間
@export_range(0,100000,0.01) var thunder_flash := 0.22:
	set(value):
		thunder_flash = value
		_values_dirty = true
## beam_dmg
@export_range(0,100000,0.01) var beam_dmg := 18.0:
	set(value):
		beam_dmg = value
		_values_dirty = true
## 狙いを固定する割合
@export_range(0,100000,0.01) var target_lock_fraction := 0.55:
	set(value):
		target_lock_fraction = value
		_values_dirty = true
## 雷の先読み距離
@export_range(0,100000,0.01) var thunder_lead := 0.4:
	set(value):
		thunder_lead = value
		_values_dirty = true

## 放つ攻撃の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/hydra_shape.tscn"):
	set(value):
		shot_visual = value
		_values_dirty = true
