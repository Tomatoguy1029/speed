## 噛みつきの値と動き。
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

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/hydra/technique_runner.gd":
	func tick_neck(a: Node, n, dt: float) -> void:
		var aim: Dictionary = a.move_params(n.mode)
		if a.tracks_during_warn(n.mode) and n.t <= minf(float(aim.get("aim_tracking", 0.0)), float(aim.get("normal_charge", 0.0))): n.target = a.run_state.ship_pos
		var p: Dictionary = a.move_params(n.mode)
		var charge := float(p.normal_charge)
		var flight := float(p.normal_lunge)
		var hold := float(p.normal_hold)
		var from: Vector2 = a._head_pos(n)
		if n.t < charge:
			a.aim_neck(n,(n.target-a._neck_base(n)).angle(),dt)
			n.length = move_toward(n.length,float(p.neck_rest)*0.4,float(p.neck_rest)*dt*2.0)
			n.glow = n.t / charge
		elif not n.locked:
			n.locked = true
			n.strike_from = from
			n.strike_pos = from
			a._cue(&"target_locked",n.mode,a.head_index(n))
		if n.locked and n.t < charge + flight:
			n.strike_pos = n.strike_from.lerp(n.target,clampf((n.t-charge)/flight,0.0,1.0))
			n.angle = (n.target-n.strike_from).angle()
			a.attack_field.add_shape(PackedVector2Array([from,n.strike_pos]),float(p.bite_radius),0.0,0.1,float(p.bite_dmg),&"bite",n.row)
		elif n.locked:
			n.strike_pos = n.target
			if kind()==&"thunder_headbutt" and n.step==0:
				n.step=1
				a.attack_field.add_shape(PackedVector2Array([n.target,n.target+Vector2(0.1,0)]),float(p.thunder_radius)*2.0,0.0,float(p.thunder_flash),float(p.beam_dmg),&"lightning",n.row)
				a._cue(&"attack_started",n.mode,a.head_index(n))
			n.glow = 0.0
		if n.t >= charge + flight + hold: a.finish_normal(n)

	func kind() -> StringName:
		return &"bite_thrust"
