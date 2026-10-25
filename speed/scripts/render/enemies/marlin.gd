## 停止→キラン→直進。停止時に固定した進路を、画面外からの進入も含めて示す。
extends EnemyVisual

## 本体の可視判定とは独立して描く。装甲付きの外観でも予告を省略しない。
func draw_marks(_c: CanvasItem, _t: EnemyTable, _i: int) -> void:
	pass

func draw_layer(c: CanvasItem, _view: Rect2) -> void:
	if state.cinematic_hide_enemies: return
	var t := run.enemies.table
	var view := rm.view_rect().grow(-_px(48.0))
	for i in behavior.rows():
		if t.dead[i] != 0 or t.mode[i] != EnemyTable.Mode.WINDUP or t.held[i] != 0 or t.stone[i] > 0.0:
			continue
		var dir := Vector2.from_angle(t.facing[i])
		var from := t.pos[i] + dir * t.r[i]
		var p: Dictionary = t.def[i].params
		var to := t.pos[i] + dir * float(p.dash_speed) * float(p.dash_time)
		var path := clip_warning(from, to, view)
		if path.is_empty(): continue
		_draw_warning(c, path[0], path[1], dir, t.r[i], t.charge[i])

## 予告を実際の表示範囲へ切り詰め、最初に画面へ入る位置を返す。
static func clip_warning(from: Vector2, to: Vector2, view: Rect2) -> PackedVector2Array:
	var dir := to - from
	var enter := 0.0
	var leave := 1.0
	for axis in 2:
		if absf(dir[axis]) < 0.0001:
			if from[axis] < view.position[axis] or from[axis] > view.end[axis]:
				return PackedVector2Array()
			continue
		var a := (view.position[axis] - from[axis]) / dir[axis]
		var b := (view.end[axis] - from[axis]) / dir[axis]
		enter = maxf(enter, minf(a, b))
		leave = minf(leave, maxf(a, b))
		if enter >= leave: return PackedVector2Array()
	return PackedVector2Array([from.lerp(to, enter), from.lerp(to, leave)])

func _draw_warning(c: CanvasItem, from: Vector2, to: Vector2, dir: Vector2, radius: float, charge: float) -> void:
	var side := dir.orthogonal()
	var color := Color(0.55, 0.85, 1.0, 0.55 + 0.4 * charge)
	var band := side * radius
	c.draw_colored_polygon(PackedVector2Array([from + band, to + band, to - band, from - band]), Color(color, 0.06 + 0.12 * charge))
	c.draw_line(from + band, to + band, Color(color, 0.25 + 0.3 * charge), _px(1.0))
	c.draw_line(from - band, to - band, Color(color, 0.25 + 0.3 * charge), _px(1.0))
	c.draw_line(from, to, Color(0.02, 0.06, 0.13, 0.9), _px(6.0))
	c.draw_line(from, to, color, _px(2.0 + charge))
	var length := from.distance_to(to)
	var arrow := _px(10.0)
	var offset := minf(_px(30.0), length * 0.5)
	while offset < length:
		var point := from + dir * offset
		c.draw_polyline(PackedVector2Array([point - dir * arrow + side * arrow * 0.65, point, point - dir * arrow - side * arrow * 0.65]), color, _px(3.0))
		offset += _px(96.0)
	# 大きさを画面上のpxで保ち、発進直前にきらめきを強くする。
	var size := _px(14.0 + 10.0 * charge + 10.0 * smoothstep(0.7, 1.0, charge))
	c.draw_circle(from, size * 0.55, Color(color, 0.25 + 0.3 * charge))
	c.draw_arc(from, size, -PI / 2.0, -PI / 2.0 + TAU * maxf(charge, 0.02), 32, color, _px(3.0))
	for axis in [Vector2.RIGHT, Vector2.DOWN]:
		c.draw_line(from - axis * size, from + axis * size, Color(0.03, 0.08, 0.2, 0.95), _px(7.0))
		c.draw_line(from - axis * size, from + axis * size, Color(0.9, 0.98, 1.0, 1.0), _px(3.0))
