## 分離後の役割と持ち場。生存位置から判断し、全員の力を確定してから動かす。
extends RefCounted
var a: Node
var predicted := Vector2.ZERO
var replan_time := 0.0
var roster: Array = []
var tactic := &"wave"
var formation_angle := 0.0
var reorient_time := 0.0
var bearer_goal := Vector2.ZERO
var bearer_replan := 0.0
var panic := 0.0
var panic_cooldown := 0.0
var chasing := false

func _init(actor: Node) -> void:
	a = actor
	predicted = a.run_state.ship_pos
	bearer_goal = a.immortal_neck.free_pos

func live() -> Array:
	return a.necks.filter(func(n): return a._alive(n))

func profile(n) -> StringName:
	return &"front" if n.motion.get("lane", &"close") == &"front" else &"close"

func tick(dt: float) -> void:
	var p: Dictionary = a.def.params.squad
	predicted = predicted.lerp(a.run_state.ship_pos + a.run_state.ship_vel * float(p.predict), 1.0 - exp(-float(p.goal_response) * dt))
	var heads := live()
	replan_time -= dt
	reorient_time = maxf(0.0, reorient_time - dt)
	if heads != roster or replan_time <= 0.0:
		replan()
	# 大技・コンボが使う首は、技の配置処理に任せる。
	var forces := []
	for n in heads:
		if n.mode != &"idle": continue
		var goal := goal_for(n)
		n.motion.squad_goal = Vector2(n.motion.get("squad_goal", goal)).lerp(goal, 1.0 - exp(-float(p.goal_response) * dt))
		var speed := float(p.front_speed if profile(n) == &"front" else p.close_speed)
		if n.free_pos.distance_to(n.motion.squad_goal) > float(p.far_distance): speed *= float(p.far_speed)
		var destination: Vector2 = a.snake_destination(n, n.motion.squad_goal, true)
		forces.append({"neck": n, "force": a.SNAKE.boid_force(n, destination, heads, a.immortal_neck, a.run_state.ship_pos, speed, dt, p), "speed": speed})
	for item in forces:
		a.swim_snake(item.neck, item.force, item.speed, float(p.turn), dt)

func replan() -> void:
	var p: Dictionary = a.def.params.squad
	roster = live()
	var guards: Array = roster.filter(func(n): return n.mode == &"idle")
	var center: Vector2 = a.immortal_neck.free_pos
	var offset := predicted - center
	formation_angle = offset.angle()
	reorient_time = float(p.reorient_gap)
	var distance := clampf(offset.length() * float(p.front_fraction), float(p.front_radius.x), float(p.front_radius.y))
	var front_center := center + offset.normalized() * distance
	var front_count := mini(int(p.front_near_count if center.distance_to(a.run_state.ship_pos) < float(p.block_distance) else p.front_count), guards.size())
	if tactic == &"wall": front_count = guards.size()
	var pool := guards.duplicate()
	var front := []
	for i in front_count:
		var weights := []
		for n in pool:
			weights.append((float(p.front_loyalty) if profile(n) == &"front" else 1.0) / pow(1.0 + n.free_pos.distance_to(front_center) / float(p.front_pick_distance), 3))
		var chosen = pick(pool, weights)
		front.append(chosen)
		pool.erase(chosen)
	var relative := func(n): return angle_difference(formation_angle, (n.free_pos - center).angle())
	front.sort_custom(func(x, y): return relative.call(x) < relative.call(y))
	pool.sort_custom(func(x, y): return relative.call(x) < relative.call(y))
	for i in front.size():
		front[i].motion.lane = &"front"
		front[i].motion.slot = i
		front[i].motion.slot_count = front.size()
	var left := ceili(pool.size() / 2.0)
	for i in pool.size():
		var j := left - 1 - i if i < left else i - left
		pool[i].motion.lane = &"close"
		pool[i].motion.close_angle = (-1.0 if i < left else 1.0) * float(p.close_angles[mini(j, p.close_angles.size() - 1)])
		pool[i].motion.close_radius = float(p.close_radii[j % p.close_radii.size()])
	replan_time = a.run_state.rng.randf_range(float(p.replan.x), float(p.replan.y))

