## ケフェウス座の兵の見た目（王を失って崩れていく兵）。
extends EnemyVisual

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	super(c, t, i)
	if t.mode[i] == EnemyTable.Mode.RECOVER:
		var flick := 0.5 + 0.5 * sin(state.world_time * 30.0 + float(t.id[i]))
		c.draw_arc(t.pos[i], t.r[i] * 1.3, 0, TAU, 20, Color(1.0, 0.3, 0.3, 0.4 + 0.4 * flick), _px(2.0))
