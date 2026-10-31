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
var _wave_speed := 0.0
## 命中判定中に同じ輪のDictionaryと設定を読み直さない。次の更新でも配列を使い回す。
var _ring_positions := PackedVector2Array()
var _ring_radii := PackedFloat64Array()

func setup(context: RunContext, d: WeaponDef) -> void:
	super.setup(context, d)
	refresh_wave_speed()

## 装備・追加強化・実行時設定が変わったときだけ更新する。既存の輪にも新しい値を使う。
func refresh_wave_speed() -> void:
	_wave_speed = at_level("speed_by_level") * 1.82 * cfg.character_scale * ctx.loadout.area_multiplier()

func on_launch(_full: bool) -> void:
	_active = true
	hits.clear()
	_last = state.ship_pos
	_distance = 0.0
	_emission = 0.0
func wave_speed() -> float:
	return _wave_speed
func wave_life() -> float: return float(p("life"))
## 音の輪を出す速さか。
func fast() -> bool:
	return speed > float(p("min_speed")) * 1.82 * cfg.character_scale
func tick(dt: float, _busy: bool) -> void:
	var enemies := ctx.enemies
	var t := enemies.table
	var life := wave_life()
	var character_scale := cfg.character_scale
	var scale := 1.82 * character_scale
	var ship_pos := state.ship_pos
	var move := _last.distance_to(ship_pos)
	for f in frames: f.age += dt
	frames = frames.filter(func(f): return f.age < life)
	pulse = maxf(0.0, pulse - dt)
	if dt > 0.0: speed = move / dt
	if _active and (state.tracing or state.glide) and not (speed > float(p("min_speed")) * 1.82 * character_scale):
		_emission = 0.0
	elif _active and (state.tracing or state.glide):
		_distance += move
		var distance := float(p("distance")) * 1.82 * character_scale
		if _distance >= distance:
			_distance = fmod(_distance, distance)
			pulse = float(p("pulse"))
		# 輪は進んだ距離ごとに出す。そのフレームの途中で出た輪は、出てからの時間だけ広げておく
		var spacing := float(p("emit_spacing")) * 1.82 * character_scale
		var nose := state.ship_heading * float(p("nose")) * 1.82 * character_scale
		_emission += move
		while _emission >= spacing:
			_emission -= spacing
			var back := _emission / maxf(move, 0.001)
			# 輪は機首（機体の中心から nose ドット前）から出す
			frames.append({"pos": _last.lerp(ship_pos, 1.0 - back) + nose, "age": back * dt})
	elif _active:
		_active = false
	_last = ship_pos
	if pulse > 0.0:
		var ring_speed := wave_speed()
		var minimum_radius := 2.0 * scale
		var half_width := 4.0 * scale
		_ring_positions.resize(frames.size())
		_ring_radii.resize(frames.size())
		var ring_count := 0
		for f in frames:
			var radius := ring_speed * float(f.age)
			if radius <= minimum_radius: continue
			_ring_positions[ring_count] = f.pos
			_ring_radii[ring_count] = radius
			ring_count += 1
		var rows := PackedInt32Array()
		if ring_count >= 3:
			var reach := ring_speed * life
			ctx.combat.nearby(ship_pos, reach + state.ship_vel.length() * life, rows)
		var forward := state.ship_heading
		var side := forward.orthogonal()
		# 威力などは最初の命中まで評価を遅らせ、同じ更新の命中で共有する。
		var damage_ready := false
		var damage := 0.0
		var delay := 0.0
		var side_speed := 0.0
		var back_speed := 0.0
		for i in rows:
			if t.dead[i] != 0 or hits.has(t.id[i]): continue
			var enemy_pos: Vector2 = t.pos[i]
			var relative := enemy_pos - ship_pos
			if relative.dot(forward) >= 0.0: continue
			var enemy_radius: float = t.r[i]
			var width := half_width + enemy_radius
			var overlaps := 0
			for k in ring_count:
				var inner := _ring_radii[k] - width
				var outer := _ring_radii[k] + width
				var distance_squared := enemy_pos.distance_squared_to(_ring_positions[k])
				# |d-r|<幅 は r-幅<d<r+幅。内側0はd>0、負なら内側条件が常に成立する。
				if outer > 0.0 and distance_squared < outer * outer and (inner < 0.0 or distance_squared > inner * inner):
					overlaps += 1
					if overlaps >= 3: break
			if overlaps < 3: continue
			hits[t.id[i]] = true
			if not damage_ready:
				damage = atk() * at_level("damage_by_level")
				delay = float(p("damage_delay"))
				side_speed = float(p("side_speed"))
				back_speed = float(p("back_speed"))
				damage_ready = true
			var sign_side := signf(relative.dot(side))
			if sign_side == 0.0: sign_side = 1.0
			var velocity := (side * sign_side * side_speed - forward * back_speed) * 1.82 * character_scale
			pending.append({"row": i, "id": t.id[i], "delay": delay, "age": 0.0, "velocity": velocity, "damage": damage, "hit": false})
			state.emit(&"sonic_push", {"pos": enemy_pos, "dir": velocity.normalized(), "row": i, "id": t.id[i]})
	var decay_ready := false
	var decay := 0.0
	for hit in pending:
		var i: int = hit.row
		if not enemies.is_same(i, hit.id) or t.dead[i] != 0: continue
		hit.age += dt
		var knockback_scale := enemies.knockback_scale(i)
		if knockback_scale > 0.0:
			if not decay_ready:
				decay = pow(float(p("decay")), dt)
				decay_ready = true
			t.pos[i] += hit.velocity * dt * knockback_scale
			hit.velocity *= decay
		if not hit.hit and hit.age >= hit.delay:
			hit.hit = true
			ctx.combat.damage_enemy(i, hit.damage, {"cause": &"sonic", "knock": 0.0})
			state.emit(&"sonic_impact", {"pos": t.pos[i], "dir": hit.velocity.normalized(), "dead": t.dead[i] != 0})
	pending = pending.filter(func(h): return h.age < 0.7 and enemies.is_same(h.row, h.id) and t.dead[h.row] == 0)
