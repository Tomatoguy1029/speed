## ビームの敵の見た目。
extends EnemyVisual

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

## ビームの敵：構えると、周りの光の粒が砲口へ吸い込まれて集まり、撃つ瞬間に砲口が白く光る。
func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	draw_warning(c,t.pos[i],t.r[i],t.facing[i],t.mode[i],t.charge[i],t.color[i],_px(1.0))

static func draw_warning(c: CanvasItem, p: Vector2, r: float, angle: float, mode: int, k: float, color: Color, pixel: float) -> void:
	var muzzle := p + Vector2.from_angle(angle) * r * 0.9
	var col := color.lightened(0.35)
	if mode != EnemyTable.Mode.WINDUP:
		c.draw_circle(muzzle, maxf(pixel*1.5, r * 0.1), Color(col, 0.6))
		return
	if k < 1.0:
		for n in 8:
			var f := fmod(k * 2.5 + n / 8.0, 1.0)
			var q := muzzle + Vector2.from_angle(n * TAU / 8.0 + k * 3.0) * r * (1.8 - 1.6 * f)
			c.draw_circle(q, maxf(pixel*1.5, r * 0.08), Color(col, f))
		c.draw_circle(muzzle, pixel*2.0 + r * 0.45 * k, Color(col, 0.25 + 0.5 * k))
		c.draw_circle(muzzle, pixel*1.5 + r * 0.2 * k, Color(1, 1, 1, 0.5 + 0.5 * k))
	else:
		c.draw_circle(muzzle, r * 0.7, Color(1, 1, 1, 0.55))
		c.draw_circle(muzzle, r * 0.45, Color(col, 0.9))

static func draw_frame(c: CanvasItem, values: PackedFloat32Array, pixel: float) -> void:
	for i in range(0,values.size(),10):
		draw_warning(c,Vector2(values[i],values[i+1]),values[i+2],values[i+3],int(values[i+4]),values[i+5],Color(values[i+6],values[i+7],values[i+8],values[i+9]),pixel)
