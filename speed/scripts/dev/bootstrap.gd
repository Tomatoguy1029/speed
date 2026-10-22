## 開発用の機能を、アプリとランの入口から足す。
extends Node
const COMMANDS := preload("res://scripts/dev/run_commands.gd")
const RECORDER := preload("res://scripts/dev/play_recorder.gd")
const DEBUG_PANEL := preload("res://scripts/dev/debug_panel.gd")
const PERF_OVERLAY := preload("res://scripts/dev/perf_overlay.gd")
func _ready() -> void:
	if not OS.is_debug_build(): return
	GameManager.extension_screens[GameManager.Screen.ENEMY_LAB] = "res://gyms/enemy_lab/enemy_lab.tscn"
	GameManager.screen_ready.connect(_on_screen_ready)
	GameManager.boot_request = _consume_launch_request
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

func _on_screen_ready(view: Control) -> void:
	var path: String = view.get_script().resource_path
	if path not in ["res://scripts/ui/title_screen.gd", "res://scripts/ui/main_menu_screen.gd"]: return
	var button := Button.new()
	button.name = "EnemyLabButton"
	button.text = tr("menu.enemy_lab")
	button.pressed.connect(view._go.bind(GameManager.Screen.ENEMY_LAB))
	if path.ends_with("/title_screen.gd"):
		view.menu_accessory = button
		button.add_theme_font_size_override("font_size", 18)
		view.add_child(button)
		button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		button.offset_left = -330.0
		button.offset_right = -24.0
		button.offset_top = 24.0
		button.offset_bottom = 68.0
	else:
		button.custom_minimum_size = Vector2(320, 52)
		view.get_node("%Content").add_child(button)

func _consume_launch_request() -> bool:
	if not OS.has_feature("editor"): return false
	var stage := StageLaunchRequest.consume()
	if stage <= 0: return false
	print("[Main] ステージ %d を直接起動" % stage)
	GameManager.reset_to_main_menu()
	GameManager.run_start_time = StageLaunchRequest.start_time
	GameManager.run_start_source = StageLaunchRequest.source
	GameManager.start_run(stage)
	return true
