## じょうぎ座の見た目。
extends EnemyVisual

func setup(render: RenderManager, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

## じょうぎ座：照射の予告は、発射元から照射の向きへ伸びる点線。予告が進むほど濃く、先端の光が強まる。
func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var p := t.pos[i]
	var r := t.r[i]
	var u := Vector2.from_angle(t.facing[i])
	var tip := p + u * r
	var col := t.color[i].lightened(0.2)
	if t.mode[i] == EnemyTable.Mode.WINDUP:
		var k := t.charge[i]
		var length := float(t.def[i].params.beam_len)
		var dash := 36.0
		var s := 0.0
		while s < length:
			c.draw_line(tip + u * s, tip + u * minf(s + dash * 0.55, length), Color(col, 0.25 + 0.6 * k), maxf(_px(2.0), 3.0 + 4.0 * k))
			s += dash
		c.draw_circle(tip, r * (0.2 + 0.4 * k), Color(1, 1, 1, 0.4 + 0.5 * k))
	elif t.mode[i] == EnemyTable.Mode.DASH and t.buds[i] != 0:
		c.draw_circle(tip, r * 0.18, Color(col, 0.6))
