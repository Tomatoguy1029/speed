## 雷の頭突きの値と動き。
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
## 踏み込み時間（秒）
@export_range(0,100000,0.01) var normal_lunge := 0.16:
	set(value):
		normal_lunge = value
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
