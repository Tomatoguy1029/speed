## みなみのさんかく座の見た目（3つの星の間に張った光の膜）。
extends EnemyVisual

func setup(render: RenderManager, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	super(c, t, i)
	if t.mode[i] != EnemyTable.Mode.RECOVER and t.parts[i].size() == 6:
		# 3つの星の間に張った光の膜。揺らめく内側の縁で厚みを見せる
		var parts := t.parts[i]
		var tri := PackedVector2Array([t.pos[parts[0]], t.pos[parts[2]], t.pos[parts[4]]])
		var shimmer := 0.5 + 0.5 * sin(state.world_time * 3.0 + float(t.id[i]))
		c.draw_colored_polygon(tri, Color(t.color[i], 0.1 + 0.06 * shimmer))
		var mid := (tri[0] + tri[1] + tri[2]) / 3.0
		for s: float in [0.82, 0.6]:
			var inner := PackedVector2Array()
			for v in tri:
				inner.append(mid + (v - mid) * (s + 0.04 * shimmer))
			inner.append(inner[0])
			c.draw_polyline(inner, Color(t.color[i].lightened(0.4), 0.18 * s), _px(1.5))
