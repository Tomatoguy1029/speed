@tool
extends EditorPlugin

var panel: Control

func _enter_tree() -> void:
	panel = preload("res://addons/boss_flow/editor.gd").new()
	panel.name = "ボス行動"
	EditorInterface.get_editor_main_screen().add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_make_visible(false)

func _has_main_screen() -> bool: return true
func _get_plugin_name() -> String: return "ボス行動"
func _make_visible(visible: bool) -> void:
	if is_instance_valid(panel): panel.visible = visible
func _exit_tree() -> void:
	if is_instance_valid(panel): panel.queue_free()
