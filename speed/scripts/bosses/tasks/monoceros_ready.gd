@tool
extends BTCondition
@export var attack: StringName = &"charge"
@export var min_phase := 1
@export var min_range := 0.0
@export var max_range := 100000.0
@export var rear_only := false
func _generate_name() -> String:
	return "%s / phase %d / %.0f–%.0f" % [attack, min_phase, min_range, max_range]
func _tick(_delta: float) -> Status:
	return SUCCESS if agent.can_select(attack, min_phase, min_range, max_range, rear_only) else FAILURE
