## 1つのランの寿命の持ち主（設計書 4.3）。RunManager が作り、消えるとランも終わる。
##
## C++のラン接続と、任意の表示（scenes/run/run.tscn）を持つ。
class_name RunSession
extends Node

var review_meta_levels: Dictionary = {}

const VIEW_PATH := "res://scenes/run/run.tscn"

## RunManager が振る番号。破棄したあとの命令を見分ける
var id := 0
var _pending_cpp: Dictionary = {}
var _pending_cpp_bridge: RefCounted
var cpp_error: Error = OK
var cpp_index_path := ""
## 明示した開発試行だけが保持する制作元。通常ランは最初にF4を開くときに参照する。
var cpp_edit_source: Dictionary = {}
var cpp_prepare: Callable
signal loading_failed(error: Error)
## 表示（表示のない試行では null）
var view: Node
## 固定更新を自分で進めるか。実験場は自分の時計でC++を進める
var auto_step := true
var bridge: RefCounted
var cpp_choices: RefCounted
var cpp_laser_audio: Node
var cpp_input_source: Callable

signal started
signal cpp_finished(result: Dictionary)
signal closing(reason: String)
var _cpp_accepting := true
var _cpp_pending_result: Dictionary = {}
var _cpp_published_result := 0
var resources: ContentResourceScope
var _loading: CanvasLayer
var _fast_loading := false
## resource_wait_msは要求の投入と暗転中の経過を含む。ほかの区間と単純合算しない。
var loading_timings: Dictionary = {}
var _load_started_us := 0
var _warm_started_us := 0
var _start_started_us := 0
var _progress: ProgressBar

## 通常の出撃は資源を別スレッドで準備し、準備が終わるまで戦闘の時計を始めない。
func start_loading(options: Dictionary) -> void:
	start(options,true)

func _show_loading() -> void:
	if _loading!=null: return
	_loading = CanvasLayer.new()
	add_child(_loading)
	preload("res://scripts/ui/canvas_order.gd").register(_loading,1)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(center)
	var column := VBoxContainer.new()
	center.add_child(column)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.x = 240
	column.add_child(_progress)
	var back := Button.new()
	back.text = tr("common.back")
	back.pressed.connect(GameManager.abort_run)
	column.add_child(back)

## 木に入ったあとに呼ぶ。表示を作る場合は、シミュレーションを組み立ててから表示を木に入れる。
## options.hud が false なら通常 HUD を省き、利用側が専用 UI を接続する。
func start(options: Dictionary, with_view: bool) -> void:
	var error := start_cpp_content(options.get("cpp_index",""),options.get("cpp_signature",""),options.get("seed",0),with_view,options)
	if error != OK:
		if cpp_error!=error:
			cpp_error = error
			loading_failed.emit(error)
		push_error("C++ランの開始に失敗: %s" % error_string(error))

func _physics_process(delta: float) -> void:
	if bridge != null:
		if _cpp_accepting and auto_step and cpp_input_source.is_valid():
			var response: Dictionary = bridge.poll_and_step(delta,cpp_input_source,get_viewport().get_visible_rect().size)
			if not response.ok:
				auto_step = false
				push_error("C++ランの更新に失敗: %s (%s)" % [response.message,response.field])
		return
func _process(_delta: float) -> void:
	if not _pending_cpp.is_empty():
		_poll_cpp_loading()
		return
	if bridge != null:
		if not _cpp_accepting: return
		if cpp_choices!=null: cpp_choices.poll()
		flush_cpp_result()
		return
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_end_fast_loading()
		# 受付停止後、記録・資源・表示・C++・登録の順に片付ける。
		_cpp_accepting = false
		if SaveManager.settings_changed.is_connected(_on_cpp_settings_changed): SaveManager.settings_changed.disconnect(_on_cpp_settings_changed)
		auto_step = false
		if bridge!=null: bridge.begin_close()
		closing.emit(str(_cpp_pending_result.get("kind","quit")))
		if is_inside_tree():
			get_parent().remove_child(self)
		if cpp_choices!=null: cpp_choices.close()
		cpp_choices = null
		if _pending_cpp_bridge!=null: _pending_cpp_bridge.dispose()
		_pending_cpp_bridge = null
		_pending_cpp.clear()
		if cpp_laser_audio!=null: cpp_laser_audio.clear()
		if resources != null: resources.cancel()
		if bridge!=null and is_instance_valid(view):
			view.free()
			view = null
		if bridge != null: bridge.dispose()
		elif cpp_core != null: cpp_core.close()
		bridge = null
		cpp_core = null
		cpp_resources = null
		if is_instance_valid(RunManager):
			RunManager.unregister(self)

