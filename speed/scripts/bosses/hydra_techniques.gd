## 大技の配置と連続動作。開始・終了の時点はAnimationPlayerが決める。
extends RefCounted
var a: Node
var time:=0.0
var playing:=false
func _init(actor: Node)->void:a=actor
func prepare()->void:
	time=0.0
	playing=false
	for n in a.participants:
		n.strike_pos=a._head_pos(n)
		n.strike_from=n.strike_pos
		n.mode=&"special_aim"
		n.locked=false
		n.step=0
		n.emission.clear()
	if a.tech==&"curve":curve(0.0)
func tick(dt: float)->void:
	if not playing:return
	time+=dt
	if a.tech==&"sequence":sequence(dt)
	elif a.tech==&"curve":curve(dt)
	for n in a.participants:
		if a._alive(n):
			a.table.pos[n.row]=a._head_pos(n)
			a._follow_neck(n,dt)
func sequence(dt: float)->void:
	var p: Dictionary=a.def.params
	for i in a.participants.size():
		var n=a.participants[i]
		var local: float=time-i*float(p.sequence_gap)
		if local<0.0:continue
		if not n.locked:
			n.target=a.run_state.ship_pos
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

func curve(dt: float)->void:
	var p: Dictionary=a.def.params
	a.table.facing[a.body]+=float(p.curve_turn)*dt
	for n in a.participants:
		if not a._alive(n):continue
		n.angle=n.base_angle+a.table.facing[a.body]
		n.strike_pos=a._neck_base(n)+Vector2.from_angle(n.angle)*float(p.neck_rest)
		var points:=PackedVector2Array([n.strike_pos])
		var at: Vector2=n.strike_pos
		for j in range(1,25):
			var f:=float(j)/24.0
			at+=Vector2.from_angle(n.angle-f*float(p.curve_lag))*float(p.beam_len)/24.0
			points.append(at)
		if n.emission.is_empty():
			n.emission=a.attack_field.add_shape(points,float(p.beam_width),0.8,float(p.curve_time),float(p.beam_dmg),&"beam",n.row)
		else:n.emission.points=points
		if time>=float(p.curve_time):
			n.emission.life=0.0
			n.mode=&"special_hold"
