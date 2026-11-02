## 風の帯の値と動き。
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
## 風の継続時間
@export_range(0,100000,0.01) var wind_time := 1.0:
	set(value):
		wind_time = value
		_values_dirty = true
## 風の長さ
@export_range(0,100000,0.01) var wind_length := 340.0:
	set(value):
		wind_length = value
		_values_dirty = true
## 風の幅
@export_range(0,100000,0.01) var wind_width := 180.0:
	set(value):
		wind_width = value
		_values_dirty = true
## 風の押し出す力
@export_range(0,100000,0.01) var wind_force := 2600.0:
	set(value):
		wind_force = value
		_values_dirty = true

func range_info(p: Dictionary) -> Dictionary:
	return {"origin": "head", "max": float(p.wind_length) + float(p.wind_width) * 0.5}

## 放つ攻撃の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/hydra_shape.tscn"):
	set(value):
		shot_visual = value
		_values_dirty = true
