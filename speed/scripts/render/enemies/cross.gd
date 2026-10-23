## みなみじゅうじ座の見た目。
extends EnemyVisual

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

## みなみじゅうじ座：構えている間、縦と横に十字の予告線が伸び、中心の光が強まる。
func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	if t.mode[i] != EnemyTable.Mode.WINDUP:
		return
	var p := t.pos[i]
	var k := t.charge[i]
	var col := t.color[i].lightened(0.2)
	var length := float(t.def[i].params.beam_len) * (0.25 + 0.75 * k)
	for q in 4:
		var u := Vector2.from_angle(q * PI / 2.0)
		var s := 0.0
		while s < length:
			c.draw_line(p + u * s, p + u * minf(s + 20.0, length), Color(col, 0.2 + 0.5 * k), maxf(_px(1.5), 2.0 + 3.0 * k))
			s += 36.0
	c.draw_circle(p, t.r[i] * (0.4 + 0.5 * k), Color(1, 1, 0.9, 0.35 + 0.5 * k))
