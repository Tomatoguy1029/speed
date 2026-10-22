## レチクル座の見た目。
extends EnemyVisual

func setup(render: RenderManager, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

## レチクル座：狙っている岩の周りに照準の四隅が縮みながら回り込み、本体から岩へ細い照準線が伸びる。
func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var col := t.color[i].lightened(0.2)
	var p := t.pos[i]
	var r := t.r[i]
	var lens := p + Vector2.from_angle(t.facing[i]) * r
	c.draw_circle(lens, maxf(_px(1.5), r * 0.12), Color(col, 0.7))
	if t.mode[i] != EnemyTable.Mode.WINDUP:
		return
	var rock := t.target[i]
	if not run.enemies.is_same(rock, t.target_id[i]):
		return
	var k := t.charge[i]
	var at := t.pos[rock]
	var size := t.r[rock] * (1.6 - 0.5 * k)
	var spin := PI / 4.0 * (1.0 - k)
	for q in 4:
		var a := spin + q * PI / 2.0
		var corner := at + Vector2.from_angle(a) * size * 1.41
		var u := Vector2.from_angle(a + PI * 0.75)
		var v := Vector2.from_angle(a - PI * 0.75)
		c.draw_line(corner, corner + u * size * 0.5, Color(col, 0.5 + 0.5 * k), maxf(_px(2.0), 3.0))
		c.draw_line(corner, corner + v * size * 0.5, Color(col, 0.5 + 0.5 * k), maxf(_px(2.0), 3.0))
	c.draw_line(at - Vector2(size * 0.3, 0), at + Vector2(size * 0.3, 0), Color(col, 0.6 * k), _px(1.5))
	c.draw_line(at - Vector2(0, size * 0.3), at + Vector2(0, size * 0.3), Color(col, 0.6 * k), _px(1.5))
	var gap := at - lens
	var steps := int(gap.length() / 18.0)
	for n in range(0, steps, 2):
		c.draw_line(lens + gap * (float(n) / steps), lens + gap * (float(n + 1) / steps), Color(col, 0.25 + 0.5 * k), _px(1.5))
