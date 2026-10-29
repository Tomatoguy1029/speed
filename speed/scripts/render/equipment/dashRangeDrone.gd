extends WeaponVisual

func setup(render: RunPresentation, owner_behavior) -> void:
	super(render, owner_behavior)
	attach("res://scripts/render/dash_range_drone.gd", "DashRangeDrone", 0)
	node.modulate = Color.WHITE

func tick(dt: float) -> void:
	node.step(behavior if active else null, cfg, rm.cam_zoom)
