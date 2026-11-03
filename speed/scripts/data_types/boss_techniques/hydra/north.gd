## 同時噛みつきの値と動き。
@tool
extends HydraTechnique

## bite_dmg
@export_range(0,100000,0.01) var bite_dmg := 16.0:
	set(value):
		bite_dmg = value
		_values_dirty = true
## bite_radius
@export_range(0,100000,0.01) var bite_radius := 75.0:
	set(value):
		bite_radius = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cooldown := 14.0:
	set(value):
		cooldown = value
		_values_dirty = true
## 北の首の飛行時間
@export_range(0,100000,0.01) var north_flight := 0.3:
	set(value):
		north_flight = value
		_values_dirty = true
## 北の首の固定時間
@export_range(0,100000,0.01) var north_lock_time := 1.4:
	set(value):
		north_lock_time = value
		_values_dirty = true
## north_spread
@export_range(0,100000,0.01) var north_spread := 120.0:
	set(value):
		north_spread = value
		_values_dirty = true
## 実行時間（秒）
@export_range(0,100000,0.01) var performance_time := 1.2:
	set(value):
		performance_time = value
		_values_dirty = true
## 技後の全体待ち（秒）
@export_range(0,100000,0.01) var tech_recovery := 1.5:
	set(value):
		tech_recovery = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warning_time := 2.4:
	set(value):
		warning_time = value
		_values_dirty = true

