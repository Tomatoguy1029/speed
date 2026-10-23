extends WeaponVisual

func setup(render: RunPresentation, owner_behavior) -> void:
	super(render, owner_behavior)
	attach("res://scripts/render/light_lance.gd", "CriticalLances", 1)

func tick(dt: float) -> void:
	node.step(0.0 if state.hitstop > 0.0 else dt, cfg.character_scale, rm.cam_zoom)

func on_event(event: Dictionary) -> void:
	if active and event.type == &"critical_lance":
		node.fire(event)

func finished() -> bool:
	return not active and node.shots.is_empty()
