## 単独技の振り付け。BTは選択し、この動作は世界時間で進む。
extends RefCounted
static func tick(a: Node, n, dt: float) -> void:
	if n.mode == &"wind_band":
		wind_band(a,n,dt)
		return
	if n.mode == &"bite_sweep":
		sweep(a,n,dt)
		return
	var p: Dictionary = a.def.params
	var charge := float(p.normal_charge)
	var flight := float(p.normal_lunge)
	var hold := float(p.normal_hold)
	var from: Vector2 = a._head_pos(n)
	if n.t < charge:
		n.angle = lerp_angle(n.angle,(a.run_state.ship_pos-a._neck_base(n)).angle(),minf(1.0,dt*6.0))
		n.length = move_toward(n.length,float(p.neck_rest)*0.4,float(p.neck_rest)*dt*2.0)
		n.glow = n.t / charge
	elif not n.locked:
		n.locked = true
		n.target = a.run_state.ship_pos
		n.strike_from = from
		n.strike_pos = from
		a._cue(&"target_locked",n.mode,a.necks.find(n))
	if n.locked and n.t < charge + flight:
		n.strike_pos = n.strike_from.lerp(n.target,clampf((n.t-charge)/flight,0.0,1.0))
		n.angle = (n.target-n.strike_from).angle()
		a.attack_field.add_shape(PackedVector2Array([from,n.strike_pos]),float(p.bite_radius),0.0,0.1,float(p.bite_dmg),&"bite",n.row)
	elif n.locked:
		n.strike_pos = n.target
		n.glow = 0.0
	if n.t >= charge + flight + hold: a.finish_normal(n)

static func sweep(a: Node,n,dt: float) -> void:
	var p: Dictionary = a.def.params
	var charge := float(p.normal_charge)
	var duration := float(p.sweep_time)
	var from: Vector2 = a._head_pos(n)
	if n.t < charge:
		n.glow = n.t/charge
		n.angle = lerp_angle(n.angle,(a.run_state.ship_pos-a._neck_base(n)).angle()-float(p.sweep_arc)*0.5,minf(1.0,dt*7.0))
	elif not n.locked:
		n.locked=true
		n.sweep=(a.run_state.ship_pos-a._neck_base(n)).angle()
		n.strike_pos=from
	if n.locked and n.t < charge+duration:
		n.angle=n.sweep+float(p.sweep_arc)*(clampf((n.t-charge)/duration,0.0,1.0)-0.5)
		n.strike_pos=a._neck_base(n)+Vector2.from_angle(n.angle)*float(p.sweep_reach)
		a.attack_field.add_shape(PackedVector2Array([from,n.strike_pos]),float(p.bite_radius),0.0,0.12,float(p.bite_dmg),&"bite",n.row)
	if n.t >= charge+duration+float(p.normal_hold): a.finish_normal(n)

static func wind_band(a: Node,n,dt: float) -> void:
	var p: Dictionary = a.def.params
	var charge := float(p.normal_charge)
	if n.t < charge:
		n.angle=lerp_angle(n.angle,(a.run_state.ship_pos-a._head_pos(n)).angle(),minf(1.0,dt*5.0))
		n.glow=n.t/charge
	elif not n.locked:
		n.locked=true
		n.strike_pos=a._neck_base(n)+Vector2.from_angle(n.angle)*n.length
		var points := PackedVector2Array([n.strike_pos,n.strike_pos+Vector2.from_angle(n.angle)*float(p.wind_length)])
		a.attack_field.add_shape(points,float(p.wind_width),0.0,float(p.wind_time),0.0,&"wind",n.row)
		a._cue(&"attack_started",n.mode,a.necks.find(n))
	if n.t >= charge+float(p.wind_time)+float(p.normal_hold): a.finish_normal(n)
