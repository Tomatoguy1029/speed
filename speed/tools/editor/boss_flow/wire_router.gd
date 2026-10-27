@tool
extends RefCounted
static var _cache := {}

static func for_graph(graph: GraphEdit, from: Vector2, to: Vector2) -> PackedVector2Array:
	# GraphEditの描画座標で経路を探すと、拡大率ごとの丸めで折れ方が変わる。
	var scale := maxf(graph.zoom, 0.001)
	var source := from / scale
	var target := to / scale
	var obstacles: Array[Rect2] = []
	for node in graph.get_children():
		if node is GraphNode and node.size.x > 1.0 and node.size.y > 1.0: obstacles.append(Rect2(node.position_offset, node.size))
	var points := natural_route(source, target, obstacles)
	# GraphEditは初期レイアウト中も2点以上を必要とする。
	if points.size() < 2: return PackedVector2Array([from, from])
	for i in points.size(): points[i] *= scale
	return points

static func natural_route(from: Vector2, to: Vector2, obstacles: Array[Rect2]) -> PackedVector2Array:
	var intermediate: Array[Rect2] = []
	for box in obstacles:
		if not box.grow(3.0).has_point(from) and not box.grow(3.0).has_point(to): intermediate.append(box.grow(8.0))
	if to.x - from.x >= 32.0:
		if absf(to.y - from.y) <= 0.5:
			var straight := PackedVector2Array([from, to])
			if _segments_clear(straight, intermediate): return straight
		var reach := minf(120.0, maxf(24.0, (to.x - from.x) * 0.45))
		var curved := PackedVector2Array()
		for i in 25:
			var t := i / 24.0
			var inverse := 1.0 - t
			curved.append(from * (inverse * inverse * inverse) + (from + Vector2(reach, 0)) * (3.0 * inverse * inverse * t) + (to - Vector2(reach, 0)) * (3.0 * inverse * t * t) + to * (t * t * t))
		if _segments_clear(curved, intermediate): return curved
	var routed := route(from, to, obstacles, 14.0)
	if routed.size() < 2: return routed
	var rounded := _round_corners(routed)
	return rounded if _segments_clear(rounded, intermediate) else routed

static func _segments_clear(points: PackedVector2Array, boxes: Array[Rect2]) -> bool:
	for i in range(1, points.size()):
		for box in boxes:
			if box.has_point(points[i - 1]) or box.has_point(points[i]): return false
			var corners := [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]
			for corner in 4:
				if Geometry2D.segment_intersects_segment(points[i - 1], points[i], corners[corner], corners[(corner + 1) % 4]) != null: return false
	return true

