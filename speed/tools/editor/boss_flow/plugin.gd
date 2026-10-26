@tool
extends EditorPlugin

var panel: Control

func _enter_tree() -> void:
	add_to_group("speed_boss_flow")
	panel = preload("res://tools/editor/boss_flow/editor.gd").new()
	panel.theme = EditorInterface.get_editor_theme()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.name = "ボス行動"
	EditorInterface.get_editor_main_screen().add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_make_visible(false)
	add_tool_menu_item("ボス行動", func(): EditorInterface.set_main_screen_editor("ボス行動"))

func open_editor() -> void:
	EditorInterface.set_main_screen_editor("ボス行動")

func _has_main_screen() -> bool: return true
func _get_plugin_name() -> String: return "ボス行動"
func _handles(object: Object) -> bool:
	return object is Resource and object.get_script() == preload("res://scripts/data_types/boss_action_rules.gd")
func _edit(object: Object) -> void:
	if object is Resource:
		var path: String = object.resource_path
		panel.open_boss(path, path.replace("_action_rules.tres", "_flow.tres"))
func _make_visible(visible: bool) -> void:
	if is_instance_valid(panel):
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if visible and panel.get_meta("boss_layout_revision", 0) != 4: panel.rebuild_ui()
		panel.visible = visible

func _shortcut_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.is_command_or_control_pressed() and event.alt_pressed and event.keycode == KEY_B:
		EditorInterface.set_main_screen_editor("ボス行動")
		get_viewport().set_input_as_handled()

func _save_external_data() -> void:
	# 終了時の遅い通知では、既に木から外れた編集画面を保存しない。
	# 入力中の値の確定は、画面自身のsave_currentが担当する。
	if is_instance_valid(panel) and panel.is_inside_tree():
		panel.save_current()
func _exit_tree() -> void:
	remove_tool_menu_item("ボス行動")
	if is_instance_valid(panel): panel.queue_free()
