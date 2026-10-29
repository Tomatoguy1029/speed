## 薙ぎ払いの値と動き。
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
## 薙ぎの角度（度）
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

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/hydra/technique_runner.gd":
	func tick_neck(a: Node,n,dt: float) -> void:
		var aim: Dictionary = a.move_params(n.mode)
		if a.tracks_during_warn(n.mode) and n.t <= minf(float(aim.get("aim_tracking", 0.0)), float(aim.get("normal_charge", 0.0))): n.target = a.run_state.ship_pos
		var p: Dictionary = a.move_params(n.mode)
		var charge := float(p.normal_charge)
		var duration := float(p.sweep_time)
		var from: Vector2 = a._head_pos(n)
		if n.t < charge:
			n.glow = n.t/charge
			a.aim_neck(n,(n.target-a._neck_base(n)).angle()-float(p.sweep_arc)*0.5,dt)
		elif not n.locked:
			n.locked=true
			n.sweep=(n.target-a._neck_base(n)).angle()
			n.strike_pos=from
		if n.locked and n.t < charge+duration:
			n.angle=n.sweep+float(p.sweep_arc)*(clampf((n.t-charge)/duration,0.0,1.0)-0.5)
			n.strike_pos=a._neck_base(n)+Vector2.from_angle(n.angle)*float(p.sweep_reach)
			a.attack_field.add_shape(PackedVector2Array([from,n.strike_pos]),float(p.bite_radius),0.0,0.12,float(p.bite_dmg),&"bite",n.row)
		if n.t >= charge+duration+float(p.normal_hold): a.finish_normal(n)

	func kind() -> StringName:
		return &"bite_sweep"
