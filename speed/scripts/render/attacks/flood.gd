## みずがめ座の水流。専用の層とshaderは初回使用時に作る。
extends AttackVisual

const FLOOD_TAIL := 1.4
var floods: Array = []
var _flood_layer: DrawLayer

static func _flood_half(width: float, spread: float, d: float) -> float:
	return width * 0.5 + maxf(d, 0.0) * tan(spread)

static func _water_strip(c: CanvasItem, p: Vector2, angle: float, length: float, width: float, spread: float,
		mode: float, strength: float, seed: float, margin := 1.12) -> void:
	var u := Vector2.from_angle(angle)
	var v := Vector2(-u.y, u.x)
	var h := _flood_half(width, spread, length) * margin
	var col := Color(mode, strength, seed, 1.0)
	c.draw_polygon(PackedVector2Array([p, p + u * length + v * h, p + u * length - v * h]),
		PackedColorArray([col, col, col]),
		PackedVector2Array([Vector2.ZERO, Vector2(length, h) / 1000.0, Vector2(length, -h) / 1000.0]))


## C++ランでは専用資源をscopeで確保し、ゲームの表を参照せず値だけを描く。
static func frame_create(scope: ContentResourceScope) -> Dictionary:
	var node := DrawLayer.new()
	var mat := ShaderMaterial.new()
	mat.shader = scope.resources.get("res://shaders/water_flood.gdshader")
	mat.set_shader_parameter("noise_tex",scope.resources.get("res://assets/fx/water_noise.png"))
	node.material = mat
	var state := {"node":node,"row":{},"tail":false,"age":0.0,"life":0.0,"collapse":0.35,"fired":false}
	node.draw_fn = func(c: CanvasItem):
		if state.row.is_empty(): return
		var row: Dictionary = state.row
		mat.set_shader_parameter("linear_colors",c.get_viewport().use_hdr_2d)
		var seed: float = float(row.order%17)/17.0
		if state.tail:
			var collapse: float = clampf(1.0-state.age/state.collapse,0.0,1.0)
			var life: float = clampf(1.0-state.age/state.life,0.0,1.0)
			if collapse>0.0: _water_strip(c,row.points[0],row.angle,row.length,row.widths[0],row.spread,1.0/3.0,collapse,seed,row.margin)
			_water_strip(c,row.points[0],row.angle,row.length,row.widths[0],row.spread,1.0,life*(1.0-collapse*0.6),seed,row.margin)
		else:
			var charging: bool = row.time<row.delay
			var strength: float = clampf(row.time/maxf(row.delay,0.001),0.0,1.0) if charging else 1.0
			_water_strip(c,row.points[0],row.angle,row.length,row.widths[0],row.spread,0.0 if charging else 1.0/3.0,strength,seed,row.margin)
	return state

static func frame_apply(state: Dictionary,row: Dictionary) -> void:
	state.row = row
	var mat: ShaderMaterial = state.node.material
	mat.set_shader_parameter("half0",row.widths[0]*0.5)
	mat.set_shader_parameter("slope",tan(row.spread))
	mat.set_shader_parameter("beam_len",row.length)
	state.node.queue_redraw()