## 開発用。開始までに生成・解析を呼ばず、保存済みの同じ版を使う。
var cpp_core: RefCounted
var cpp_resources: Resource
func start_cpp_content(index_path: String, input_sha256: String, seed_value: int, with_view := false, options := {}) -> Error:
	if cpp_core != null or not _pending_cpp.is_empty(): return ERR_ALREADY_IN_USE
	cpp_index_path = index_path
	cpp_edit_source = options.get("cpp_edit_source",{}).duplicate(true)
	cpp_error = OK
	_warm_started_us = 0
	_start_started_us = Time.get_ticks_usec()
	var prepared := preload("res://scripts/runtime/run_content_loader.gd").read_bundle(index_path,input_sha256)
	loading_timings["bundle_read_ms"] = (Time.get_ticks_usec()-_start_started_us)/1000.0
	if prepared.is_empty() or not ClassDB.class_exists(&"SpeedRunCore"): return ERR_INVALID_DATA
	if not RunManager.ensure_registered(self): return ERR_OUT_OF_MEMORY
	var configure_started := Time.get_ticks_usec()
	var next_bridge = preload("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = next_bridge.configure(prepared.bytes,{"api_version":1,"run_id":id,"mode":2 if SaveManager.is_review_build() else 1 if OS.is_debug_build() or options.get("cpp_start",{}).get("lab_mode",false) else 0,
		"stage_id":prepared.index.get("stage_id",""),"profile":options.get("cpp_profile",{}),"settings":{"hitstop":bool(SaveManager.settings.get("hitstop",true))}})
	loading_timings["core_configure_ms"] = (Time.get_ticks_usec()-configure_started)/1000.0
	if not configured.ok:
		next_bridge.dispose()
		return ERR_INVALID_DATA
	# 資源の読込中は、開始していないC++をSession内だけで保持する。
	cpp_resources = prepared.resources
	_pending_cpp_bridge = next_bridge
	_pending_cpp = {"seed":seed_value,"options":options.duplicate(true),"with_view":with_view}
	if not SaveManager.settings_changed.is_connected(_on_cpp_settings_changed): SaveManager.settings_changed.connect(_on_cpp_settings_changed)
	_load_started_us = Time.get_ticks_usec()
	next_bridge.begin_resource_wait()
	if with_view:
		_show_loading()
		resources = cpp_prepare.call(cpp_resources.paths) if cpp_prepare.is_valid() else ContentManager.prepare_resources(cpp_resources.paths,DisplayServer.get_name()!="headless",cpp_resources.signatures)
	else:
		resources = ContentResourceScope.new()
		resources.warmup_complete = true
	loading_timings["resource_request_ms"] = (Time.get_ticks_usec()-_load_started_us)/1000.0
	if with_view and not (resources.is_ready() and resources.warmup_complete):
		_fast_loading = true
		ContentManager.begin_fast_loading()
	_poll_cpp_loading()
	return cpp_error

func _end_fast_loading() -> void:
	if not _fast_loading: return
	_fast_loading = false
	ContentManager.end_fast_loading()

func _on_cpp_settings_changed() -> void:
	_apply_cpp_settings.call_deferred()

func _apply_cpp_settings() -> void:
	if not _cpp_accepting or bridge==null: return
	bridge.command("set_settings",{"hitstop":bool(SaveManager.settings.get("hitstop",true))})

