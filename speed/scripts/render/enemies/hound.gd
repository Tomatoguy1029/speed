## 猟犬の仮表示。共通の矢じりに耳の図形を添える。正式アートは別途差し替える。
extends EnemyVisual

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	super(c, t, i)
	var u := Vector2.from_angle(t.facing[i])
	var side := u.orthogonal()
	var r := t.r[i]
	for sign: float in [-1.0, 1.0]:
		c.draw_colored_polygon(PackedVector2Array([
			t.pos[i] + u * r * 0.1 + side * r * 0.35 * sign,
			t.pos[i] - u * r * 0.45 + side * r * 0.85 * sign,
			t.pos[i] - u * r * 0.65 + side * r * 0.25 * sign,
		]), t.color[i].lightened(0.25))
