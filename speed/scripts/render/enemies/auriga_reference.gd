## ぎょしゃ座の左右の轍を、寿命を持つ区間から連続した帯として描く。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
var _settings: Dictionary = SETTINGS.for_id("G12-auriga")
var _raster := SpeedFxRaster.new()

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
	if groups.is_empty(): return
	var painter = canvas.back
	_raster.begin_painter(painter, float(canvas.world_scale), canvas._camera_position, true, true)
	for group: Array in groups.values():
		group.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.order) < int(b.order))
		_draw_trail(group, canvas, clock)
	painter.colors = _raster.take_colors()
	painter.lights = _raster.take_lights()
	painter.has_color = painter.has_color or _raster.has_color()
	painter.has_light = painter.has_light or _raster.has_light()

func _draw_trail(rows: Array, canvas, clock: float) -> void:
	var points := PackedVector2Array()
	var strengths := PackedFloat64Array()
	var intensity := minf(1.0, float(_settings.intensity))
	for row: Dictionary in rows:
		var age := float(row.age)
		var left := float(row.life) - age
		if left <= 0.0: continue
		var k := minf(1.0, clampf(age / 0.12, 0.0, 1.0) * (0.3 + 0.7 * clampf(left / (0.6 * float(_settings.timing)), 0.0, 1.0))) * intensity
		if points.is_empty():
			points.append(canvas.to_logical(row["from"]))
			strengths.append(k)
		points.append(canvas.to_logical(row["to"]))
		strengths.append(k)
	if points.size() < 2: return
	var width: float = float(rows[0].width) * 0.5 * canvas.world_scale * float(_settings.size)
	_raster.auriga_trail(points, strengths, width, PackedColorArray(FX.ramp(Color(_settings.color))), clock)
