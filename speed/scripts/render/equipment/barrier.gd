extends WeaponVisual

func setup(render: RunPresentation, owner_behavior) -> void:
	super(render, owner_behavior)
	overlay_order = 10
	overlay = load("res://assets/pixel/airship_armor.png")
