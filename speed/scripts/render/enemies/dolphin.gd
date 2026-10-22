## いるか座の見た目。
extends EnemyVisual

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

## いるか座：構えている間、撃つ向きへ扇の輪郭と数層の弧が伸びていき、撃つ向きを予告する。
func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	if t.mode[i] != EnemyTable.Mode.WINDUP:
		return
	var p := t.pos[i]
	var r := t.r[i]
	var k := t.charge[i]
	var dp: Dictionary = t.def[i].params
	var arc := float(dp.wave_arc)
	var f := t.facing[i]
	var col := t.color[i].lightened(0.3)
	var reach := r * (2.0 + 4.0 * k)
	for s: float in [-1.0, 1.0]:
		c.draw_line(p, p + Vector2.from_angle(f + s * arc) * reach, Color(col, 0.25 + 0.4 * k), _px(2.0))
	for n in 3:
		var fr := fmod(k * 2.0 + n / 3.0, 1.0)
		c.draw_arc(p, r * (1.2 + 3.5 * fr), f - arc, f + arc, 24, Color(col, (1.0 - fr) * (0.3 + 0.5 * k)), _px(3.0))
	c.draw_circle(p + Vector2.from_angle(f) * r, r * (0.2 + 0.25 * k), Color(1, 1, 1, 0.5 + 0.4 * k))
