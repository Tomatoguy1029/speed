extends Button
var value: Dictionary = {}
var canvas
var caption := ""
func _ready() -> void:
	custom_minimum_size = Vector2(280, 150)
func _draw() -> void:
	var path: PackedVector2Array = value.get("route", PackedVector2Array())
	if path.size() < 2:
		draw_string(ThemeDB.fallback_font, Vector2(8, 45), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 13)
		return
	var bounds := Rect2(path[0], Vector2.ONE)
	for point in path: bounds = bounds.expand(point)
	for command in value.get("commands", []): bounds = bounds.expand(canvas.session.vector(command.args.pos))
	bounds = bounds.grow(70)
	var ratio := minf((size.x - 20) / maxf(1, bounds.size.x), 100 / maxf(1, bounds.size.y))
	var origin := Vector2(size.x / 2, 55) - bounds.get_center() * ratio
	var points := PackedVector2Array()
	for point in path: points.append(origin + point * ratio)
	draw_polyline(points, Color("#8ed9b8"), 2)
	for command in value.get("commands", []):
		var point: Vector2 = origin + canvas.session.vector(command.args.pos) * ratio
		var texture: Texture2D = canvas.texture_for(String(command.args.type))
		if texture != null: draw_texture_rect(texture, Rect2(point - Vector2(8, 8), Vector2(16, 16)), false)
		else: draw_circle(point, 4, Color("#efb684"))
	draw_string(ThemeDB.fallback_font, Vector2(8, 124), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 12)
	var validation: Dictionary = value.get("validation", {})
	draw_string(ThemeDB.fallback_font, Vector2(8, 143), "L %.0f / %.0f   +%.0f   %.1fs" % [float(validation.get("length", 0)), float(validation.get("budget", 0)), float(validation.get("margin", 0)), float(validation.get("window", 0))], HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 11, Color.LIGHT_GRAY)
