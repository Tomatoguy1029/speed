## Shared authored spine, silhouette and armor for the dragon and its whole-body copies.
## Runtime geometry follows moving poses; all widths use the same taper as damage rows.
extends RefCounted

static func taper(t: float) -> float:
	return lerpf(1.0,0.23,pow(clampf((t-0.55)/0.45,0.0,1.0),1.35))

static func length(points: PackedVector2Array) -> float:
	var result := 0.0
	for j in range(points.size()-1): result+=points[j].distance_to(points[j+1])
	return result

static func fractions(points: PackedVector2Array) -> PackedFloat32Array:
	var result := PackedFloat32Array([0.0])
	var length := 0.0
	for j in range(points.size()-1):
		length += points[j].distance_to(points[j+1])
		result.append(length)
	if length>0.001:
		for j in result.size(): result[j]/=length
	return result

static func sample(points: PackedVector2Array, fraction: float) -> Vector2:
	if points.is_empty(): return Vector2.ZERO
	var length := 0.0
	for j in range(points.size()-1): length+=points[j].distance_to(points[j+1])
	var remaining := length*clampf(fraction,0.0,1.0)
	for j in range(points.size()-1):
		var segment := points[j].distance_to(points[j+1])
		if remaining<=segment: return points[j].lerp(points[j+1],remaining/maxf(0.001,segment))
		remaining-=segment
	return points[-1]

static func draw_body(canvas: CanvasItem, points: PackedVector2Array, width: float, time: float, cosmic := false, alpha := 1.0, fractions_override := PackedFloat32Array()) -> void:
	if points.size()<2 or alpha<=0.001: return
	var progress := fractions_override if fractions_override.size()==points.size() else fractions(points)
	# Each span uses its own perpendicular, rather than a miter between opposing neck tangents.
	# Round joins share the capsule radii used by the damage samples; no self-crossing ribbon is triangulated.
	for j in points.size():
		var half := width*0.5*taper(progress[j])
		canvas.draw_circle(points[j],half,faded(Color("#5a5377"),alpha))
	for j in range(points.size()-1):
		var delta := points[j+1]-points[j]
		if delta.length_squared()<0.01: continue
		var normal := delta.normalized().orthogonal()
		var half0 := width*0.5*taper(progress[j])
		var half1 := width*0.5*taper(progress[j+1])
		var left0 := points[j]+normal*half0
		var left1 := points[j+1]+normal*half1
		var right0 := points[j]-normal*half0
		var right1 := points[j+1]-normal*half1
		var shade := 0.5+0.5*sin(float(j)*0.61)
		quad(canvas,left0,left1,right1,right0,faded(Color("#544c70").lerp(Color("#756b91"),shade*0.32),alpha))
		quad(canvas,left0,left1,points[j+1]+normal*half1*0.15,points[j]+normal*half0*0.15,faded(Color("#857b9e"),alpha))
		canvas.draw_line(right0,right1,faded(Color("#211c39"),alpha),maxf(3.0,width*0.04),false)
		canvas.draw_line(left0,left1,faded(Color(0.48,0.55,0.87,0.7),alpha),3.0,false)
		if j%2==0:
			canvas.draw_line(left0,right0,faded(Color("#39314e"),alpha),3.0,false)
			var flow := 0.58+0.18*sin(time*1.6-j*0.4)
			canvas.draw_circle(points[j]-normal*half0*0.2,3.0,faded(Color(0.52,0.66,1.0,flow),alpha))
		if cosmic:
			canvas.draw_line(left0,left1,faded(Color(0.55,0.42,1.0,0.7),alpha),5.0,false)
			canvas.draw_line(right0,right1,faded(Color(0.27,0.63,1.0,0.6),alpha),5.0,false)

static func quad(canvas: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	triangle(canvas,a,b,c,color)
	triangle(canvas,a,c,d,color)

static func triangle(canvas: CanvasItem, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	if absf((b-a).cross(c-a))>0.01: canvas.draw_colored_polygon(PackedVector2Array([a,b,c]),color)

static func draw_head(canvas: CanvasItem, scale: float, mouth_open := 0.0, light := 1.0, alpha := 1.0, offset := Vector2.ZERO) -> void:
	canvas.draw_set_transform(offset,0.0,Vector2.ONE*scale)
	var skull := PackedVector2Array([Vector2(-80,-60),Vector2(-38,-96),Vector2(24,-91),Vector2(76,-57),Vector2(103,-23),Vector2(110,0),Vector2(92,32),Vector2(55,62),Vector2(-8,87),Vector2(-66,65),Vector2(-95,21)])
	canvas.draw_colored_polygon(skull,faded(Color("#211d39"),alpha))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-76,-51),Vector2(-31,-84),Vector2(21,-78),Vector2(64,-49),Vector2(91,-20),Vector2(101,0),Vector2(75,21),Vector2(12,23),Vector2(-51,5)]),faded(Color("#77718f"),alpha))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-70,38),Vector2(0,58),Vector2(52,37),Vector2(91,8),Vector2(79,38),Vector2(48,64),Vector2(-8,77)]),faded(Color("#4a4567"),alpha))
	# Swept-back horns and a brow identify a dragon without adding forelegs.
	for side in [-1,1]:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-27,side*66),Vector2(-118,side*108),Vector2(-75,side*35),Vector2(-11,side*43)]),faded(Color("#625d7c"),alpha))
		canvas.draw_line(Vector2(-107,side*94),Vector2(-26,side*59),faded(Color("#aaa1bb"),alpha),3.0,false)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(18,side*36),Vector2(60,side*20),Vector2(75,side*30),Vector2(33,side*46)]),faded(Color("#19162a"),alpha))
		canvas.draw_line(Vector2(32,side*33),Vector2(61,side*27),faded(Color(1.0,0.13,0.32,light),alpha),7.0,false)
		canvas.draw_line(Vector2(31,side*30),Vector2(59,side*25),faded(Color(1.0,0.67,0.8,light),alpha),2.0,false)
	var jaw := 7.0+mouth_open*29.0
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(29,-jaw),Vector2(103,-jaw*0.5),Vector2(110,jaw*0.35),Vector2(33,jaw)]),faded(Color("#090a19"),alpha))
	for side in [-1,1]:
		for j in 3:
			var x := 48.0+float(j)*20.0
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(x,side*jaw*0.72),Vector2(x+8,side*jaw*0.58),Vector2(x+3,side*maxf(0,jaw-13))]),faded(Color("#bcb9cb"),alpha))
	canvas.draw_line(Vector2(-50,-67),Vector2(2,-63),faded(Color("#b2a7c0"),alpha),5.0,false)
	canvas.draw_line(Vector2(2,-63),Vector2(40,-45),faded(Color("#a399b4"),alpha),4.0,false)
	canvas.draw_set_transform(Vector2.ZERO)

static func star(canvas: CanvasItem, at: Vector2, size: float, color: Color) -> void:
	if size<=0.01 or color.a<=0.001: return
	canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(-size,0),at+Vector2(-size*0.18,-size*0.18),at+Vector2(0,-size),at+Vector2(size*0.18,-size*0.18),at+Vector2(size,0),at+Vector2(size*0.18,size*0.18),at+Vector2(0,size),at+Vector2(-size*0.18,size*0.18)]),color)
	canvas.draw_rect(Rect2((at-Vector2.ONE*size*0.12).snapped(Vector2(2,2)),Vector2.ONE*maxf(2,size*0.24)),Color.WHITE)

static func faded(color: Color, alpha: float) -> Color:
	color.a*=alpha
	return color
