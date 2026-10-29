## T03 エンドホール：機体に追従して発動し、倒しきれる敵を引き込む。消えた瞬間に回復する。
extends TraitBehavior
var vortexes: Array[Dictionary] = []
func on_end() -> void:
	vortexes.append({"pos": state.ship_pos, "age": 0.0, "radius": float(def.params.radius_by_level[n - 1]) * ctx.loadout.area_multiplier(),
		"damage": atk() * val("damage"), "kills": 0, "hit": {}, "duration": float(def.params.charge) + float(def.params.hold) + float(def.params.collapse)})
	state.emit(&"end_hole", {"pos": state.ship_pos, "life": float(def.params.charge) + float(def.params.hold) + float(def.params.collapse)})
func tick(dt: float, _busy: bool) -> void:
	for v in vortexes:
		v.pos = state.ship_pos
		v.age += dt
		if v.age >= float(def.params.charge) and v.age < v.duration:
			var rows := PackedInt32Array()
			ctx.combat.nearby(v.pos, v.radius, rows)
			var t := ctx.enemies.table
			for i in rows:
				if t.dead[i] != 0 or v.hit.has(t.id[i]) or t.pos[i].distance_to(v.pos) > v.radius + t.r[i]: continue
				v.hit[t.id[i]] = true
				var lethal: bool = t.is_boss[i] == 0 and t.hp[i] <= v.damage
				var captured := {"pos": t.pos[i], "radius": t.r[i], "enemy_type": t.type[i], "color": t.color[i], "facing": t.facing[i]}
				var scattered_before := t.hull_scattered[i]
				if lethal: t.hull_scattered[i] = 1
				ctx.combat.damage_enemy(i, v.damage, {"cause": &"vortex", "knock": 0.0})
				if lethal and t.dead[i] != 0:
					state.emit(&"hole_capture", captured)
					v.kills += 1
				else: t.hull_scattered[i] = scattered_before
		if v.age >= v.duration:
			var amount := minf(1.0, float(v.kills) / float(def.params.kills_by_level[n - 1]))
			state.gauge = minf(state.stats.capacity, state.gauge + amount)
			state.emit(&"hole_recover", {"pos": state.ship_pos, "amount": amount})
	vortexes = vortexes.filter(func(v): return v.age < v.duration)
