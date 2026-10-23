## 雷は照準の予告と、発動中に形を変える稲妻を描く。
extends "res://scripts/render/attacks/zone_reticle.gd"
func _color(_pr: ProjectileSystem, _i: int) -> Color:
	return PIXEL_LIGHTNING.COLOR
func _burst(c: CanvasItem, pr: ProjectileSystem, i: int, p: Vector2, len: float, f: float, col: Color) -> void:
	super(c, pr, i, p, len, f, col)
	var age := pr.hazard_t[i] - pr.hazard_delay[i]
	var shape := int(age / PIXEL_LIGHTNING.SHAPE_INTERVAL)
	PIXEL_LIGHTNING.draw(c, p - Vector2(0, len * 3.0), p, _px(2.0), i * 7919 + shape * 101,
		PIXEL_LIGHTNING.intensity(age, pr.hazard_active[i]))
