## ヒュドラの技に必要な首の種類。技の値の編集契約は共通型を使う。
@tool
extends "res://scripts/data_types/boss_technique.gd"
class_name HydraTechnique
const NECKS := {
	3: [&"bite", &"vortex", &"debris"],
	5: [&"bite", &"vortex", &"debris", &"beam", &"thunder"],
	8: [&"bite", &"vortex", &"debris", &"beam", &"thunder", &"bite", &"beam", &"vortex"],
}
@export var head_kind: StringName

func _validate_property(property: Dictionary) -> void:
	if property.name in ["technique", "head_kind"]: property.usage |= PROPERTY_USAGE_READ_ONLY
