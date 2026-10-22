## やまねこ座の見た目。
extends EnemyVisual

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

## やまねこ座：構えると、次に斬撃を伸ばす側の前足に、爪痕の光が強まる。
func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var k := t.charge[i]
	if k <= 0.0:
		return
	var r := t.r[i]
	var f := t.facing[i]
	var u := Vector2.from_angle(f)
	var side: float = behavior.lynx_side(i)
	var paw: Vector2 = t.pos[i] + u * r * 0.55 + Vector2(-u.y, u.x) * side * r * 0.6
	c.draw_circle(paw, r * (0.25 + 0.35 * k), Color(1.0, 0.55, 0.2, 0.25 * k))
	rm._attack_visual("slash").draw_claws(c, paw, f, r * (0.5 + 0.5 * k), side, 0.3 + 0.7 * k)
