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
		var terrain_hit = run.field.first_body_hit(t.pos[i], to, t.r[i])
		if terrain_hit != null:
			to = t.pos[i].lerp(to, float(terrain_hit.t))
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
	var color := Color(1.0, 0.17, 0.12, 0.65 + 0.35 * charge)
	var band := side * radius
	c.draw_colored_polygon(PackedVector2Array([from + band, to + band, to - band, from - band]), Color(color, 0.04 + 0.08 * charge))
	c.draw_line(from, to, Color(color, 0.18 + 0.12 * charge), _px(12.0))
	c.draw_line(from, to, color, _px(3.0 + charge))
	c.draw_line(from, to, Color(1.0, 0.75, 0.55, 0.8 + 0.2 * charge), _px(1.0))
	c.draw_circle(from, _px(3.0 + 3.0 * charge), color)
