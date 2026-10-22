## REFLECTEDの弾の表示。
extends AttackVisual

func draw_shot(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> bool:
	var u := pr.hostile_vel[i].normalized()
	c.draw_line(pos - u * pr.hostile_r[i] * 3.0, pos, Color("#ff84df"), pr.hostile_r[i] * 0.9)
	c.draw_circle(pos, pr.hostile_r[i], Color("#f45ec5"))
	c.draw_circle(pos, pr.hostile_r[i] * 0.5, Color("#fff0fc"))
	return true
