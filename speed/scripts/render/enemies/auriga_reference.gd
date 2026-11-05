## ぎょしゃ座の左右の轍を、寿命を持つ区間から連続した帯として描く。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
var _settings: Dictionary = SETTINGS.for_id("G12-auriga")

func render(rows: Array, canvas, clock: float) -> void:
	var groups := {}
	for row: Dictionary in rows:
		var key := "%s/%s" % [row.owner_id, row.side]
		if not groups.has(key): groups[key] = []
		groups[key].append(row)
		var left := float(row.life) - float(row.age)
		var fade_time := 0.6 * float(_settings.timing)
		if left < fade_time:
			var middle: Vector2 = (row["from"] + row["to"]) * 0.5
			FX.sparks(canvas.front, canvas.to_logical(middle), fposmod(fade_time - left, 0.4), (clock - float(row.age)) * 7, 2, Color("ffe6b0"), 20, 0.4, -PI / 2.0, 0.8)
	for group: Array in groups.values():
		group.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.order) < int(b.order))
		_draw_trail(group, canvas, clock)

func _draw_trail(rows: Array, canvas, clock: float) -> void:
	var points: Array = []
	var intensity := minf(1.0, float(_settings.intensity))
	for row: Dictionary in rows:
		var age := float(row.age)
		var left := float(row.life) - age
		if left <= 0.0: continue
		var k := minf(1.0, clampf(age / 0.12, 0.0, 1.0) * (0.3 + 0.7 * clampf(left / (0.6 * float(_settings.timing)), 0.0, 1.0))) * intensity
		if points.is_empty(): points.append({"p": canvas.to_logical(row["from"]), "k": k})
		points.append({"p": canvas.to_logical(row["to"]), "k": k})
	if points.size() < 2: return
	var total := 0.0
	for i in range(1, points.size()): total += Vector2(points[i-1].p).distance_to(points[i].p)
	var width: float = float(rows[0].width) * 0.5 * canvas.world_scale * float(_settings.size)
	var palette := FX.ramp(Color(_settings.color))
	var cumulative := 0.0
	for i in range(1, points.size()):
		var a: Dictionary = points[i-1]
		var b: Dictionary = points[i]
		var delta: Vector2 = b.p - a.p
		var length := delta.length()
		if length < 0.01: continue
		var u := delta / length
		var normal := Vector2(-u.y, u.x)
		var d := 0.0
		while d < length:
			var c := cumulative + d
			var k := lerpf(float(a.k), float(b.k), d / length)
			if k > 0.01:
				var taper := pow(minf(1.0, minf(c / 10.0, (total-c) / 6.0)), 0.7)
				var noise := _noise(c * 0.22, clock * 9.0, 3) * 0.5 + 0.5
				var h := width * (0.7 + 0.9 * noise) * k * taper
				if h >= 0.3:
					var point: Vector2 = a.p + u * d
					var q := -h
					while q <= h:
						var edge := absf(q) / h
						var level := 4 if edge < 0.25 else (3 if edge < 0.5 else (2 if edge < 0.8 else 1))
						var at := point + normal * q
						canvas.back.dot(at.x, at.y, palette[level], k * (0.6 if edge > 0.8 else 1.0))
						q += 0.5
					if (roundi(c * 2.0) & 3) == 0: canvas.back.light(point.x, point.y, palette[2], 0.22 * k)
			d += 0.5
		cumulative += length

func _rand(x: int, y: int, seed: int) -> float:
	var h := 0x9e3779b9
	for n in [x, y, seed]:
		h = ((h ^ n) * 0x85ebca6b) & 0xffffffff
		h = h ^ (h >> 13)
		h = (h * 0xc2b2ae35) & 0xffffffff
		h = h ^ (h >> 16)
	return float(h & 0xffffffff) / 4294967296.0

func _noise(x: float, y: float, seed: int) -> float:
	var ix := floori(x)
	var iy := floori(y)
	var fx := x - ix
	var fy := y - iy
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uy := fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(_rand(ix, iy, seed), _rand(ix+1, iy, seed), ux), lerpf(_rand(ix, iy+1, seed), _rand(ix+1, iy+1, seed), ux), uy) * 2.0 - 1.0
