## 広がる輪・扇の見た目（いるか座の数層の弧を含む）。
extends AttackVisual
const HazardStyle := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.HazardStyleId

const LASER = preload("res://scripts/render/pulser_laser.gd")
var _rings: Array[LASER] = []
var _count := 0

## 前の描画で使った分だけ隠す。死亡・寿命終了・行の再利用でも古い輪を残さない。
static func draw_values(c: CanvasItem, values: Dictionary, view: Rect2, pixel: float) -> void:
	var p: Vector2 = values.position
	var t: float = values.time
	var delay: float = values.delay
	var col: Color = values.color
	if values.style == HazardStyle.Lightning:
		col = PIXEL_LIGHTNING.COLOR
	var len: float = values.length
	var charging := t < delay
	var k := clampf(t / maxf(delay, 0.001), 0.0, 1.0)
	if charging:
		c.draw_circle(p, 4.0 * pixel + 8.0 * k, Color(col, 0.2 + 0.5 * k))
		return
	var rad: float = values.radius
	if rad <= 0.0 or not view.grow(rad).has_point(p):
		return
	var w: float = values.width
	var arc: float = values.arc
	var center: float = values.angle
	var gap_w: float = values.gap_width
	var fade := 1.0 - 0.5 * clampf(rad / maxf(len, 1.0), 0.0, 1.0)
	if values.style == HazardStyle.Ripple:
		# いるか座の波動：先頭の1枚（当たる）と、その後ろの薄い数枚（見た目だけ）
		draw_round_arc(c, p, rad, center - arc, center + arc, 48, Color(col, 0.3 * fade), w * 2.0)
		draw_round_arc(c, p, rad, center - arc, center + arc, 48, Color(col.lightened(0.3), 0.95 * fade), w)
		for n in range(1, 4):
			var back := rad - float(n) * w * 1.6
			if back > 0.0:
				draw_round_arc(c, p, back, center - arc, center + arc, 40, Color(col, 0.28 * fade / float(n)), w * 0.45)
		return
	if gap_w > 0.0:
		# 切れ目の反対側から一周、切れ目を空けて描く
		var g: float = values.gap
		c.draw_arc(p, rad, g + gap_w, g + TAU - gap_w, 48, Color(col, 0.85 * fade), w)
	else:
		c.draw_arc(p, rad, center - arc, center + arc, 48, Color(col, 0.85 * fade), w)

static func draw_round_arc(c: CanvasItem, center: Vector2, radius: float, start: float, end: float,
		segments: int, color: Color, width: float) -> void:
	var half := minf(width * 0.5, radius * 0.9)
	if half <= 0.0:
		return
	var fillet := half * 0.5
	var points := PackedVector2Array()
	var indices := PackedInt32Array()
	for n in segments:
		var direction := Vector2.from_angle(lerpf(start, end, float(n) / (segments - 1)))
		points.append(center + direction * (radius + half))
		points.append(center + direction * (radius - half))
		if n > 0:
			var i := n * 2
			indices.append_array(PackedInt32Array([i - 2, i - 1, i, i, i - 1, i + 1]))
	for cap_index in 2:
		var direction := Vector2.from_angle(end if cap_index == 0 else start)
		var tangent := Vector2(-direction.y, direction.x) * (1.0 if cap_index == 0 else -1.0)
		var cap := center + direction * radius
		var pivot := points.size()
		points.append(cap)
		# 外角と内角を1/4円でつなぎ、端の中央には短い平面を残す。
		for corner in 2:
			var offset := (half - fillet) * (1.0 if corner == 0 else -1.0)
			for n in 7:
				var angle := (corner + float(n) / 6.0) * PI * 0.5
				points.append(cap + direction * (offset + cos(angle) * fillet) + tangent * sin(angle) * fillet)
				var i := points.size() - 1
				if i > pivot + 1:
					indices.append_array(PackedInt32Array([pivot, i - 1, i]))
	RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), indices, points, PackedColorArray([color]))


var _cpp_values: Dictionary = {}
var _cpp_pixel := 1.0
func apply_frame(row: Dictionary, pixel: float) -> void:
	var styles := [HazardStyle.Plain,HazardStyle.Ripple,HazardStyle.Lightning,HazardStyle.Pulser]
	_cpp_pixel = pixel
	_cpp_values = {"position":row.points[0],"time":row.time,"delay":row.delay,"color":row.colors[0],"style":styles[row.wave_style],
		"length":row.max_radius,"radius":row.radius,"width":row.widths[0],"arc":row.arc,"angle":row.angle,"gap_width":row.gap_arc,"gap":row.gap}
	if _cpp_values.style==HazardStyle.Pulser:
		if _rings.is_empty():
			var ring: LASER = LASER.new()
			ring.setup(self)
			_rings.append(ring)
		_rings[0].show_ring(_cpp_values.position,_cpp_values.radius,_cpp_values.width,-1.0)
	else:
		for ring: LASER in _rings: ring.hide()
	queue_redraw()

func _draw() -> void:
	if not _cpp_values.is_empty() and _cpp_values.style!=HazardStyle.Pulser:
		draw_values(self,_cpp_values,Rect2(_cpp_values.position-Vector2.ONE*20000.0,Vector2.ONE*40000.0),_cpp_pixel)
