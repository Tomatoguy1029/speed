## 導入の場面進行と表示。練習のラン状態・固定更新はC++Sessionが所有する。
extends RefCounted

enum Beat { FOCUS, DEVOUR, DEPART, FLIGHT, TRANSFORM, HANDOFF, PRACTICE, RESTORE, OMEN, MOTIVE }
signal beat_changed(beat: Beat)
signal completed
const DT := 1.0/120.0
var beat := Beat.FOCUS
var opening_complete := false
var beat_time := 0.0
var presentation: IntroPresentation
var session: RunSession
var bridge: RefCounted
var run: RefCounted
var practice := preload("res://scripts/runtime/intro_practice.gd").new()
var error := {}
var _bars := 1.0
var _accumulator := 0.0
var _practice_finished := false
var _disposed := false

func setup(parent: Node, visuals: IntroPresentation) -> void:
	presentation = visuals
	var config := _practice_config()
	var stage := RuntimeStage.new()
	stage.index = 1
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray([String(presentation.practice_enemy.id)])
	stage.boss_enabled = false
	var definitions := {presentation.practice_enemy.id:presentation.practice_enemy.duplicate(true)}
	var output := "res://.content/dev/intro_%d_%d" % [OS.get_process_id(),parent.get_instance_id()]
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,config,output,"導入練習".sha256_text(),definitions)
	if built!=OK:
		error = {"ok":false,"message":"導入の定義を生成できません"}
		return
	var index_path := output.path_join("stage_1.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	session = RunManager.create_session(parent,{"runtime":"cpp","cpp_index":index_path,"cpp_signature":index.input_sha256,"seed":932,"hud":false,"cpp_start":{"lab_mode":true},"cpp_edit_source":{"stage":stage,"config":config,"definitions":definitions}},true)
	session.remove_from_group("recordable_runs")
	session.auto_step = false
	while is_instance_valid(session) and session.bridge==null and session.cpp_error==OK: await parent.get_tree().process_frame
	if _disposed or not is_instance_valid(session) or session.bridge==null: return
	bridge = session.bridge
	run = preload("res://scripts/runtime/run_read_model.gd").new()
	run.cfg = config
	run.state.data.stage = stage
	run.enemies.data.definitions = definitions
	run.input = session.cpp_input_source.get_object()
	bridge.subscribe("導入の出来事",_consume_frame)
	error = bridge.command("dev_set_scenario",{"kind":"intro","params":{"lab_mode":true,"auto_spawn":false,"auto_boss":false,"invincible":true,"empty":true,"level":1}})
	if not error.ok:
		push_error("導入の開始設定に失敗: "+str(error))
		run = null
		return
	bridge.command("dev_remove_weapon",{"id":"W01"})
	bridge.command("set_settings",{"hitstop":bool(SaveManager.settings.hitstop)})
	bridge.command("dev_ship_motion",{"position":bridge.read_frame().value.ui.ship.ship_pos,"velocity":Vector2(32,0)})
	_refresh()
	practice.setup(self,presentation,run.state.ship_pos)
	_film_camera(1.15)

func _practice_config() -> GameConfig:
	var config := ContentManager.cfg.duplicate(true) as GameConfig
	config.planet_radius = 0.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	config.gravity_interval_min = 1.0e9
	config.gravity_interval_max = 1.0e9
	config.comet_interval_min = 1.0e9
	config.comet_interval_max = 1.0e9
	return config

func command(kind: String, payload: Dictionary) -> Dictionary:
	if bridge==null: return {"ok":false}
	var result: Dictionary = bridge.command(kind,payload)
	if result.ok: _refresh()
	else: error = result
	return result

func _refresh() -> bool:
	var values: Dictionary = bridge.read_lab()
	var frame: Dictionary = bridge.read_frame()
	if not values.ok or not frame.ok: return false
	run.refresh(values.value,frame.value.ui)
	return true

func advance(delta: float) -> void:
	if run==null or _disposed or run.state.phase==RunState.Phase.PAUSED: return
	beat_time += delta
	match beat:
		Beat.FOCUS:
			_film_camera(1.15)
			if beat_time>=presentation.focus_time: _next(Beat.DEVOUR)
		Beat.DEVOUR:
			_film_camera(1.15)
			if beat_time>=presentation.devour_time: _next(Beat.DEPART)
		Beat.DEPART:
			_film_camera(1.15)
			if beat_time>=presentation.depart_time:
				opening_complete = true
				_bars = 0.0
				_film_camera(1.15)
				run.input.cancel_gesture()
				_next(Beat.FLIGHT)
		Beat.FLIGHT:
			_step(delta)
			_film_camera(1.35)
			if beat_time>=presentation.flight_time:
				practice.relocate(run.state.ship_pos)
				_next(Beat.TRANSFORM)
		Beat.TRANSFORM:
			command("dev_edit",{"kind":"ship","payload":{"position":run.state.ship_pos,"velocity":Vector2.ZERO}})
			_film_camera(1.35)
			if beat_time>=presentation.transform_time:
				practice.spawn()
				_next(Beat.HANDOFF)
		Beat.HANDOFF:
			var progress := smoothstep(0.0,presentation.handoff_time,beat_time)
			_film_camera(lerpf(1.35,1.0,progress))
			practice.approach(progress)
			if beat_time>=presentation.handoff_time:
				practice.build_guide()
				_next(Beat.PRACTICE)
		Beat.PRACTICE:
			_step(delta)
			if beat==Beat.PRACTICE: practice.update()
		Beat.RESTORE:
			_film_camera(1.0)
			if beat_time>=presentation.restore_time: _next(Beat.OMEN)
		Beat.OMEN:
			_film_camera(1.0)
			if beat_time>=presentation.omen_time: _next(Beat.MOTIVE)
		Beat.MOTIVE:
			_film_camera(1.0)
			if beat_time>=presentation.motive_time: completed.emit()

func _step(delta: float) -> void:
	_accumulator += delta
	while _accumulator+1e-10>=DT:
		run.input.drawing = run.state.drawing
		var intent: Intent = run.input_source.call() if run.input_source.is_valid() else run.input.poll()
		error = bridge.step(DT,bridge.pack_intent(intent),{"logical_size":run._view_size()})
		if not error.ok: return
		_refresh()
		_accumulator = maxf(0.0,_accumulator-DT)
		if _practice_finished:
			_practice_finished = false
			run.input.cancel_gesture()
			run.input.drawing = false
			command("dev_edit",{"kind":"finish_input","payload":{}})
			_next(Beat.RESTORE)
			break

func _film_camera(multiplier: float) -> void:
	command("dev_edit",{"kind":"camera","payload":{"center":run.state.ship_pos+Vector2(80,-20),"size":run._view_size(),"zoom":run._base_zoom()*multiplier,"bars":_bars}})

func _next(next: Beat) -> void:
	beat = next
	beat_time = 0.0
	beat_changed.emit(next)

func _consume_frame(frame: Dictionary) -> bool:
	var events: Array[Dictionary] = []
	for item: Dictionary in frame.events:
		var event: Dictionary = item.payload.duplicate(true)
		event.merge({"type":item.type,"tick":item.tick},true)
		events.append(event)
		if item.type==&"kill" and practice.record_kill(event) and practice.enemies.is_empty(): _practice_finished = true
	if run!=null: run.frame_events.emit(events)
	return true

func dispose() -> void:
	_disposed = true
	if bridge!=null: bridge.unsubscribe("導入の出来事")
	practice.dispose()
	if is_instance_valid(session): session.queue_free()
	bridge = null
	run = null
	session = null
