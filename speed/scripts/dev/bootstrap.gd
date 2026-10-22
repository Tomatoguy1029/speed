## 開発用の機能を、アプリとランの入口から足す。
extends Node
const COMMANDS := preload("res://scripts/dev/run_commands.gd")
const RECORDER := preload("res://scripts/dev/play_recorder.gd")
const DEBUG_PANEL := preload("res://scripts/dev/debug_panel.gd")
const PERF_OVERLAY := preload("res://scripts/dev/perf_overlay.gd")
func _ready() -> void:
	if not OS.is_debug_build(): return
	RunManager.session_created.connect(_on_session_created)
	var recorder := RECORDER.new()
	recorder.name = "PlayRecorder"
	add_child(recorder)
func _on_session_created(session: RunSession) -> void:
	var commands := COMMANDS.new()
	commands.setup(session.sim)
	session.sim.command_extension = func(name: StringName, args: Dictionary) -> bool: return commands.handle(name, args)
	if not session.sim.options.get("lab", false): session.add_to_group("recordable_runs")
	session.started.connect(_decorate.bind(weakref(session)), CONNECT_ONE_SHOT)
func _decorate(reference: WeakRef) -> void:
	var session := reference.get_ref() as RunSession
	if session == null or session.view == null or session.sim.state.lab_mode: return
	var panel := DEBUG_PANEL.new()
	panel.name = "DebugPanel"
	panel.run = session.sim
	panel.position = Vector2(16, 110)
	panel.size = Vector2(420, 580)
	session.view.get_node("Hud").add_child(panel)
	var overlay := PERF_OVERLAY.new()
	overlay.name = "PerfOverlay"
	overlay.run = session.sim
	session.view.get_node("Hud").add_child(overlay)
