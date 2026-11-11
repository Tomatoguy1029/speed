## 操作練習の目印を世界座標へ描く。光る輪と、お手本の線の始点・終点。
## お手本の線の帯は本番の描線と同じ RouteVisual を色違いで使う。
extends Node2D

const ROUTE := preload("res://scripts/render/route_visual.gd")
const MOUSE := preload("res://assets/ui/tutorial/mouse.png")
const CYAN := Color("5fe3ff")
var ship := Vector2.ZERO
## 世界の長さ1あたりの、原画1ドットの大きさ
var pixel := 1.0
var gate_radius := 0.0
var _gate := Vector2.ZERO
var _gate_on := false
var _path := PackedVector2Array()
var _drawing := false
var _target := Vector2.ZERO
var _target_on := false
var _route: Node2D
var _clock := 0.0

func _ready() -> void:
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_route = ROUTE.new()
	_route.visible = false
	add_child(_route)

func show_gate(at: Vector2) -> void:
	_gate = at
	_gate_on = true

func hide_gate() -> void:
	_gate_on = false

func show_path(points: PackedVector2Array, radius: float) -> void:
	_path = points
	_route.set_route(points, radius, Color(1, 1, 1, 0.55), pixel)

func hide_path() -> void:
	_path = PackedVector2Array()
	_route.visible = false

## 画面の外にある目標の向きを、機体からの矢羽根で示す。
func point_to(at: Vector2, on: bool) -> void:
	_target = at
	_target_on = on

func set_drawing(drawing: bool) -> void:
	_drawing = drawing

func _process(delta: float) -> void:
	_clock += delta
	if _route.visible:
		_route.set_clock(_clock)
	queue_redraw()

func _chevrons(target: Vector2, margin: float) -> void:
	var distance := ship.distance_to(target)
	if distance < margin + 60.0 * pixel:
		return
	var direction := (target - ship) / distance
	var normal := direction.orthogonal()
	var span := minf(110.0 * pixel, distance - margin - 30.0 * pixel)
	for i in 3:
		var phase := fposmod(_clock * 1.2 + i / 3.0, 1.0)
		var at := ship + direction * (34.0 * pixel + phase * span)
		var arm := 5.0 * pixel
		draw_polyline(PackedVector2Array([at - direction * arm + normal * arm, at, at - direction * arm - normal * arm]), Color(CYAN, 1.0 - phase), 1.5 * pixel, false)

func _point(at: Vector2, label: String, on: bool) -> void:
	var pulse := 0.5 + 0.5 * sin(_clock * 5.0)
	var color := CYAN if on else Color(1, 1, 1, 0.4)
	draw_arc(at, (11.0 + (pulse * 3.0 if on else 0.0)) * pixel, 0.0, TAU, 40, color, 1.5 * pixel, false)
	var font := ThemeDB.fallback_font
	var font_size := 16
	var scale_factor := pixel * 0.75
	draw_set_transform(at, 0.0, Vector2.ONE * scale_factor)
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, Vector2(-text_size.x * 0.5, text_size.y * 0.3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var pressed := on and fmod(_clock, 0.7) < 0.4
	var icon := Rect2(at + Vector2(-5.5, 16.0) * pixel, Vector2(11, 16) * pixel)
	draw_texture_rect_region(MOUSE, icon, Rect2(11 if pressed else 0, 0, 11, 16), Color(1, 1, 1, 1.0 if on else 0.4))

func _draw() -> void:
	if _gate_on:
		var pulse := 0.5 + 0.5 * sin(_clock * 5.0)
		draw_arc(_gate, gate_radius * (0.82 + 0.1 * pulse), 0.0, TAU, 64, Color(CYAN, 0.25), 6.0 * pixel, false)
		draw_arc(_gate, gate_radius * (0.82 + 0.1 * pulse), 0.0, TAU, 64, CYAN, 2.0 * pixel, false)
		_chevrons(_gate, gate_radius)
	if _target_on:
		_chevrons(_target, 0.0)
	if _path.size() > 1:
		if not _drawing:
			_chevrons(_path[0], 14.0 * pixel)
		_point(_path[0], "1", not _drawing)
		_point(_path[-1], "2", _drawing)
