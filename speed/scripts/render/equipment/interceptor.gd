extends WeaponVisual
const INTERCEPTOR_VISUAL := preload("res://scripts/render/interceptor_visual.gd")

func draw_objects(c: CanvasItem) -> void:
	var interceptors = behavior
	for d in interceptors.drones:
		INTERCEPTOR_VISUAL.drone(c, d.pos, d.angle, cfg.character_scale, d.flash, visual_color(Color.WHITE))
