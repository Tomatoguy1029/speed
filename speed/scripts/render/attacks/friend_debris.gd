## C++が確定した破片の位置・回転・軌跡だけを描く。
extends Node2D
const STYLE = preload("res://tools/content/generated/run_schema.gd").ENUMS.DebrisStyle
const PUMP_SHADER := preload("res://shaders/pump_debris.gdshader")
const PUMP_ENEMIES := [preload("res://assets/pixel/drifter.png"),preload("res://assets/pixel/swarm.png"),preload("res://assets/pixel/splitling.png")]
var _row: Dictionary = {}
var _pixel := 1.0
var _zoom := 1.0
var _painter: PixelPainter
var _pump: MeshInstance2D
var _scope: ContentResourceScope
func setup(scope: ContentResourceScope, pixel: float) -> void:
	_scope = scope
	_pixel = pixel
func apply_frame(row: Dictionary, zoom: float) -> void:
	_row = row
	_zoom = maxf(zoom,0.01)
	if _painter!=null: _painter.hide()
	if _pump!=null: _pump.hide()
	if row.debris_style==STYLE.Stardust:
		_stardust()
	elif row.debris_style==STYLE.Pump:
		_pump_debris()
	queue_redraw()
func _draw() -> void:
	if _row.is_empty() or _row.debris_style!=STYLE.Plain: return
	var row := _row
	var p: Vector2 = row.points[0]
	var tint: Color = row.colors[0]
	if row.trail.size()>1: draw_polyline(row.trail,Color(1.0,0.6,0.25,0.7)*tint,3.0*_pixel/_zoom*row.trail_width)
	var u := Vector2.from_angle(row.angle)*float(row.widths[0])
	var v := Vector2(-u.y,u.x)*0.6
	draw_colored_polygon(PackedVector2Array([p+u,p+v,p-u*0.7,p-v]),Color("aeb6c4")*tint)
	draw_polyline(PackedVector2Array([p+u,p+v,p-u*0.7,p-v,p+u]),Color("ff9a3c")*tint,1.5*_pixel/_zoom)
func _stardust() -> void:
	if _painter==null:
		_painter = PixelPainter.new()
		_painter.setup_painter(_pixel)
		_painter.visibility_layer = 1|RenderPipeline.GLOW_LAYER
		add_child(_painter)
	_painter.show()
	_painter.begin()
	var p: Vector2 = _row.points[0]
	var tail: Vector2 = p-(_row.velocity as Vector2)*0.07
	var n := ceili(tail.distance_to(p)/_painter.px) if _row.age<1.2 else 0
	for j in range(0,n,2):
		var k := float(j)/maxi(n,1)
		_painter.dot(tail.lerp(p,k),Color("7a4fd0") if k<0.5 else Color("b48cff"))
	if not (_row.age>=1.3 and int(_row.age*20.0)%2!=0):
		var twinkle := sin(_row.clock*30.0+_row.order*1.7)>-0.3
		var size: int = 2+(int(_row.order)*7)%3
		var cell := _painter.cell(p)
		_painter.fill(cell.x-size/2.0,cell.y-size/2.0,Color("fff3c4") if twinkle else Color("e0d0ff"),size,size)
	_painter.end()
func _pump_debris() -> void:
	if _pump==null:
		_pump = MeshInstance2D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(288,32)
		_pump.mesh = quad
		var material := ShaderMaterial.new()
		material.shader = PUMP_SHADER
		material.set_shader_parameter("linear_output",get_viewport().use_hdr_2d)
		for k in 3: material.set_shader_parameter("enemy%d" % k,PUMP_ENEMIES[k])
		material.set_shader_parameter("pump_art",_scope.resources.get("res://assets/pixel/pump.png"))
		_pump.material = material
		add_child(_pump)
	var dir: Vector2 = (_row.velocity as Vector2).normalized()
	_pump.position = (_row.points[0] as Vector2)-dir*128.0
	_pump.rotation = dir.angle()
	_pump.show()
	var material := _pump.material as ShaderMaterial
	for key in ["age","life"]: material.set_shader_parameter(key,_row[key])
	material.set_shader_parameter("speed",(_row.velocity as Vector2).length())
	material.set_shader_parameter("clock",_row.clock)
	material.set_shader_parameter("seed",float(_row.order))
	material.set_shader_parameter("pixel",_pixel)
	material.set_shader_parameter("spin",_row.angle-dir.angle())
	material.set_shader_parameter("kind",_row.pump_kind)
