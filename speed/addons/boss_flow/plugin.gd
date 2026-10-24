@tool
extends EditorPlugin

var panel: Control
var _hidden_limbo_tabs: Array[Control] = []

func _enter_tree() -> void:
	panel = preload("res://addons/boss_flow/editor.gd").new()
	panel.theme = EditorInterface.get_editor_theme()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.name = "ボス行動"
	EditorInterface.get_editor_main_screen().add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_make_visible(false)
	add_tool_menu_item("ボス行動", func(): EditorInterface.set_main_screen_editor("ボス行動"))
	main_screen_changed.connect(_screen_changed)
	_hide_limbo_tab.call_deferred()

func _screen_changed(_screen_name: String) -> void:
	_hide_limbo_tab.call_deferred()

func _hide_limbo_tab() -> void:
	# Limboの実行クラスは他ボスも参照するため、編集画面の入口だけ隠す。
	for node in EditorInterface.get_base_control().find_children("*", "Button", true, false):
		if node.text == "LimboAI":
			if node.visible and not _hidden_limbo_tabs.has(node): _hidden_limbo_tabs.append(node)
			node.hide()

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
		if visible and panel.get_meta("boss_layout_revision", 0) != 3: panel.rebuild_ui()
		panel.visible = visible

func _shortcut_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.is_command_or_control_pressed() and event.alt_pressed and event.keycode == KEY_B:
		EditorInterface.set_main_screen_editor("ボス行動")
		get_viewport().set_input_as_handled()

func _save_external_data() -> void:
	if is_instance_valid(panel):
		var focus := get_viewport().gui_get_focus_owner()
		if focus != null and panel.is_ancestor_of(focus): focus.release_focus()
		panel.save_current()
func _exit_tree() -> void:
	remove_tool_menu_item("ボス行動")
	if main_screen_changed.is_connected(_screen_changed): main_screen_changed.disconnect(_screen_changed)
	for tab in _hidden_limbo_tabs:
		if is_instance_valid(tab): tab.show()
	if is_instance_valid(panel): panel.queue_free()
