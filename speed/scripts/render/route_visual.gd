## 突進範囲の輪郭を点線で示し、中央の矢羽根を終点へ流す。
extends Node2D

const SHAPES = preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.RenderShapeKind
const DASH := 9.0
const GAP := 7.0
const CHEVRON_SPACING := 52.0
const FLOW_SPEED := 65.0
var _path := PackedVector2Array()
var _distances := PackedFloat32Array()
var _boundary := PackedVector2Array()
var _radius := 0.0
var _pixel := 1.0
var _color := Color("8feaff")
var _clock := 0.0

## C++の描線用3行。本体と双子・敵の経路は別のorder/ownerを持つ。
static func is_route_shape(row: Dictionary) -> bool:
	if row.owner_id != 0:
		return false
	if row.layer == 3:
		if row.kind == SHAPES.Polyline:
			return row.order == 0 and row.get("rounded", false)
		return row.kind == SHAPES.Circle and row.order == 1
	return row.layer == 12 and row.kind == SHAPES.Polyline and row.order == 0

func sync_shapes(shapes: Array, pixel: float) -> void:
	for row: Dictionary in shapes:
		if is_route_shape(row) and row.kind == SHAPES.Polyline and row.layer == 3:
			set_route(row.points, float(row.widths[0]) * 0.5, row.colors[0], pixel)
			return
	visible = false

func set_route(points: PackedVector2Array, radius: float, color: Color, pixel: float) -> void:
	visible = points.size() > 1 and radius > 0.0
	_color = color
	# 入力中のルートと実効半径が変わったときだけ輪郭を作り直す。
	if _path != points or _radius != radius or not is_equal_approx(_pixel, pixel):
		_path = points.duplicate()
		_radius = radius
		_pixel = maxf(pixel, 0.01)
		_rebuild()
	queue_redraw()

func set_clock(world_time: float) -> void:
	if _clock == world_time:
		return
	_clock = world_time
	if visible:
		queue_redraw()

func _rebuild() -> void:
	_distances.clear()
	_boundary.clear()
	if not visible:
		return
	_distances.append(0.0)
	for i in range(1, _path.size()):
		_distances.append(_distances[-1] + _path[i-1].distance_to(_path[i]))
	if _distances[-1] < 0.001:
		visible = false
		return
	# 丸い端・曲がり角の和集合を作る。交差したルートにも内側の余分な境界を描かない。
	for outline: PackedVector2Array in Geometry2D.offset_polyline(_path, _radius, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
		_add_dashes(outline)

func _add_dashes(outline: PackedVector2Array) -> void:
	if outline.size() < 2:
		return
	var perimeter := 0.0
	for i in outline.size():
		perimeter += outline[i].distance_to(outline[(i+1) % outline.size()])
	# 閉じ目だけ間隔が詰まらないよう、一周に収まる整数個の点線へ揃える。
	var count := maxi(1, roundi(perimeter / ((DASH + GAP) * _pixel)))
	var period := perimeter / count
	var on_length := period * DASH / (DASH + GAP)
	var traveled := 0.0
	for i in outline.size():
		var from := outline[i]
		var to := outline[(i+1) % outline.size()]
		var length := from.distance_to(to)
		var position := 0.0
		while position < length - 0.0001:
			var phase := fposmod(traveled + position, period)
			var on := phase < on_length
			var step := minf(length-position, (on_length if on else period)-phase)
			if step < 0.0001:
				step = minf(length-position, 0.0001)
			if on:
				_boundary.append(from.lerp(to, position/length))
				_boundary.append(from.lerp(to, (position+step)/length))
			position += step
		traveled += length

func _sample(distance: float) -> Vector2:
	var index := clampi(_distances.bsearch(distance), 1, _path.size()-1)
	var length := _distances[index] - _distances[index-1]
	var fraction := clampf((distance-_distances[index-1]) / maxf(length, 0.001), 0.0, 1.0)
	return _path[index-1].lerp(_path[index], fraction)

func _draw() -> void:
	if _distances.is_empty() or _distances[-1] < 0.001:
		return
	if not _boundary.is_empty():
		draw_multiline(_boundary, Color(_color, 0.8), 1.5*_pixel, false)
	var spacing := CHEVRON_SPACING * _pixel
	var length := _distances[-1]
	var offset := fposmod(_clock * FLOW_SPEED * _pixel, spacing)
	var arm := minf(6.0*_pixel, _radius*0.65)
	var distance := offset
	while distance < length:
		var at := _sample(distance)
		var direction := (_sample(minf(length, distance+_pixel)) - _sample(maxf(0.0, distance-_pixel))).normalized()
		var normal := direction.orthogonal()
		var tip := at + direction*arm*0.5
		var tail := at - direction*arm*0.5
		var chevron := PackedVector2Array([tail + normal*arm*0.7, tip, tail - normal*arm*0.7])
		var alpha := minf(1.0, minf(distance, length-distance)/(arm*2.0))
		var wake := _sample(maxf(0.0, distance-12.0*_pixel))
		for side in [-1.0, 1.0]:
			draw_line(wake + normal*arm*0.7*side, tail + normal*arm*0.7*side, Color(_color, alpha*0.2), _pixel, false)
		draw_polyline(chevron, Color(_color, alpha*0.12), 3.0*_pixel, false)
		draw_polyline(chevron, Color(_color, alpha*0.85), 1.5*_pixel, false)
		draw_polyline(chevron, Color(Color.WHITE, alpha*0.7), 0.65*_pixel, false)
		distance += spacing
