## 円・線分の掃引で静止配置を判定する。点サンプルで通過可能とは扱わない。
extends RefCounted

static func distance_to_path(p: Vector2, path: PackedVector2Array) -> float:
	var distance := INF
	for n in range(1, path.size()):
		distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, path[n - 1], path[n])))
	return distance

static func length(path: PackedVector2Array) -> float:
	var value := 0.0
	for n in range(1, path.size()):
		value += path[n - 1].distance_to(path[n])
	return value

static func validate(session, path: PackedVector2Array, margin := 20.0, window := 0.0, draw_seconds := 0.5, exit_clearance := 0.0) -> Dictionary:
	var run: RunSimulation = session.run
	exit_clearance = maxf(0, exit_clearance)
	var blockers := []
	var fodder := []
	var unsupported := []
	var horizon := maxf(0, window) + maxf(draw_seconds, run.cfg.draw_confirm_delay) + run.cfg.draw_run_time + run.cfg.kill_hitstop_cap
	horizon = horizon * maxf(1, maxf(run.cfg.draw_time_scale, run.cfg.draw_run_scale_min)) + run.world_time_pending()
	var radius := sweep_radius(run, margin)
	var budget := run.draw.budget(run.state.stats.capacity * run.state.gauge)
	if path.size() < 2:
		return {"status": "invalid", "reason": TranslationServer.translate("lab.message_7474db4292"), "valid": false}
	if run.state.gauge < run.cfg.draw_min_charge: blockers.append({"reason": TranslationServer.translate("lab.low_charge"), "pos": path[0]})
	if path[path.size() - 1].length() + radius + exit_clearance >= run.cfg.field_radius: blockers.append({"reason": TranslationServer.translate("lab.message_fdee8bc433"), "pos": path[path.size() - 1]})
	if length(path) > budget + 0.01:
		blockers.append({"reason": TranslationServer.translate("lab.message_ace1dcf08b"), "pos": path[path.size() - 1]})
	for p in path:
		if p.length() + radius >= run.cfg.field_radius:
			blockers.append({"reason": TranslationServer.translate("lab.message_fdee8bc433"), "pos": p})
	for body in run.field.bodies:
		var growth: float = run.field.body_speed_max * (horizon if window > 0 else 0)
		if minf(distance_to_path(body.pos, path), body.pos.distance_to(path[path.size() - 1]) - exit_clearance) <= body.r + radius + growth:
			blockers.append({"reason": TranslationServer.translate("lab.message_409189caf0"), "pos": body.pos})
	var t := run.enemies.table
	var attack := run.combat.attack_power()
	if window > 0: attack = run.cfg.base_attack * run.cfg.atk_scale * minf(1, run.state.stats.attack_mult) * minf(1, run.combat.burst_power)
	for i in t.alive.size():
		if not t.alive[i] or t.dead[i]:
			continue
		var def: EnemyDef = t.def[i]
		# 時間幅の証明は静止した非攻撃の対象に限定する。
		if window > 0 and (t.is_boss[i] or def == null or def.behavior not in [&"drift", &"chase"] or t.speed[i] > 0 or t.vel[i].length() > 0.01 or def.params.has("chain_power") or def.params.has("death_split") or def.params.has("life") or t.gate[i] != EnemyTable.Gate.NONE):
			unsupported.append(t.id[i])
		if minf(distance_to_path(t.pos[i], path), t.pos[i].distance_to(path[path.size() - 1]) - exit_clearance) > t.r[i] + radius:
			continue
		if t.gate[i] in [EnemyTable.Gate.GHOST, EnemyTable.Gate.SOLID]:
			continue
		if t.gate[i] != EnemyTable.Gate.NONE:
			blockers.append({"reason": TranslationServer.translate("lab.message_416deae061"), "id": t.id[i], "pos": t.pos[i]})
		elif attack < t.armor[i] or attack < t.hp[i]:
			blockers.append({"reason": TranslationServer.translate("lab.message_676b643ad5"), "id": t.id[i], "pos": t.pos[i]})
		else:
			fodder.append(t.id[i])
	if window > 0:
		if run.field.body_speed_max > 0 or not run.field.rocks.is_empty(): unsupported.append("moving terrain / streamed rocks")
		for command in session.history:
			if int(command.tick) > session.tick and int(command.tick) <= session.tick + ceili(horizon * 60): unsupported.append("recorded future commands")
		if not run.state.weapons.is_empty() or not run.state.traits.is_empty() or run.state.hero_active_t > 0 or not run.field.wells.is_empty(): unsupported.append(TranslationServer.translate("lab.message_eaf4530ecf"))
		if run.field.gimmick(&"comets")._comet_t <= horizon or run.field.gimmick(&"gravity")._well_t <= horizon: unsupported.append(TranslationServer.translate("lab.message_feb890132f"))
	var p := run.projectiles
	for i in p.hostile_alive.size():
		if p.hostile_alive[i]:
			var intersects := minf(distance_to_path(p.hostile_pos[i], path), p.hostile_pos[i].distance_to(path[path.size() - 1]) - exit_clearance) < p.hostile_r[i] + radius
			if window > 0:
				if p.hostile_turn[i] > 0 or p.hostile_kind[i] == ProjectileSystem.HostileKind.MISSILE:
					unsupported.append("bullet:%d" % i)
				else:
					var end := p.hostile_pos[i] + p.hostile_vel[i] * horizon
					for n in range(1, path.size()):
						var pair := Geometry2D.get_closest_points_between_segments(p.hostile_pos[i], end, path[n - 1], path[n])
						if pair[0].distance_to(pair[1]) <= radius + p.hostile_r[i] or Geometry2D.get_closest_point_to_segment(path[path.size() - 1], p.hostile_pos[i], end).distance_to(path[path.size() - 1]) <= radius + p.hostile_r[i] + exit_clearance: intersects = true
			if intersects:
				blockers.append({"reason": TranslationServer.translate("lab.message_8e84357015"), "pos": p.hostile_pos[i]})
	for i in p.hazard_alive.size():
		if not p.hazard_alive[i]:
			continue
		if window > 0 and p.hazard_owner[i] >= 0:
			unsupported.append("hazard:%d" % i)
		var hit := false
		if p.hazard_kind[i] in [ProjectileSystem.HazardKind.ZONE, ProjectileSystem.HazardKind.WAVE]:
			# 扇や切れ目を広い円に丸める。保守的な未成立を許す。
			hit = minf(distance_to_path(p.hazard_pos[i], path), p.hazard_pos[i].distance_to(path[path.size() - 1]) - exit_clearance) <= p.hazard_len[i] + radius + p.hazard_width[i]
		else:
			var from := p.hazard_pos[i]
			var to := from + Vector2.from_angle(p.hazard_angle[i]) * p.hazard_len[i]
			for n in range(1, path.size()):
				var pair := Geometry2D.get_closest_points_between_segments(from, to, path[n - 1], path[n])
				if pair[0].distance_to(pair[1]) <= radius + p.hazard_width[i] * 0.5 or Geometry2D.get_closest_point_to_segment(path[path.size() - 1], from, to).distance_to(path[path.size() - 1]) <= radius + p.hazard_width[i] * 0.5 + exit_clearance:
					hit = true
		if hit:
			blockers.append({"reason": TranslationServer.translate("lab.message_c977ed9a15"), "pos": p.hazard_pos[i]})
	var status := "static" if blockers.is_empty() else "unfound"
	if window > 0:
		status = "window" if blockers.is_empty() and unsupported.is_empty() and not session.spec.get("auto_spawn", false) and session.schedule.is_empty() else "unsupported"
	return {"status": status, "valid": blockers.is_empty() and (window <= 0 or status == "window"),
		"blockers": blockers, "fodder": fodder, "unsupported": unsupported, "length": length(path),
		"budget": budget, "margin": margin, "window": window, "tick": session.tick,
		"digest": session.digest(), "critical_dependent": false, "horizon": horizon, "draw_seconds": draw_seconds, "exit_clearance": exit_clearance}

## 入力点の省略と角の補正で線が寄る範囲も、通過する円に加える。
static func sweep_radius(run: RunSimulation, margin: float) -> float:
	return run.cfg.ship_radius + maxf(0, margin) + run.cfg.draw_step + 2.5 / maxf(run.state.camera_zoom, 0.01)
