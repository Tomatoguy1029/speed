## 編集元から再構築した隔離ランで本番の描画・突進判定を実行する。
extends Node
signal progress(value: float)
const SESSION := preload("res://gyms/enemy_lab/lab_session.gd")
var cancelled := false
var worker

func cancel() -> void:
	cancelled = true
	if is_instance_valid(worker):
		worker.cancel_seek()

func evaluate(source, path: PackedVector2Array, draw_seconds := 0.5, start_offset := 0) -> Dictionary:
	cancelled = false
	if path.size() < 2:
		return {"status": "invalid", "reason": "線には2点以上必要です"}
	var key: String = source.digest() + str(hash(var_to_bytes([source.spec, source.history, path, draw_seconds, start_offset])))
	worker = SESSION.new()
	add_child(worker)
	worker.seek_progress.connect(func(v): progress.emit(v * 0.5))
	await worker.reset(source.spec)
	worker.history.assign(source.history.duplicate(true))
	worker.furthest = source.tick
	await worker.seek(source.tick)
	if cancelled:
		return await _finish({"status": "cancelled"})
	for n in clampi(start_offset, 0, 3600):
		worker.step()
	var run: RunManager = worker.run
	# 被弾を測るため、評価側では無敵を解除する。
	run.ship.invincible = false
	worker.events.clear()
	var initial_hp := run.state.ship_hp
	var it := Intent.new()
	it.press = true
	it.pen = path[0]
	it.has_cursor = true
	it.cursor = path[0]
	run.draw._start(it)
	var frames: int = clampi(ceili(maxf(draw_seconds, run.cfg.draw_confirm_delay) / worker.DT), 1, 1800)
	var drawn := false
	for n in frames:
		if cancelled:
			return await _finish({"status": "cancelled"})
		var index := clampf(float(n + 1) / frames * (path.size() - 1), 0, path.size() - 1)
		var lo := mini(floori(index), path.size() - 2)
		# 頂点を飛ばさない。通常と同じ長さ・地形制限と角の補正を適用する。
		var previous := float(n) / frames * (path.size() - 1)
		for k in range(ceili(previous), floori(index) + 1):
			if k > 0 and k < path.size():
				run.draw._extend(path[k])
		run.draw._extend(path[lo].lerp(path[lo + 1], index - lo))
		worker.step()
		if not run.state.drawing:
			drawn = true
			break
		if n % 60 == 0:
			progress.emit(0.5 + 0.15 * float(n) / frames)
			await get_tree().process_frame
	var accepted := run.state.draw_points.duplicate()
	if run.state.drawing:
		run.draw._commit(it)
	var trajectory := []
	var completed := false
	for n in 3600:
		if cancelled:
			return await _finish({"status": "cancelled"})
		trajectory.append([run.state.ship_pos.x, run.state.ship_pos.y])
		if not run.state.tracing:
			completed = run.state.ship_pos.distance_to(path[path.size() - 1]) <= maxf(run.cfg.draw_step * 2, 12)
			break
		worker.step()
		if n % 120 == 0:
			progress.emit(0.65 + 0.3 * float(n) / 3600)
			await get_tree().process_frame
	var kills := 0
	var impacts := []
	for event in worker.events:
		if event.get("type") == &"kill":
			kills += 1
		if event.get("type") in [&"kill", &"hit", &"bounce", &"block_impact", &"damage", &"ship_hit"]:
			impacts.append(event.duplicate(true))
	var result := {"status": "replayed", "key": key, "source_tick": source.tick,
		"seed": source.spec.seed, "draw_seconds": draw_seconds, "offset": start_offset,
		"completed": completed, "kills": kills, "damage": maxf(0, initial_hp - run.state.ship_hp),
		"gauge": run.state.gauge, "end": [run.state.ship_pos.x, run.state.ship_pos.y],
		"trajectory": trajectory, "events": impacts, "accepted": accepted,
		"success": completed and initial_hp <= run.state.ship_hp}
	progress.emit(1.0)
	return await _finish(result)

func _finish(result: Dictionary) -> Dictionary:
	if is_instance_valid(worker):
		worker.queue_free()
		await get_tree().process_frame
	worker = null
	return result
