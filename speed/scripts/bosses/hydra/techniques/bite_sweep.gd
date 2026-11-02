## 通常入口を切り替えるまで使う互換Runner。編集値は専用Resourceへ置く。
@tool
extends "res://scripts/data_types/boss_techniques/hydra/bite_sweep.gd"

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
