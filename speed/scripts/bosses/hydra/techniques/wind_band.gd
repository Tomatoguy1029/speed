## 風の帯の互換Runner。値は編集用Resourceを使う。
@tool
extends "res://scripts/data_types/boss_techniques/hydra/wind_band.gd"

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/hydra/technique_runner.gd":
	func tick_neck(a: Node,n,dt: float) -> void:
		var aim: Dictionary = a.move_params(n.mode)
		if a.tracks_during_warn(n.mode) and n.t <= minf(float(aim.get("aim_tracking", 0.0)), float(aim.get("normal_charge", 0.0))): n.target = a.run_state.ship_pos
		var p: Dictionary = a.move_params(n.mode)
		var charge := float(p.normal_charge)
		if n.t < charge:
			a.aim_neck(n,(n.target-a._head_pos(n)).angle(),dt)
			n.glow=n.t/charge
		elif not n.locked:
			n.locked=true
			n.strike_pos=a._neck_base(n)+Vector2.from_angle(n.angle)*n.length
			var points := PackedVector2Array([n.strike_pos,n.strike_pos+Vector2.from_angle(n.angle)*float(p.wind_length)])
			var effect: Dictionary = a.attack_field.add_shape(points,float(p.wind_width),0.0,float(p.wind_time),0.0,&"wind",n.row)
			effect.wind_force = float(p.wind_force)
			a._cue(&"attack_started",n.mode,a.head_index(n))
		if n.t >= charge+float(p.wind_time)+float(p.normal_hold): a.finish_normal(n)

	func kind() -> StringName:
		return &"wind_band"
