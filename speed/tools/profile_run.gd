## 短時間の性能計測専用。実ゲームの仕様・セーブは変更しない。
## -- --time=320 --size=1280x720 --sparks=off --glow=off
extends Node

var run: RunManager
var render: RenderManager
var drawing_times: Dictionary = {}
var frames: Array[float] = []
var gpu_times: Array[float] = []
var render_times: Array[float] = []
var draws: Array[float] = []
var measuring := false
var previous_us := 0
var start_us := 0
var counts := {"enemies": 0.0, "hostile": 0.0, "friendly": 0.0, "gems": 0.0}
var options: Dictionary = {}
var saved_rd: RenderingDevice
var attacked := false
var detail: RefCounted
var timeline: Array = []
var last_totals: Dictionary = {}

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", false, 1)
		if parts.size() == 2:
			options[parts[0]] = parts[1]
	SaveManager.data = SaveManager.default_data()
	GameManager.run_stage = 1
	GameManager.run_endless = false
	var scene := preload("res://scenes/run/run.tscn").instantiate()
	add_child(scene)
	run = scene.get_node("Managers/RunManager")
	render = scene.get_node("Managers/RenderManager")
	await get_tree().process_frame
	await get_tree().process_frame
	run.command(&"choose_card", {"index": 0})
	run.build.reset_loadout()
	run.build.grant(&"weapon", &"W01", 1)
	if options.get("attack", "off") == "on":
		run.build.reset_loadout()
		for id in [&"W03", &"W04", &"W08", &"W17"]:
			run.build.grant(&"weapon", id, 5)
		run.build.grant(&"trait", &"T04", 5)
	run.state.rng.seed = 1029
	# RunManager の初期化は乱数配置なので、天体も同じシードで作り直す。
	# 天体との接触量の違いを、描画の比較条件へ混ぜない。
	run.field.bodies.clear()
	run.field.moons.clear()
	run.field.dust.clear()
	run.field.rocks.clear()
	run.enemies.list.clear()
	run.field.setup(run.state, run.cfg)
	run.ship.setup(run.state, run.cfg)
	run.state.world_time = 0.0
	run.ship.invincible = true
	run.input._touch = true
	run.input.set_process_input(false)
	run.input.set_process_unhandled_input(false)
	run.state.time = float(options.get("time", "10"))
	if options.has("enemies"):
		run.enemies.debug_spawn_random(int(options.enemies))
		run.combat.rebuild_grid()
	if options.has("size") and DisplayServer.get_name() != "headless":
		var size := String(options.size).split("x")
		DisplayServer.window_set_size(Vector2i(int(size[0]), int(size[1])))
	if options.get("sparks", "on") == "off":
		saved_rd = render.pipeline.sparks.rd
		render.pipeline.sparks.rd = null
		render.pipeline.sparks.hide()
	if options.get("glow", "on") == "off":
		for child in scene.get_node("World").get_children():
			if child is WorldEnvironment:
				child.environment.glow_enabled = false
	if options.get("background", "on") == "off":
		render._layers.background.draw_fn = func(_c): pass
		if render.get("_star_batch") != null:
			render._star_batch.hide()
	if options.has("hz"):
		Engine.physics_ticks_per_second = int(options.hz)
	for key in render._layers:
		var layer: DrawLayer = render._layers[key]
		layer.draw_fn = _timed_draw.bind(key, layer.draw_fn)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	await get_tree().create_timer(6.0).timeout
	run.profile.clear()
	drawing_times.clear()
	run.profiling = true
	if options.get("detail", "off") == "on":
		detail = preload("res://tools/profile_enemy_detail.gd").new()
		detail.m = run.enemies
		run.enemies.profile_tick_hook = detail.tick
		run.enemies.profile_survey_hook = detail.survey
	previous_us = Time.get_ticks_usec()
	start_us = previous_us
	measuring = true
	print("PROFILE_BEGIN ", JSON.stringify({"options": options, "window": str(DisplayServer.window_get_size()),
		"viewport": str(get_viewport().get_visible_rect().size), "texture": str(get_viewport().get_texture().get_size()),
		"field_seed": 1029,
		"sparks_size": str(render.pipeline.sparks._image_size), "gpu_sparks": render.pipeline.sparks.available(),
		"renderer": RenderingServer.get_current_rendering_method(), "physics_hz": Engine.physics_ticks_per_second,
		"machine": OS.get_processor_name(), "initial_enemies": run.enemies.list.size(), "adapter": RenderingServer.get_video_adapter_name()}))

func _timed_draw(c: CanvasItem, key: String, original: Callable) -> void:
	if not measuring:
		original.call(c)
		return
	var before := Time.get_ticks_usec()
	original.call(c)
	var rec: Array = drawing_times.get(key, [0, 0])
	rec[0] += Time.get_ticks_usec() - before
	rec[1] += 1
	drawing_times[key] = rec

