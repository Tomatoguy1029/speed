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
	var parameters := {"margin":margin,"window":window,"draw_seconds":draw_seconds,"exit_clearance":exit_clearance}
	var response: Dictionary
	if session is RunSession and session.bridge!=null:
		response = session.bridge.query_route(path,parameters)
	else:
		# 実験場本体の移行前だけ、読取値を同じC++判定へ一括で渡す。複製したゲーム状態は保持しない。
		var core: RefCounted = ClassDB.instantiate(&"SpeedRunCore")
		var future_ticks := PackedInt64Array()
		for command in session.history: future_ticks.append(int(command.tick))
		parameters.future_ticks = future_ticks
		parameters.scheduled = not session.schedule.is_empty()
		response = core.query_route_snapshot(_snapshot(session),path,parameters)
	if not response.ok:
		return {"status":"invalid","reason":response.message,"valid":false,"blockers":[],"fodder":[],"unsupported":[]}
	var result: Dictionary = response.value
	if result.has("reason_key"): result.reason = TranslationServer.translate(result.reason_key)
	for row: Dictionary in result.blockers:
		row.reason = TranslationServer.translate(row.reason_key)
	var unsupported := []
	for row: Dictionary in result.unsupported:
		unsupported.append(row.id if row.has("id") and row.get("reason")=="動く敵や特殊な敵" else TranslationServer.translate(row.reason_key) if not row.reason_key.is_empty() else row.reason)
	result.unsupported = unsupported
	if session.has_method("digest"): result.digest = session.digest()
	return result

static func _snapshot(session) -> Dictionary:
	var run: RunSimulation = session.run
	var cfg: GameConfig = run.cfg
	var values := {"ship_radius":cfg.ship_radius,"field_radius":cfg.field_radius,"point_step":cfg.draw_step,"zoom":run.state.camera_zoom,"gauge":run.state.gauge,"capacity":run.state.stats.capacity,"min_charge":cfg.draw_min_charge,
		"draw_length":cfg.draw_length,"max_speed":run.state.stats.max_speed,"base_speed":cfg.base_max_speed,"length_mult":run.state.stats.length_mult,"confirm_delay":cfg.draw_confirm_delay,"run_time":cfg.draw_run_time,"hitstop_cap":cfg.kill_hitstop_cap,
		"time_scale":cfg.draw_time_scale,"scale_min":cfg.draw_run_scale_min,"pending_world":run.world_time_pending(),"attack":run.combat.attack_power(),"window_attack":cfg.base_attack*cfg.atk_scale*minf(1,run.state.stats.attack_mult)*minf(1,run.combat.burst_power),
		"body_speed":run.field.body_speed_max,"comet_time":run.field.gimmick(&"comets")._comet_t,"gravity_time":run.field.gimmick(&"gravity")._well_t}
	var snapshot := {"values":values,"tick":session.tick,"history_hz":60,"equipment_count":run.state.weapons.size()+run.state.traits.size(),"well_count":run.field.wells.size(),"rock_count":run.field.rocks.size(),
		"hero":run.state.hero_active_t>0,"auto_spawn":session.spec.get("auto_spawn",false),"bodies":[],"enemies":[],"bullets":[],"hazards":[]}
	for body in run.field.bodies: snapshot.bodies.append({"position":body.pos,"radius":body.r})
	var t: EnemyTable = run.enemies.table
	for i in t.alive.size():
		if not t.alive[i] or t.dead[i]: continue
		var definition: EnemyDef = t.def[i]
		snapshot.enemies.append({"id":t.id[i],"position":t.pos[i],"velocity":t.vel[i],"radius":t.r[i],"hp":t.hp[i],"armor":t.armor[i],"speed":t.speed[i],"gate":int(t.gate[i]),"boss":bool(t.is_boss[i]),
			"behavior":String(definition.behavior) if definition!=null else "","chain":definition!=null and definition.params.has("chain_power"),"split":definition!=null and definition.params.has("death_split"),"life":definition!=null and definition.params.has("life")})
	var p: ProjectileSystem = run.projectiles
	for i in p.hostile_alive.size():
		if p.hostile_alive[i]: snapshot.bullets.append({"id":i,"position":p.hostile_pos[i],"velocity":p.hostile_vel[i],"radius":p.hostile_r[i],"homing":p.hostile_turn[i]>0 or p.hostile_kind[i]==ProjectileSystem.HostileKind.MISSILE})
	for i in p.hazard_alive.size():
		if not p.hazard_alive[i]: continue
		var circle: bool = p.hazard_kind[i] in [ProjectileSystem.HazardKind.ZONE,ProjectileSystem.HazardKind.WAVE]
		snapshot.hazards.append({"id":i,"position":p.hazard_pos[i],"end":p.hazard_pos[i]+Vector2.from_angle(p.hazard_angle[i])*p.hazard_len[i],"radius":p.hazard_len[i]+p.hazard_width[i] if circle else p.hazard_width[i]*0.5,"circle":circle,"attached":p.hazard_owner[i]>=0})
	return snapshot

## 入力点の省略と角の補正で線が寄る範囲も、通過する円に加える。
static func sweep_radius(run: RunSimulation, margin: float) -> float:
	return run.cfg.ship_radius + maxf(0, margin) + run.cfg.draw_step + 2.5 / maxf(run.state.camera_zoom, 0.01)
