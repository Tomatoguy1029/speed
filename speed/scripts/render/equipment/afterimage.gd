extends WeaponVisual

func setup(render: RunPresentation, owner_behavior) -> void:
	super(render, owner_behavior)
	attach("res://scripts/render/afterimage.gd", "Afterimages", -1)

func tick(dt: float) -> void:
	node.step(dt, state, cfg, behavior if active else null)
