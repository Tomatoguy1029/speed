## 戦闘の判定・威力から独立した表示用の上書き値。
extends Resource

@export var profiles: Dictionary = {}
var _preview_profiles: Dictionary = {}
var _preview_enabled := false
var preview_revision := 0

## ビジュアル編集の別プロセス内だけで使用する。ResourceSaver はこの値を保存しない。
func set_preview_profiles(values: Dictionary) -> void:
	preview_revision += 1
	_preview_profiles = values.duplicate(true)
	_preview_enabled = true

func clear_preview_profiles() -> void:
	preview_revision += 1
	_preview_profiles.clear()
	_preview_enabled = false

func values_for(key: String) -> Dictionary:
	return (_preview_profiles if _preview_enabled else profiles).get(key, {})

## 個々の使用元の設定を優先し、未移行の保存キーは既定値として引き継ぐ。
func resolved_values(key: String, fallback := "") -> Dictionary:
	return values_for(fallback).merged(values_for(key), true) if not fallback.is_empty() else values_for(key)

func component_values(key: String, component: String, fallback := "") -> Dictionary:
	var values := values_for(fallback).duplicate()
	var prefix := component + "/"
	for name in values_for(key):
		if String(name).begins_with(prefix): values[String(name).trim_prefix(prefix)] = values_for(key)[name]
	return values

func tinted(key: String, original: Color) -> Color:
	var tint: Color = values_for(key).get("effect_tint", Color.WHITE)
	return original * tint

func number(key: String, field: String, original: float) -> float:
	return float(values_for(key).get(field, original))

func apply_to(node: CanvasItem) -> void:
	apply_key(node, node.get_meta("visual_profile", node.scene_file_path), node.scene_file_path)

func apply_key(node: CanvasItem, key: String, fallback := "") -> void:
	var values := resolved_values(key, fallback)
	apply_values(node, values)

func apply_values(node: CanvasItem, values: Dictionary) -> void:
	for name in values:
		if name == "effect_tint":
			if not node.has_meta("visual_base_modulate"):
				node.set_meta("visual_base_modulate", node.modulate)
			node.modulate = node.get_meta("visual_base_modulate") * values[name]
		elif name in node:
			node.set(name, values[name])
