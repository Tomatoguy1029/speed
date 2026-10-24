@tool
extends Control
var gate: Dictionary = {}
var layers: Array = []
var coverage_mode := false
var gaps := PackedVector2Array()
var radius := 1800.0

static func analyze(conditions: Array, limit: float) -> Dictionary:
	var missing := PackedVector2Array()
	for ring in 16:
		for angle in 64:
			var point := Vector2.from_angle(TAU * angle / 64.0) * limit * (ring + 0.5) / 16.0
			var found := false
			for condition in conditions:
				if covers(condition, point):
					found = true
					break
			if not found: missing.append(point)
	return {"holes": missing.size(), "points": missing}

static func covers(condition: Dictionary, point: Vector2) -> bool:
	var range_test := preload("res://scripts/bosses/flow/range_condition.gd")
	return range_test.allows_snapshot(condition, point) if condition.has("gate") else range_test.allows(condition, point - condition.get("offset", Vector2.ZERO))
func _ready() -> void:
	custom_minimum_size = Vector2(180, 180)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var center := size * 0.5
	if coverage_mode:
		var scaling := minf(size.x, size.y) * 0.43 / maxf(1.0, radius)
		for index in layers.size():
			var color := Color.from_hsv(fmod(index * 0.618, 1.0), 0.5, 0.9, 0.25)
			for ring in 16:
				for angle in 64:
					var direction := TAU * angle / 64.0
					if not covers(layers[index], Vector2.from_angle(direction) * radius * (ring + 0.5) / 16.0): continue
					var cell := PackedVector2Array()
					for corner in [Vector2(ring, -0.5), Vector2(ring + 1, -0.5), Vector2(ring + 1, 0.5), Vector2(ring, 0.5)]:
						if ring == 0 and cell.size() == 3: continue
						cell.append(center + Vector2.from_angle(direction + TAU * corner.y / 64.0) * radius * corner.x / 16.0 * scaling)
					draw_colored_polygon(cell, color)
		for point in gaps: draw_circle(center + point * scaling, 1.5, Color(0.95, 0.55, 0.2, 0.7))
		draw_circle(center, 5, Color(0.9, 0.5, 0.25))
		return
	var maximum := maxf(1.0, float(gate.get("max", 600.0)))
	var scale_factor := minf(size.x, size.y) * 0.43 / maximum
	_sector(gate, center, scale_factor)
	draw_circle(center, 5, Color(0.9, 0.5, 0.25))
	draw_line(center, center + Vector2(18, 0), Color(0.9, 0.5, 0.25), 2)

func _sector(value: Dictionary, center: Vector2, scale_factor: float) -> void:
	var maximum := float(value.get("max", 600.0))
	var points := PackedVector2Array()
	var half := deg_to_rad(float(value.get("half_angle", 180.0)))
	var angle := deg_to_rad(float(value.get("angle", 0.0)))
	for distance in [maximum, float(value.get("min", 0.0))]:
		for i in 49:
			var k := i if distance == maximum else 48 - i
			points.append(center + Vector2.from_angle(angle - half + half * 2.0 * k / 48.0) * distance * scale_factor)
	draw_colored_polygon(points, Color(0.2, 0.65, 0.9, 0.25))
