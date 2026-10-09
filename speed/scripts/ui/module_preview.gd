## 図鑑の効果イメージ。機体・ドローンはゲームと同じ素材を使う。
## 専用画像が定義されていれば優先。未入手は動かさず単色のシルエットにする。
class_name ModulePreview
extends Control

const SILHOUETTE := preload("res://shaders/module_silhouette.gdshader")
const SHIP := preload("res://assets/pixel/airship.png")
const FOLLOWER := preload("res://assets/pixel/drone.png")
const ENEMY := preload("res://assets/pixel/drifter.png")
const CYAN := Color("#9fe8ff")
const GOLD := Color("#ffe99a")

var definition: Resource
var known := false
var animated := false
var _clock := 0.0

func setup(def: Resource, acquired: bool, animate := false) -> void:
	definition = def
	known = acquired
	animated = animate
	_clock = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = null
	if not known:
		var silhouette := ShaderMaterial.new()
		silhouette.shader = SILHOUETTE
		material = silhouette
	set_process(animated and known)
	queue_redraw()

func _process(dt: float) -> void:
	_clock += dt
	queue_redraw()

func _draw() -> void:
	if definition == null:
		return
	var scale_factor := minf(size.x / 360.0, size.y / 220.0)
	draw_set_transform(size / 2.0, 0.0, Vector2.ONE * scale_factor)
	if definition.preview_texture != null:
		var texture: Texture2D = definition.preview_texture
		var image_size := texture.get_size()
		image_size *= minf(300.0 / image_size.x, 180.0 / image_size.y)
		draw_texture_rect(texture, Rect2(-image_size / 2.0, image_size), false,
			Color.WHITE if known else Color(0, 0, 0, 1))
	elif definition is LegendaryModuleDef:
		_draw_legend(String(definition.id))
	else:
		_draw_effect(String(definition.code_id))
	draw_set_transform(Vector2.ZERO)

func _ink(color: Color) -> Color:
	return color if known else Color("#394151")

func _sprite(texture: Texture2D, pos: Vector2, width: float, angle := 0.0) -> void:
	var image_size := texture.get_size() * (width / texture.get_width())
	var points := PackedVector2Array()
	for corner in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
		points.append(pos + (corner * image_size).rotated(angle))
	draw_polygon(points, PackedColorArray([_ink(Color.WHITE)]),
		PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]), texture)

func _ring(pos: Vector2, radius: float, color := CYAN) -> void:
	draw_arc(pos, radius, 0, TAU, 48, _ink(color), 3.0, true)

func _line(a: Vector2, b: Vector2, color := CYAN, width := 3.0) -> void:
	draw_line(a, b, _ink(color), width, true)

func _burst(pos: Vector2, radius: float, color := GOLD) -> void:
	_ring(pos, radius, color)
	for i in 8:
		var dir := Vector2.from_angle(i * TAU / 8.0)
		_line(pos + dir * radius * 0.45, pos + dir * radius * 1.15, color, 2.0)

