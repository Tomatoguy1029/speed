## 予告線のあるビームの見た目（ビームの敵）。予告の間、ビームの通り道に細い予告線を引き、撃つ時が近づくほど濃くする。
## 砲口の光と照射はビームの見た目と同じ。
extends "res://scripts/render/attacks/beam.gd"

func draw_hazard(c: CanvasItem, pr: ProjectileSystem, i: int, view: Rect2) -> void:
	var p := pr.hazard_pos[i]
	var t := pr.hazard_t[i]
	var delay := pr.hazard_delay[i]
	var len := pr.hazard_len[i]
	if t < delay and view.grow(len).has_point(p):
		var k := clampf(t / maxf(delay, 0.001), 0.0, 1.0)
		var b := p + Vector2.from_angle(pr.hazard_angle[i]) * len
		c.draw_line(p, b, Color(_color(pr, i), 0.2 + 0.5 * k), _px(1.5))
	super(c, pr, i, view)
