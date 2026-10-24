## 開始地点を原点に、背景の配置・拡大表示を行う。
extends Control

var editor
var center := Vector2.ZERO
var zoom := 0.65
var guides := true
var _panning := false
var _dragging := false
var _grab := Vector2.ZERO
var _before: Array = []
var _original_offset := Vector2.ZERO

func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)

func screen(world: Vector2) -> Vector2:
	return (world - center) * zoom + size * 0.5

func world(point: Vector2) -> Vector2:
	return (point - size * 0.5) / zoom + center

func focus_item() -> void:
	if editor.selected < 0:
		center = Vector2.ZERO
		zoom = 0.65
	else:
		var item: BackgroundPlacement = editor.items[editor.selected]
		center = item.offset
		zoom = clampf(minf(size.x, size.y) * 0.7 / maxf(1.0, item.bounds().size.length() * item.scale), 0.02, 8.0)
	queue_redraw()

func _hit(point: Vector2) -> int:
	for i in range(editor.items.size() - 1, -1, -1):
		var item: BackgroundPlacement = editor.items[i]
		if item.texture == null:
			continue
		var bounds := item.bounds()
		var local := (point - item.offset).rotated(-deg_to_rad(item.rotation_degrees)) / item.scale + bounds.size * 0.5
		if Rect2(Vector2.ZERO, bounds.size).has_point(local):
			if item.texture.get_image().get_pixelv(Vector2i(local + bounds.position)).a > 0.0:
				return i
	return -1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var at := world(event.position)
			zoom = clampf(zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 0.02, 8.0)
			center += at - world(event.position)
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			if event.pressed:
				var index := _hit(world(event.position))
				editor.select(index)
				_dragging = index >= 0
				if _dragging:
					_grab = world(event.position) - editor.items[index].offset
					_original_offset = editor.items[index].offset
					_before = editor.snapshot()
			else:
				finish_drag()
			accept_event()
	elif event is InputEventMouseMotion:
		if _panning:
			center -= event.relative / zoom
			queue_redraw()
		elif _dragging and editor.selected >= 0:
			editor.items[editor.selected].offset = world(event.position) - _grab
			editor.refresh(false)
			queue_redraw()

func finish_drag() -> void:
	if _dragging and editor.selected >= 0 and editor.items[editor.selected].offset != _original_offset:
		editor.remember(_before)
	_dragging = false
	_before = []

func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_EXIT:
		finish_drag()
		_panning = false

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07))
	if editor == null:
		return
	if guides:
		var step := 100.0
		while step * zoom < 50.0: step *= 5.0
		var first := world(Vector2.ZERO)
		for x in range(int(floor(first.x / step)), int(ceil(world(size).x / step)) + 1):
			var px := screen(Vector2(x * step, 0)).x
			draw_line(Vector2(px, 0), Vector2(px, size.y), Color(0.22, 0.35, 0.48, 0.18))
		for y in range(int(floor(first.y / step)), int(ceil(world(size).y / step)) + 1):
			var py := screen(Vector2(0, y * step)).y
			draw_line(Vector2(0, py), Vector2(size.x, py), Color(0.22, 0.35, 0.48, 0.18))
		var cfg: GameConfig = ContentManager.base
		draw_arc(screen(Vector2(cfg.start_radius, 0)), cfg.field_radius * zoom, 0, TAU, 256, Color(0.3, 0.5, 0.6, 0.4), 1)
	for item: BackgroundPlacement in editor.items:
		if item.texture == null: continue
		var bounds := item.bounds()
		draw_set_transform(screen(item.offset), deg_to_rad(item.rotation_degrees), Vector2.ONE * zoom * item.scale)
		draw_texture_rect_region(item.texture, Rect2(-bounds.size * 0.5, bounds.size), bounds, item.display_tint())
	draw_set_transform(Vector2.ZERO)
	if guides:
		var origin := screen(Vector2.ZERO)
		draw_line(origin - Vector2(12, 0), origin + Vector2(12, 0), Color("#71e4e0"), 2)
		draw_line(origin - Vector2(0, 12), origin + Vector2(0, 12), Color("#71e4e0"), 2)
		draw_string(ThemeDB.fallback_font, origin + Vector2(16, -12), tr("bg.origin"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#71e4e0"))
	if editor.selected >= 0 and guides:
		var item: BackgroundPlacement = editor.items[editor.selected]
		var half := item.bounds().size * item.scale * 0.5
		var corners := PackedVector2Array()
		for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y), Vector2(-half.x, -half.y)]:
			corners.append(screen(item.offset + corner.rotated(deg_to_rad(item.rotation_degrees))))
		draw_polyline(corners, Color("#71e4e0"), 2.0)