func goal_for(n) -> Vector2:
	var p: Dictionary = a.def.params.squad
	var center: Vector2 = a.immortal_neck.free_pos
	var offset := predicted - center
	var angle := offset.angle()
	var radius := float(n.motion.get("close_radius", p.close_radii[0]))
	if profile(n) == &"front":
		var count := int(n.motion.get("slot_count", 1))
		var slot := int(n.motion.get("slot", 0))
		radius = clampf(offset.length() * float(p.front_fraction), float(p.front_radius.x), float(p.front_radius.y))
		var rows := tactic == &"wall" and count > 3
		var per_row := ceili(count / 2.0) if rows else count
		var spread := minf(float(p.front_spread_max), maxf(float(p.wall_spread if tactic == &"wall" else p.front_spread), (float(p.separation_radius) + float(p.front_spacing)) * (per_row - 1) / radius))
		if rows and slot % 2: radius += float(p.front_outer)
		if count > 1: angle += -spread * 0.5 + spread * slot / (count - 1)
	else:
		angle += float(n.motion.get("close_angle", 0.0))
	return a.arena.clamp_point(center + Vector2.from_angle(angle) * radius, float(p.slot_margin))

func pick(options: Array, weights: Array):
	var sum := 0.0
	for weight in weights: sum += float(weight)
	if options.is_empty() or sum <= 0.0: return null
	var sample: float = a.run_state.rng.randf() * sum
	for i in options.size():
		sample -= float(weights[i])
		if sample <= 0.0: return options[i]
	return options.back()

func tick_bearer(dt: float) -> void:
	var p: Dictionary = a.def.params.squad
	var n = a.immortal_neck
	var distance: float = n.free_pos.distance_to(a.run_state.ship_pos)
	var band: Vector2 = p.bearer_wall_band if tactic == &"wall" else p.bearer_band
	bearer_replan -= dt
	panic = maxf(0.0, panic - dt)
	panic_cooldown -= dt
	if distance < float(p.panic_distance) and panic_cooldown <= 0.0:
		panic = float(p.panic_time)
		panic_cooldown = float(p.panic_cooldown)
		choose_flee(float(p.panic_radius), band)
	elif bearer_replan <= 0.0:
		bearer_replan = float(p.bearer_replan)
		choose_flee(float(p.bearer_ring), band)
		if distance > band.y + float(p.chase_extra): chasing = true
		if distance < band.y: chasing = false
	var goal := bearer_goal
	if goal.distance_to(n.free_pos) < float(p.bearer_arrival) and panic <= 0.0:
		goal += (a.run_state.ship_pos - n.free_pos).normalized() * float(p.bearer_drift)
	var speed := float(p.bearer_panic_speed if panic > 0.0 else p.bearer_near_speed if distance < band.x or chasing else p.bearer_speed)
	# 不死の蛇は参照実装の滑らかな操舵を使い、通常の群れとは力を混ぜない。
	a.swim_bearer(n, goal, speed, float(p.bearer_turn), dt)

func choose_flee(ring: float, band: Vector2) -> void:
	var p: Dictionary = a.def.params.squad
	var guards := live().filter(func(n): return n.motion.get("role", &"guard") == &"guard")
	var center := Vector2.ZERO
	for n in guards: center += n.free_pos
	if not guards.is_empty(): center /= guards.size()
	var bounds: Rect2 = a.arena.bounds
	var view: Rect2 = a.run_state.view_rect().grow_individual(-float(p.view_margin.x), -float(p.view_margin.y), -float(p.view_margin.x), -float(p.view_margin.y))
	var best := -INF
	for i in int(p.flee_candidates):
		var at: Vector2 = a.immortal_neck.free_pos + Vector2.from_angle(TAU * i / int(p.flee_candidates)) * ring
		if not bounds.grow(-float(p.flee_margin)).has_point(at): continue
		var distance: float = at.distance_to(a.run_state.ship_pos)
		var off := band.x - distance if distance < band.x else (distance - band.y) * float(p.flee_far_weight) if distance > band.y else 0.0
		var out := maxf(0.0, view.position.x - at.x) + maxf(0.0, at.x - view.end.x) + maxf(0.0, view.position.y - at.y) + maxf(0.0, at.y - view.end.y)
		var wall := minf(float(p.wall_max), minf(minf(at.x - bounds.position.x, bounds.end.x - at.x), minf(at.y - bounds.position.y, bounds.end.y - at.y)))
		var behind: float = 0.0 if guards.is_empty() else (at - a.run_state.ship_pos).normalized().dot((center - a.run_state.ship_pos).normalized())
		var score: float = -off * float(p.flee_distance_weight) - out * float(p.flee_view_weight) + wall * float(p.flee_wall_weight) + behind * float(p.flee_guard_weight) + a.run_state.rng.randf() * float(p.flee_noise)
		if score > best:
			best = score
			bearer_goal = at
