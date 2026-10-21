## 距離は BossDef.params の基準に対する倍率。選んだ技の予告中・実行中は固定する。
@tool
extends BTCondition
@export var distance_parameter: StringName = &"engage"
@export_range(0.0, 10.0) var minimum_ratio := 0.0
@export_range(0.0, 10.0) var maximum_ratio := 1.3
func _tick(_delta: float) -> Status:
	if agent.busy: return SUCCESS
	var distance: float = blackboard.get_var(&"player_distance", INF)
	var basis: float = agent.def.params.get(distance_parameter, 0.0)
	return SUCCESS if distance >= basis * minimum_ratio and distance <= basis * maximum_ratio else FAILURE
