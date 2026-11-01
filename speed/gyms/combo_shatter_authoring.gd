## 未ベイクの割れを編集時だけ組み立てる。ランの描画更新からは呼ばない。
## Radial/ring cells adapt pixelfx a841596, Patch / Hugo Duprez, MIT.
## See assets/ui/rewards/pixelfx_LICENSE.txt and pixelfx_NOTICE.txt.
extends RefCounted

const SIZE := Vector2(640, 360)
var _random := 1

func _next() -> float:
	_random = (_random * 1664525 + 1013904223) & 0xffffffff
	return float(_random) / 4294967296.0

func _range(low: float, high: float) -> float:
	return lerpf(low, high, _next())

func build(settings: ComboTransitionSettings) -> Dictionary:
	_random = settings.pattern_seed
	var center := settings.focus * SIZE
	var far_radius := maxf(center.distance_to(Vector2.ZERO), center.distance_to(SIZE))
	far_radius = maxf(far_radius, maxf(center.distance_to(Vector2(SIZE.x, 0)), center.distance_to(Vector2(0, SIZE.y))))
	far_radius *= maxf(1.2, 1.05 / (1.0 - settings.radius_jitter))
	var count := settings.ray_count
	var bands := settings.band_count
	var angles: Array[float] = []
	for i in count:
		angles.append((i + _range(-settings.angle_jitter, settings.angle_jitter)) / count * TAU)
	var rays: Array[PackedVector2Array] = []
	for angle in angles:
		var points := PackedVector2Array([center])
		var previous_radius := 0.0
		for j in range(1, bands + 1):
			var radius := far_radius * pow(float(j) / bands, settings.radius_distribution) * _range(1.0 - settings.radius_jitter, 1.0 + settings.radius_jitter)
			radius = maxf(previous_radius + 2.0, radius)
			previous_radius = radius
			var bend := minf(0.07, TAU / count * (0.5 - settings.angle_jitter) * 0.35)
			var a := angle + _range(-bend, bend)
			points.append(center + Vector2.from_angle(a) * radius)
		rays.append(points)
	var keep: Array = []
	for i in count:
		var row: Array[bool] = []
		for j in bands + 1:
			row.append(j <= 2 or j == bands or _next() > settings.ring_gap * float(j) / bands)
		keep.append(row)
	var faces := {"vertices": [], "uv": [], "colors": []}
	var edges := {"vertices": [], "uv": [], "colors": []}
	for i in count:
		var j := 0
		while j < bands:
			var last := j + 1
			while not keep[i][last]: last += 1
			var points := PackedVector2Array()
			for k in range(j, last + 1): points.append(rays[i][k])
			for k in range(last, j - 1, -1): points.append(rays[(i + 1) % count][k])
			if j == 0: points.remove_at(points.size() - 1)
			var bounds := Rect2(points[0], Vector2.ZERO)
			for p in points: bounds = bounds.expand(p)
			if bounds.intersects(Rect2(Vector2.ZERO, SIZE)):
				var clipped := bounds.intersection(Rect2(Vector2.ZERO, SIZE))
				var origin := clipped.get_center() / SIZE
				var meta := Color(origin.x, origin.y, _next(), _next())
				if Geometry2D.is_polygon_clockwise(points): points.reverse()
				var triangles := Geometry2D.triangulate_polygon(points)
				for index in triangles: _vertex(faces, points[index], meta)
				for k in points.size():
					var a := points[k]
					var b := points[(k + 1) % points.size()]
					var normal := (b - a).normalized().orthogonal() * settings.rim_width * 0.5
					for p in [a - normal, b - normal, b + normal, a - normal, b + normal, a + normal]:
						_vertex(edges, p, meta)
			j = last
	return {"faces": _mesh(faces), "edges": _mesh(edges)}

func _vertex(out: Dictionary, point: Vector2, meta: Color) -> void:
	out.vertices.append(point)
	out.uv.append(point / SIZE)
	out.colors.append(meta)

func _mesh(data: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if data.vertices.is_empty(): return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array(data.vertices)
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(data.uv)
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray(data.colors)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
