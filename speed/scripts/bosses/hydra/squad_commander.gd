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
var tactic_time := 0.0
var attack_gap := 1.0
var pair: Array = []
var pair_elapsed := 0.0
var pair_launched := false
var wave_current
var wave_angle := INF
var wave_gap := 0.6
var suspended := false
var section_index := -1

func _init(actor: Node) -> void:
	a = actor
	predicted = a.run_state.ship_pos
	bearer_goal = a.immortal_neck.free_pos

func live() -> Array:
	return a.necks.filter(func(n): return a._alive(n))

func profile(n) -> StringName:
	if n.motion.has("block"): return &"block"
	if n.motion.get("role", &"guard") == &"attack": return &"attack"
	return &"front" if n.motion.get("lane", &"close") == &"front" else &"close"

func tick(dt: float) -> void:
	var p: Dictionary = a.def.params.squad
	predicted = predicted.lerp(a.run_state.ship_pos + a.run_state.ship_vel * float(p.predict), 1.0 - exp(-float(p.goal_response) * dt))
	var heads := live()
	tick_tactic(dt)
	if a.busy: return
	replan_time -= dt
	reorient_time = maxf(0.0, reorient_time - dt)
	if heads != roster or replan_time <= 0.0:
		replan()
	# 大技・コンボが使う首は、技の配置処理に任せる。
	var forces := []
	for n in heads:
		if n.mode != &"idle" and not a._normal_moves.has(n.mode): continue
		if n.motion.get("extension", false): continue
		var goal := goal_for(n)
		n.motion.squad_goal = Vector2(n.motion.get("squad_goal", goal)).lerp(goal, 1.0 - exp(-float(p.goal_response) * dt))
		var speed := float(p.attack_speed if profile(n) == &"attack" else p.front_speed if profile(n) == &"front" else p.close_speed)
		if a._normal_moves.has(n.mode): speed *= float(p.busy_speed[a.NORMAL_SWIM.phase(a, n)])
		if n.free_pos.distance_to(n.motion.squad_goal) > float(p.far_distance): speed *= float(p.far_speed)
		var destination: Vector2 = a.snake_destination(n, n.motion.squad_goal, true)
		forces.append({"neck": n, "force": a.SNAKE.boid_force(n, destination, heads, a.immortal_neck, a.run_state.ship_pos, speed, dt, p), "speed": speed})
	for item in forces:
		a.swim_snake(item.neck, item.force, item.speed, float(p.turn), dt)
		var n = item.neck
		var near: bool = n.free_pos.distance_to(a.run_state.ship_pos) < minf(float(p.attack_ranges[n.kind]), 300.0) + 100.0 + float(p.look_near_extra)
		if a._normal_moves.has(n.mode) and a.NORMAL_SWIM.phase(a, n) != &"hold": continue
		a.SNAKE.update_look(n, a.run_state.ship_pos, dt, a._time, a.run_state.rng, p, profile(n), near)

func replan() -> void:
	var p: Dictionary = a.def.params.squad
	roster = live()
	var guards: Array = roster.filter(func(n): return n.motion.get("role", &"guard") == &"guard" and not n.motion.get("counter", false) and (n.mode == &"idle" or a._normal_moves.has(n.mode)))
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
	if n.motion.get("role", &"guard") == &"attack": return attack_slot(n, n.motion.move, float(n.motion.attack_angle))
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

## 指名は戦闘中の役割と予約だけを作り、技の開始は区間フローに任せる。
func reserved() -> float:
	var result := 0.0
	for n in live(): result += float(n.motion.get("reserved", 0.0))
	return result

func section() -> Dictionary:
	var runner = a.flow_runner
	if runner.flow == null or runner.flow.sections.is_empty(): return {}
	return runner.flow.sections[runner.index]

func available() -> float:
	var data := section()
	var runner = a.flow_runner
	return maxf(0.0, minf(runner.stamina, minf(float(data.get("cap", runner.stamina)), float(data.get("section_budget", INF)) - runner.section_spent)) - reserved())

func allowed(id: StringName) -> bool:
	var data := section()
	return (not data.has("allowed_techniques") or String(id) in data.allowed_techniques) and String(id) not in data.get("excluded_techniques", [])

func guard(n) -> void:
	n.motion.role = &"guard"
	n.motion.lane = &"close"
	n.motion.reserved = 0.0
	n.motion.erase("move")
	n.motion.erase("ready")

func cancel_pending() -> void:
	for n in live():
		if n.motion.get("role", &"guard") == &"attack" and n.mode == &"idle": guard(n)
	pair.clear()
	wave_current = null

