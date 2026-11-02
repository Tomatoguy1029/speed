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
func _effect_key() -> String: return "weapon/interceptor"
func setup_frame(parent: Node2D, effect_parent: Node2D, pixel: float, scale_value: float) -> void:
	_objects = FrameDrones.new()
	_objects.scale_value = scale_value
	_objects.tint = visual_color(Color.WHITE)
	parent.add_child(_objects)
	_painter = PixelPainter.new()
	_painter.setup_painter(pixel)
	effect_parent.add_child(_painter)
func frame_tick(values: Array, dt: float) -> void:
	_frame = values
	_objects.drones = values
	_objects.queue_redraw()
	_draw_effects(dt)
func dispose() -> void:
	if is_instance_valid(_objects): _objects.queue_free()
	super()


func on_event(ev: Dictionary) -> void:
	if ev.type == &"shot_hit" and String(ev.get("visual_key", "")) == "weapon/interceptor":
		sparks.add(ev.pos, 4, ev.dir.angle() + PI, 2.0, 25.0, 70.0, 0.16, [Color.WHITE, Color("#8fffe2"), Color("#3e9eaa")])

func draw_objects(c: CanvasItem) -> void:
	for d in (_frame if rm==null else behavior.drones):
		INTERCEPTOR_VISUAL.drone(c, d.pos, d.angle, cfg.character_scale, d.flash, visual_color(Color.WHITE))

func tick(_dt: float) -> void:
	_draw_effects(world_dt())

func _draw_effects(dt: float) -> void:
	var p: PixelPainter = _painter if rm==null else painter()
	p.begin()
	if active:
		sparks.draw(p, dt)
		for d in (_frame if rm==null else behavior.drones):
			if d.flash <= 0.0: continue
			# 砲口の光：撃った直後の半分は白い3ドット角、そのあとアンバーの2ドット角。
			var cell := p.cell(d.pos + Vector2.from_angle(d.angle) * 6.0 * p.px)
			if d.flash > 0.03: p.fill(cell.x - 1, cell.y - 1, Color.WHITE, 3, 3)
			else: p.fill(cell.x - 1, cell.y - 1, Color("#ffc77c"), 2, 2)
	p.end()
