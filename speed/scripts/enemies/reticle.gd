## レチクル座。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_reticle(i, dt)

func setup(system: EnemySystem, behavior_name: StringName, idx: int) -> void:
	super(system, behavior_name, idx)
	admission = false

func admit_due(_i: int, _dt: float) -> bool:
	return true

func admit_duration(i: int) -> float:
	return float(table.def[i].params.aim_time) + 0.25

## 支援するぼうえんきょう座の処理（いなければ null）。
func _telescopes():
	return m.behavior(&"sniper")

func telescope_lens(i: int) -> Vector2:
	return _telescopes().telescope_lens(i)

func _ensure_sight_rocks() -> void:
	_telescopes()._ensure_sight_rocks()

## レチクル座：ぼうえんきょう座に付き従う支援機。いちばん近いぼうえんきょう座のそばへ動き、そばにいる間（follow_reach 以内）、
## ぼうえんきょう座と機体の間で視線を遮っている小隕石（半径 small_r 以下）を探す。見つけたら照準を出して予告し（WINDUP、
## 狙う岩は target）、aim_time ののち本体からビームを撃って壊す。機体への直接攻撃や、支援と関係のない岩は撃たない。
## 支援先がいなくなると退却し（DASH）、画面の外で exit_margin より離れると消える（撃破にはならない）。
func _reticle(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var tel := _nearest_telescope(t.pos[i])
	if tel < 0:
		if projectiles.director != null:
			projectiles.director.cancel_wait(_lab_owner(i), t.id[i])
		t.mode[i] = EnemyTable.Mode.DASH
		t.target[i] = -1
		var away := (t.pos[i] - state.ship_pos).normalized()
		_steer_to(i, t.pos[i] + away * 400.0, float(p.retreat_speed), t.accel[i], dt)
		_turn_toward(i, away.angle(), t.turn[i], dt)
		var rel := t.pos[i] - _vc
		var margin := float(p.exit_margin)
		if (absf(rel.x) > _vh.x + margin or absf(rel.y) > _vh.y + margin) and rel.dot(t.vel[i]) > 0.0:
			mark_dead(i)
		return
	if t.mode[i] == EnemyTable.Mode.DASH:
		t.mode[i] = EnemyTable.Mode.MOVE
	# ぼうえんきょう座の横に付き従う
	var tf := Vector2.from_angle(t.facing[tel])
	var side := 1.0 if t.id[i] % 2 == 1 else -1.0
	var goal := t.pos[tel] + Vector2(-tf.y, tf.x) * side * float(p.follow_gap) - tf * 30.0
	_steer_to(i, goal, t.speed[i], t.accel[i], dt)
	var near := t.pos[i].distance_to(t.pos[tel]) <= float(p.follow_reach)
	t.fire_t[i] -= dt
	if t.mode[i] == EnemyTable.Mode.WINDUP:
		var rock := t.target[i]
		if not near or not is_same(rock, t.target_id[i]) or t.dead[rock] != 0:
			t.mode[i] = EnemyTable.Mode.MOVE
			t.target[i] = -1
			t.charge[i] = 0.0
			return
		_turn_toward(i, (t.pos[rock] - t.pos[i]).angle(), t.turn[i] * 3.0, dt)
		t.timer[i] -= dt
		t.charge[i] = 1.0 - maxf(0.0, t.timer[i]) / float(p.aim_time)
		if t.timer[i] <= 0.0:
			var from := t.pos[i] + Vector2.from_angle(t.facing[i]) * t.r[i]
			state.emit(&"beam", {"from": from, "to": t.pos[rock], "width": 10.0, "life": 0.25, "color": t.color[i].lightened(0.3)})
			state.emit(&"rock_break", {"pos": t.pos[rock], "r": t.r[rock], "meteor_index": t.meteor_index[rock],
				"facing": t.facing[rock], "dir": (t.pos[rock] - from).normalized(), "color": Color("#a08a78")})
			mark_dead(rock)
			t.mode[i] = EnemyTable.Mode.MOVE
			t.target[i] = -1
			t.charge[i] = 0.0
			t.fire_t[i] = float(p.break_interval)
		return
	_turn_toward(i, (t.pos[tel] - t.pos[i]).angle() if not near else t.facing[tel], t.turn[i], dt)
	if near and t.fire_t[i] <= 0.0:
		var rock := _blocking_rock(tel, float(p.small_r))
		if rock >= 0 and _lab_admit(i, dt):
			t.target[i] = rock
			t.target_id[i] = t.id[rock]
			t.mode[i] = EnemyTable.Mode.WINDUP
			t.timer[i] = float(p.aim_time)
		elif rock < 0 and projectiles.director != null:
			projectiles.director.cancel_wait(_lab_owner(i), t.id[i])
	elif projectiles.director != null:
		projectiles.director.cancel_wait(_lab_owner(i), t.id[i])

## 位置 at にいちばん近い、生きているぼうえんきょう座の行（いなければ -1）。
func _nearest_telescope(at: Vector2) -> int:
	var t := table
	var best := -1
	var best_d := INF
	for j in _telescopes().rows() if _telescopes() != null else PackedInt32Array():
		if t.dead[j] != 0:
			continue
		var d := at.distance_squared_to(t.pos[j])
		if d < best_d:
			best_d = d
			best = j
	return best

## ぼうえんきょう座（行 tel）のレンズと機体の間で、視線を遮っている小隕石（半径 small_r 以下）のうち、レンズにいちばん近いもの。
## 機体がサーチライトの届く距離の外にいるときは探さない。
func _blocking_rock(tel: int, small_r: float) -> int:
	var t := table
	var lens := telescope_lens(tel)
	var ship := state.ship_pos
	var length := lens.distance_to(ship)
	if length > float(t.def[tel].params.band_len):
		return -1
	_ensure_sight_rocks()
	var center := (lens + ship) * 0.5
	var search_radius := length * 0.5 + small_r
	var best := -1
	var best_d := INF
	for j in _telescopes()._sight_rocks:
		if t.alive[j] == 0 or t.meteor_index[j] < 0 or t.dead[j] != 0 or t.r[j] > small_r:
			continue
		var c := t.pos[j]
		var radius := search_radius + t.r[j]
		if c.distance_squared_to(center) > radius * radius:
			continue
		if Geometry2D.get_closest_point_to_segment(c, lens, ship).distance_to(c) > t.r[j] + cfg.ship_radius:
			continue
		var d := lens.distance_squared_to(c)
		if d < best_d:
			best_d = d
			best = j
	return best
