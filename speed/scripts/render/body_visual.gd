## 表示する天体の画像だけを読む。
extends RefCounted
var _textures: Dictionary = {}
func draw(c: CanvasItem, body: FieldSystem.Body) -> void:
	var kind := "planet" if body.is_planet else "moon"
	if not _textures.has(kind):
		_textures[kind] = load("res://assets/pixel/%s.png" % kind)
	c.draw_texture_rect(_textures[kind], Rect2(body.pos - Vector2.ONE * body.r, Vector2.ONE * body.r * 2.0), false)
