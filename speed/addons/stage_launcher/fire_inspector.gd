## 2D編集入口でも実行画面と同じ炎操作を使う。Inspectorの古い個別欄は置き換える。
@tool
extends EditorInspectorPlugin

const PREVIEW_SCRIPT := "res://gyms/pixel_fire_preview.gd"
const Controls := preload("res://gyms/pixel_fire_controls.gd")
const HIDDEN := ["preset_path", "load_action", "settings", "save_action", "copy_path", "copy_action", "playing", "emission_seconds", "seed_value", "restart_action", "step_action", "status"]

func _can_handle(object: Object) -> bool:
	return object is Control and object.get_script() != null and object.get_script().resource_path == PREVIEW_SCRIPT

func _parse_begin(object: Object) -> void:
	var panel := Controls.new()
	add_custom_control(panel)
	panel.bind_preview.call_deferred(object)

func _parse_property(_object: Object, _type: Variant.Type, name: String, _hint_type: PropertyHint, _hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	return name in HIDDEN
