extends WeaponVisual

func setup(render: RenderManager, owner_behavior) -> void:
	super(render, owner_behavior)
	attach("res://scripts/render/dash_range_drone.gd", "DashRangeDrone", 0)

func tick(dt: float) -> void:
	node.step(behavior if active else null, cfg, rm.cam_zoom)
