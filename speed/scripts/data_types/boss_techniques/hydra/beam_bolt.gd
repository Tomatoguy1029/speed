## ビーム弾の編集値。
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
## 光弾の長さ
@export_range(0,100000,0.01) var bolt_length := 150.0:
	set(value):
		bolt_length = value
		_values_dirty = true
## 光弾の幅
@export_range(0,100000,0.01) var bolt_width := 28.0:
	set(value):
		bolt_width = value
		_values_dirty = true
## 光弾が残る時間
@export_range(0,100000,0.01) var bolt_life := 2.8:
	set(value):
		bolt_life = value
		_values_dirty = true
## 光弾の速さ
@export_range(0,100000,0.01) var bolt_speed := 780.0:
	set(value):
		bolt_speed = value
		_values_dirty = true
## beam_dmg
@export_range(0,100000,0.01) var beam_dmg := 18.0:
	set(value):
		beam_dmg = value
		_values_dirty = true

func range_info(p: Dictionary) -> Dictionary:
	return {"origin": "head", "max": float(p.bolt_speed) * float(p.bolt_life) + float(p.bolt_length) + float(p.bolt_width) * 0.5}

## 放つ攻撃の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/hydra_shape.tscn"):
	set(value):
		shot_visual = value
		_values_dirty = true
