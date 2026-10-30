## W05 バリアシステム：攻撃を耐久で受け止め、殻が光ってから外へ波動を送る。
extends WeaponBehavior
var durability := -1.0
var restore := 0.0
var waves: Array[Dictionary] = []
func radius() -> float: return area(at_level("radius_by_level"))
func shell_radius() -> float: return float(p("shell_radius")) * 1.82 * cfg.character_scale
func ready() -> bool: return restore <= 0.0
func block_segment(from: Vector2, to: Vector2, bullet_radius: float, damage: float) -> Variant:
	if not ready(): return null
	var fraction := Geom.seg_circle_t(from, to, state.ship_pos, shell_radius() + bullet_radius)
	if fraction < 0.0: return null
	var hit := from.lerp(to, fraction)
	if not block_damage(damage, hit): return null
	return {"t": fraction, "pos": hit}

func block_damage(damage: float, hit: Vector2) -> bool:
	if not ready() or damage <= 0.0: return false
	if durability < 0.0: durability = at_level("durability_by_level")
	durability -= damage
	var broken := durability <= 0.0
	if broken: restore = interval(at_level("revive_by_level"))
	waves.append({"pos": state.ship_pos, "age": 0.0, "radius": radius(), "damage": atk() * at_level("damage_by_level"), "hit": {}})
	state.emit(&"barrier_hit", {"pos": state.ship_pos, "hit": hit, "angle": (hit - state.ship_pos).angle(), "radius": radius(), "broken": broken})
	return true
func tick(dt: float, _busy: bool) -> void:
	if restore > 0.0:
		restore = maxf(0.0, restore - dt)
		if restore <= 0.0:
			durability = at_level("durability_by_level")
			state.emit(&"barrier_restore", {"pos": state.ship_pos})
	for wave in waves:
		wave.age += dt
		if wave.age < 0.21: continue
		var step := 4 + floori((wave.age - 0.21) / 0.05)
		var reach := minf(wave.radius, step * sqrt(3.0) * 4.0 * 1.82 * cfg.character_scale)
		var rows := PackedInt32Array()
		ctx.combat.nearby(wave.pos, reach, rows)
		var t := ctx.enemies.table
		for i in rows:
			if t.dead[i] != 0 or wave.hit.has(t.id[i]) or t.pos[i].distance_to(wave.pos) > reach + t.r[i]: continue
			wave.hit[t.id[i]] = true
			ctx.combat.damage_enemy(i, wave.damage, {"cause": &"barrier", "dir": (t.pos[i] - wave.pos).normalized(), "knock": p("knock")})
	waves = waves.filter(func(w): return w.age < 0.26 + ceil(w.radius / (sqrt(3.0) * 4.0 * 1.82 * cfg.character_scale) - 4.0) * 0.05)
