## 薙ぎ払いの編集値。
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
## 薙ぎ時間（秒）
@export_range(0,100000,0.01) var sweep_time := 0.7:
	set(value):
		sweep_time = value
		_values_dirty = true
## 薙ぎの角度（ラジアン）
@export_range(0,100000,0.01) var sweep_arc := 1.8:
	set(value):
		sweep_arc = value
		_values_dirty = true
## 薙ぎの長さ
@export_range(0,100000,0.01) var sweep_reach := 350.0:
	set(value):
		sweep_reach = value
		_values_dirty = true
## bite_radius
@export_range(0,100000,0.01) var bite_radius := 75.0:
	set(value):
		bite_radius = value
		_values_dirty = true
## bite_dmg
@export_range(0,100000,0.01) var bite_dmg := 16.0:
	set(value):
		bite_dmg = value
		_values_dirty = true

func range_info(p: Dictionary) -> Dictionary:
	return {"origin": "base", "max": float(p.sweep_reach) + float(p.bite_radius) * 0.5}
