## ビームの敵の見た目。
extends EnemyVisual

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

## ビームの敵：構えると、周りの光の粒が砲口へ吸い込まれて集まり、撃つ瞬間に砲口が白く光る。
func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var p := t.pos[i]
	var r := t.r[i]
	var muzzle := p + Vector2.from_angle(t.facing[i]) * r * 0.9
	var col := t.color[i].lightened(0.35)
	var k := t.charge[i]
	if t.mode[i] != EnemyTable.Mode.WINDUP:
		c.draw_circle(muzzle, maxf(_px(1.5), r * 0.1), Color(col, 0.6))
		return
	if k < 1.0:
		for n in 8:
			var f := fmod(k * 2.5 + n / 8.0, 1.0)
			var q := muzzle + Vector2.from_angle(n * TAU / 8.0 + k * 3.0) * r * (1.8 - 1.6 * f)
			c.draw_circle(q, maxf(_px(1.5), r * 0.08), Color(col, f))
		c.draw_circle(muzzle, _px(2.0) + r * 0.45 * k, Color(col, 0.25 + 0.5 * k))
		c.draw_circle(muzzle, _px(1.5) + r * 0.2 * k, Color(1, 1, 1, 0.5 + 0.5 * k))
	else:
		c.draw_circle(muzzle, r * 0.7, Color(1, 1, 1, 0.55))
		c.draw_circle(muzzle, r * 0.45, Color(col, 0.9))
