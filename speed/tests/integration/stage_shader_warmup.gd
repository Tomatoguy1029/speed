## ステージの事前描画準備後、敵・ボス・攻撃の初表示でコンパイルが増えないことを確認する。
extends Node

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[stage_shader_warmup] 実GPUを使う確認のためheadlessでは省略")
		get_tree().quit()
		return
	GameManager.run_stage = 4
	var session := RunManager.create_run()
	session.auto_step = false
	add_child(session)
	for frame in 4000:
		if session.bridge != null or session.cpp_error != OK: break
		await get_tree().process_frame
	if session.bridge == null:
		push_error("通常のC++出撃を準備できない")
		get_tree().quit(1)
		return
	var bridge: RefCounted = session.bridge
	var cards: Dictionary = bridge.read_frame().value.ui.cards
	var first: Dictionary = cards.candidates[0]
	var failed: bool = not bridge.command("choose_card", {"offer_id":cards.offer_id,"candidate_id":first.candidate_id}).ok
	for frame in 4000:
		session.cpp_choices.poll()
		failed = not _step(bridge) or failed
		if not bridge.read_frame().value.ui.cards.initial: break
		await get_tree().process_frame
	failed = bridge.read_frame().value.ui.cards.initial or failed
	failed = not bridge.command("dev_edit", {"kind":"debug_action","payload":{"action":"invincible","args":{}}}).ok or failed
	await get_tree().create_timer(1.1).timeout
	var before_canvas := Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)
	var before_draw := Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
	var index := 0
	var stage: RuntimeStage = ContentManager.runtime_stage(4)
	var position: Vector2 = bridge.read_frame().value.ui.ship.ship_pos
	for id in stage.resources.enemy_ids:
		var spawned: Dictionary = bridge.command("dev_spawn", {"definition_id":String(id),"position":position+Vector2((index%6-3)*55,(index/6-2)*55)})
		failed = not spawned.ok or failed
		index += 1
	_step(bridge)
	await get_tree().create_timer(1.1).timeout
	print("[stage_shader_warmup] 敵の表示後=%d" % (Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)-before_canvas))
	var at: float = stage.boss_start(ContentManager.cfg)+ContentManager.cfg.boss_time_spread+0.1
	failed = not bridge.command("dev_set_scenario", {"kind":"lab","params":{"lab_mode":true,"auto_spawn":false,"auto_boss":true,"invincible":true,"time":at,"level":1}}).ok or failed
	_step(bridge)
	await get_tree().create_timer(1.1).timeout
	print("[stage_shader_warmup] ボスの表示後=%d" % (Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)-before_canvas))
	failed = bridge.read_frame().value.ui.boss_bodies.is_empty() or failed
	failed = not bridge.command("dev_edit", {"kind":"debug_action","payload":{"action":"hazards","args":{}}}).ok or failed
	_step(bridge)
	await get_tree().create_timer(1.1).timeout
	var canvas_delta := Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)-before_canvas
	var draw_delta := Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)-before_draw
	print("[stage_shader_warmup] 敵=%d canvas_delta=%d draw_delta=%d" % [index,canvas_delta,draw_delta])
	failed = canvas_delta != 0 or draw_delta != 0 or failed
	if failed: push_error("事前準備後の初回表示でコンパイル増加または条件不成立")
	session.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)

func _step(bridge: RefCounted) -> bool:
	return bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":get_viewport().get_visible_rect().size}).ok
