extends WeaponVisual
func setup(render: RunPresentation, owner_behavior) -> void:
	super(render,owner_behavior)
	attach("res://scripts/render/interceptor_visual.gd","Interceptor",0)
	node.modulate = Color.WHITE
func tick(_dt: float) -> void:
	node.step(behavior if active else null,cfg)
