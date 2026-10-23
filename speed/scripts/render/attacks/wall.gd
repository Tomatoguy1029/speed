## 残る線の見た目（じょうぎ座のビームの柱を含む）。
extends AttackVisual

func draw_hazard(c: CanvasItem, pr: ProjectileSystem, i: int, view: Rect2) -> void:
	if pr.hazard_style[i] == ProjectileSystem.HazardStyle.TRAIL:
		# 付いている敵の見た目が描く（みなみのさんかく座の軌跡）
		return
	var p := pr.hazard_pos[i]
	var t := pr.hazard_t[i]
	var delay := pr.hazard_delay[i]
	var col := pr.hazard_color[i]
	if pr.hazard_style[i] == ProjectileSystem.HazardStyle.LIGHTNING:
		col = PIXEL_LIGHTNING.COLOR
	var len := pr.hazard_len[i]
	var charging := t < delay
	var k := clampf(t / maxf(delay, 0.001), 0.0, 1.0)
	var b := p + Vector2.from_angle(pr.hazard_angle[i]) * len
	if not view.grow(len).has_point(p):
		return
	var w := pr.hazard_width[i]
	if pr.hazard_style[i] == ProjectileSystem.HazardStyle.RAY and not charging:
		# じょうぎ座のビーム：発射元から伸びる、揺らめく光の柱
		var left := delay + pr.hazard_active[i] - t
		var f := clampf(left / 0.3, 0.0, 1.0) * clampf((t - delay) / 0.12, 0.0, 1.0)
		var flick := 0.85 + 0.15 * sin(t * 50.0 + float(i))
		c.draw_line(p, b, Color(col, 0.22 * f), w * 2.6 * flick)
		c.draw_line(p, b, Color(col.lightened(0.2), 0.9 * f), w)
		c.draw_line(p, b, Color(1, 1, 1, 0.9 * f), maxf(_px(2.0), w * 0.35))
		c.draw_circle(p, w * (0.9 + 0.2 * flick), Color(1, 1, 1, 0.8 * f))
		return
	if charging:
		c.draw_line(p, b, Color(col, 0.15 + 0.35 * k), maxf(_px(2.0), w * 0.25 * k))
		return
	var left := delay + pr.hazard_active[i] - t
	var f := clampf(left / 0.4, 0.0, 1.0)
	c.draw_line(p, b, Color(col, 0.35 * f), w * 1.5)
	c.draw_line(p, b, Color(col, 0.9 * f), w)
