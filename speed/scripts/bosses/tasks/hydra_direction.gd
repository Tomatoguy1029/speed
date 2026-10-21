## 本体の正面を 0 度とする自機の方向。実行中の技は位置条件で中断しない。
@tool
extends BTCondition
@export_range(-180.0, 180.0) var center_degrees := 0.0
@export_range(0.0, 180.0) var half_angle_degrees := 180.0
func _tick(_delta: float) -> Status:
	if agent.busy: return SUCCESS
	var angle: float = blackboard.get_var(&"player_angle", 0.0)
	return SUCCESS if absf(angle_difference(deg_to_rad(center_degrees), angle)) <= deg_to_rad(half_angle_degrees) else FAILURE
