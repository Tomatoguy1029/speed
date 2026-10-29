## ケフェウス座の兵の見た目（王を失って崩れていく兵）。
extends EnemyVisual

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	super(c, t, i)
	if t.mode[i] == EnemyTable.Mode.MOVE and t.charge[i] > 0.0:
		var dir := Vector2.from_angle(t.facing[i])
		var start := t.pos[i] + dir * t.r[i]
		var glow := Color(1.0, 0.88, 0.48, 0.25 + 0.55 * t.charge[i])
		c.draw_line(start, start + dir * 90.0, glow, _px(2.0))
		c.draw_arc(t.pos[i], t.r[i] * 1.4, 0.0, TAU * t.charge[i], 24, glow, _px(2.0))
	if t.mode[i] == EnemyTable.Mode.RECOVER:
		var flick := 0.5 + 0.5 * sin(state.world_time * 30.0 + float(t.id[i]))
		c.draw_arc(t.pos[i], t.r[i] * 1.3, 0, TAU, 20, Color(1.0, 0.3, 0.3, 0.4 + 0.4 * flick), _px(2.0))
