extends WeaponVisual
## ストライクウィング：今の機体の絵のまま、撃つたびに砲口の先が白→アンバーに光り、当たった所に火花。
const INTERCEPTOR_VISUAL := preload("res://scripts/render/interceptor_visual.gd")

var sparks := PixelSparks.new()
class FrameDrones extends Node2D:
	var drones: Array = []
	var scale_value := 1.0
	var tint := Color.WHITE
	func _draw() -> void:
		for d: Dictionary in drones: INTERCEPTOR_VISUAL.drone(self,d.pos,d.angle,scale_value,d.flash,tint)
var _frame: Array = []
var _objects: FrameDrones
func setup_frame(parent: Node2D, effect_parent: Node2D, pixel: float, scale_value: float) -> void:
	_objects = FrameDrones.new()
	_objects.scale_value = scale_value
	_objects.tint = visual_color(Color.WHITE)
	parent.add_child(_objects)
	_painter = PixelPainter.new()
	_painter.setup_painter(pixel)
	effect_parent.add_child(_painter)
func frame_tick(values: Array, dt: float) -> void:
	# ふたご座の影のドローンは、影の粒が集まって形になるまで描かない（集まる粒は gemini_twins.gd が描く）
	values = values.filter(func(d): return not (d.get("twin", false) and float(d.get("appear", 1.0)) < 1.0))
	_frame = values
	_objects.drones = values
	_objects.queue_redraw()
	_draw_effects(dt)
func dispose() -> void:
	if is_instance_valid(_objects): _objects.queue_free()
	super()


func _draw_effects(dt: float) -> void:
	var p: PixelPainter = _painter
	p.begin()
	if active:
		sparks.draw(p, dt)
		for d in (_frame):
			if d.flash <= 0.0: continue
			# 砲口の光：撃った直後の半分は白い3ドット角、そのあとアンバーの2ドット角。
			var cell := p.cell(d.pos + Vector2.from_angle(d.angle) * 6.0 * p.px)
			if d.flash > 0.03: p.fill(cell.x - 1, cell.y - 1, Color.WHITE, 3, 3)
			else: p.fill(cell.x - 1, cell.y - 1, Color("#ffc77c"), 2, 2)
	p.end()

func on_event(ev: Dictionary) -> void:
	if ev.type == &"shot_hit" and String(ev.get("visual_key", "")) == "weapon/interceptor":
		sparks.add(ev.pos, 4, ev.dir.angle() + PI, 2.0, 25.0, 70.0, 0.16, [Color.WHITE, Color("#8fffe2"), Color("#3e9eaa")])
