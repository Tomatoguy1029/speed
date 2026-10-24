## ビームの見た目。予告の間は砲口に光が集まり、照射の間は光の線を描く。広がるビーム（水流）は水流の見た目が描く。
extends AttackVisual

func draw_hazard(c: CanvasItem, pr: ProjectileSystem, i: int, view: Rect2) -> void:
	var p := pr.hazard_pos[i]
	var t := pr.hazard_t[i]
	var delay := pr.hazard_delay[i]
	var col := _color(pr, i)
	var len := pr.hazard_len[i]
	var charging := t < delay
	var k := clampf(t / maxf(delay, 0.001), 0.0, 1.0)
	if charging:
		# 砲口に光が集まっていく
		c.draw_circle(p, _px(4.0) + 10.0 * k, Color(col, 0.25 + 0.5 * k))
		return
	var b := p + Vector2.from_angle(pr.hazard_angle[i]) * len
	if not view.grow(len).has_point(p):
		return
	var w := pr.hazard_width[i]
	var fade := 1.0 - clampf((t - delay) / maxf(pr.hazard_active[i], 0.001), 0.0, 1.0) * 0.6
	if pr.hazard_style[i] == ProjectileSystem.HazardStyle.TELESCOPE:
		var remaining := delay + pr.hazard_active[i] - t
		fade *= smoothstep(0.0, minf(0.08, pr.hazard_active[i]), remaining)
		rm._draw_round_beam(c, p, b, Color(col, 0.35 * fade), w * 1.6)
		rm._draw_round_beam(c, p, b, Color(col, 0.9 * fade), w)
		rm._draw_round_beam(c, p, b, Color(1, 1, 1, 0.85 * fade), maxf(_px(2.0), w * 0.3))
		return
	c.draw_line(p, b, Color(col, 0.35 * fade), w * 1.6)
	c.draw_line(p, b, Color(col, 0.9 * fade), w)
	c.draw_line(p, b, Color(1, 1, 1, 0.85 * fade), maxf(_px(2.0), w * 0.3))

func _color(pr: ProjectileSystem, i: int) -> Color:
	return pr.hazard_color[i]
