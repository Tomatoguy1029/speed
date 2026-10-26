## 1つのランの寿命の持ち主（設計書 4.3）。RunManager が作り、消えるとランも終わる。
##
## シミュレーション（RunSimulation）と、任意の表示（scenes/run/run.tscn）を持つ。
## 表示のない試行は表示を作らず、ボスの役者は見えないノードの下に置く。
class_name RunSession
extends Node

const VIEW_PATH := "res://scenes/run/run.tscn"

## RunManager が振る番号。破棄したあとの命令を見分ける
var id := 0
var sim := RunSimulation.new()
## 表示（表示のない試行では null）
var view: Node
## 固定更新を自分で進めるか。実験場は自分の時計で sim を進める
var auto_step := true
## 開発用の録画条件。途中録画でもラン初期化時の実効値を保持する。
var recording_initial: Dictionary = {}

signal started
var resources: ContentResourceScope
var _pending_options: Dictionary = {}
var _loading: CanvasLayer
## resource_wait_msは要求の投入と暗転中の経過を含む。ほかの区間と単純合算しない。
var loading_timings: Dictionary = {}
var _load_started_us := 0
var _warm_started_us := 0
var _progress: ProgressBar

## 通常の出撃は資源を別スレッドで準備し、準備が終わるまで戦闘の時計を始めない。
func start_loading(options: Dictionary) -> void:
	var stage: RuntimeStage = options.get("stage")
	if stage == null: return
	_load_started_us = Time.get_ticks_usec()
	_pending_options = options
	_loading = CanvasLayer.new()
	add_child(_loading)
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
	# 描画を持たないDummy rendererはテクスチャ生成を主スレッドで行う。
	resources = ContentManager.prepare_resources(stage.resources.paths, DisplayServer.get_name() != "headless")
	loading_timings["resource_request_ms"] = (Time.get_ticks_usec() - _load_started_us) / 1000.0

## 木に入ったあとに呼ぶ。表示を作る場合は、シミュレーションを組み立ててから表示を木に入れる。
## options.hud が false なら通常 HUD を省き、利用側が専用 UI を接続する。
func start(options: Dictionary, with_view: bool) -> void:
	options = options.duplicate()
	if not options.has("stage"):
		options.stage = ContentManager.runtime_stage(int(options.get("stage_index", 1)))
	if options.stage == null: return
	if resources == null:
		var paths := PackedStringArray()
		if with_view:
			for placement: BackgroundPlacement in options.stage.backgrounds:
				if not placement.texture_path.is_empty(): paths.append(placement.texture_path)
				if not placement.fire_preset_path.is_empty(): paths.append(placement.fire_preset_path)
			for fire_use: Dictionary in options.stage.fire_uses.values():
				var preset_path := str(fire_use.get("preset", ""))
				if not preset_path.is_empty(): paths.append(preset_path)
		resources = ContentManager.prepare_resources(paths, false)
	sim.ctx.resources = resources
	sim.options = options
	sim.view_size_source = func(): return get_viewport().get_visible_rect().size
	var before := Time.get_ticks_usec()
	if with_view:
		view = load(VIEW_PATH).instantiate()
		loading_timings["view_instantiate_ms"] = (Time.get_ticks_usec() - before) / 1000.0
		view.get_node("RunPresentation").run = sim
		if options.get("hud", true):
			view.get_node("Hud/HudRoot").run = sim
		else:
			view.get_node("Hud").free()
		sim.input = view.get_node("World/InputRouter")
		sim.actor_parent = view.get_node("World")
	else:
		var actors := Node2D.new()
		actors.name = "Actors"
		actors.visible = false
		add_child(actors)
		sim.actor_parent = actors
	before = Time.get_ticks_usec()
	sim.setup()
	loading_timings["simulation_setup_ms"] = (Time.get_ticks_usec() - before) / 1000.0
	before = Time.get_ticks_usec()
	var identity_path := "res://scripts/dev/recording_identity.gd"
	if OS.is_debug_build() and not sim.state.lab_mode and ResourceLoader.exists(identity_path):
		recording_initial = load(identity_path).capture(sim)
	loading_timings["recording_identity_ms"] = (Time.get_ticks_usec() - before) / 1000.0
	before = Time.get_ticks_usec()
	if view != null:
		add_child(view)
	loading_timings["view_ready_ms"] = (Time.get_ticks_usec() - before) / 1000.0
	before = Time.get_ticks_usec()
	started.emit()
	loading_timings["started_callbacks_ms"] = (Time.get_ticks_usec() - before) / 1000.0

func _physics_process(delta: float) -> void:
	if auto_step and sim.state != null:
		sim.physics_step(delta)

func _process(delta: float) -> void:
	if sim.state == null:
		if resources == null or _pending_options.is_empty(): return
		_progress.value = resources.progress() * 100.0
		if not resources.is_ready(): return
		if resources.failed or resources.cancelled:
			_pending_options.clear()
			sim.aborted.emit()
			return
		if _warm_started_us == 0:
			_warm_started_us = Time.get_ticks_usec()
			loading_timings["resource_wait_ms"] = (_warm_started_us - _load_started_us) / 1000.0
		if not resources.warmup_complete:
			load("res://scripts/render/run_presentation.gd").warm_resources(self, resources)
			return
		loading_timings["shader_warmup_ms"] = (Time.get_ticks_usec() - _warm_started_us) / 1000.0
		_loading.queue_free()
		_loading = null
		var options := _pending_options
		_pending_options = {}
		start(options, true)
		return
	if sim.bosses != null: sim.bosses.tick_feedback(delta)
	sim.flush_events()

## 実験場はチェックポイントのために木から外して持つので、片付けは消えるときに行う。
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# 記録の終了と役者の退出は、シミュレーションの参照が使える間に済ませる。
		if is_inside_tree():
			get_parent().remove_child(self)
		if resources != null: resources.cancel()
		_pending_options.clear()
		sim.dispose()
		if is_instance_valid(RunManager):
			RunManager.unregister(self)
