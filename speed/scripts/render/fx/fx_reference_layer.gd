## 元の通常色→加算光をsRGB上で合成し、本体の前後へ配置する。
extends RefCounted
const CANVAS := preload("res://scripts/render/fx/fx_reference_canvas.gd")
const COMPOSITE := preload("res://shaders/fx_reference_composite.gdshader")
var canvas := CANVAS.new()
var shadows: Node2D
var overlay: Node2D
var _sprites: Array[Sprite2D] = []
var _lights: Array[ImageTexture] = []
var _copies: Array[BackBufferCopy] = []
var _parent: Node2D
var _size := Vector2.ZERO
var _center := Vector2.ZERO
var _zoom := 1.0

func setup(parent: Node2D) -> void:
	_parent = parent
	shadows = Node2D.new()
	shadows.z_index = -2
	parent.add_child(shadows)
	overlay = Node2D.new()
	overlay.z_index = 9
	parent.add_child(overlay)
	for i in 2:
		var depth := -1 if i==0 else 10
		var copy := BackBufferCopy.new()
		copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		copy.z_index = depth
		parent.add_child(copy)
		_copies.append(copy)
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = depth
		var material := ShaderMaterial.new()
		material.shader = COMPOSITE
		sprite.material = material
		parent.add_child(sprite)
		_sprites.append(sprite)
		_lights.append(null)

func begin_frame(size: Vector2, center: Vector2, zoom: float) -> void:
	_size = size
	_center = center
	_zoom = maxf(zoom, 0.0001)
	canvas.begin_frame(size, center, _zoom)

func end_frame() -> void:
	canvas.end_frame()
	var painters: Array = [canvas.back,canvas.front]
	for i in 2:
		var painter = painters[i]
		var visible: bool = painter.has_color or painter.has_light
		_copies[i].visible = visible
		_sprites[i].visible = visible
		if not visible: continue
		var image: Image = painter.color_image
		var sprite := _sprites[i]
		if sprite.texture == null or sprite.texture.get_size() != Vector2(image.get_size()):
			sprite.texture = ImageTexture.create_from_image(image)
			_lights[i] = ImageTexture.create_from_image(painter.light_image)
		else:
			(sprite.texture as ImageTexture).update(image)
			_lights[i].update(painter.light_image)
		sprite.material.set_shader_parameter("color_pixels",sprite.texture)
		sprite.material.set_shader_parameter("light_pixels",_lights[i])
		sprite.material.set_shader_parameter("has_light",painter.has_light)
		sprite.material.set_shader_parameter("linear_target",_parent.get_viewport().use_hdr_2d)
		sprite.position = _center - _size / (2.0 * _zoom)
		sprite.scale = Vector2.ONE * (_size.y / 225.0) / _zoom
