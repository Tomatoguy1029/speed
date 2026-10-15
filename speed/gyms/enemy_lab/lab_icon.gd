extends Control
var definition: Resource
var texture: Texture2D
func _ready() -> void:
	custom_minimum_size = Vector2(44, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var center := size * 0.5
	if texture != null:
		var extent := texture.get_size()
		extent *= 42.0 / maxf(extent.x, extent.y)
		draw_texture_rect(texture, Rect2(center - extent / 2, extent), false)
	elif definition is EnemyDef:
		var points := RenderManager._placeholder_points(definition.shape)
		for i in points.size():
			points[i] = points[i] * 20 + center
		draw_colored_polygon(points, definition.color)
		draw_polyline(points, Color.WHITE, 1)
	else:
		draw_circle(center, 19, Color("#c76f93"), false, 3)
		draw_line(center - Vector2(18, 0), center + Vector2(18, 0), Color.WHITE, 2)
