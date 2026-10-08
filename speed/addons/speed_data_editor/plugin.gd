## データ編集ツール（設計書 8.4）。メニューバーの「プロジェクト → ツール → データ編集」で、別のウィンドウに開く。
@tool
extends EditorPlugin

const EditorPanel := preload("res://addons/speed_data_editor/data_editor_panel.gd")
const MENU_NAME := "データ編集"

var _window: Window
var _panel: Control

func _enter_tree() -> void:
	add_tool_menu_item(MENU_NAME, _open)

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_NAME)
	if _window != null:
		_window.queue_free()
		_window = null

func _open() -> void:
	if _window == null:
		_window = Window.new()
		_window.title = MENU_NAME
		_window.min_size = Vector2i(900, 600)
		_window.close_requested.connect(_window.hide)
		var bg := ColorRect.new()
		bg.color = EditorInterface.get_editor_settings().get_setting("interface/theme/base_color")
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		_window.add_child(bg)
		_panel = EditorPanel.new()
		_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		_panel.theme = EditorInterface.get_editor_theme()
		_window.add_child(_panel)
		EditorInterface.get_base_control().add_child(_window)
	_panel.reload()
	if _window.visible:
		_window.grab_focus()
	else:
		_window.popup_centered_ratio(0.8)
