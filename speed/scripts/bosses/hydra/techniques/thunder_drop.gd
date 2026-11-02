## 通常入口を切り替えるまで使う互換Runner。
@tool
extends "res://scripts/data_types/boss_techniques/hydra/thunder_drop.gd"

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/hydra/technique_runner.gd":
	func tick_neck(a: Node,n,dt: float) -> void:
		var aim: Dictionary = a.move_params(n.mode)
		if a.tracks_during_warn(n.mode) and n.t <= minf(float(aim.get("aim_tracking", 0.0)), float(aim.get("normal_charge", 0.0))): n.target = a.run_state.ship_pos
		var p: Dictionary = a.move_params(n.mode)
		var charge := float(p.normal_charge)
		if not n.locked:
			var points := PackedVector2Array([n.target,n.target+Vector2(0.1,0)])
			if n.emission.is_empty(): n.emission=a.attack_field.add_shape(points,float(p.thunder_radius)*2.0,charge-n.t,float(p.thunder_flash),float(p.beam_dmg),&"lightning",n.row)
			else: n.emission.points=points
			n.glow=n.t/charge
			if n.t>=charge*float(p.target_lock_fraction):
				n.strike_pos=a._head_pos(n)
				n.locked=true
				a._cue(&"target_locked",n.mode,a.head_index(n))
		if n.t>=charge and n.step==0:
			n.step=1
			a._cue(&"attack_started",n.mode,a.head_index(n))
		if n.t>=charge+float(p.thunder_flash)+float(p.normal_hold): a.finish_normal(n)

	func kind() -> StringName:
		return &"thunder_drop"
