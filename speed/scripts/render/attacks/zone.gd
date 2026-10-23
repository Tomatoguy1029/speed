## 範囲攻撃の共通表示。予告と発動の装飾を種類ごとに差し替える。
extends AttackVisual
func _color(pr: ProjectileSystem, i: int) -> Color:
	return pr.hazard_color[i]
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
	if fmod(t, 0.16) < 0.08: c.draw_circle(p, _px(6.0), Color(col, 0.9))
func _burst(c: CanvasItem, _pr: ProjectileSystem, _i: int, p: Vector2, len: float, f: float, col: Color) -> void:
	c.draw_circle(p, len, Color(col, 0.45 * f))
	c.draw_arc(p, len, 0.0, TAU, 40, Color(1, 1, 1, 0.8 * f), _px(3.0))