func tick_tactic(dt: float) -> void:
	var p: Dictionary = a.def.params.squad
	var runner = a.flow_runner
	# 配置を所有する大技の間は指名も移動目標の更新も止める。
	if a.busy or (a.flow_adapter != null and a.flow_adapter.custom_run != null):
		if not suspended: cancel_pending()
		suspended = true
		return
	if suspended:
		suspended = false
		replan()
	if section_index != runner.index:
		section_index = runner.index
		cancel_pending()
	for n in live():
		if not pair.has(n) and n.motion.get("role", &"guard") == &"attack" and n.mode == &"idle" and float(n.motion.get("reserved", 0.0)) <= 0.0:
			guard(n)
			replan()
	pair = pair.filter(func(n): return a._alive(n) and n.motion.get("role", &"guard") == &"attack")
	if runner.rest_remaining > 0.0:
		cancel_pending()
		return
	tactic_time -= dt
	if tactic_time <= 0.0: choose_tactic()
	if not a.hsm.active: return
	if tactic == &"wall": return
	if tactic == &"pincer":
		if pair.is_empty():
			attack_gap -= dt
			if attack_gap > 0.0: return
			var first = pick_attacker([])
			if first == null: return
			var second = pick_attacker([first])
			if second == null: return
			var first_move := choose_move(first)
			var second_move := choose_move(second)
			if first_move == &"" or second_move == &"" or a._normal_cost(first_move) + a._normal_cost(second_move) > available() + 0.00001: return
			var heading: float = a.run_state.ship_vel.angle() if a.run_state.ship_vel.length() >= float(p.pincer_velocity) else (a.immortal_neck.free_pos - a.run_state.ship_pos).angle() + a.run_state.rng.randf_range(-float(p.pincer_idle_noise), float(p.pincer_idle_noise))
			var left: float = heading + PI * 0.5 + a.run_state.rng.randf_range(-float(p.pincer_noise), float(p.pincer_noise))
			var right: float = heading - PI * 0.5 + a.run_state.rng.randf_range(-float(p.pincer_noise), float(p.pincer_noise))
			var direct: float = first.free_pos.distance_to(attack_slot(first, first_move, left)) + second.free_pos.distance_to(attack_slot(second, second_move, right))
			var crossed: float = first.free_pos.distance_to(attack_slot(first, first_move, right)) + second.free_pos.distance_to(attack_slot(second, second_move, left))
			nominate(first, first_move, left if direct <= crossed else right)
			nominate(second, second_move, right if direct <= crossed else left)
			pair = [first, second]
			pair_elapsed = 0.0
			pair_launched = false
			replan()
		else:
			pair_elapsed += dt
			if not pair_launched and pair.all(func(n): return in_view(n) and (n.free_pos.distance_to(attack_slot(n, n.motion.move, n.motion.attack_angle)) < float(p.attack_arrival) or pair_elapsed >= float(p.pincer_timeout) or pair.size() == 1)):
				for n in pair: n.motion.ready = true
			if pair_launched and pair.all(func(n): return n.mode == &"idle"):
				for n in pair: guard(n)
				pair.clear()
				attack_gap = a.run_state.rng.randf_range(p.pincer_gap.x, p.pincer_gap.y)
				replan()
	else:
		if wave_current != null and a._alive(wave_current) and wave_current.motion.get("role", &"guard") == &"attack" and wave_current.mode == &"idle" and float(wave_current.motion.get("reserved", 0.0)) > 0.0:
			wave_current.motion.wait = float(wave_current.motion.wait) + dt
			if in_view(wave_current) and (wave_current.free_pos.distance_to(attack_slot(wave_current, wave_current.motion.move, wave_current.motion.attack_angle)) < float(p.attack_arrival) or wave_current.motion.wait >= float(p.wave_timeout)):
				wave_current.motion.ready = true
			return
		wave_gap -= dt
		if wave_gap > 0.0: return
		var n = pick_attacker([])
		if n == null: return
		var move := choose_move(n)
		if move == &"" or a._normal_cost(move) > available() + 0.00001: return
		var angles := []
		var weights := []
		var current: float = (n.free_pos - a.run_state.ship_pos).angle()
		for i in int(p.wave_candidates):
			var angle := TAU * i / int(p.wave_candidates)
			angles.append(angle)
			weights.append((float(p.wave_repeat_weight) if wave_angle != INF and absf(angle_difference(angle, wave_angle)) <= float(p.wave_separation) else 1.0) * pow(1.0 + cos(angle_difference(angle, current)), 2))
		wave_angle = pick(angles, weights)
		nominate(n, move, wave_angle)
		wave_current = n
		wave_gap = a.run_state.rng.randf_range(p.wave_gap.x, p.wave_gap.y)
		replan()

func choose_tactic() -> void:
	var p: Dictionary = a.def.params.squad
	var options := [&"pincer", &"wave", &"wall"]
	var weights := [float(p.pincer_weight) if live().size() >= 2 else 0.0, float(p.wave_weight), float(p.wall_weight) + (float(p.wall_near_weight) if a.immortal_neck.free_pos.distance_to(a.run_state.ship_pos) < float(p.block_distance) else 0.0)]
	for i in options.size():
		if options[i] == tactic: weights[i] *= float(p.repeat_weight)
	cancel_pending()
	tactic = pick(options, weights)
	var timing: Vector2 = p.wall_time if tactic == &"wall" else p.tactic_time
	tactic_time = a.run_state.rng.randf_range(timing.x, timing.y)
	attack_gap = a.run_state.rng.randf_range(p.initial_gap.x, p.initial_gap.y)
	wave_gap = 0.6
	replan()

