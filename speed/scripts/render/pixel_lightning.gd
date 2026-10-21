## 描画だけに使う雷。乱数は攻撃判定・出現抽選と共有しない。
extends RefCounted

const PALE := Color("#e1f7ff")

static func draw(c: CanvasItem, from: Vector2, to: Vector2, pixel: float,
		seed_value: int, alpha: float) -> void:
	assert(pixel > 0.0)
	var a := from / pixel
	var b := to / pixel
	var distance := a.distance_to(b)
	if distance < 0.5:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var depth := clampi(int(ceil(log(maxf(distance / 6.0, 1.0)) / log(2.0))), 1, 6)
	var main := _path(a, b, minf(distance * 0.22, 24.0), depth, rng)
	var core := _pixels(main, pixel)
	var branches := PackedVector2Array()
	var count := mini(3, int(distance / 28.0))
	for i in count:
		var index := clampi(int((i + 1.0) * (main.size() - 1) / (count + 1.0)), 1, main.size() - 2)
		var start := main[index]
		var direction := (b - a).normalized().rotated(rng.randf_range(0.6, 1.2) * (-1.0 if i % 2 else 1.0))
		var end := start + direction * minf(distance * 0.22, 22.0)
		branches.append_array(_pixels(_path(start, end, minf(distance * 0.05, 5.0), 3, rng), pixel))
	if not branches.is_empty():
		c.draw_multiline(branches, Color(PALE, alpha * 0.12), pixel * 3.0)
		c.draw_multiline(branches, Color(PALE, alpha * 0.75), pixel)
	c.draw_multiline(core, Color(PALE, alpha * 0.12), pixel * 5.0)
	c.draw_multiline(core, Color(PALE, alpha * 0.35), pixel * 3.0)
	c.draw_multiline(core, Color(1, 1, 1, alpha), pixel)

static func intensity(age: float, lifetime: float) -> float:
	var progress := clampf(age / maxf(lifetime, 0.001), 0.0, 1.0)
	if progress < 0.18:
		return 0.4
	if progress < 0.38:
		return 1.0
	if progress < 0.5:
		return 0.12
	return (1.0 - progress) * 2.0

static func _path(a: Vector2, b: Vector2, amplitude: float, depth: int,
		rng: RandomNumberGenerator) -> PackedVector2Array:
	if depth == 0:
		return PackedVector2Array([a, b])
	var middle := (a + b) * 0.5 + (b - a).normalized().orthogonal() * rng.randf_range(-amplitude, amplitude)
	var points := _path(a, middle, amplitude * 0.52, depth - 1, rng)
	points.resize(points.size() - 1)
	points.append_array(_path(middle, b, amplitude * 0.52, depth - 1, rng))
	return points

static func _pixels(path: PackedVector2Array, pixel: float) -> PackedVector2Array:
	var cells: Dictionary = {}
	for i in range(1, path.size()):
		var a := Vector2i(path[i - 1].round())
		var b := Vector2i(path[i].round())
		var dx := absi(b.x - a.x)
		var dy := -absi(b.y - a.y)
		var step_x := 1 if a.x < b.x else -1
		var step_y := 1 if a.y < b.y else -1
		var error := dx + dy
		while true:
			cells[a] = true
			if a == b:
				break
			var twice := error * 2
			if twice >= dy:
				error += dy
				a.x += step_x
			if twice <= dx:
				error += dx
				a.y += step_y
	var lines := PackedVector2Array()
	for cell: Vector2i in cells:
		var center := Vector2(cell) * pixel
		lines.append(center - Vector2(pixel * 0.5, 0))
		lines.append(center + Vector2(pixel * 0.5, 0))
	return lines
