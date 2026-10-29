## 順番噛みつきの値と動き。
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
## 踏み込み時間（秒）
@export_range(0,100000,0.01) var normal_lunge := 0.16:
	set(value):
		normal_lunge = value
		_values_dirty = true
## 実行時間（秒）
@export_range(0,100000,0.01) var performance_time := 3.4:
	set(value):
		performance_time = value
		_values_dirty = true
## 連続攻撃の予備動作
@export_range(0,100000,0.01) var sequence_charge := 0.45:
	set(value):
		sequence_charge = value
		_values_dirty = true
## 連続攻撃の間隔
@export_range(0,100000,0.01) var sequence_gap := 0.55:
	set(value):
		sequence_gap = value
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

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/hydra/technique_runner.gd":
	func sequence(dt: float)->void:
		var p: Dictionary=a.move_params(a.tech)
		for i in a.participants.size():
			var n=a.participants[i]
			var local: float=time-i*float(p.sequence_gap)
			if local<0.0:continue
			if not n.locked:
				if a.tracks_during_warn(a.tech):n.target=a.run_state.ship_pos
				if local<float(p.sequence_charge):continue
				n.locked=true
				n.strike_from=n.strike_pos
				n.angle=(n.target-n.strike_from).angle()
				a._cue(&"target_locked",a.tech,a.necks.find(n))
				a._cue(&"attack_started",a.tech,a.necks.find(n))
			var fraction:=clampf((local-float(p.sequence_charge))/float(p.normal_lunge),0.0,1.0)
			if n.mode!=&"special_hold":
				var before: Vector2=n.strike_pos
				n.strike_pos=n.strike_from.lerp(n.target,fraction)
				a.attack_field.add_shape(PackedVector2Array([before,n.strike_pos]),float(p.bite_radius)*2.0,0.0,maxf(dt,0.02)+0.001,float(p.bite_dmg),&"bite",n.row)
				if fraction>=1.0:n.mode=&"special_hold"

	func perform(dt: float) -> void:
		sequence(dt)

	func kind() -> StringName:
		return &"sequence"
