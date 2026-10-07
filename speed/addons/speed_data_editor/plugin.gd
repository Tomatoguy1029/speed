## データ編集ツール（設計書 8.4）。エディタの上部に「データ」の画面を足す。
@tool
extends EditorPlugin

const EditorPanel := preload("res://addons/speed_data_editor/data_editor_panel.gd")

var _panel: Control

func _enter_tree() -> void:
	_panel = EditorPanel.new()
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	EditorInterface.get_editor_main_screen().add_child(_panel)
	_make_visible(false)

func _exit_tree() -> void:
	if _panel != null:
		_panel.queue_free()

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if _panel != null:
		_panel.visible = visible
		if visible:
			_panel.reload()

func _get_plugin_name() -> String:
	return "データ"

func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("ResourcePreloader", "EditorIcons")
