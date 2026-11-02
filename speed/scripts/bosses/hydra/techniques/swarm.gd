extends "res://scripts/data_types/boss_techniques/hydra/swarm.gd"

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/hydra/technique_runner.gd":
	func swarm(dt: float)->void:
		var p: Dictionary=a.move_params(a.tech)
		for i in a.participants.size():
			var n=a.participants[i]
			if not a._alive(n):continue
			var local: float=time-i*float(p.swarm_gap)
			if local<0.0:continue
			if n.emission.is_empty():n.emission=a.attack_field.add_shape(PackedVector2Array([n.strike_from,n.target]),float(p.bite_radius),float(p.sequence_charge),0.001,0.0,&"bite",n.row)
			if local<float(p.sequence_charge):continue
			if not n.locked:
				n.locked=true
				n.angle=(n.target-n.strike_from).angle()
				a._cue(&"target_locked",a.tech,a.necks.find(n))
				a._cue(&"attack_started",a.tech,a.necks.find(n))
			var f:=clampf((local-float(p.sequence_charge))/float(p.swarm_flight),0.0,1.0)
			if n.mode!=&"special_hold":
				var before: Vector2=n.strike_pos
				n.strike_pos=n.strike_from.lerp(n.target,f)
				n.free_pos=n.strike_pos
				a.attack_field.add_shape(PackedVector2Array([before,n.strike_pos]),float(p.bite_radius),0.0,dt+0.001,float(p.bite_dmg),&"bite",n.row)
				if f>=1.0:n.mode=&"special_hold"

	func perform(dt: float) -> void:
		swarm(dt)

	func kind() -> StringName:
		return &"swarm"
