## 戦闘の判定・威力から独立した表示用の上書き値。
extends Resource

@export var profiles: Dictionary = {}

func values_for(key: String) -> Dictionary:
	return profiles.get(key, {})

func tinted(key: String, original: Color) -> Color:
	var tint: Color = values_for(key).get("effect_tint", Color.WHITE)
	return original * tint

func number(key: String, field: String, original: float) -> float:
	return float(values_for(key).get(field, original))

func apply_to(node: CanvasItem) -> void:
	var values := values_for(node.scene_file_path)
	for name in values:
		if name == "effect_tint":
			if not node.has_meta("visual_base_modulate"):
				node.set_meta("visual_base_modulate", node.modulate)
			node.modulate = node.get_meta("visual_base_modulate") * values[name]
		elif name in node:
			node.set(name, values[name])
