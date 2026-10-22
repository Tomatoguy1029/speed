@tool
extends BTAction
func _tick(delta: float) -> Status:
	agent.position_head(int(blackboard.get_var(&"head_index")),delta)
	return SUCCESS
