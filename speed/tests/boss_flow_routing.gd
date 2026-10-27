## 配線は右側から出て左側へ入り、途中のノードから余白を空けて迂回する。
extends SceneTree

const ROUTER_PATH := "res://tools/editor/boss_flow/wire_router.gd"
const EPSILON := 0.001
var failures := 0
var finished := false

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	print("[boss-wire-routing] ", "PASS " if ok else "FAIL ", message)
	if not ok: failures += 1

func _crosses_interior(a: Vector2, b: Vector2, obstacle: Rect2) -> bool:
	# 境界に沿う配線を許し、矩形内部と交わる線分だけを拒否する。
	var interior := obstacle.grow(-EPSILON)
	if interior.has_point(a) or interior.has_point(b): return true
	var corners := [interior.position, Vector2(interior.end.x, interior.position.y), interior.end, Vector2(interior.position.x, interior.end.y)]
	for index in 4:
		if Geometry2D.segment_intersects_segment(a, b, corners[index], corners[(index + 1) % 4]) != null: return true
	return false

func _verify(router: Script, title_text: String, from: Vector2, to: Vector2, obstacles: Array[Rect2], margin := 14.0) -> void:
	var value: Variant = router.route(from, to, obstacles, margin)
	check(value is PackedVector2Array, title_text + ": route returns a polyline")
	if not value is PackedVector2Array: return
	var points: PackedVector2Array = value
	check(points.size() >= 2, title_text + ": route contains both endpoints")
	if points.size() < 2: return
	check(points[0].is_equal_approx(from) and points[-1].is_equal_approx(to), title_text + ": ports remain the exact endpoints")
	var finite := true
	var compact := PackedVector2Array()
	for point in points:
		if not point.is_finite(): finite = false
		if compact.is_empty() or compact[-1].distance_to(point) > EPSILON: compact.append(point)
	check(finite and compact.size() >= 2, title_text + ": route has finite, nondegenerate segments")
	if not finite or compact.size() < 2: return
	var outgoing := compact[1] - compact[0]
	var incoming := compact[-1] - compact[-2]
	check(outgoing.x > EPSILON and absf(outgoing.y) <= EPSILON, title_text + ": line leaves the source to the right")
	check(incoming.x > EPSILON and absf(incoming.y) <= EPSILON, title_text + ": line enters the target from the left")
	var clear := true
	for index in range(1, compact.size()):
		for obstacle in obstacles:
			var source_stub: bool = index == 1 and obstacle.grow(EPSILON).has_point(from)
			var target_stub: bool = index == compact.size() - 1 and obstacle.grow(EPSILON).has_point(to)
			var clearance := obstacle if source_stub or target_stub else obstacle.grow(margin)
			if _crosses_interior(compact[index - 1], compact[index], clearance): clear = false
	check(clear, title_text + ": every segment clears the intermediate nodes and margin")

func exercise() -> void:
	create_timer(20.0).timeout.connect(func():
		if not finished:
			push_error("[boss-wire-routing] FAIL route exercise timed out")
			quit(1))
	if not FileAccess.file_exists(ROUTER_PATH):
		check(false, "shared wire router exists")
		quit(1)
		return
	var router: Script = load(ROUTER_PATH)
	if router == null:
		check(false, "shared wire router loads")
		quit(1)
		return
	var none: Array[Rect2] = []
	_verify(router, "forward connection", Vector2(40, 60), Vector2(440, 60), none)
	var loop_obstacles: Array[Rect2] = [Rect2(200, -40, 120, 200)]
	_verify(router, "right-to-left loop", Vector2(480, 60), Vector2(40, 60), loop_obstacles)
	var blocked: Array[Rect2] = [Rect2(200, 30, 120, 180)]
	_verify(router, "intermediate node", Vector2(40, 100), Vector2(540, 100), blocked)
	blocked[0] = Rect2(250, -180, 260, 460)
	_verify(router, "moved and resized nodes", Vector2(110, 180), Vector2(740, -100), blocked)
	var endpoints: Array[Rect2] = [Rect2(0, 0, 100, 60), Rect2(-200, 0, 100, 60)]
	_verify(router, "loop with endpoint nodes", Vector2(100, 30), Vector2(-200, 30), endpoints)
	var first: PackedVector2Array = router.route(Vector2(40, 60), Vector2(440, 60), none)
	first[0] += Vector2(30, 30)
	var again: PackedVector2Array = router.route(Vector2(40, 60), Vector2(440, 60), none)
	check(again[0].is_equal_approx(Vector2(40, 60)), "drawing offsets cannot mutate a cached route")
	var straight: PackedVector2Array = router.natural_route(Vector2(40, 60), Vector2(440, 60), none)
	check(straight.size() == 2 and straight[0].is_equal_approx(Vector2(40, 60)) and straight[-1].is_equal_approx(Vector2(440, 60)), "side-by-side nodes connect with one straight line")
	var curved: PackedVector2Array = router.natural_route(Vector2(40, 60), Vector2(440, 360), none)
	check(curved.size() > 2 and curved[1].x > curved[0].x and curved[-1].x > curved[-2].x, "lower branches curve naturally while leaving and entering horizontally")
	var detour: PackedVector2Array = router.natural_route(Vector2(40, 100), Vector2(540, 100), blocked)
	var clearance: Array[Rect2] = [blocked[0].grow(8.0)]
	check(detour.size() > 2 and router._segments_clear(detour, clearance), "curved routing still avoids an intervening node")
	var graph := GraphEdit.new()
	root.add_child(graph)
	var source := GraphNode.new()
	source.name = "source"
	source.size = Vector2(150, 100)
	graph.add_child(source)
	var target := GraphNode.new()
	target.name = "target"
	target.position_offset = Vector2(450, 300)
	target.size = Vector2(150, 100)
	graph.add_child(target)
	await process_frame
	graph.zoom = 1.0
	var full: PackedVector2Array = router.for_graph(graph, Vector2(150, 50), Vector2(450, 350))
	graph.zoom = 0.5
	var half: PackedVector2Array = router.for_graph(graph, Vector2(75, 25), Vector2(225, 175))
	var same_shape := full.size() == half.size()
	if same_shape:
		for i in full.size(): same_shape = same_shape and full[i].distance_to(half[i] * 2.0) < EPSILON
	check(same_shape, "zoom changes only the scale, never the route shape")
	graph.queue_free()
	finished = true
	print("[boss-wire-routing] failures=", failures)
	quit(1 if failures else 0)
