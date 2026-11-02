## 範囲攻撃の共通表示。予告と発動の装飾を種類ごとに差し替える。
extends AttackVisual
func _color(pr: ProjectileSystem, i: int) -> Color:
	return pr.hazard_color[i] * effect_tint
func draw_hazard(c: CanvasItem, pr: ProjectileSystem, i: int, view: Rect2) -> void:
	var p := pr.hazard_pos[i]
	var t := pr.hazard_t[i]
	var delay := pr.hazard_delay[i]
	var col := _color(pr, i)
	var len := pr.hazard_len[i]
	if not view.grow(len).has_point(p): return
	if t < delay:
		_charge(c, p, len, t, clampf(t / maxf(delay, 0.001), 0.0, 1.0), col)
		return
	var f := 1.0 - clampf((t - delay) / maxf(pr.hazard_active[i], 0.001), 0.0, 1.0)
	_burst(c, pr, i, p, len, f, col)
func _charge(c: CanvasItem, p: Vector2, _len: float, t: float, _k: float, col: Color) -> void:
	if fmod(t, 0.16) < 0.08: c.draw_circle(p, _px(6.0), Color(col, 0.9 * effect_tint.a))
func _burst(c: CanvasItem, _pr: ProjectileSystem, _i: int, p: Vector2, len: float, f: float, col: Color) -> void:
	draw_burst(c,p,len,f,col,_px(1.0),effect_tint)

static func draw_burst(c: CanvasItem, p: Vector2, radius: float, fade: float, color: Color, pixel: float, tint := Color.WHITE) -> void:
	c.draw_circle(p,radius,Color(color,0.45*fade*tint.a))
	c.draw_arc(p,radius,0.0,TAU,40,Color(1,1,1,0.8*fade)*tint,3.0*pixel)

static func frame_group(circles: Array, pixel: float) -> DrawLayer:
	var node := DrawLayer.new()
	var tint: Color = EFFECT_SETTINGS.values_for("res://scenes/attacks/zone.tscn").get("effect_tint",Color.WHITE)
	node.draw_fn = func(canvas: CanvasItem):
		for circle: Dictionary in circles:
			draw_burst(canvas,circle.position,circle.radius,circle.color.a,Color(circle.color,1.0)*tint,pixel,tint)
	return node
