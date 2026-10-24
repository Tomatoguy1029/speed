@tool
extends Control
var gate: Dictionary = {}
func _ready() -> void:
	custom_minimum_size = Vector2(180, 180)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var center := size * 0.5
	var maximum := maxf(1.0, float(gate.get("max", 600.0)))
	var scale_factor := minf(size.x, size.y) * 0.43 / maximum
	var points := PackedVector2Array()
	var half := deg_to_rad(float(gate.get("half_angle", 180.0)))
	var angle := deg_to_rad(float(gate.get("angle", 0.0)))
	for radius in [maximum, float(gate.get("min", 0.0))]:
		for i in 49:
			var k := i if radius == maximum else 48 - i
			points.append(center + Vector2.from_angle(angle - half + half * 2.0 * k / 48.0) * radius * scale_factor)
	draw_colored_polygon(points, Color(0.2, 0.65, 0.9, 0.25))
	draw_circle(center, 5, Color(0.9, 0.5, 0.25))
	draw_line(center, center + Vector2(18, 0), Color(0.9, 0.5, 0.25), 2)
