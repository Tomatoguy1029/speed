@tool
extends EditorPlugin

const TITLE := "ボスAI"
const MENU_PROBE := "__speed_boss_flow_menu_probe__"
const SEPARATOR_ID := 0x424F5353
var panel: Control
var _tool_menu: PopupMenu

func _enter_tree() -> void:
	add_to_group("speed_boss_flow")
	panel = preload("res://tools/editor/boss_flow/editor.gd").new()
	panel.theme = EditorInterface.get_editor_theme()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.name = TITLE
	EditorInterface.get_editor_main_screen().add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_make_visible(false)
	add_tool_menu_item(MENU_PROBE, open_editor)
	_tool_menu = _find_tools_menu()
	remove_tool_menu_item(MENU_PROBE)
	if _tool_menu != null:
		_tool_menu.add_separator("", SEPARATOR_ID)
	else:
		push_warning("Boss Flow: Tools メニューを見つけられず区切りを表示できません")
	add_tool_menu_item(TITLE, open_editor)

func _find_tools_menu() -> PopupMenu:
	for node in EditorInterface.get_base_control().find_children("*", "PopupMenu", true, false):
		var menu := node as PopupMenu
		for index in menu.item_count:
			if menu.get_item_text(index) == MENU_PROBE:
				return menu
	return null

func open_editor() -> void:
	EditorInterface.set_main_screen_editor(TITLE)

func _has_main_screen() -> bool: return true
func _get_plugin_name() -> String: return TITLE
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
		EditorInterface.set_main_screen_editor(TITLE)
		get_viewport().set_input_as_handled()

func _save_external_data() -> void:
	# 終了時の遅い通知では、既に木から外れた編集画面を保存しない。
	# 入力中の値の確定は、画面自身のsave_currentが担当する。
	if is_instance_valid(panel) and panel.is_inside_tree():
		panel.save_current()
func _exit_tree() -> void:
	remove_tool_menu_item(TITLE)
	if is_instance_valid(_tool_menu):
		for index in range(_tool_menu.item_count - 1, -1, -1):
			if _tool_menu.is_item_separator(index) and _tool_menu.get_item_id(index) == SEPARATOR_ID:
				_tool_menu.remove_item(index)
				break
	_tool_menu = null
	if is_instance_valid(panel): panel.queue_free()