func _poll_cpp_loading() -> void:
	if _pending_cpp.is_empty() or not _cpp_accepting: return
	# create_runは木へ入れる前に資源を準備する。同期読込でも開始と表示は追加後に行う。
	if not is_inside_tree(): return
	if is_instance_valid(_progress): _progress.value = resources.progress()*100.0
	if resources.failed or resources.cancelled:
		_fail_cpp_loading(ERR_CANT_OPEN)
		return
	if not resources.is_ready(): return
	if _warm_started_us==0:
		var prepare_visuals: Callable = _pending_cpp.options.get("cpp_prepare_visuals",Callable())
		if _pending_cpp.with_view and prepare_visuals.is_valid(): prepare_visuals.call(resources,cpp_resources)
		_warm_started_us = Time.get_ticks_usec()
		loading_timings["resource_wait_ms"] = (_warm_started_us-_load_started_us)/1000.0
	if not resources.warmup_complete:
		load("res://scripts/render/run_presentation.gd").warm_resources(self,resources)
		return
	loading_timings["shader_warmup_ms"] = (Time.get_ticks_usec()-_warm_started_us)/1000.0
	var pending := _pending_cpp
	var next_bridge: RefCounted = _pending_cpp_bridge
	_pending_cpp = {}
	_pending_cpp_bridge = null
	var options: Dictionary = pending.options
	var with_view: bool = pending.with_view
	var start_options: Dictionary = options.get("cpp_start",{}).duplicate(true)
	start_options.endless = options.get("endless",false)
	var initialize_started := Time.get_ticks_usec()
	if not next_bridge.start(pending.seed,start_options).ok:
		next_bridge.dispose()
		_fail_cpp_loading(ERR_INVALID_DATA)
		return
	loading_timings["simulation_initialize_ms"] = (Time.get_ticks_usec()-initialize_started)/1000.0
	_end_fast_loading()
	if _loading!=null:
		_loading.queue_free()
		_loading = null
	next_bridge.end_resource_wait()
	bridge = next_bridge
	bridge.recording_origin["source"] = str(options.get("cpp_source","unknown"))
	bridge.subscribe("result",_consume_cpp_result,[],[])
	if RunManager.current_id==id or options.get("manage_result",false): cpp_finished.connect(GameManager.finish_cpp_run)
	cpp_core = bridge._core
	cpp_choices = preload("res://scripts/runtime/run_choice_resources.gd").new()
	cpp_choices.attach(bridge,cpp_resources,self)
	var scene_started := Time.get_ticks_usec()
	if with_view:
		view = (resources.resources[VIEW_PATH] as PackedScene).instantiate()
		loading_timings["scene_instantiate_ms"] = (Time.get_ticks_usec()-scene_started)/1000.0
		scene_started = Time.get_ticks_usec()
		var presentation: Node = view.get_node("RunPresentation")
		presentation.bridge = bridge
		presentation.cpp_resources = cpp_resources
		presentation.cpp_scope = resources
		if options.get("hud",true):
			var hud: Node = view.get_node("Hud/HudRoot")
			hud.input_router = view.get_node("World/InputRouter")
			hud.bridge = bridge
			hud.cpp_scope = resources
			hud.cpp_resources = cpp_resources
			hud.tutorial_requested = bool(start_options.get("tutorial",false))
		else: view.get_node("Hud").free()
		cpp_input_source = view.get_node("World/InputRouter").poll
		add_child(view)
		bridge.subscribe("audio",AudioManager.consume_cpp_frame,[],AudioManager.event_types().map(func(type: StringName) -> String: return String(type)))
		cpp_laser_audio = preload("res://scripts/ui/enemy_laser_audio.gd").new()
		add_child(cpp_laser_audio)
		bridge.subscribe("laser_audio",cpp_laser_audio.consume_cpp_frame,["laser_voices","world_scale"],["enemy_laser_charge","enemy_laser_cancel","enemy_laser_fire"])
	else:
		var router = preload("res://scripts/input/input_router.gd").new()
		add_child(router)
		cpp_input_source = router.poll
	loading_timings["presentation_setup_ms"] = (Time.get_ticks_usec()-scene_started)/1000.0
	for recorder: Node in get_tree().get_nodes_in_group("cpp_recorders"):
		recorder.attach_cpp(self)
	# 配布では開発用スクリプトを除くため、エディター実行時だけ取得する。
	if OS.has_feature("editor"):
		var identity_started := Time.get_ticks_usec()
		var identity = load("res://scripts/dev/recording_identity.gd")
		bridge.recording_origin["conditions"] = identity.capture(self)
		bridge.recording_origin.merge(bridge.recording_origin.conditions.run_state,true)
		loading_timings["recording_identity_ms"] = (Time.get_ticks_usec()-identity_started)/1000.0
	started.emit()
	_apply_cpp_settings()
	var publish_started := Time.get_ticks_usec()
	var delivered: Dictionary = bridge.collect_frame()
	loading_timings["initial_publish_ms"] = (Time.get_ticks_usec()-publish_started)/1000.0
	# 総時間とresource_request_msは内包区間を持つ。項目を足して総時間にしない。
	loading_timings["loading_total_ms"] = (Time.get_ticks_usec()-_start_started_us)/1000.0
	if OS.is_debug_build() and with_view: _print_loading_timings()
	if not delivered.ok: push_warning(delivered.message)

## 出撃の読み込みの内訳を出力へ1行で出す。資源の待ちは要求を含み、合計は全区間を含む。
func _print_loading_timings() -> void:
	var t := loading_timings
	var ms := func(key: String) -> String: return "%.0f" % float(t.get(key,0.0))
	print("出撃の読み込み: 合計 %sms（データ読込 %s / C++設定 %s / 資源の待ち %s / shader準備 %s（%d件）/ 開始 %s / 画面の用意 %s / 記録の識別 %s / 最初の配信 %s）" % [
		ms.call("loading_total_ms"), ms.call("bundle_read_ms"), ms.call("core_configure_ms"), ms.call("resource_wait_ms"),
		ms.call("shader_warmup_ms"), resources.warm_materials.size() if resources!=null else 0, ms.call("simulation_initialize_ms"),
		ms.call("presentation_setup_ms"), ms.call("recording_identity_ms"), ms.call("initial_publish_ms")])

func _fail_cpp_loading(error: Error) -> void:
	cpp_error = error
	if _pending_cpp_bridge!=null: _pending_cpp_bridge.dispose()
	_pending_cpp_bridge = null
	_pending_cpp.clear()
	if resources!=null: resources.cancel()
	cpp_resources = null
	_end_fast_loading()
	if _loading!=null:
		_loading.queue_free()
		_loading = null
	loading_failed.emit(error)

func _consume_cpp_result(frame: Dictionary) -> bool:
	_cpp_pending_result = frame.result if frame.result is Dictionary else {}
	return true

## 画面遷移の通知は、Bridgeの配信を抜けた後に一度だけ返す。
func flush_cpp_result() -> void:
	if not _cpp_accepting or _cpp_pending_result.is_empty(): return
	var result_id := int(_cpp_pending_result.result_id)
	if result_id==_cpp_published_result: return
	_cpp_published_result = result_id
	cpp_finished.emit(_cpp_pending_result.duplicate(true))

## 旧入口だけが旧シミュレーションを作る。通常入口の切替後に撤去する。
