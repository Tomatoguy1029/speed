extends WeaponVisual

func setup(render: RunPresentation, owner_behavior) -> void:
	super(render, owner_behavior)
	attach("res://scripts/render/afterimage.gd", "Afterimages", -1)

func tick(dt: float) -> void:
	node.step(dt, state, cfg, behavior if active else null)

var _frame_node: Node2D
func setup_frame(parent: Node2D) -> void:
	_frame_node = preload("res://scripts/render/afterimage.gd").new()
	parent.add_child(_frame_node)
func frame_tick(values: Dictionary, character_scale: float, dt: float) -> void:
	_frame_node.step_frame(dt,character_scale,values.echoes)
func dispose() -> void:
	if is_instance_valid(_frame_node): _frame_node.queue_free()
	super()
