## 単独技の振り付け。共通フローは選択し、この動作は世界時間で進む。
extends RefCounted

## 同じ技の数値から求める到達上限。標的位置へ直接出す技は発動条件で領域を決める。
static func reach(id: StringName, p: Dictionary) -> Dictionary:
	match id:
		&"bite_sweep": return {"origin": "base", "max": float(p.sweep_reach) + float(p.bite_radius) * 0.5}
		&"wind_band": return {"origin": "head", "max": float(p.wind_length) + float(p.wind_width) * 0.5}
		&"wind_blades": return {"origin": "head", "max": float(p.blade_speed) * float(p.blade_life) + float(p.blade_size)}
		&"beam_fixed": return {"origin": "head", "max": float(p.beam_len) + float(p.beam_width) * 0.5}
		&"beam_bolt": return {"origin": "head", "max": float(p.bolt_speed) * float(p.bolt_life) + float(p.bolt_length) + float(p.bolt_width) * 0.5}
	return {"origin": "head", "max": INF}
static func tick(a: Node, n, dt: float) -> void:
	var aim: Dictionary = a.move_params(n.mode)
	if a.tracks_during_warn(n.mode) and n.t <= minf(float(aim.get("aim_tracking", 0.0)), float(aim.get("normal_charge", 0.0))): n.target = a.run_state.ship_pos
	if n.mode == &"thunder_drop":
		thunder_drop(a,n,dt)
		return
	if n.mode == &"beam_bolt":
		beam_bolt(a,n,dt)
		return
	if n.mode == &"beam_fixed":
		beam_fixed(a,n,dt)
		return
	if n.mode in [&"rubble_lump",&"rubble_fan"]:
		rubble(a,n,dt)
		return
	if n.mode == &"wind_blades":
		wind_blades(a,n,dt)
		return
	if n.mode == &"wind_band":
		wind_band(a,n,dt)
		return
	if n.mode == &"bite_sweep":
		sweep(a,n,dt)
		return
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
		if n.mode==&"thunder_headbutt" and n.step==0:
			n.step=1
			a.attack_field.add_shape(PackedVector2Array([n.target,n.target+Vector2(0.1,0)]),float(p.thunder_radius)*2.0,0.0,float(p.thunder_flash),float(p.beam_dmg),&"lightning",n.row)
			a._cue(&"attack_started",n.mode,a.head_index(n))
		n.glow = 0.0
	if n.t >= charge + flight + hold: a.finish_normal(n)

static func sweep(a: Node,n,dt: float) -> void:
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

static func wind_band(a: Node,n,dt: float) -> void:
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

static func wind_blades(a: Node,n,dt: float) -> void:
	var p: Dictionary = a.move_params(n.mode)
	var charge := float(p.normal_charge)
	if n.t < charge:
		a.aim_neck(n,(n.target-a._head_pos(n)).angle()-float(p.blade_spread)*0.5,dt)
		n.glow=n.t/charge
	elif not n.locked:
		n.strike_pos=a._head_pos(n)
		n.locked=true
		n.sweep=(n.target-n.strike_pos).angle()
	if n.locked and n.step<3 and n.t>=charge+n.step*float(p.blade_interval):
		n.angle=n.sweep+(float(n.step)*0.5-0.5)*float(p.blade_spread)
		var points := PackedVector2Array()
		for i in 13:
			var angle := -PI*0.5+PI*float(i)/12.0
			points.append(n.strike_pos+Vector2(cos(angle)*float(p.blade_size)*0.6,sin(angle)*float(p.blade_size)).rotated(n.angle))
		a.attack_field.add_shape(points,float(p.blade_width),0.0,float(p.blade_life),float(p.bite_dmg),&"wind_blade",n.row,Vector2.from_angle(n.angle)*float(p.blade_speed),true)
		n.step+=1
		a._cue(&"attack_started",n.mode,a.head_index(n))
	if n.t>=charge+2.0*float(p.blade_interval)+float(p.normal_hold): a.finish_normal(n)

static func rubble(a: Node,n,dt: float) -> void:
	var p: Dictionary = a.move_params(n.mode)
	var charge := float(p.normal_charge)
	if n.t < charge:
		a.aim_neck(n,(n.target-a._head_pos(n)).angle(),dt)
		n.glow=n.t/charge
	elif not n.locked:
		n.strike_pos=a._head_pos(n)
		n.locked=true
		if n.mode==&"rubble_lump":
			launch_rubble(a,n,n.angle,float(p.lump_r))
		else:
			for i in int(p.rubble_count):
				var angle: float = n.angle+float(p.rubble_spread)*(float(i)/maxf(1.0,float(p.rubble_count)-1.0)-0.5)
				launch_rubble(a,n,angle,float(p.rubble_small_radius))
		a._cue(&"attack_started",n.mode,a.head_index(n))
	if n.t>=charge+float(p.normal_hold): a.finish_normal(n)

static func launch_rubble(a: Node,n,angle: float,radius: float) -> void:
	var row: int = a.ctx.enemies.spawn(a.ctx.enemies.def_of(&"hydra_rubble"),a._head_pos(n))
	a.table.r[row]=radius
	a.table.vel[row]=Vector2.from_angle(angle)*float(a.move_params(n.mode).lump_speed)
	var at: Vector2 = a.table.pos[row]
	var e: Dictionary = a.attack_field.add_shape(PackedVector2Array([at,at+Vector2(0.1,0)]),radius*2.0,0.0,float(a.ctx.enemies.def_of(&"hydra_rubble").params.life),float(a.move_params(n.mode).lump_dmg),&"rubble",n.row,Vector2.ZERO,true)
	e.follow_row=row
	e.follow_id=a.table.id[row]

static func beam_fixed(a: Node,n,dt: float) -> void:
	var p: Dictionary = a.move_params(n.mode)
	var charge := float(p.normal_charge)
	if n.t < charge:
		a.aim_neck(n,(n.target-a._head_pos(n)).angle(),dt)
		n.glow=n.t/charge
		var at: Vector2 = a._head_pos(n)
		var points := PackedVector2Array([at,at+Vector2.from_angle(n.angle)*float(p.beam_len)])
		if n.emission.is_empty():
			n.emission=a.attack_field.add_shape(points,float(p.beam_width),charge-n.t,float(p.beam_time),float(p.beam_dmg),&"beam",n.row)
		else: n.emission.points=points
	elif not n.locked:
		n.strike_pos=a._head_pos(n)
		n.locked=true
		a._cue(&"attack_started",n.mode,a.head_index(n))
	if n.t>=charge+float(p.beam_time)+float(p.normal_hold): a.finish_normal(n)

static func beam_bolt(a: Node,n,dt: float) -> void:
	var p: Dictionary = a.move_params(n.mode)
	var charge := float(p.normal_charge)
	if n.t < charge:
		a.aim_neck(n,(n.target-a._head_pos(n)).angle(),dt)
		n.glow=n.t/charge
	elif not n.locked:
		n.strike_pos=a._head_pos(n)
		n.locked=true
		var u := Vector2.from_angle(n.angle)
		a.attack_field.add_shape(PackedVector2Array([n.strike_pos,n.strike_pos+u*float(p.bolt_length)]),float(p.bolt_width),0.0,float(p.bolt_life),float(p.beam_dmg),&"bolt",n.row,u*float(p.bolt_speed),true)
		a._cue(&"attack_started",n.mode,a.head_index(n))
	if n.t>=charge+float(p.normal_hold): a.finish_normal(n)

static func thunder_drop(a: Node,n,dt: float) -> void:
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
