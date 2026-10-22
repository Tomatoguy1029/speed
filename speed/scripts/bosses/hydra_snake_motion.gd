## 独立蛇の操舵と、通過した頭位置をたどる胴体。世界時間で動作を混ぜる。
extends RefCounted
static func steer(n, target: Vector2, dt: float, p: Dictionary, speed_scale:=1.0)->void:
	var offset: Vector2=target-n.free_pos
	var previous: float=n.angle
	if offset.length()>1.0:
		n.angle=rotate_toward(n.angle,offset.angle(),float(p.snake_turn)*dt)
	var speed: float=float(p.snake_speed)*speed_scale*clampf(offset.length()/100.0,0.3,1.0)
	var desired:=Vector2.from_angle(n.angle)*speed
	n.velocity=n.velocity.lerp(desired,1.0-exp(-float(p.snake_accel)*dt))
	n.free_pos+=n.velocity*dt
	n.motion.turn=angle_difference(previous,n.angle)/maxf(dt,0.001)
static func follow(n, head: Vector2, dt: float, time: float, p: Dictionary)->void:
	if dt<=0.0:return
	var length:=float(p.neck_rest)
	var count:=int(p.neck_segments)
	if not n.motion.has("trail"):
		var initial: PackedVector2Array=n.segs.duplicate()
		initial.reverse()
		if initial.size()<2:
			for i in count+1:initial.append(head-Vector2.from_angle(n.angle)*length*float(i)/count)
		n.motion.trail=initial
		n.motion.weights={"swim":0.0,"turn":0.0,"hit":0.0,"windup":0.0,"attack":0.0,"hold":0.0}
		n.motion.hit=0.0
	var trail: PackedVector2Array=n.motion.trail
	if trail.is_empty() or head.distance_to(trail[0])>=4.0:trail.insert(0,head)
	while trail.size()>256:trail.remove_at(trail.size()-1)
	n.motion.trail=trail
	n.motion.hit=maxf(0.0,float(n.motion.hit)-dt)
	var weight: float=1.0-exp(-8.0*dt)
	var attacking: bool=n.mode!=&"idle"
	var goals: Dictionary={"swim":clampf(n.velocity.length()/float(p.snake_speed),0.0,1.0),"turn":clampf(absf(float(n.motion.get("turn",0.0)))/float(p.snake_turn),0.0,1.0),"hit":1.0 if float(n.motion.hit)>0.0 else 0.0,"windup":1.0 if attacking and not n.locked else 0.0,"attack":1.0 if attacking and n.locked else 0.0,"hold":1.0 if String(n.mode).ends_with("hold") else 0.0}
	for key in goals:n.motion.weights[key]=lerpf(float(n.motion.weights[key]),float(goals[key]),weight)
	var path:=PackedVector2Array([head])
	path.append_array(trail)
	var samples:=PackedVector2Array([head])
	var cursor:=1
	var at:=head
	for i in range(1,count+1):
		var needed: float=length/count
		while cursor<path.size() and at.distance_to(path[cursor])<needed:
			needed-=at.distance_to(path[cursor])
			at=path[cursor]
			cursor+=1
		var direction: Vector2=(path[cursor]-at).normalized() if cursor<path.size() else -Vector2.from_angle(n.angle)
		at+=direction*needed
		var f:=float(i)/count
		var amplitude: float=float(p.neck_wave_amplitude)*(0.3+0.7*float(n.motion.weights.swim))
		var wave: float=sin(time*float(p.neck_wave_speed)*2.0-f*TAU*float(p.neck_wave_frequency)+n.base_angle)*amplitude*sin(f*PI)
		var recoil: float=sin(f*PI)*sin(time*35.0-f*5.0)*float(n.motion.weights.hit)*12.0
		samples.append(at+direction.orthogonal()*(wave+recoil))
	n.segs.resize(count+1)
	for i in count+1:n.segs[i]=samples[count-i]
