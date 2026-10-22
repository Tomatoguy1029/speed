extends WeaponVisual

func setup(render: RenderManager, owner_behavior) -> void:
	super(render, owner_behavior)
	attach("res://scripts/render/light_lance.gd", "LightLance", 1)

func tick(dt: float) -> void:
	node.step(dt, state, cfg, behavior if active else null, rm.cam_zoom)

func on_event(event: Dictionary) -> void:
	if event.type == &"lance_hit":
		node.hit(event)

func finished() -> bool:
	return not active and node._ages.is_empty() and node._hits.is_empty()
