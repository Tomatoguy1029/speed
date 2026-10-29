## 独立蛇の操舵と、通過した頭位置をたどる胴体。世界時間で動作を混ぜる。
extends RefCounted
static func steer(n, target: Vector2, dt: float, p: Dictionary, speed_scale:=1.0)->void:
	var offset: Vector2=target-n.free_pos
	var previous: float=n.angle
	if offset.length()>1.0:
		n.angle=rotate_toward(n.angle,offset.angle(),float(p.snake_turn)*dt)
	# 目標へ着いたら減速して止まる。最低速度があると目標の周囲を旋回し続け、胴体履歴が一箇所へ巻き込まれる。
	var speed: float=float(p.snake_speed)*speed_scale*clampf(offset.length()/100.0,0.0,1.0)
	speed*=0.3+0.7*maxf(0.0,cos(angle_difference(n.angle,offset.angle())))
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

## 同じ更新の位置・速度を読み、まだ移動せずに力だけを返す。
static func boid_force(n, target: Vector2, heads: Array, bearer, player: Vector2, speed: float, dt: float, p: Dictionary) -> Vector2:
	var offset: Vector2 = target - n.free_pos
	var distance := offset.length()
	var blocking: bool = n.motion.has("block")
	var attacker: bool = n.motion.get("role", &"guard") == &"attack"
	var direction := offset.normalized()
	if distance >= 1.0:
		var projection := clampf((bearer.free_pos - n.free_pos).dot(offset) / offset.length_squared(), 0.0, 1.0)
		if (n.free_pos + offset * projection).distance_to(bearer.free_pos) < float(p.detour_radius) and projection >= 0.05 and projection <= 0.95:
			var radial: Vector2 = (n.free_pos - bearer.free_pos).normalized()
			var side := float(n.motion.get("detour_side", 0.0))
			if side == 0.0: side = 1.0 if radial.cross(offset) >= 0.0 else -1.0
			n.motion.detour_side = side
			direction = (direction * float(p.detour_seek) + radial.orthogonal() * side).normalized()
		else:
			n.motion.detour_side = 0.0
	var desired := direction * speed * minf(1.0, distance / float(p.block_arrival if blocking else p.arrival))
	if distance < float(p.arrival_drift_distance): desired += (player - n.free_pos).normalized() * float(p.arrival_drift)
	if not blocking and player.distance_to(n.free_pos) < float(p.sight_distance) and desired.length() >= 1.0:
		var sight: float = p.front_sight if attacker or n.motion.get("lane", &"close") == &"front" else p.close_sight
		var to_player: float = (player - n.free_pos).angle()
		var delta := angle_difference(to_player, desired.angle())
		if absf(delta) > sight:
			desired = Vector2.from_angle(to_player + signf(delta) * sight) * desired.length() * maxf(float(p.sight_floor), cos(absf(delta) - sight))
	var seek: Vector2 = ((desired - n.velocity) * float(p.gain)).limit_length(speed * float(p.seek_cap))
	var separation := Vector2.ZERO
	var velocity := Vector2.ZERO
	var center := Vector2.ZERO
	var total := 0.0
	for other in heads + [bearer]:
		if other == n: continue
		var delta: Vector2 = n.free_pos - other.free_pos
		var dist := delta.length()
		if dist < 0.1 or dist > 500.0: continue
		var radius: float = p.bearer_radius if other == bearer else p.separation_radius
		if dist < radius: separation += delta / dist * ((radius - dist) / radius)
		# 体の点は先端から距離で間引く。更新頻度による点密度の違いを持ち込まない。
		var body: PackedVector2Array = other.segs
		var length := 0.0
		var next_sample := float(p.body_step)
		for i in range(body.size() - 2, -1, -1):
			length += body[i].distance_to(body[i + 1])
			if length > float(p.body_length): break
			if length < next_sample: continue
			next_sample += float(p.body_step)
			var away: Vector2 = n.free_pos - body[i]
			var body_distance := away.length()
			if body_distance > 0.1 and body_distance < float(p.body_radius):
				separation += away / body_distance * (1.0 - body_distance / float(p.body_radius)) * float(p.body_weight)
		if other != bearer and n.mode == &"idle" and other.mode == &"idle" and not blocking and not other.motion.has("block") and not attacker and other.motion.get("role", &"guard") == &"guard" and other.motion.get("lane", &"close") == n.motion.get("lane", &"close") and dist < float(p.neighbor_radius):
			var weight := clampf((float(p.neighbor_radius) - dist) / (float(p.neighbor_radius) * float(p.neighbor_soft)), 0.0, 1.0)
			velocity += other.velocity * weight
			center += other.free_pos * weight
			total += weight
	var smooth: Vector2 = Vector2(n.motion.get("separation", Vector2.ZERO)).lerp(separation, 1.0 - exp(-dt / float(p.separation_tau)))
	n.motion.separation = smooth
	var avoid := (smooth * speed * float(p.gain) * float(p.separation_weight) * (float(p.block_separation) if blocking else 1.0)).limit_length(speed * float(p.separation_cap))
	var alignment := Vector2.ZERO
	var cohesion := Vector2.ZERO
	if total > 0.01:
		alignment = ((velocity / total - n.velocity) * float(p.gain) * float(p.alignment_weight)).limit_length(speed * float(p.alignment_cap))
		var towards: Vector2 = center / total - n.free_pos
		if towards.length() > float(p.separation_radius): cohesion = (towards.normalized() * speed * 0.5 * float(p.gain) * float(p.cohesion_weight)).limit_length(speed * float(p.cohesion_cap))
	var urgency := clampf(smooth.length() / float(p.urgency), 0.0, 1.0)
	return ((seek + alignment + cohesion) * (1.0 - float(p.avoid_reduction) * urgency) + avoid).limit_length(maxf(speed, 80.0) * float(p.block_force_cap if blocking else p.force_cap))

