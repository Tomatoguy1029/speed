## 連続飛びかかりの値と動き。
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
@export_range(0,100000,0.01) var cooldown := 15.0:
	set(value):
		cooldown = value
		_values_dirty = true
## 実行時間（秒）
@export_range(0,100000,0.01) var performance_time := 5.2:
	set(value):
		performance_time = value
		_values_dirty = true
## 連続攻撃の予備動作
@export_range(0,100000,0.01) var sequence_charge := 0.45:
	set(value):
		sequence_charge = value
		_values_dirty = true
## 群れの飛行時間
@export_range(0,100000,0.01) var swarm_flight := 1.0:
	set(value):
		swarm_flight = value
		_values_dirty = true
## 群れの間隔
@export_range(0,100000,0.01) var swarm_gap := 0.3:
	set(value):
		swarm_gap = value
		_values_dirty = true
## 群れの到達距離
@export_range(0,100000,0.01) var swarm_reach := 1000.0:
	set(value):
		swarm_reach = value
		_values_dirty = true
## 技後の全体待ち（秒）
@export_range(0,100000,0.01) var tech_recovery := 1.5:
	set(value):
		tech_recovery = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warning_time := 0.8:
	set(value):
		warning_time = value
		_values_dirty = true

