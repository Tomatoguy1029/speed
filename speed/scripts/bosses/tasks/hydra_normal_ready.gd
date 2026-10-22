@tool
extends BTCondition
@export var attack: StringName = &"bite_thrust"
func _tick(_delta: float) -> Status:
	return SUCCESS if agent.normal_ready(int(blackboard.get_var(&"head_index")),attack) else FAILURE
