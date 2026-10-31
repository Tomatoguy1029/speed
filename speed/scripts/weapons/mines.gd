## W07 マインランチャー：終点から前方へまっすぐ撃ち出す。Lv3から近くの機雷も誘爆する。
extends WeaponBehavior
var mines: Array[Dictionary] = []
var _serial := 0
var _rows := PackedInt32Array()
var _queue: Array[Dictionary] = []
func on_end() -> void:
	var direction := state.ship_heading
	var trace: TraceRun = ctx.draw.run
	if trace != null and state.trace_path.size() >= 2:
		var segment := mini(trace.seg,state.trace_path.size()-2)
		direction = (state.trace_path[segment+1]-state.trace_path[segment]).normalized()
	var heading := direction.angle()
	var count := int(at_level("count_by_level"))
	for k in count:
		var a := heading + deg_to_rad(state.rng.randf_range(-float(p("spread")), float(p("spread"))))
		var target := state.ship_pos + Vector2.from_angle(a) * state.rng.randf_range(float(p("range_min")), float(p("range_max")))
		_serial += 1
		mines.append({"id": _serial, "pos": state.ship_pos, "from": state.ship_pos, "to": target, "age": 0.0,
			"life": at_level("life_by_level"), "armed": 0.0,
			"damage": atk() * at_level("damage_by_level"), "radius": area(at_level("radius_by_level")), "detonate": false})
	while mines.size() > int(p("max")): mines.pop_front()
func tick(dt: float, _busy: bool) -> void:
	_queue.clear()
	for m in mines:
		m.life -= dt
		m.age += dt
		m.pos = m.from.lerp(m.to, 1.0 - pow(1.0 - minf(1.0, m.age / 0.14), 3.0))
		if m.life <= 0.0 or m.age < 0.14: continue
		var trigger := area(float(p("trigger")))
		ctx.combat.nearby(m.pos, trigger, _rows)
		for i in _rows:
			if ctx.enemies.table.dead[i] == 0 and ctx.enemies.table.pos[i].distance_to(m.pos) <= trigger + ctx.enemies.table.r[i]:
				m.detonate = true
				_queue.append(m)
				break
	var queue_index := 0
	while queue_index < _queue.size():
		var m: Dictionary = _queue[queue_index]
		queue_index += 1
		if m.life <= 0.0: continue
		m.life = 0.0
		ctx.combat.explode(m.pos, m.radius, m.damage, {"cause": &"mine", "knock": 300.0 * post_factor(&"knockback"), "life": 0.6})
		if level >= 3:
			for other in mines:
				if other.life > 0.0 and other.age >= 0.14 and not other.detonate and other.pos.distance_to(m.pos) <= m.radius:
					other.detonate = true
					_queue.append(other)
	_queue.clear()
	var kept := 0
	for mine in mines:
		if mine.life > 0.0:
			mines[kept] = mine
			kept += 1
	mines.resize(kept)