static func apply_force(n, force: Vector2, speed: float, turn: float, dt: float, p: Dictionary) -> void:
	var velocity: Vector2 = n.velocity + force * dt
	var previous: float = n.angle
	if velocity.length() > 8.0:
		n.angle = rotate_toward(n.angle, velocity.angle(), turn * dt)
		var amount := minf(velocity.length(), maxf(speed, 60.0) * float(p.velocity_cap)) * (float(p.velocity_floor) + (1.0 - float(p.velocity_floor)) * maxf(0.0, cos(angle_difference(n.angle, velocity.angle()))))
		n.velocity = Vector2.from_angle(n.angle) * amount
	else:
		n.velocity = velocity
	n.free_pos += n.velocity * dt
	n.motion.turn = angle_difference(previous, n.angle) / maxf(dt, 0.001)

static func watch_player(n, rng: RandomNumberGenerator, p: Dictionary, role: StringName) -> void:
	n.motion.look_on = true
	var timing: Vector2 = p.look[role].on
	n.motion.look_time = rng.randf_range(timing.x, timing.y)

static func update_look(n, player: Vector2, dt: float, time: float, rng: RandomNumberGenerator, p: Dictionary, role: StringName, keep: bool) -> void:
	var settings: Dictionary = p.look[role]
	n.motion.look_time = float(n.motion.get("look_time", 0.0)) - dt
	if n.motion.look_time <= 0.0:
		n.motion.look_on = not n.motion.get("look_on", true)
		var timing: Vector2 = settings.on if n.motion.look_on else settings.off
		n.motion.look_time = rng.randf_range(timing.x, timing.y)
		n.motion.look_offset = rng.randf_range(-float(p.look_forward_noise), float(p.look_forward_noise))
	if keep:
		n.motion.look_on = true
		n.motion.look_time = maxf(n.motion.look_time, 0.3)
	var on: bool = n.motion.look_on
	var desired: float = (player - n.free_pos).angle() + sin(time * float(p.look_wave_speed) + n.base_angle) * float(p.look_wave) if on else n.angle + float(n.motion.get("look_offset", 0.0))
	desired = n.angle + clampf(angle_difference(n.angle, desired), -float(settings.limit), float(settings.limit))
	n.look_angle = rotate_toward(n.look_angle, desired, float(p.look_player_turn if on else p.look_forward_turn) * dt)
	n.look_angle = n.angle + clampf(angle_difference(n.angle, n.look_angle), -float(settings.limit), float(settings.limit))
