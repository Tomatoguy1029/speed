extends WeaponVisual

func setup(render: RenderManager, owner_behavior) -> void:
	super(render, owner_behavior)
	overlay_order = 20
	overlay = load("res://assets/pixel/airship_electronic_probe.png")
