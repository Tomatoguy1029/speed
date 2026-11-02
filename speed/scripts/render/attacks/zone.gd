## 範囲攻撃の共通表示。予告と発動の装飾を種類ごとに差し替える。
extends AttackVisual
func _color(pr: ProjectileSystem, i: int) -> Color:
	return pr.hazard_color[i] * effect_tint
func draw_hazard(c: CanvasItem, pr: ProjectileSystem, i: int, view: Rect2) -> void:
	var p := pr.hazard_pos[i]
	var t := pr.hazard_t[i]
	var delay := pr.hazard_delay[i]
	var col := _color(pr, i)
	var len := pr.hazard_len[i]
	if not view.grow(len).has_point(p): return
	if t < delay:
		_charge(c, p, len, t, clampf(t / maxf(delay, 0.001), 0.0, 1.0), col)
		return
	var f := 1.0 - clampf((t - delay) / maxf(pr.hazard_active[i], 0.001), 0.0, 1.0)
	_burst(c, pr, i, p, len, f, col)
func _charge(c: CanvasItem, p: Vector2, _len: float, t: float, _k: float, col: Color) -> void:
	if fmod(t, 0.16) < 0.08: c.draw_circle(p, _px(6.0), Color(col, 0.9 * effect_tint.a))
func _burst(c: CanvasItem, _pr: ProjectileSystem, _i: int, p: Vector2, len: float, f: float, col: Color) -> void:
	draw_burst(c,p,len,f,col,_px(1.0),effect_tint)

static func draw_burst(c: CanvasItem, p: Vector2, radius: float, fade: float, color: Color, pixel: float, tint := Color.WHITE) -> void:
	c.draw_circle(p,radius,Color(color,0.45*fade*tint.a))
	c.draw_arc(p,radius,0.0,TAU,40,Color(1,1,1,0.8*fade)*tint,3.0*pixel)

static func frame_group(circles: Array, pixel: Callable) -> DrawLayer:
	var node := DrawLayer.new()
	var tint: Color = EFFECT_SETTINGS.values_for("res://scenes/attacks/zone.tscn").get("effect_tint",Color.WHITE)
	node.draw_fn = func(canvas: CanvasItem):
		for circle: Dictionary in circles:
			draw_burst(canvas,circle.position,circle.radius,circle.color.a,Color(circle.color,1.0)*tint,pixel.call(),tint)
	return node

## C++側で確定した値を、従来と同じ予告・発動の図形へ渡す。
static func draw_frame(c: CanvasItem, row: Dictionary, pixel: float) -> void:
	var p: Vector2 = row.points[0]
	var radius: float = row.widths[0]
	var style: int = row.zone_style
	var age: float = row.time-row.delay
	var tint: Color = row.tint
	var col: Color = PIXEL_LIGHTNING.COLOR if style==2 else row.colors[0]*tint
	if age<0.0:
		if style>=5: return
		if style in [1,2,4]:
			var k: float = clampf(row.time/maxf(row.delay,0.001),0.0,1.0)
			var a := 0.25+0.55*k
			c.draw_arc(p,radius,0.0,TAU,40,Color(col,a),2.0*pixel)
			c.draw_arc(p,radius*(1.0-0.7*k),0.0,TAU,32,Color(col,a),1.5*pixel)
			for q in 4:
				var u := Vector2.from_angle(q*PI/2.0+PI/4.0)
				c.draw_line(p+u*radius*0.55,p+u*radius*1.15,Color(col,a),2.0*pixel)
		elif fmod(row.time,0.16)<0.08: c.draw_circle(p,6.0*pixel,Color(col,0.9*tint.a))
		return
	if style>=5: return
	var f: float = 1.0-clampf(age/maxf(row.active,0.001),0.0,1.0)
	if style==3:
		for side: float in [-1.0,1.0]:
			var a0: float = PI/2.0*side*(1.0-(1.0-f)*0.8)
			c.draw_arc(p,radius*0.75,a0-0.9,a0+0.9,10,Color(1,1,1,f),3.0*pixel)
		c.draw_circle(p,radius*0.4,Color(col,0.35*f))
	elif style==4:
		c.draw_circle(p,radius,Color(col,row.glow_opacity*f))
		c.draw_arc(p,radius,0.0,TAU,40,Color(col,row.ring_opacity*f),row.ring_width*pixel)
		for arm in row.arm_count:
			var ray: Vector2 = Vector2.from_angle(float(arm)*TAU/float(row.arm_count)+float(row.order%7))*radius*row.lightning_reach
			PIXEL_LIGHTNING.draw(c,p,p+ray,row.lightning_width*pixel,row.order*7919+arm*313+int(age/PIXEL_LIGHTNING.SHAPE_INTERVAL)*101,PIXEL_LIGHTNING.intensity(age,row.active)*f,col)
	else:
		draw_burst(c,p,radius,f,col,pixel,tint)
		if style==2: PIXEL_LIGHTNING.draw(c,p-Vector2(0,radius*3.0),p,2.0*pixel,row.order*7919+int(age/PIXEL_LIGHTNING.SHAPE_INTERVAL)*101,PIXEL_LIGHTNING.intensity(age,row.active))