func _draw_effect(code: String) -> void:
	var pulse := 0.5 + 0.5 * sin(_clock * 3.0)
	var ship := Vector2(-92, 12)
	if code == "rear":
		ship.x = 92
	var end := Vector2(65, 12)
	var route := PackedVector2Array([Vector2(-145, 65), Vector2(-75, -45), end])
	var route_effect := code in ["knockback", "contactWave", "mines", "endBlast", "vortex", "fullCharge", "killSonic", "critBeam", "length"]
	if route_effect:
		draw_polyline(route, _ink(Color(0.8, 0.97, 1.0, 0.45)), 3.0, true)
		ship = end
	_sprite(SHIP, ship, 46.0, PI / 2.0)
	match code:
		"forward", "scatter", "rear":
			var shots := 5 if code == "scatter" else 2
			var direction := -1.0 if code == "rear" else 1.0
			var color := Color(definition.params.get("color", "#9fe8ff"))
			for i in shots:
				var angle := (i - (shots - 1) * 0.5) * (0.19 if code == "scatter" else 0.06)
				var dir := Vector2(direction, 0).rotated(angle)
				for j in 3:
					var distance := 36.0 + fmod(j * 35.0 + _clock * 65.0, 110.0)
					_line(ship + dir * distance, ship + dir * (distance + 16), color, 4.0)
			_sprite(ENEMY, Vector2(115, -15), 46.0)
		"knockback":
			_sprite(ENEMY, Vector2(110 + pulse * 15, 12), 42.0)
			for i in 3:
				_line(Vector2(80, i * 13 - 1), Vector2(111, i * 13 - 1), Color("#ff9a3c"), 2.0)
			_sprite(ENEMY, Vector2(152, -26), 33.0)
		"contactWave", "barrier", "sonic", "killSonic", "reactive":
			var color := Color("#76aaff") if code == "barrier" else CYAN
			var center := ship + Vector2(26, 0) if code == "contactWave" else ship
			for i in 2:
				_ring(center, 32 + i * 20 + pulse * 14, color)
			_sprite(ENEMY, center + Vector2(85, -35), 35.0)
		"drone":
			for i in 3:
				var pos := ship + Vector2.from_angle(_clock * 0.8 + i * TAU / 3.0) * 62
				_sprite(FOLLOWER, pos, 32.0, PI / 2.0)
				_line(pos + Vector2(15, 0), pos + Vector2(45, 0), CYAN, 2.0)
		"mines":
			for i in 5:
				var pos := route[0].lerp(route[1], i / 4.0)
				draw_circle(pos, 7, _ink(Color("#ff7b54")))
				_ring(pos, 11, Color(1, 0.6, 0.4, 0.5))
		"contactArc":
			var points := PackedVector2Array([ship + Vector2(20, 0), Vector2(-35, -20), Vector2(-18, -7), Vector2(25, -45), Vector2(60, -5), Vector2(110, 30)])
			draw_polyline(points, _ink(Color("#b3d9ff")), 3.0, true)
			for pos in [Vector2(-35, -20), Vector2(25, -45), Vector2(110, 30)]:
				_sprite(ENEMY, pos, 30.0)
		"endBlast":
			_burst(end, 42 + pulse * 12)
		"vortex":
			for i in 3:
				var angle := _clock + i * TAU / 3
				draw_arc(end, 25 + i * 14, angle, angle + 2.0, 24, _ink(Color(0.75, 0.45, 1, 0.8)), 3.0, true)
		"critBeam":
			_line(end, Vector2(165, 12), GOLD, 12.0)
			_line(end, Vector2(165, 12), Color.WHITE, 3.0)
		"fullCharge", "quickCharge", "capacity":
			_ring(ship, 48, Color(0.3, 0.5, 0.6, 0.4))
			var fill := 1.0 if code == "fullCharge" else 0.4 + pulse * 0.6
			draw_arc(ship, 48, -PI / 2, -PI / 2 + TAU * fill, 48, _ink(CYAN), 5.0, true)
			if code == "capacity":
				_ring(ship, 58, CYAN)
		"pickup":
			_ring(ship, 72, Color("#c7a2ff"))
			for i in 5:
				var pos := ship + Vector2.from_angle(i * TAU / 5) * (65 - pulse * 20)
				draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -7), pos + Vector2(5, 0), pos + Vector2(0, 7), pos + Vector2(-5, 0)]), _ink(Color("#c7a2ff")))
		"speed", "length":
			for i in 3:
				_line(ship + Vector2(-65, -15 + i * 15), ship + Vector2(-27, -15 + i * 15), CYAN, 2.0)
			if code == "length":
				_line(end, Vector2(155, -55), CYAN)
		"attack", "critRate":
			_sprite(ENEMY, Vector2(48, 12), 48.0)
			_line(ship + Vector2(24, 0), Vector2(30, 12), CYAN, 5.0)
			_burst(Vector2(30, 12), 22 + pulse * 10)

func _draw_legend(id: String) -> void:
	# 専用素材がない間は部品を示す仮の図。完成アートとは区別する。
	var color := _ink(GOLD)
	match id:
		"legendary_compass":
			_ring(Vector2.ZERO, 66, GOLD)
			_ring(Vector2.ZERO, 53, GOLD)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -48), Vector2(14, 0), Vector2(0, 48), Vector2(-14, 0)]), color)
		"legendary_sail":
			_line(Vector2(-35, 60), Vector2(-35, -65), GOLD, 5.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-26, -62), Vector2(65, 38), Vector2(-26, 38)]), color)
		"legendary_keel":
			draw_polyline(PackedVector2Array([Vector2(-85, -28), Vector2(-60, 25), Vector2(0, 50), Vector2(60, 25), Vector2(85, -28)]), color, 8.0, true)
			_line(Vector2.ZERO, Vector2(0, 50), GOLD, 6.0)
		"legendary_stern":
			draw_colored_polygon(PackedVector2Array([Vector2(-50, -50), Vector2(50, -50), Vector2(68, 45), Vector2(-68, 45)]), color)
			_line(Vector2(-35, 65), Vector2(35, 65), GOLD, 8.0)
