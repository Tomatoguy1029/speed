@tool
extends BTAction
@export var attack: StringName = &"bite_thrust"
var started := false
func _enter() -> void:
	started = false
func _tick(_delta: float) -> Status:
	var index := int(blackboard.get_var(&"head_index"))
	if not started:
		started = agent.start_normal(index,attack)
		return RUNNING if started else FAILURE
	return RUNNING if agent.necks[index].mode == attack else SUCCESS
func _exit() -> void:
	pass
