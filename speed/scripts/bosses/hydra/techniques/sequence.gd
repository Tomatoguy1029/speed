extends "res://scripts/data_types/boss_techniques/hydra/sequence.gd"

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
				n.target=a.neck_tracking_target(n,n.target)
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
