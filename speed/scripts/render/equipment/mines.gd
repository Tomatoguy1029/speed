extends WeaponVisual

func setup(render: RenderManager, owner_behavior) -> void:
	super(render, owner_behavior)
	overlay_order = 30
	overlay = load("res://assets/pixel/airship_mine.png")

func draw_objects(c: CanvasItem) -> void:
	var mines = behavior
	for m in mines.mines:
		var col := Color("#ff7b54") if m.armed <= 0.0 else Color(1, 0.5, 0.3, 0.4)
		c.draw_circle(m.pos, 7.0, col)
		c.draw_arc(m.pos, 11.0, 0, TAU, 12, Color(1, 0.6, 0.4, 0.5), _px(1.5))
