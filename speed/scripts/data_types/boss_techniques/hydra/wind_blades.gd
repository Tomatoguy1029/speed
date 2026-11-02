## 風刃の編集値。
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
## 刃を出す間隔
@export_range(0,100000,0.01) var blade_interval := 0.18:
	set(value):
		blade_interval = value
		_values_dirty = true
## 刃の大きさ
@export_range(0,100000,0.01) var blade_size := 100.0:
	set(value):
		blade_size = value
		_values_dirty = true
## 刃の幅
@export_range(0,100000,0.01) var blade_width := 28.0:
	set(value):
		blade_width = value
		_values_dirty = true
## 刃が残る時間
@export_range(0,100000,0.01) var blade_life := 3.0:
	set(value):
		blade_life = value
		_values_dirty = true
## 刃の速さ
@export_range(0,100000,0.01) var blade_speed := 600.0:
	set(value):
		blade_speed = value
		_values_dirty = true
## 刃の広がり角度（ラジアン）
@export_range(0,100000,0.01) var blade_spread := 1.0:
	set(value):
		blade_spread = value
		_values_dirty = true
## bite_dmg
@export_range(0,100000,0.01) var bite_dmg := 16.0:
	set(value):
		bite_dmg = value
		_values_dirty = true

func range_info(p: Dictionary) -> Dictionary:
	return {"origin": "head", "max": float(p.blade_speed) * float(p.blade_life) + float(p.blade_size)}

## 放つ攻撃の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/hydra_shape.tscn"):
	set(value):
		shot_visual = value
		_values_dirty = true