func _process(_delta: float) -> void:
	if run == null:
		return
	# フォーカスによるポーズと強化選択を計測に含めない。
	if run.state.phase == RunState.Phase.PAUSED:
		run.command(&"resume")
	elif run.state.phase == RunState.Phase.LEVELUP:
		run.command(&"choose_card", {"index": 0})
	if not measuring:
		return
	var now := Time.get_ticks_usec()
	frames.append((now - previous_us) / 1000.0)
	previous_us = now
	var row := {"elapsed_ms": (now - start_us) / 1000.0, "frame_ms": frames[-1], "managers": {}, "drawing": {}}
	for key in run.profile:
		var rec: Array = run.profile[key]
		var prev: Array = last_totals.get(key, [0, 0])
		row.managers[key] = {"ms": (rec[0] - prev[0]) / 1000.0, "calls": rec[1] - prev[1]}
		last_totals[key] = [rec[0], rec[1]]
	for key in drawing_times:
		var rec: Array = drawing_times[key]
		var label: String = "draw:" + key
		var prev: Array = last_totals.get(label, [0, 0])
		row.drawing[key] = {"ms": (rec[0] - prev[0]) / 1000.0, "calls": rec[1] - prev[1]}
		last_totals[label] = [rec[0], rec[1]]
	timeline.append(row)
	if options.get("attack", "off") == "on" and not attacked and now - start_us > 1500000:
		attacked = true
		var p := run.state.ship_pos
		var it := Intent.new()
		it.press = true
		it.pen = p + Vector2(-400, 0)
		run.draw._start(it)
		run.draw._extend(p + Vector2(400, 0))
		run.draw._extend(p + Vector2(200, 400))
		run.draw._commit(it)
	var viewport := get_viewport().get_viewport_rid()
	gpu_times.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
	render_times.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
	draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	counts.enemies += run.enemies.list.size()
	counts.hostile += run.projectiles.hostile.size()
	counts.friendly += run.projectiles.friendly.size()
	counts.gems += run.pickups.gems.size()
	if now - start_us >= int(float(options.get("seconds", "6")) * 1000000.0):
		measuring = false
		_finish((now - start_us) / 1000000.0)

func _stats(values: Array[float]) -> Dictionary:
	values.sort()
	var total := 0.0
	for value in values:
		total += value
	return {"mean": total / values.size(), "p95": values[int((values.size() - 1) * 0.95)], "max": values[-1]}

func _finish(seconds: float) -> void:
	var manager_ms := {}
	for key in run.profile:
		var rec: Array = run.profile[key]
		manager_ms[key] = {"ms_tick": rec[0] / 1000.0 / rec[1], "ms_frame": rec[0] / 1000.0 / frames.size(), "calls": rec[1]}
		if rec.size() >= 3:
			manager_ms[key].max_tick_ms = rec[2] / 1000.0
	var draw_ms := {}
	for key in drawing_times:
		var rec: Array = drawing_times[key]
		draw_ms[key] = rec[0] / 1000.0 / frames.size()
	for key in counts:
		counts[key] /= frames.size()
	var result := {"seconds": seconds, "frames": frames.size(), "fps": frames.size() / seconds,
		"frame_ms": _stats(frames), "gpu_viewport_ms": _stats(gpu_times), "render_cpu_ms": _stats(render_times),
		"draw_calls": _stats(draws), "counts": counts, "managers": manager_ms, "drawing_ms_frame": draw_ms,
		"phase": run.state.phase, "time": run.state.time, "world_time": run.state.world_time, "weapons": run.state.weapons}
	result.timeline = timeline
	if detail != null:
		result.enemy_detail = detail.summary()
	result.kills = run.state.kills
	if options.get("body_benchmark", "off") == "on":
		result.body_benchmark = _benchmark_bodies()
	if gpu_times[-1] <= 0.0:
		result.gpu_viewport_ms = {"available": false}
	print("PROFILE_RESULT ", JSON.stringify(result))
	if options.has("capture"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(options.capture)
	if saved_rd != null:
		render.pipeline.sparks.rd = saved_rd
	set_process(false)
	run.profiling = false
	run.enemies.profile_tick_hook = Callable()
	run.enemies.profile_survey_hook = Callable()
	# ランと描画リソースの後始末を、通常のノード削除で済ませてから閉じる。
	run.get_parent().get_parent().queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()

## 同じ弾の位置で旧方式と格子方式を交互に測る。ランの状態は変更しない。
func _benchmark_bodies() -> Dictionary:
	var old_ms: Array[float] = []
	var grid_ms: Array[float] = []
	for sample in 20:
		for mode in 2:
			var start := Time.get_ticks_usec()
			for s: Shot in run.projectiles.hostile:
				var from := s.pos - s.vel / 120.0
				if (sample + mode) % 2 == 0:
					_old_body_hit(from, s.pos, s.r)
				else:
					run.field.first_body_hit(from, s.pos, s.r)
			var elapsed := (Time.get_ticks_usec() - start) / 1000.0
			if (sample + mode) % 2 == 0:
				old_ms.append(elapsed)
			else:
				grid_ms.append(elapsed)
	return {"bullets": run.projectiles.hostile.size(), "old_ms": _stats(old_ms), "grid_ms": _stats(grid_ms)}

func _old_body_hit(p0: Vector2, p1: Vector2, radius: float) -> Variant:
	var found = null
	var earliest := INF
	for b: FieldManager.Body in run.field.bodies:
		var rr := b.r + radius
		if maxf(p0.x, p1.x) < b.pos.x - rr or minf(p0.x, p1.x) > b.pos.x + rr \
				or maxf(p0.y, p1.y) < b.pos.y - rr or minf(p0.y, p1.y) > b.pos.y + rr:
			continue
		var t := Geom.seg_circle_t(p0, p1, b.pos, rr)
		if t >= 0.0 and t < earliest:
			earliest = t
			found = {"body": b, "t": t, "point": p0.lerp(p1, t)}
	return found
