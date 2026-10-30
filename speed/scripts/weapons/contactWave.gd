## W04 震空：波の先頭で押し運び、先頭が抜けたときに威力を与える。
extends WeaponBehavior
var waves: Array[Dictionary] = []
func on_contact(_i: int, hit: Vector2, _dir: Vector2) -> void:
	var radius := float(p("radius")) * radius_k()
	waves.append({"pos": hit, "radius": radius, "age": 0.0, "damage": atk() * float(p("damage")) * dmg_k(), "caught": {}, "done": {}})
	state.emit(&"space_quake", {"pos": hit, "radius": radius, "life": 0.58})
func tick(dt: float, _busy: bool) -> void:
	var t := ctx.enemies.table
	for wave in waves:
		wave.age += dt
		if wave.age < 0.08: continue
		var progress := minf(1.0, (wave.age - 0.08) / 0.5)
		var radius: float = wave.radius * (1.0 - pow(1.0 - progress, 3.0))
		var rows := PackedInt32Array()
		ctx.combat.nearby(wave.pos, radius, rows)
		for i in rows:
			if t.dead[i] != 0 or wave.done.has(t.id[i]): continue
			var distance := t.pos[i].distance_to(wave.pos)
			if distance > radius + t.r[i]: continue
			if not wave.caught.has(t.id[i]): wave.caught[t.id[i]] = {"row": i, "age": 0.0}
		for id in wave.caught.keys():
			var held: Dictionary = wave.caught[id]
			var i: int = held.row
			if not ctx.enemies.is_same(i, id) or t.dead[i] != 0:
				wave.caught.erase(id)
				continue
			held.age += dt
			var dir: Vector2 = (t.pos[i] - wave.pos).normalized()
			if ctx.enemies.knockback_scale(i) > 0.0:
				t.pos[i] += dir * 150.0 * 1.82 * cfg.character_scale * dt * ctx.enemies.knockback_scale(i)
			if held.age >= 0.16 or progress >= 1.0:
				wave.done[id] = true
				wave.caught.erase(id)
				ctx.combat.damage_enemy(i, wave.damage, {"cause": &"contactWave", "dir": dir, "knock": p("knock")})
	waves = waves.filter(func(w): return w.age < 0.58)
