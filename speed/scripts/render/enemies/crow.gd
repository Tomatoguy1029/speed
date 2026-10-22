## からす座の見た目（足に抱えた経験値の束）。
extends EnemyVisual

func setup(render: RenderManager, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	super(c, t, i)
	if t.carry[i] > 0.0:
		_draw_crow_bundle(c, t, i)

## からす座が足に抱えた経験値の結晶の束（尾の側の足元）。運んでいる量が多いほど大きく、明るく光る。
func _draw_crow_bundle(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var p := t.pos[i]
	var r := t.r[i]
	var n := clampi(t.buds[i], 1, 12)
	var amount := clampf(sqrt(t.carry[i]) / 8.0, 0.0, 1.0)
	var u := Vector2.from_angle(t.facing[i])
	var side := Vector2(-u.y, u.x)
	var center := p - u * r * 0.62
	var s := maxf(_px(2.0), r * (0.07 + 0.05 * amount))
	var pulse := 0.5 + 0.5 * sin(state.world_time * 6.0)
	c.draw_circle(center, s * (2.2 + 1.6 * amount), Color(RenderManager.XP_COLOR.lightened(0.3), 0.1 + 0.2 * amount * (0.6 + 0.4 * pulse)))
	# 足の爪
	for k: float in [-1.0, 1.0]:
		c.draw_line(center + side * s * 1.2 * k + u * s * 2.2, center + side * s * 1.8 * k + u * s * 0.4, Color("#d8d2dc"), maxf(_px(1.0), s * 0.4))
	var col := RenderManager.XP_COLOR.lightened(0.15 + 0.4 * amount)
	var edge := RenderManager.XP_COLOR.darkened(0.55)
	for k in n:
		var ring := 0 if k == 0 else (1 if k < 7 else 2)
		var a := float(k) * 2.399963
		var q := center + (side * cos(a) - u * sin(a) * 0.8) * s * 1.4 * float(ring)
		var pts := PackedVector2Array([q - u * s * 1.3, q + side * s * 0.8, q + u * s * 1.3, q - side * s * 0.8])
		c.draw_colored_polygon(pts, col)
		pts.append(pts[0])
		c.draw_polyline(pts, edge, maxf(_px(1.0), s * 0.22))
		c.draw_line(q - u * s * 0.8, q - side * s * 0.3, Color(1, 1, 1, 0.75), maxf(_px(1.0), s * 0.22))
