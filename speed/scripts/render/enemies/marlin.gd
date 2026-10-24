## 停止予告の間、吻先へ十字のきらめきを重ねる。
extends EnemyVisual

func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	if t.mode[i] != EnemyTable.Mode.WINDUP: return
	super(c, t, i)
	var point := t.pos[i] + Vector2.from_angle(t.facing[i]) * t.r[i]
	var size := t.r[i] * (0.3 + 0.7 * t.charge[i])
	var color := Color(0.85, 0.95, 1.0, 0.5 + 0.5 * t.charge[i])
	c.draw_line(point - Vector2(size, 0), point + Vector2(size, 0), color, _px(2.0))
	c.draw_line(point - Vector2(0, size), point + Vector2(0, size), color, _px(2.0))
