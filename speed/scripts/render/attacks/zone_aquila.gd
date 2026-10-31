## 雷の予告と放電は、実際の円形当たり判定の内側に収める。
extends "res://scripts/render/attacks/zone_reticle.gd"
@export_range(0.0, 0.5, 0.01) var glow_opacity := 0.16
@export_range(0.0, 1.0, 0.05) var ring_opacity := 0.75
@export_range(0.5, 8.0, 0.25) var ring_width := 3.0
@export_range(2, 12, 1) var arm_count := 5
@export_range(0.1, 0.8, 0.05) var lightning_reach := 0.65
@export_range(0.5, 6.0, 0.25) var lightning_width := 2.0

func _apply_effect_settings() -> void:
	super()
	EFFECT_SETTINGS.apply_key(self, "enemy/aquila", scene_file_path)
	effect_tint = EFFECT_SETTINGS.resolved_values("enemy/aquila", scene_file_path).get("effect_tint", Color.WHITE)

func _burst(c: CanvasItem, pr: ProjectileSystem, i: int, p: Vector2, radius: float, fade: float, col: Color) -> void:
	c.draw_circle(p, radius, Color(col, glow_opacity * fade))
	c.draw_arc(p, radius, 0.0, TAU, 40, Color(col, ring_opacity * fade), _px(ring_width))
	var age := pr.hazard_t[i] - pr.hazard_delay[i]
	var shape := int(age / PIXEL_LIGHTNING.SHAPE_INTERVAL)
	for arm in arm_count:
		var ray := Vector2.from_angle(float(arm) * TAU / float(arm_count) + float(i % 7)) * radius * lightning_reach
		PIXEL_LIGHTNING.draw(c, p, p + ray, _px(lightning_width), i * 7919 + arm * 313 + shape * 101,
			PIXEL_LIGHTNING.intensity(age, pr.hazard_active[i]) * fade, col)
