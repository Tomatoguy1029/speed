## 発動時の距離条件。実際の攻撃範囲は技の Settings が持つ。
@tool
extends BTCondition
@export_enum("Body", "Head", "Neck Base") var origin: int = 0
@export_range(0.0, 100000.0, 1.0, "or_greater") var minimum_distance := 0.0
@export_range(0.0, 100000.0, 1.0, "or_greater") var maximum_distance := 100000.0
func allows(actor: Node, head_index := -1) -> bool:
	var at: Vector2 = actor.table.pos[actor.body]
	if origin != 0:
		if head_index < 0 or head_index >= actor.necks.size(): return false
		at = actor._head_pos(actor.necks[head_index]) if origin == 1 else actor._neck_base(actor.necks[head_index])
	var distance: float = actor.run_state.ship_pos.distance_to(at)
	return distance >= minimum_distance and distance <= maximum_distance
func _tick(_delta: float) -> Status:
	return SUCCESS if allows(agent, int(blackboard.get_var(&"head_index", -1))) else FAILURE
