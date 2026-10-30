## W08 ソニックブーム：ブーストと勢いの間、速さが min_speed（試作のドット/秒）を超えているときだけ、
## emit_spacing ドット進むごとに音の輪を残し、重なる円錐のふちを攻撃する。
extends WeaponBehavior
var frames: Array[Dictionary] = []
var pending: Array[Dictionary] = []
var hits: Dictionary = {}
var _active := false
var _last := Vector2.ZERO
var _emission := 0.0
var _distance := 0.0
var pulse := 0.0
## 前のフレームから実際に進んだ速さ（世界の単位/秒）
var speed := 0.0
func on_launch(_full: bool) -> void:
	_active = true
	hits.clear()
	_last = state.ship_pos
	_distance = 0.0
	_emission = 0.0
func wave_speed() -> float:
	return at_level("speed_by_level") * 1.82 * cfg.character_scale * ctx.loadout.area_multiplier()
func wave_life() -> float: return float(p("life"))
## 音の輪を出す速さか。
func fast() -> bool:
	return speed > float(p("min_speed")) * 1.82 * cfg.character_scale
func tick(dt: float, _busy: bool) -> void:
	var t := ctx.enemies.table
	for f in frames: f.age += dt
	frames = frames.filter(func(f): return f.age < wave_life())
	pulse = maxf(0.0, pulse - dt)
	if dt > 0.0: speed = _last.distance_to(state.ship_pos) / dt
	if _active and (state.tracing or state.glide) and not fast():
		_emission = 0.0
	elif _active and (state.tracing or state.glide):
		var move := _last.distance_to(state.ship_pos)
		_distance += move
		if _distance >= float(p("distance")) * 1.82 * cfg.character_scale:
			_distance = fmod(_distance, float(p("distance")) * 1.82 * cfg.character_scale)
			pulse = float(p("pulse"))
		# 輪は進んだ距離ごとに出す。そのフレームの途中で出た輪は、出てからの時間だけ広げておく
		var spacing := float(p("emit_spacing")) * 1.82 * cfg.character_scale
		_emission += move
		while _emission >= spacing:
			_emission -= spacing
			var back := _emission / maxf(move, 0.001)
			# 輪は機首（機体の中心から nose ドット前）から出す
			var nose := state.ship_heading * float(p("nose")) * 1.82 * cfg.character_scale
			frames.append({"pos": _last.lerp(state.ship_pos, 1.0 - back) + nose, "age": back * dt})
	elif _active:
		_active = false
	_last = state.ship_pos
	if pulse > 0.0:
		var rows := PackedInt32Array()
		var reach := wave_speed() * wave_life()
		ctx.combat.nearby(state.ship_pos, reach + state.ship_vel.length() * wave_life(), rows)
		var forward := state.ship_heading
		var side := forward.orthogonal()
		for i in rows:
			if t.dead[i] != 0 or hits.has(t.id[i]) or (t.pos[i] - state.ship_pos).dot(forward) >= 0.0: continue
			var overlaps := 0
			for f in frames:
				var radius := wave_speed() * float(f.age)
				if radius > 2.0 * 1.82 * cfg.character_scale and absf(t.pos[i].distance_to(f.pos) - radius) < 4.0 * 1.82 * cfg.character_scale + t.r[i]:
					overlaps += 1
					if overlaps >= 3: break
			if overlaps < 3: continue
			hits[t.id[i]] = true
			var sign_side := signf((t.pos[i] - state.ship_pos).dot(side))
			if sign_side == 0.0: sign_side = 1.0
			var velocity := (side * sign_side * float(p("side_speed")) - forward * float(p("back_speed"))) * 1.82 * cfg.character_scale
			pending.append({"row": i, "id": t.id[i], "delay": float(p("damage_delay")), "age": 0.0, "velocity": velocity, "damage": atk() * at_level("damage_by_level"), "hit": false})
			state.emit(&"sonic_push", {"pos": t.pos[i], "dir": velocity.normalized(), "row": i, "id": t.id[i]})
	for hit in pending:
		var i: int = hit.row
		if not ctx.enemies.is_same(i, hit.id) or t.dead[i] != 0: continue
		hit.age += dt
		if ctx.enemies.knockback_scale(i) > 0.0:
			t.pos[i] += hit.velocity * dt * ctx.enemies.knockback_scale(i)
			hit.velocity *= pow(float(p("decay")), dt)
		if not hit.hit and hit.age >= hit.delay:
			hit.hit = true
			ctx.combat.damage_enemy(i, hit.damage, {"cause": &"sonic", "knock": 0.0})
			state.emit(&"sonic_impact", {"pos": t.pos[i], "dir": hit.velocity.normalized(), "dead": t.dead[i] != 0})
	pending = pending.filter(func(h): return h.age < 0.7 and ctx.enemies.is_same(h.row, h.id) and t.dead[h.row] == 0)
