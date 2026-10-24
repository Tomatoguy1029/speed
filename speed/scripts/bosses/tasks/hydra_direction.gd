## Body は本体正面、Neck Base は首の根元の正面を0度とする発動方向。
@tool
extends BTCondition
@export_enum("Body", "Neck Base") var origin: int = 0
@export var ignore_when_separated := false
@export_range(-180.0, 180.0) var center_degrees := 0.0
@export_range(0.0, 180.0) var half_angle_degrees := 180.0
func allows(actor: Node, head_index := -1) -> bool:
	if ignore_when_separated and actor.separated: return true
	var at: Vector2 = actor.table.pos[actor.body]
	var facing: float = actor.table.facing[actor.body]
	if origin == 1:
		if head_index < 0 or head_index >= actor.necks.size(): return false
		at = actor._neck_base(actor.necks[head_index])
		facing += actor.necks[head_index].base_angle
	var angle := angle_difference(facing, (actor.run_state.ship_pos-at).angle())
	return absf(angle_difference(deg_to_rad(center_degrees), angle)) <= deg_to_rad(half_angle_degrees)
func _tick(_delta: float) -> Status:
	return SUCCESS if allows(agent, int(blackboard.get_var(&"head_index", -1))) else FAILURE
