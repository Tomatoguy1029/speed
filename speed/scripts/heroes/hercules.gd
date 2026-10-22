extends HeroBehavior

## ヘルクレス座の火の隕石：落ちてくる途中（位置と、落ちるまでの残り時間）と、燃えている跡（位置と残り時間）
var falls: Array[Vector3] = []
var burns: Array[Vector3] = []
var _fire_t := 0.0
var _burn_tick := 0.0
## 効いている間、間隔ごとに機体の周りへ火の隕石を落とす。落ちた所で爆発し、跡はしばらく燃える。
func tick(dt: float, _world_dt: float) -> void:
	var p := def.params
	if active():
		_fire_t -= dt
		if _fire_t <= 0.0:
			_fire_t = float(p.interval)
			var at := _fire_target()
			falls.append(Vector3(at.x, at.y, float(p.fall_time)))
	var dmg := combat.attack_power() * float(p.power)
	for k in range(falls.size() - 1, -1, -1):
		var f := falls[k]
		f.z -= dt
		if f.z > 0.0:
			falls[k] = f
			continue
		falls.remove_at(k)
		var at := Vector2(f.x, f.y)
		_burn_enemies(at, float(p.radius), dmg)
		state.emit(&"explode", {"pos": at, "radius": float(p.radius), "cause": &"fire", "color": Color("#ff7a2e"), "life": 0.45})
		burns.append(Vector3(at.x, at.y, float(p.burn_time)))
	_burn_tick -= dt
	var tick := _burn_tick <= 0.0
	if tick:
		_burn_tick = 0.25
	for k in range(burns.size() - 1, -1, -1):
		var b := burns[k]
		b.z -= dt
		if b.z <= 0.0:
			burns.remove_at(k)
			continue
		burns[k] = b
		if tick:
			_burn_enemies(Vector2(b.x, b.y), float(p.radius) * 0.8, dmg * float(p.burn_power))

## 火の隕石を落とす位置：機体の周り（画面の半分くらいの範囲）のランダムな位置。敵がいれば、その位置に寄せる。
## ボス戦の間は、35% の確率でボスの部位（うみへび座の頭）に寄せる。
func _fire_target() -> Vector2:
	var half := state.view_half * 0.5
	if combat.grid.table == null:
		return state.ship_pos
	var rows := PackedInt32Array()
	combat.grid.query_radius(state.ship_pos, half.length(), combat.enemy_query_padding, rows)
	var t := enemies.table
	# ボス戦の間は、ボスの部位（うみへび座の頭）に少しだけ寄せる
	if state.rng.randf() < 0.35:
		for i in rows:
			if t.dead[i] == 0 and t.parent[i] >= 0 and t.is_boss[t.parent[i]] != 0:
				return t.pos[i] + Vector2.from_angle(state.rng.randf() * TAU) * state.rng.randf() * 60.0
	for attempt in 6:
		if rows.is_empty():
			break
		var i := rows[state.rng.randi_range(0, rows.size() - 1)]
		if t.dead[i] == 0 and t.meteor_index[i] < 0:
			return t.pos[i] + Vector2.from_angle(state.rng.randf() * TAU) * state.rng.randf() * 40.0
	return state.ship_pos + Vector2(state.rng.randf_range(-half.x, half.x), state.rng.randf_range(-half.y, half.y))

## 範囲の敵を、装甲に関係なく焼く。
func _burn_enemies(center: Vector2, radius: float, dmg: float) -> void:
	var rows := PackedInt32Array()
	combat.grid.query_radius(center, radius, combat.enemy_query_padding, rows)
	var t := enemies.table
	for i in rows:
		if t.dead[i] == 0 and t.meteor_index[i] < 0 and t.pos[i].distance_to(center) <= radius + t.r[i]:
			combat.damage_enemy(i, dmg, {"cause": &"fire", "no_crit": true, "knock": 80.0,
				"dir": (t.pos[i] - center).normalized(), "impact": center})
			if state.phase != RunState.Phase.PLAY:
				return
