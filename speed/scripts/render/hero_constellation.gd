## 旧ランとC++表示が共有する星座の描画。値の読み取りだけを行う。
extends RefCounted
static func _px(pixel: float,value: float) -> float:
	return pixel*value
static func draw(c: CanvasItem,h: Dictionary,unit: float,world_time: float,view: Rect2,aura: MeshInstance2D,material: ShaderMaterial) -> void:
	aura.hide()
	if h.get("id",&"")==&"" or h.stars.is_empty():
		return
	var visible := view.grow(900.0)
	if not visible.has_point(h.center):
		return
	var gold := Color("#ffe8a0")
	var brass := Color("#e2b96b")
	var hot := Color(gold.r * 1.7, gold.g * 1.7, gold.b * 1.7)
	var links: PackedInt32Array = h.links
	var connected := PackedByteArray()
	connected.resize(h.stars.size())
	var bounds := Rect2(h.stars[0], Vector2.ZERO)
	for star in h.stars:
		bounds = bounds.expand(star)
	# 星間の空間まで包む光の雲。線に沿った細い縁取りにせず、星座全体を一つの光源として見せる。
	var center := bounds.get_center()
	var radii := bounds.size * 0.65 + Vector2.ONE * _px(unit,72.0)
	var aura_pixel := _px(unit,4.0)
	var columns := ceili(radii.x * 2.0 / aura_pixel)
	var rows := ceili(radii.y * 2.0 / aura_pixel)
	var breath := 0.95 + 0.05 * sin(world_time * 0.8)
	if material != null:
		aura.position = (center-radii).snapped(Vector2.ONE*aura_pixel)
		aura.scale = Vector2(columns,rows)*aura_pixel
		material.set_shader_parameter("cell_count",Vector2(columns,rows))
		material.set_shader_parameter("radii",radii)
		material.set_shader_parameter("aura_center",center)
		material.set_shader_parameter("cell_size",aura_pixel)
		material.set_shader_parameter("breath",breath)
		aura.show()
	# 基本線は操作線と共通。光の広がりと芯を同じ経路に重ねて光線として見せる。
	for n in h.lit.size():
		var a: Vector2 = h.stars[links[n * 2]]
		var b: Vector2 = h.stars[links[n * 2 + 1]]
		var points := PackedVector2Array([a, b])
		var lit: bool = h.lit[n] != 0
		if lit:
			connected[links[n * 2]] = 1
			connected[links[n * 2 + 1]] = 1
		if lit:
			_draw_route_line(c,unit, points, Color(brass, 0.055), 22.0)
			_draw_route_line(c,unit, points, Color(gold, 0.13), 12.0)
			_draw_route_line(c,unit, points, Color(gold, 0.32), 6.0)
			_draw_route_line(c,unit, points, Color(gold, 0.95), 4.0)
			_draw_route_line(c,unit, points, Color(hot, 0.95), 2.0)
		else:
			# 光が戻る前の経路には、弱い金色の光だけを点線で残す。
			_draw_route_line(c,unit, points, Color(gold, 0.35), 2.0, true)
	var pixel := _px(unit,2.0)
	var grid := Vector2.ONE * pixel
	var glow_pixel := _px(unit,4.0)
	for index in h.stars.size():
		var p: Vector2 = h.stars[index].snapped(grid)
		var lit: bool = connected[index] != 0
		# 同じ星光の強さと広がりを変え、残り火のような星が接続すると輝きを取り戻す。
		var strength := 1.3 if lit else 0.6
		var light_strength := 1.0 if lit else 0.32
		for layer in 4:
			var radius := _px(unit,[34.0, 25.0, 17.0, 10.0][layer]) * strength
			var alpha: float = [0.035, 0.06, 0.12, 0.24][layer] * light_strength
			var count := ceili(radius / glow_pixel)
			for y in range(-count, count + 1):
				var dy := y * glow_pixel
				var half_width := floorf(sqrt(maxf(0.0, radius * radius - dy * dy)) / glow_pixel) * glow_pixel
				if half_width > 0.0:
					c.draw_rect(Rect2(p + Vector2(-half_width, dy - glow_pixel * 0.5),
						Vector2(half_width * 2.0, glow_pixel)), Color(gold, alpha))
		var arm := _px(unit,26.0 if lit else 9.0)
		c.draw_rect(Rect2(p - Vector2(arm, pixel), Vector2(arm * 2.0, pixel * 2.0)), Color(gold, 0.45 * light_strength))
		c.draw_rect(Rect2(p - Vector2(pixel * 0.5, arm * 1.15), Vector2(pixel, arm * 2.3)), Color(gold, 0.85 * light_strength))
		var light_rows := [1, 3, 5, 7, 9, 7, 5, 3, 1] if lit else [1, 3, 5, 7, 5, 3, 1]
		for row in light_rows.size():
			var width: int = light_rows[row]
			c.draw_rect(Rect2(p + Vector2(-width * 0.5, row - light_rows.size() * 0.5) * pixel,
				Vector2(width, 1) * pixel), Color(gold, 1.0 if lit else 0.4))
		var core := grid * (3.0 if lit else 2.0)
		c.draw_rect(Rect2(p - core * 0.5, core), hot if lit else Color(gold, 0.55))

static func _draw_route_line(c: CanvasItem,unit: float,points: PackedVector2Array,color: Color,width: float,dashed := false) -> void:
	if not dashed:
		c.draw_polyline(points,color,_px(unit,width))
		return
	for i in points.size()-1:
		var gap := points[i+1]-points[i]
		var steps := int(gap.length()/_px(unit,14.0))
		for k in range(0,steps,2): c.draw_line(points[i]+gap*(float(k)/steps),points[i]+gap*(float(k+1)/steps),color,_px(unit,width))
