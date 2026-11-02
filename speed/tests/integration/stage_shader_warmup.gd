## 出撃の準備後、ステージに出る敵・ボス・攻撃の描画で初回コンパイルを増やさない。
extends Node
func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[stage_shader_warmup] headless: 実GPUの実行で確認")
		get_tree().quit()
		return
	GameManager.run_stage = 4
	var session := RunManager.create_run()
	session.auto_step = false
	add_child(session)
	if session.sim.state == null: await session.started
	var run := session.sim
	while run.state.cards.is_empty(): await get_tree().process_frame
	while run.loadout.resource_scopes().any(func(scope): return not scope.warmup_complete): await get_tree().process_frame
	run.choose_card(0)
	await get_tree().create_timer(1.1).timeout
	var before_canvas := Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)
	var before_draw := Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
	var index := 0
	for id in run.state.stage.resources.enemy_ids:
		var definition := run.enemies.def_of(StringName(id))
		if definition == null: continue
		run.enemies.spawn(definition, run.state.ship_pos + Vector2((index % 6 - 3) * 55, (index / 6 - 2) * 55))
		index += 1
	await get_tree().create_timer(1.1).timeout
	print("[stage_shader_warmup] after_enemies=%d" % (Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS) - before_canvas))
	run.bosses.spawn(null, run.state.ship_pos + Vector2(200, 0))
	await get_tree().create_timer(1.1).timeout
	print("[stage_shader_warmup] after_boss=%d" % (Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS) - before_canvas))
	run.command(&"debug_hazards")
	run.flush_events()
	await get_tree().create_timer(1.1).timeout
	var canvas_delta := Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS) - before_canvas
	var draw_delta := Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) - before_draw
	print("[stage_shader_warmup] enemies=%d canvas_delta=%d draw_delta=%d" % [index, canvas_delta, draw_delta])
	var failed := canvas_delta != 0 or draw_delta != 0
	if failed: push_error("ステージの初回描画でコンパイルが増えた")
	session.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
