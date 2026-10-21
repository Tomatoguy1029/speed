## 生きている首の種類と必要数。条件ノードを並べて組み合わせる。
@tool
extends BTCondition
@export_enum("bite", "vortex", "debris", "beam", "homing") var kind := "bite"
@export_range(1, 9) var minimum_count := 1
func _tick(_delta: float) -> Status:
	var counts: Dictionary = blackboard.get_var(&"live_heads", {})
	return SUCCESS if int(counts.get(StringName(kind), 0)) >= minimum_count else FAILURE