func pick_attacker(excluded: Array):
	var p: Dictionary = a.def.params.squad
	var pool := live().filter(func(n): return n.mode == &"idle" and n.cd <= 0.0 and n.motion.get("role", &"guard") == &"guard" and not n.motion.has("block") and not n.motion.get("counter", false) and not excluded.has(n))
	var closest := INF
	for n in pool: closest = minf(closest, n.free_pos.distance_to(a.run_state.ship_pos))
	pool = pool.filter(func(n): return n.free_pos.distance_to(a.run_state.ship_pos) <= closest + float(p.pick_band))
	var weights := []
	for n in pool:
		var distance: float = n.free_pos.distance_to(a.run_state.ship_pos)
		var age := minf(a._time - float(n.motion.get("last_attack", -9.0)), float(p.pick_rest))
		weights.append((1.0 + age / float(p.pick_rest)) * pow(1.0 / (1.0 + (distance - closest) / float(p.pick_distance)), 3) * (float(p.pick_front_weight) if profile(n) == &"front" and distance > float(p.pick_front_distance) else 1.0))
	return pick(pool, weights)

func choose_move(n) -> StringName:
	var options := []
	for id in a._normal_moves:
		if a._moves[id].head_kind == n.kind and allowed(id) and not a.action_rules.active_gates_for(String(id)).is_empty(): options.append(id)
	if options.is_empty(): return &""
	return options[a.run_state.rng.randi_range(0, options.size() - 1)]

func nominate(n, move: StringName, angle: float) -> void:
	n.motion.role = &"attack"
	n.motion.move = move
	n.motion.attack_angle = angle
	n.motion.reserved = a._normal_cost(move)
	n.motion.ready = false
	n.motion.wait = 0.0

func in_view(n) -> bool:
	return a.run_state.view_rect().grow(-a.table.r[n.row]).has_point(a._head_pos(n))

func attack_slot(n, move: StringName, angle: float) -> Vector2:
	var p: Dictionary = a.def.params.squad
	var preferred := float(p.attack_ranges[n.kind])
	var at: Vector2 = a.run_state.ship_pos + Vector2.from_angle(angle) * preferred
	var best := INF
	# 間合いは技ごとの条件と到達範囲に合わせる。現在の頭・根元の向きを保って仮の位置を照合する。
	for gate in a.action_rules.active_gates_for(String(move)):
		var distances := [preferred, float(gate.get("min", 0.0)), float(gate.get("max", preferred))]
		var reach: Dictionary = a.move_reach(move)
		var upper := minf(float(gate.get("max", preferred * 2.0)), maxf(preferred * 2.0, minf(float(reach.get("max", preferred * 2.0)), 2000.0)))
		for i in 17: distances.append(upper * i / 16.0)
		for distance in distances:
			var head: Vector2 = a.arena.clamp_point(a.run_state.ship_pos + Vector2.from_angle(angle) * float(distance), float(p.slot_margin))
			var snapshot := {"gate": gate, "body": a.table.pos[a.body], "facing": a.table.facing[a.body], "head": head, "base": head - Vector2.from_angle(n.angle) * float(a.def.params.neck_rest), "base_angle": n.base_angle, "separated": true, "reach": reach}
			if a.flow_adapter.RANGE.allows_snapshot(snapshot, a.run_state.ship_pos) and absf(float(distance) - preferred) < best:
				best = absf(float(distance) - preferred)
				at = head
	return a.arena.clamp_point(at, float(p.slot_margin))

func is_candidate(n, id: StringName) -> bool:
	return n.motion.get("role", &"guard") == &"attack" and n.motion.get("ready", false) and n.motion.get("move", &"") == id and allowed(id)

func group_candidates(options: Array) -> Array:
	if tactic != &"pincer" or pair.is_empty(): return options
	var members := []
	for n in pair:
		var eligible := options.filter(func(c): return c.get("execution_kind", "") == "single" and c.heads[0] == n and allowed(StringName(c.id)))
		if eligible.is_empty(): return options.filter(func(c): return c.get("execution_kind", "") != "single")
		members.append(eligible[0])
	var result := options.filter(func(c): return c.get("execution_kind", "") != "single")
	if members.size() == 1:
		result.append(members[0])
		return result
	var grouped: Dictionary = members[0].duplicate()
	grouped.execution_kind = "squad"
	grouped.members = members
	grouped.heads = []
	grouped.parts = []
	grouped.cost = 0.0
	grouped.exclusive = true
	for member in members:
		grouped.heads.append_array(member.heads)
		grouped.parts.append_array(member.parts)
		grouped.cost += float(member.cost)
		grouped.post_gap = maxf(float(grouped.post_gap), float(member.post_gap))
	result.append(grouped)
	return result

func started(n) -> void:
	n.motion.reserved = 0.0
	n.motion.last_attack = a._time
	if pair.has(n): pair_launched = true
