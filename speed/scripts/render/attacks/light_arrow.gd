## 共通の輪郭を読み、通常色とコズミック色を描き分ける。時刻は世界秒を使う。
extends AttackVisual
const TEXTURE := preload("res://assets/fx/light_arrow.svg")

func draw_shot(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> bool:
	draw_arrow(c, pos, pr.hostile_vel[i].angle(), pr.hostile_r[i], false, state.world_time, 1.0, effect_tint)
	return true

static func draw_arrow(c: CanvasItem, pos: Vector2, angle: float, radius: float,
		cosmic: bool, world_time: float, opacity := 1.0, effect_color := Color.WHITE) -> void:
	var scale := radius / 12.0
	var tint := Color("ffe4a1")
	if cosmic:
		tint = Color("9d70ff").lerp(Color("73dcff"), 0.5 + sin(world_time * 3.0) * 0.5)
	tint.a = opacity
	c.draw_set_transform(pos, angle, Vector2.ONE * scale)
	c.draw_texture_rect(TEXTURE, Rect2(-52, -12, 64, 24), false, tint * effect_color)
	c.draw_line(Vector2(-32, 0), Vector2(4, 0), Color(0.94, 0.97, 1.0, opacity) * effect_color, 1.5)
	if cosmic:
		# 光の尾に固定した星。画像の形はimportで準備し、実行時は色と明滅だけを変える。
		for n in 3:
			var p := Vector2(-12.0 - n * 11.0, -3.0 if n % 2 == 0 else 3.0)
			var a := (0.55 + sin(world_time * 6.0 + n * 2.0) * 0.35) * opacity
			c.draw_rect(Rect2(p - Vector2.ONE, Vector2.ONE * 2.0), Color(0.87, 0.94, 1.0, a) * effect_color)
	c.draw_set_transform(Vector2.ZERO)
