## 遅れて弾ける範囲の見た目（照準の模様・点滅・噛みつき・雷）。
extends AttackVisual

func draw_hazard(c: CanvasItem, pr: ProjectileSystem, i: int, view: Rect2) -> void:
	var p := pr.hazard_pos[i]
	var t := pr.hazard_t[i]
	var delay := pr.hazard_delay[i]
	var col := pr.hazard_color[i]
	if pr.hazard_style[i] == ProjectileSystem.HazardStyle.LIGHTNING:
		col = PIXEL_LIGHTNING.COLOR
	var len := pr.hazard_len[i]
	var charging := t < delay
	var k := clampf(t / maxf(delay, 0.001), 0.0, 1.0)
	if not view.grow(len).has_point(p):
		return
	var style := pr.hazard_style[i]
	if charging:
		if style == ProjectileSystem.HazardStyle.RETICLE or style == ProjectileSystem.HazardStyle.LIGHTNING:
			# 照準の模様（敵が刻む印）。溜まるほど濃く、内側の輪が閉じていく
			var a := 0.25 + 0.55 * k
			c.draw_arc(p, len, 0.0, TAU, 40, Color(col, a), _px(2.0))
			c.draw_arc(p, len * (1.0 - 0.7 * k), 0.0, TAU, 32, Color(col, a), _px(1.5))
			for q in 4:
				var u := Vector2.from_angle(q * PI / 2.0 + PI / 4.0)
				c.draw_line(p + u * len * 0.55, p + u * len * 1.15, Color(col, a), _px(2.0))
		else:
			# 弾ける前の点滅
			if fmod(t, 0.16) < 0.08:
				c.draw_circle(p, _px(6.0), Color(col, 0.9))
		return
	var f := 1.0 - clampf((t - delay) / maxf(pr.hazard_active[i], 0.001), 0.0, 1.0)
	if style == ProjectileSystem.HazardStyle.BITE:
		# 噛みつき：上下のあごが閉じる
		var shut := 1.0 - f
		for side: float in [-1.0, 1.0]:
			var a0 := PI / 2.0 * side * (1.0 - shut * 0.8)
			c.draw_arc(p, len * 0.75, a0 - 0.9, a0 + 0.9, 10, Color(1, 1, 1, f), _px(3.0))
		c.draw_circle(p, len * 0.4, Color(col, 0.35 * f))
		return
	c.draw_circle(p, len, Color(col, 0.45 * f))
	c.draw_arc(p, len, 0.0, TAU, 40, Color(1, 1, 1, 0.8 * f), _px(3.0))
	if style == ProjectileSystem.HazardStyle.LIGHTNING:
		var age := t - delay
		var shape := int(age / PIXEL_LIGHTNING.SHAPE_INTERVAL)
		PIXEL_LIGHTNING.draw(c, p - Vector2(0, len * 3.0), p, _px(2.0), i * 7919 + shape * 101,
			PIXEL_LIGHTNING.intensity(age, pr.hazard_active[i]))
