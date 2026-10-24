@tool
extends RefCounted
static var _cache := {}

static func for_graph(graph: GraphEdit, from: Vector2, to: Vector2) -> PackedVector2Array:
	var obstacles: Array[Rect2] = []
	for node in graph.get_children():
		if node is GraphNode and node.size.x > 1.0 and node.size.y > 1.0: obstacles.append(Rect2(node.position_offset * graph.zoom, node.size * graph.zoom))
	var points := route(from, to, obstacles, 3.0 * graph.zoom)
	# GraphEditは初期レイアウト中も2点以上を必要とする。
	return points if points.size() >= 2 else PackedVector2Array([from, from])

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
