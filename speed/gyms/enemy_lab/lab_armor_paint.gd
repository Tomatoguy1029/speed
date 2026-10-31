## 元画像の向きで装甲を拡大し、クリックした装甲片をバケツ塗りする。
extends Control

signal piece_pressed(region: int, restore: bool)
const PAINT := preload("res://tools/content/visual_transforms.gd")
var source: Texture2D
var data: Dictionary = {}
var _texture: Texture2D
var _palette_hash := 0
var _hover := -1

func _init() -> void:
	custom_minimum_size = Vector2(0, 260)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_exited.connect(func(): _hover = -1; queue_redraw())

func show_armor(texture: Texture2D, palettes: Dictionary) -> void:
	if source == texture and (texture == null or _palette_hash == hash(palettes.get(data.key, {}))):
		return
	source = texture
	data = PAINT.layout(source) if source != null else {}
	_hover = -1
	if source != null:
		_palette_hash = hash(palettes.get(data.key, {}))
		_texture = ImageTexture.create_from_image(PAINT.painted_image(source, palettes))
	else:
		_texture = null
	queue_redraw()

func _image_rect() -> Rect2:
	var dimensions := source.get_size()
	var scale := maxf(0.01, minf((size.x - 16) / dimensions.x, (size.y - 16) / dimensions.y))
	var shown := dimensions * scale
	return Rect2((size - shown) * 0.5, shown)

func region_at(point: Vector2) -> int:
	if source == null:
		return -1
	var rect := _image_rect()
	if not rect.has_point(point):
		return -1
	var pixel := Vector2i((point - rect.position) / rect.size * source.get_size())
	return int(data.labels[pixel.y * int(data.width) + pixel.x])

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var region := region_at(event.position)
		if region != _hover:
			_hover = region
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		grab_focus()
		var region := region_at(event.position)
		if region >= 0:
			piece_pressed.emit(region, event.button_index == MOUSE_BUTTON_RIGHT)
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#101925"))
	if source == null:
		return
	var rect := _image_rect()
	for y in ceili(rect.size.y / 8.0):
		for x in ceili(rect.size.x / 8.0):
			var tile := Rect2(rect.position + Vector2(x, y) * 8, Vector2(8, 8)).intersection(rect)
			draw_rect(tile, Color("#293342") if (x + y) % 2 == 0 else Color("#1c2633"))
	draw_texture_rect(_texture, rect, false)
	if _hover >= 0:
		var scale := rect.size / source.get_size()
		for pixel: int in data.regions[_hover]:
			var at := rect.position + Vector2(pixel % int(data.width), pixel / int(data.width)) * scale
			draw_rect(Rect2(at, scale), Color(1, 1, 1, 0.25))
