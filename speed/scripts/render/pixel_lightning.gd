## 雷撃の外観を共通の整数グリッドで描く。枝は装飾。ゲーム用の乱数・当たり判定は使わない。
extends RefCounted

const COLOR := Color("#e1f7ff")
const SHAPE_INTERVAL := 0.07
## 同じ放電の形を切り替えるまで、セル列を使い回す。寿命の短い演出用に保持数を制限する。
const CACHE_LIMIT := 512
static var _cache: Dictionary = {}

static func intensity(age: float, lifetime: float) -> float:
	if age < 0.0 or lifetime <= 0.0 or age >= lifetime:
		return 0.0
	var t := age / lifetime
	if t < 0.18:
		return 0.4
	if t < 0.38:
		return 1.0
	if t < 0.5:
		return 0.12
	return (1.0 - t) * 2.0

## from・to・pixel は呼び出し元の座標系。pixel は画面またはプレビュー上のドット幅。
static func draw(c: CanvasItem, from: Vector2, to: Vector2, pixel: float, seed_value: int, alpha: float, color := COLOR) -> void:
	if pixel <= 0.0 or alpha <= 0.0 or from.distance_squared_to(to) < pixel * pixel * 0.25:
		return
	var key := [from, to, pixel, seed_value]
	if not _cache.has(key):
		if _cache.size() >= CACHE_LIMIT:
			_cache.erase(_cache.keys()[0])
		var cells := _generate(from / pixel, to / pixel, seed_value)
		_cache[key] = [_lines(cells[0], pixel), _lines(cells[1], pixel)]
	var cells: Array = _cache[key]
	# セルの中央に短い水平線を置き、アンチエイリアスなしでドットの階段を出す。
	_draw_lines(c, cells[0], pixel, color, alpha * 0.12, 5.0)
	_draw_lines(c, cells[1], pixel, color, alpha * 0.12, 3.0)
	_draw_lines(c, cells[0], pixel, color, alpha * 0.35, 3.0)
	_draw_lines(c, cells[1], pixel, color, alpha * 0.75, 1.0)
	_draw_lines(c, cells[0], pixel, Color.WHITE, alpha, 1.0)

static func _draw_lines(c: CanvasItem, lines: PackedVector2Array, pixel: float, color: Color, alpha: float, width: float) -> void:
	if lines.is_empty():
		return
	c.draw_multiline(lines, Color(color, alpha), pixel * width, false)

static func _lines(cells: PackedVector2Array, pixel: float) -> PackedVector2Array:
	var lines := PackedVector2Array()
	lines.resize(cells.size() * 2)
	for i in cells.size():
		lines[i * 2] = cells[i] * pixel
		lines[i * 2 + 1] = (cells[i] + Vector2.RIGHT) * pixel
	return lines

static func _generate(from: Vector2, to: Vector2, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var distance := from.distance_to(to)
	var depth := clampi(ceili(log(maxf(distance / 4.0, 1.0)) / log(2.0)), 1, 6)
	var path := PackedVector2Array([from])
	_split(path, from, to, depth, minf(distance * 0.22, 24.0), rng)
	var main := {}
	var branches := {}
	_raster_path(main, path)
	for i in mini(int(distance / 28.0), 3):
		var at := path[rng.randi_range(1, path.size() - 2)]
		var direction := (to - from).normalized().rotated(rng.randf_range(0.45, 1.15) * (-1.0 if i % 2 == 0 else 1.0))
		var end := at + direction * minf(distance * 0.22, 22.0) * rng.randf_range(0.6, 1.0)
		var branch := PackedVector2Array([at])
		_split(branch, at, end, 3, at.distance_to(end) * 0.22, rng)
		_raster_path(branches, branch)
	return [PackedVector2Array(main.keys()), PackedVector2Array(branches.keys())]

static func _split(out: PackedVector2Array, from: Vector2, to: Vector2, depth: int, offset: float, rng: RandomNumberGenerator) -> void:
	if depth <= 0:
		out.append(to)
		return
	var normal := (to - from).orthogonal().normalized()
	var midpoint := (from + to) * 0.5 + normal * rng.randf_range(-offset, offset)
	_split(out, from, midpoint, depth - 1, offset * 0.52, rng)
	_split(out, midpoint, to, depth - 1, offset * 0.52, rng)

static func _raster_path(cells: Dictionary, path: PackedVector2Array) -> void:
	for i in range(1, path.size()):
		var a := Vector2i(path[i - 1].round())
		var b := Vector2i(path[i].round())
		var dx := absi(b.x - a.x)
		var dy := -absi(b.y - a.y)
		var sx := 1 if a.x < b.x else -1
		var sy := 1 if a.y < b.y else -1
		var error := dx + dy
		while true:
			cells[Vector2(a)] = true
			if a == b:
				break
			var twice := error * 2
			if twice >= dy:
				error += dy
				a.x += sx
			if twice <= dx:
				error += dx
				a.y += sy
