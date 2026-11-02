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
		var future_ticks := PackedInt64Array()
		for command in session.history: future_ticks.append(int(command.tick))
		parameters.future_ticks = future_ticks
		parameters.scheduled = not session.schedule.is_empty()
		response = session.bridge.query_route(path,parameters)
	if not response.ok:
		return {"status":"invalid","reason":response.message,"valid":false,"blockers":[],"fodder":[],"unsupported":[]}
	var result: Dictionary = response.value
	if result.has("reason_key"): result.reason = TranslationServer.translate(result.reason_key)
	for row: Dictionary in result.blockers:
		row.reason = TranslationServer.translate(row.reason_key)
	var unsupported := []
	for row: Dictionary in result.unsupported:
		unsupported.append(row.id if row.has("id") and row.get("enemy",false) else TranslationServer.translate(row.reason_key) if not row.reason_key.is_empty() else row.reason)
	result.unsupported = unsupported
	if session.has_method("digest"): result.digest = session.digest()
	return result

## 入力点の省略と角の補正で線が寄る範囲も、通過する円に加える。
static func sweep_radius(run, margin: float) -> float:
	return run.cfg.ship_radius + maxf(0, margin) + run.cfg.draw_step + 2.5 / maxf(run.state.camera_zoom, 0.01)
