## 戦闘の判定・威力から独立した表示用の上書き値。
extends Resource

@export var profiles: Dictionary = {}
var _preview_profiles: Dictionary = {}
var _preview_enabled := false

## ビジュアル編集の別プロセス内だけで使用する。ResourceSaver はこの値を保存しない。
func set_preview_profiles(values: Dictionary) -> void:
	_preview_profiles = values.duplicate(true)
	_preview_enabled = true

func clear_preview_profiles() -> void:
	_preview_profiles.clear()
	_preview_enabled = false

func values_for(key: String) -> Dictionary:
	return (_preview_profiles if _preview_enabled else profiles).get(key, {})

func tinted(key: String, original: Color) -> Color:
	var tint: Color = values_for(key).get("effect_tint", Color.WHITE)
	return original * tint

func number(key: String, field: String, original: float) -> float:
	return float(values_for(key).get(field, original))

func apply_to(node: CanvasItem) -> void:
	apply_key(node, node.scene_file_path)

func apply_key(node: CanvasItem, key: String) -> void:
	var values := values_for(key)
	for name in values:
		if name == "effect_tint":
			if not node.has_meta("visual_base_modulate"):
				node.set_meta("visual_base_modulate", node.modulate)
			node.modulate = node.get_meta("visual_base_modulate") * values[name]
		elif name in node:
			node.set(name, values[name])
