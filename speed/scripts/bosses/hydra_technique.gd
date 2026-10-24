## BT の Settings から編集する技別の正本。実行コードと内部 Timeline は同じ値を読む。
@tool
extends Resource
class_name HydraTechnique
@export var technique: StringName
@export var head_kind: StringName
@export_storage var parameters: Dictionary = {}:
	set(value):
		parameters = value
		notify_property_list_changed()

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	for key: String in parameters:
		properties.append({"name": key, "type": TYPE_INT if parameters[key] is int else TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.001,100000,0.001,or_greater" if key in ["normal_charge", "normal_lunge", "sweep_time", "blade_interval", "sequence_gap", "sequence_charge", "swarm_flight", "swarm_gap", "pincer_time", "shatter_time", "shatter_deploy", "tornado_charge", "curve_time", "warning_time", "performance_time", "north_flight"] else "0,100000,0.01,or_greater",
			"usage": PROPERTY_USAGE_EDITOR})
	return properties

func _get(property: StringName) -> Variant:
	return parameters.get(String(property))

func _set(property: StringName, value: Variant) -> bool:
	if not parameters.has(String(property)): return false
	parameters[String(property)] = value
	emit_changed()
	return true

func _validate_property(property: Dictionary) -> void:
	if property.name in ["technique", "head_kind"]: property.usage |= PROPERTY_USAGE_READ_ONLY
