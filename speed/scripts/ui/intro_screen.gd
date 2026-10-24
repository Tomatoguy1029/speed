## 導入の画面。場面の状態を表示し、操作は既存のセッション命令へ渡す。
## 尺と差し替え用の仮素材は data/visuals/intro_presentation.tres。
extends Node

const SEQUENCE := preload("res://scripts/runtime/intro_sequence.gd")
const Beat = SEQUENCE.Beat

@export var presentation: IntroPresentation = preload("res://data/visuals/intro_presentation.tres")

var sequence := SEQUENCE.new()
var session: RunSession:
	get: return sequence.session
var run: RunSimulation:
	get: return sequence.run
var practice: RefCounted:
	get: return sequence.practice
var beat: int:
	get: return sequence.beat
var beat_time: float:
	get: return sequence.beat_time
var _paused: bool:
	get: return run != null and run.state.phase == RunState.Phase.PAUSED

var visual: Node2D
var sky: Node2D
var _hud: CanvasLayer
var _hint: Label
var _motive: Label
var _draw_button: Button
var _touch := false

func _ready() -> void:
	sequence.beat_changed.connect(_on_beat_changed)
	sequence.completed.connect(GameManager.finish_intro)
	sequence.setup(self, presentation)
	run.input.process_mode = Node.PROCESS_MODE_DISABLED
	run.frame_events.connect(_on_events)
	visual = preload("res://scripts/render/intro_visual.gd").new()
	visual.intro = sequence
	visual.z_index = 30
	session.view.get_node("World").add_child(visual)
	# 遠景は背景星の直上、機体・敵・瓦礫より奥に置く。
	sky = preload("res://scripts/render/intro_visual.gd").new()
	sky.intro = sequence
	sky.distant_sky = true
	sky.z_index = 1
	sky.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
	session.view.get_node("World").add_child(sky)
	_build_overlay()
	get_window().focus_exited.connect(_pause)

func _physics_process(delta: float) -> void:
	if run == null or _paused:
		return
	sequence.advance(delta)
	if beat == Beat.PRACTICE:
		_update_hint()
	visual.queue_redraw()
	sky.queue_redraw()

func _on_beat_changed(next: int) -> void:
	_hint.hide()
	_draw_button.visible = next == Beat.PRACTICE and _touch
	_motive.visible = next == Beat.MOTIVE
	if next == Beat.PRACTICE:
		run.input.cancel_gesture()
		run.input.process_mode = Node.PROCESS_MODE_INHERIT
		_update_hint()
	if next == Beat.RESTORE:
		run.input.process_mode = Node.PROCESS_MODE_DISABLED
		var renderer: RunPresentation = session.view.get_node("RunPresentation")
		renderer._layers.pickups.hide()

func _on_events(events: Array[Dictionary]) -> void:
	for event in events:
		if event.type == &"launch":
			AudioManager.play(&"dash", -6.0)
		if event.type == &"kill":
			AudioManager.play(&"kill", -10.0)

func _update_hint() -> void:
	_hint.visible = beat_time >= presentation.hint_delay
	_hint.text = tr("intro.touch") if _touch else tr("intro.confirm" if run.state.drawing else "intro.draw")

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_touch = true
		_draw_button.visible = beat == Beat.PRACTICE

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if _paused:
			_resume()
		else:
			_pause()

func _pause() -> void:
	if run != null:
		RunManager.command(session.id, &"pause")
		run.input.process_mode = Node.PROCESS_MODE_DISABLED
		_hud.get_node("Pause").show()
		_hud.get_node("Pause").get_child(0).get_child(0).grab_focus()

func _resume() -> void:
	_hud.get_node("Pause").hide()
	RunManager.command(session.id, &"resume")
	run.input.process_mode = Node.PROCESS_MODE_INHERIT if beat == Beat.PRACTICE else Node.PROCESS_MODE_DISABLED

func _exit_tree() -> void:
	sequence.dispose()
	# RenderPipeline が導入の間だけ設定した HDR を次のメニューへ残さない。
	get_viewport().use_hdr_2d = false

func _build_overlay() -> void:
	var overlay := preload("res://scripts/ui/intro_overlay.gd").new()
	overlay.intro = self
	_hud = overlay
	add_child(overlay)
	_hint = overlay.hint
	_motive = overlay.motive
	_draw_button = overlay.draw_button
