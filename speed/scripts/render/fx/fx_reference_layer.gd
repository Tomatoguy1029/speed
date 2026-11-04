## 試作と同じ前後の色・加算光を、実カメラの論理画素へ配置する。
extends RefCounted
const CANVAS := preload("res://scripts/render/fx/fx_reference_canvas.gd")
var canvas := CANVAS.new()
var shadows: Node2D
var _sprites: Array[Sprite2D] = []
var _size := Vector2.ZERO
var _center := Vector2.ZERO
var _zoom := 1.0

func setup(parent: Node2D) -> void:
	shadows = Node2D.new()
	shadows.z_index = -2
	parent.add_child(shadows)
	for i in 4:
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = -1 if i < 2 else 10
		if i % 2 == 1:
			var additive := CanvasItemMaterial.new()
			additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			sprite.material = additive
		parent.add_child(sprite)
		_sprites.append(sprite)

func begin_frame(size: Vector2, center: Vector2, zoom: float) -> void:
	_size = size
	_center = center
	_zoom = maxf(zoom, 0.0001)
	canvas.begin_frame(size, center, _zoom)

func end_frame() -> void:
	canvas.end_frame()
	var images: Array[Image] = [canvas.back.color_image, canvas.back.light_image, canvas.front.color_image, canvas.front.light_image]
	for i in _sprites.size():
		var image := images[i]
		var sprite := _sprites[i]
		if sprite.texture == null or sprite.texture.get_size() != Vector2(image.get_size()):
			sprite.texture = ImageTexture.create_from_image(image)
		else:
			(sprite.texture as ImageTexture).update(image)
		sprite.position = _center - _size / (2.0 * _zoom)
		sprite.scale = _size / Vector2(image.get_size()) / _zoom
