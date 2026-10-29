extends FieldGimmick
const Well = FieldSystem.Well
var _well_t := 0.0

func initialize() -> void:
	field.wells.clear()
	# 通常出撃の定期発生は止める。手動配置の渦は残す。
	_well_t = INF

func tick(_real_dt: float, world_dt: float) -> void:
	if world_dt > 0.0:
		_tick_wells(world_dt)

func _tick_wells(dt: float) -> void:
	var now := state.world_time
	for k in range(field.wells.size() - 1, -1, -1):
		if now - field.wells[k].born >= field.wells[k].life:
			field.wells.remove_at(k)
	if field.wells.is_empty():
		return
	var fast := state.tracing or state.glide or state.ship_vel.length() >= state.stats.max_speed * cfg.ram_speed_ratio
	var t := enemies.table
	for w in field.wells:
		var k := 1.0 - (now - w.born) / w.life
		var reach := w.radius * k
		var pull := w.pull * k * dt
		if not fast:
			state.ship_vel += _well_pull(w.pos, state.ship_pos, reach, pull)
		for i in t.alive.size():
			if t.alive[i] != 0 and t.dead[i] == 0 and t.is_boss[i] == 0 and t.meteor_index[i] < 0 and t.parent[i] < 0:
				t.vel[i] += _well_pull(w.pos, t.pos[i], reach, pull)
		var hostile_alive := projectiles.hostile_alive
		for i in hostile_alive.size():
			if hostile_alive[i] != 0:
				projectiles.hostile_vel[i] += _well_pull(w.pos, projectiles.hostile_pos[i], reach, pull)

func _well_pull(center: Vector2, p: Vector2, reach: float, pull: float) -> Vector2:
	var d := center - p
	var dist := d.length()
	if dist >= reach or dist < 1.0:
		return Vector2.ZERO
	return d / dist * pull * (1.0 - dist / reach)

func spawn_well() -> void:
	var w := Well.new()
	for attempt in 8:
		var p := state.view_center + Vector2(state.rng.randf_range(-0.7, 0.7) * state.view_half.x,
			state.rng.randf_range(-0.7, 0.7) * state.view_half.y)
		w.pos = p
		if p.distance_to(state.ship_pos) > 300.0 and field.body_gap(p, 0.0) > 100.0:
			break
	w.born = state.world_time
	w.life = cfg.gravity_life
	w.radius = cfg.gravity_radius
	w.pull = cfg.gravity_pull
	field.wells.append(w)

func add_well(pos: Vector2, life: float, radius: float, pull: float) -> void:
	var w := Well.new()
	w.pos = pos
	w.born = state.world_time
	w.life = life
	w.radius = radius
	w.pull = pull
	field.wells.append(w)
