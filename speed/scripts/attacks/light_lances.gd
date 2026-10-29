## 光の槍の即時の貫通判定と、命中地点からの分裂。飛ぶ見た目は共通の発射イベントで再生する。
extends RunSystem
var items: Array[Dictionary] = []
func fire(from: Vector2, direction: Vector2, length: float, width: float, damage: float, knock: float) -> void:
	var queue: Array[Dictionary] = [{"from": from, "velocity": direction * length / 0.18, "length": length, "width": width,
		"damage": damage, "knock": knock, "generation": 0, "hit": {}}]
	while not queue.is_empty() and state.phase == RunState.Phase.PLAY:
		var lance: Dictionary = queue.pop_front()
		lance.life = 0.5
		items.append(lance)
		var to: Vector2 = lance.from + lance.velocity.normalized() * lance.length
		state.emit(&"critical_lance", {"from": lance.from, "to": to, "width": lance.width})
		var rows := PackedInt32Array()
		var pad := Vector2.ONE * float(lance.width) * 0.5
		ctx.combat.in_rect(lance.from.min(to) - pad, lance.from.max(to) + pad, rows)
		var t := ctx.enemies.table
		var hits: Array = []
		for i in rows:
			if t.dead[i] != 0 or lance.hit.has(t.id[i]): continue
			var fraction := Geom.seg_circle_t(lance.from, to, t.pos[i], t.r[i] + lance.width * 0.5)
			if fraction >= 0.0: hits.append([fraction, i])
		hits.sort_custom(func(a, b): return a[0] < b[0])
		for hit in hits:
			var i: int = hit[1]
			if t.dead[i] != 0: continue
			lance.hit[t.id[i]] = true
			var impact: Vector2 = lance.from.lerp(to, hit[0])
			ctx.combat.damage_enemy(i, lance.damage, {"cause": &"critBeam", "no_crit": true, "dir": lance.velocity.normalized(), "knock": lance.knock})
			var vectors := ctx.loadout.split_vectors(lance.velocity, lance.generation)
			if ctx.projectiles.flying_count() + queue.size() + vectors.size() > 220: continue
			for velocity in vectors:
				queue.append({"from": impact, "velocity": velocity, "length": lance.length * (1.0 - hit[0]), "width": lance.width,
					"damage": lance.damage * ctx.loadout.split_damage(), "knock": lance.knock, "generation": lance.generation + 1, "hit": lance.hit.duplicate()})
			if not vectors.is_empty(): state.emit(&"duplicate", {"pos": impact, "directions": vectors})
func tick(_real_dt: float, world_dt: float) -> void:
	for lance in items: lance.life -= world_dt
	items = items.filter(func(l): return l.life > 0.0)
