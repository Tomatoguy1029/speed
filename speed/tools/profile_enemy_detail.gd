## Opt-in detailed profiling. Sample every 16th update; normal game formulas are copied
## from EnemyManager for measurement only. Do not use these copies to change gameplay.
extends RefCounted

var m: EnemyManager
var records: Dictionary = {}
var serial := 0
var survey_serial := 0
var interval := 16

func add(key: String, us: int, operations: int) -> void:
	var rec: Array = records.get(key, [0, 0, 0, 0])
	rec[0] += us
	rec[1] += 1
	rec[2] = maxi(rec[2], us)
	rec[3] += operations
	records[key] = rec

func tick(real_dt: float, world_dt: float) -> void:
	serial += 1
	var sampled := serial % interval == 0
	var start := Time.get_ticks_usec()
	if sampled:
		_sample_tick(real_dt, world_dt)
	else:
		m.profile_tick_hook = Callable()
		m.tick(real_dt, world_dt)
		m.profile_tick_hook = tick
	add("sampled_tick" if sampled else "normal_tick", Time.get_ticks_usec() - start, 1)

func survey() -> int:
	survey_serial += 1
	if survey_serial % interval == 0:
		return _sample_survey()
	m.profile_survey_hook = Callable()
	var result := m._survey()
	m.profile_survey_hook = survey
	return result

func summary() -> Dictionary:
	var result := {}
	for key in records:
		var rec: Array = records[key]
		result[key] = {"ms_sample": rec[0] / 1000.0 / rec[1], "max_sample_ms": rec[2] / 1000.0,
			"samples": rec[1], "operations": rec[3]}
	return result

func _sample_tick(_real_dt: float, world_dt: float) -> void:
	if world_dt <= 0.0:
		return
	var totals := PackedInt64Array()
	totals.resize(7)
	var counts := PackedInt64Array()
	counts.resize(7)
	var stamp := 0
	m._update_aim(world_dt)
	var dt := world_dt
	var aim := m.state.enemy_aim
	var vc := m.state.view_center
	var vh := m.state.view_half
	var cycle_len := m.cfg.enemy_approach_cycle
	var appr := m.cfg.enemy_approach_time
	var blend := m.cfg.enemy_approach_blend
	var roam_turn := m.cfg.enemy_roam_turn
	for e: Enemy in m.list:
		if e.dead or e.is_boss or e.meteor_index >= 0:
			continue
		e.age += dt
		if e.hit_cd > 0.0:
			e.hit_cd -= dt
		if e.flash > 0.0:
			e.flash -= dt
		var from := e.pos
		if e.shove_time > 0.0 or e.knock_t > 0.0 or e.beh != Enemy.Beh.CHASE:
			stamp = Time.get_ticks_usec()
			m._update(e, dt)
			totals[0] += Time.get_ticks_usec() - stamp
			counts[0] += 1
		else:
			# 追跡（いちばん多い雑魚）は関数を呼ばずにここで計算する（仕様書 11.5）
			stamp = Time.get_ticks_usec()
			var cycle := fmod(e.age + e.roam_phase, cycle_len)
			var roam := clampf(minf((cycle - appr) / blend, (cycle_len - cycle) / blend), 0.0, 1.0)
			var target := aim
			if roam > 0.0:
				var ang := e.roam_angle + e.age * roam_turn
				var ux := cos(ang)
				var uy := sin(ang)
				var edge := e.roam_radius / maxf(absf(ux), absf(uy))
				target = aim + (Vector2(vc.x + ux * edge * vh.x, vc.y + uy * edge * vh.y) - aim) * roam
			var d := target - e.pos
			var dist := d.length()
			if dist < 0.001:
				dist = 1.0
			totals[1] += Time.get_ticks_usec() - stamp
			counts[1] += 1
			stamp = Time.get_ticks_usec()
			var k := minf(1.0, e.accel * dt)
			e.vel += (d * (e.speed / dist) - e.vel) * k
			var to_aim := (aim - e.pos).angle()
			var turn_max := e.turn * dt
			e.facing += clampf(wrapf(to_aim - e.facing, -PI, PI), -turn_max, turn_max)
			totals[2] += Time.get_ticks_usec() - stamp
			counts[2] += 1
			stamp = Time.get_ticks_usec()
			e.pos += e.vel * dt
			totals[3] += Time.get_ticks_usec() - stamp
			counts[3] += 1
		stamp = Time.get_ticks_usec()
		var near := m.field.near_body(e.pos, e.r + e.vel.length() * dt)
		totals[4] += Time.get_ticks_usec() - stamp
		counts[4] += 1
		if near:
			stamp = Time.get_ticks_usec()
			m.field.collide_enemy(e, from)
			totals[5] += Time.get_ticks_usec() - stamp
			counts[5] += 1
	stamp = Time.get_ticks_usec()
	m._flush_new()
	totals[6] = Time.get_ticks_usec() - stamp
	counts[6] = 1
	var names := ["special_behavior", "chase_target", "velocity_heading", "position", "near_body", "body_collision", "flush_new"]
	for i in names.size():
		add(names[i], totals[i], counts[i])


func _sample_survey() -> int:
	var stamp := Time.get_ticks_usec()
	m._edge_counts.fill(0)
	m._type_counts.clear()
	var battleships := 0
	var titans := 0
	var vc := m.state.view_center
	var vh := m.state.view_half
	var lim := vh * m.cfg.spawn_recycle_scale + Vector2(200, 200)
	var alive := 0
	var center_x := vh.x * 0.45
	var center_y := vh.y * 0.45
	m._far_enemies.clear()
	for e: Enemy in m.list:
		if e.dead or e.is_boss or e.meteor_index >= 0:
			continue
		# 種類別上限を使う2種類だけ集計。全種類の辞書更新は不要。
		var type := e.type
		if type == &"battleship":
			battleships += 1
		elif type == &"titan":
			titans += 1
		var rel := e.pos - vc
		if absf(rel.x) > lim.x or absf(rel.y) > lim.y:
			m._far_enemies.append(e)
			continue
		alive += 1
		var ax := absf(rel.x)
		var ay := absf(rel.y)
		if ax < center_x and ay < center_y:
			continue
		# 正規化した距離の比較を交差乗算にし、個体ごとの除算を省く。
		var side := (0 if rel.x < 0.0 else 1) if ax * vh.y > ay * vh.x else (2 if rel.y < 0.0 else 3)
		m._edge_counts[side] += 1
	m._type_counts[&"battleship"] = battleships
	m._type_counts[&"titan"] = titans
	add("survey_scan", Time.get_ticks_usec() - stamp, m.list.size())
	stamp = Time.get_ticks_usec()
	for e: Enemy in m._far_enemies:
		if m._recycle(e):
			alive += 1
	add("survey_recycle", Time.get_ticks_usec() - stamp, m._far_enemies.size())
	return alive