static func _round_corners(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array([points[0]])
	for i in range(1, points.size() - 1):
		var here := points[i]
		var incoming := here - points[i - 1]
		var outgoing := points[i + 1] - here
		if incoming.length() < 1.0 or outgoing.length() < 1.0 or absf(incoming.normalized().cross(outgoing.normalized())) < 0.01:
			result.append(here)
			continue
		var radius := minf(28.0, minf(incoming.length(), outgoing.length()) * 0.35)
		var entry := here - incoming.normalized() * radius
		var exit := here + outgoing.normalized() * radius
		result.append(entry)
		for step in range(1, 9):
			var t := step / 8.0
			result.append(entry * (1.0 - t) * (1.0 - t) + here * (2.0 * (1.0 - t) * t) + exit * (t * t))
	result.append(points[-1])
	return result

static func draw_directions(graph: GraphEdit, color: Color) -> void:
	for connection in graph.get_connection_list():
		var source := graph.get_node_or_null(NodePath(connection.from_node)) as GraphNode
		var target := graph.get_node_or_null(NodePath(connection.to_node)) as GraphNode
		if source == null or target == null: continue
		var from := (source.position_offset + source.get_output_port_position(connection.from_port)) * graph.zoom
		var to := (target.position_offset + target.get_input_port_position(connection.to_port)) * graph.zoom
		var points := for_graph(graph, from, to)
		for i in points.size(): points[i] -= graph.scroll_offset
		arrow(graph, points, color)

static func refresh(graph: GraphEdit) -> void:
	var connections := graph.get_connection_list()
	graph.clear_connections()
	for connection in connections: graph.connect_node(connection.from_node, connection.from_port, connection.to_node, connection.to_port)
	graph.queue_redraw()

static func _clear(a: Vector2, b: Vector2, boxes: Array[Rect2]) -> bool:
	for box in boxes:
		if is_equal_approx(a.y, b.y):
			if a.y > box.position.y + 0.01 and a.y < box.end.y - 0.01 and maxf(minf(a.x, b.x), box.position.x) < minf(maxf(a.x, b.x), box.end.x) - 0.01: return false
		elif a.x > box.position.x + 0.01 and a.x < box.end.x - 0.01 and maxf(minf(a.y, b.y), box.position.y) < minf(maxf(a.y, b.y), box.end.y) - 0.01: return false
	return true

static func route(from: Vector2, to: Vector2, obstacles: Array[Rect2], margin := 14.0) -> PackedVector2Array:
	var key := hash([from, to, obstacles, margin])
	if _cache.has(key): return _cache[key].duplicate()
	# 描画と線分交差の丸め誤差を避け、境界より1px外を通す。
	var start := from + Vector2(margin + 1.0, 0)
	var goal := to - Vector2(margin + 1.0, 0)
	# Godotのポート中心はノードの境界より数px内側に置かれる。
	for obstacle in obstacles:
		if obstacle.grow(3).has_point(from): start.x = maxf(start.x, obstacle.end.x + margin + 1.0)
		if obstacle.grow(3).has_point(to): goal.x = minf(goal.x, obstacle.position.x - margin - 1.0)
	var boxes: Array[Rect2] = []
	var xs := [start.x, goal.x]
	var ys := [start.y, goal.y]
	for obstacle in obstacles:
		var box := obstacle.grow(margin + 1.0)
		boxes.append(box)
		for x in [box.position.x, box.end.x]:
			if not xs.has(x): xs.append(x)
		for y in [box.position.y, box.end.y]:
			if not ys.has(y): ys.append(y)
	xs.sort()
	ys.sort()
	var first := Vector2i(xs.find(start.x), ys.find(start.y))
	var last := Vector2i(xs.find(goal.x), ys.find(goal.y))
	var open := [first]
	var costs := {first: 0.0}
	var parents := {}
	var closed := {}
	while not open.is_empty():
		var best := 0
		var score := INF
		for i in open.size():
			var p: Vector2i = open[i]
			var candidate: float = costs[p] + absf(xs[p.x] - goal.x) + absf(ys[p.y] - goal.y)
			if candidate < score:
				best = i
				score = candidate
		var here: Vector2i = open.pop_at(best)
		if here == last: break
		closed[here] = true
		var a := Vector2(xs[here.x], ys[here.y])
		for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = here + delta
			if next.x < 0 or next.y < 0 or next.x >= xs.size() or next.y >= ys.size() or closed.has(next): continue
			var b := Vector2(xs[next.x], ys[next.y])
			if not _clear(a, b, boxes): continue
			var cost: float = costs[here] + a.distance_to(b)
			if cost >= float(costs.get(next, INF)): continue
			costs[next] = cost
			parents[next] = here
			if not open.has(next): open.append(next)
	var points := PackedVector2Array([to, goal])
	var cursor := last
	while parents.has(cursor):
		cursor = parents[cursor]
		points.append(Vector2(xs[cursor.x], ys[cursor.y]))
	if cursor != first:
		# 重なったノード等で経路がない場合は、接続を捏造しない。
		return PackedVector2Array()
	points.append(from)
	points.reverse()
	if _cache.size() >= 128: _cache.clear()
	_cache[key] = points.duplicate()
	return points

static func arrow(canvas: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	var total := 0.0
	for i in range(1, points.size()): total += points[i - 1].distance_to(points[i])
	var halfway := total * 0.5
	for i in range(1, points.size()):
		var length := points[i - 1].distance_to(points[i])
		if length >= halfway and length > 0:
			var direction := (points[i] - points[i - 1]).normalized()
			var at := points[i - 1] + direction * halfway
			canvas.draw_colored_polygon(PackedVector2Array([at + direction * 5, at - direction * 4 + direction.orthogonal() * 4, at - direction * 4 - direction.orthogonal() * 4]), color)
			return
		halfway -= length
