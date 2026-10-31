## 広がる輪・扇の見た目（いるか座の数層の弧を含む）。
extends AttackVisual

const LASER = preload("res://scripts/render/pulser_laser.gd")
var _rings: Array[LASER] = []
var _count := 0

## 前の描画で使った分だけ隠す。死亡・寿命終了・行の再利用でも古い輪を残さない。
func update(_dt: float) -> void:
	for n in _count:
		_rings[n].visible = false
	_count = 0

func draw_hazard(c: CanvasItem, pr: ProjectileSystem, i: int, view: Rect2) -> void:
	if pr.hazard_style[i] == ProjectileSystem.HazardStyle.PULSER:
		_draw_pulser(c, pr, i, view)
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
	if charging:
		c.draw_circle(p, _px(4.0) + 8.0 * k, Color(col, 0.2 + 0.5 * k))
		return
	var rad := pr.wave_radius(i)
	if rad <= 0.0 or not view.grow(rad).has_point(p):
		return
	var w := pr.hazard_width[i]
	var arc := pr.hazard_arc[i]
	var center := pr.hazard_angle[i]
	var gap_w := pr.hazard_gap_w[i]
	var fade := 1.0 - 0.5 * clampf(rad / maxf(len, 1.0), 0.0, 1.0)
	if pr.hazard_style[i] == ProjectileSystem.HazardStyle.RIPPLE:
		# いるか座の波動：先頭の1枚（当たる）と、その後ろの薄い数枚（見た目だけ）
		rm._draw_round_arc(c, p, rad, center - arc, center + arc, 48, Color(col, 0.3 * fade), w * 2.0)
		rm._draw_round_arc(c, p, rad, center - arc, center + arc, 48, Color(col.lightened(0.3), 0.95 * fade), w)
		for n in range(1, 4):
			var back := rad - float(n) * w * 1.6
			if back > 0.0:
				rm._draw_round_arc(c, p, back, center - arc, center + arc, 40, Color(col, 0.28 * fade / float(n)), w * 0.45)
		return
	if gap_w > 0.0:
		# 切れ目の反対側から一周、切れ目を空けて描く
		var g := pr.hazard_gap[i]
		c.draw_arc(p, rad, g + gap_w, g + TAU - gap_w, 48, Color(col, 0.85 * fade), w)
	else:
		c.draw_arc(p, rad, center - arc, center + arc, 48, Color(col, 0.85 * fade), w)

func _draw_pulser(c: CanvasItem, pr: ProjectileSystem, i: int, view: Rect2) -> void:
	if pr.hazard_t[i] < pr.hazard_delay[i]:
		return
	var radius: float = pr.wave_radius(i)
	var width: float = pr.hazard_width[i]
	if not view.grow(radius + width * 2.4).has_point(pr.hazard_pos[i]):
		return
	if _count == _rings.size():
		var ring: LASER = LASER.new()
		ring.setup(c)
		_rings.append(ring)
	_rings[_count].show_ring(pr.hazard_pos[i], radius, width, -1.0)
	_count += 1
