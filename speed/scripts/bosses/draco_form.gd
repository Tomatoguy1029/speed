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

## Sample a whole spine in one pass. The target distances match repeated sample() calls.
static func samples_even(points: PackedVector2Array, count: int, include_head := true) -> PackedVector2Array:
	var result := PackedVector2Array()
	if points.is_empty() or count <= 0: return result
	var lengths := PackedFloat32Array()
	var total := 0.0
	for j in range(points.size() - 1):
		var segment := points[j].distance_to(points[j + 1])
		lengths.append(segment)
		total += segment
	var cursor := 0
	var traversed := 0.0
	for j in count:
		var fraction := float(j) / float(maxi(1, count - 1)) if include_head else float(j + 1) / float(count)
		var target := total * fraction
		while cursor < lengths.size() - 1 and target > traversed + lengths[cursor]:
			traversed += lengths[cursor]
			cursor += 1
		if cursor >= lengths.size(): result.append(points[-1])
		else: result.append(points[cursor].lerp(points[cursor + 1], (target - traversed) / maxf(0.001, lengths[cursor])))
	return result

## Retain the head's travelled route and place each body sample at a fixed arc distance.
## The input trail runs from head to tail; a new head position extends it without moving old bends.
static func follow_trail(trail: PackedVector2Array, head: Vector2, body_length: float, count: int) -> Dictionary:
	if trail.size() < 2: trail = PackedVector2Array([head, head + Vector2.LEFT * body_length])
	var previous := trail[0]
	var distance := previous.distance_to(head)
	if distance < 0.01 and trail.size() == count and absf(length(trail) - body_length) < body_length * 0.02:
		return {"trail": trail, "points": trail}
	if distance > 0.01:
		var steps := maxi(1, ceili(distance / 24.0))
		for step in range(1, steps + 1):
			trail.insert(0, previous.lerp(head, float(step) / float(steps)))
	else:
		trail[0] = head
	var path := PackedVector2Array([trail[0]])
	var remaining := body_length
	for j in range(1, trail.size()):
		var span := path[-1].distance_to(trail[j])
		if span < 0.001: continue
		if span >= remaining:
			path.append(path[-1].lerp(trail[j], remaining / span))
			remaining = 0.0
			break
		path.append(trail[j])
		remaining -= span
	if remaining > 0.001:
		var direction := (path[-1] - path[-2]).normalized() if path.size() > 1 else Vector2.LEFT
		path.append(path[-1] + direction * remaining)
	return {"trail": path, "points": samples_even(path, count)}

static func draw_body(canvas: CanvasItem, points: PackedVector2Array, width: float, time: float, cosmic := false, alpha := 1.0, fractions_override := PackedFloat32Array(), batch_segments := false) -> void:
	if points.size()<2 or alpha<=0.001: return
	var progress := fractions_override if fractions_override.size()==points.size() else fractions(points)
	var right_lines := PackedVector2Array()
	var left_lines := PackedVector2Array()
	var cosmic_left := PackedVector2Array()
	var cosmic_right := PackedVector2Array()
	var rib_lines := PackedVector2Array()
	var flow_points := PackedVector2Array()
	var flow_colors := PackedColorArray()
	var triangles := PackedVector2Array()
	var triangle_colors := PackedColorArray()
	var triangle_indices := PackedInt32Array()
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
		var main_color := faded(Color("#544c70").lerp(Color("#756b91"),shade*0.32),alpha)
		var glint_color := faded(Color("#857b9e"),alpha)
		if batch_segments:
			_append_quad(triangles,triangle_colors,triangle_indices,left0,left1,right1,right0,main_color)
			_append_quad(triangles,triangle_colors,triangle_indices,left0,left1,points[j+1]+normal*half1*0.15,points[j]+normal*half0*0.15,glint_color)
		else:
			quad(canvas,left0,left1,right1,right0,main_color)
			quad(canvas,left0,left1,points[j+1]+normal*half1*0.15,points[j]+normal*half0*0.15,glint_color)
		if batch_segments:
			right_lines.append_array(PackedVector2Array([right0,right1]))
			left_lines.append_array(PackedVector2Array([left0,left1]))
		else:
			canvas.draw_line(right0,right1,faded(Color("#211c39"),alpha),maxf(3.0,width*0.04),false)
			canvas.draw_line(left0,left1,faded(Color(0.48,0.55,0.87,0.7),alpha),3.0,false)
		if j%2==0:
			if batch_segments: rib_lines.append_array(PackedVector2Array([left0,right0]))
			else: canvas.draw_line(left0,right0,faded(Color("#39314e"),alpha),3.0,false)
			var flow := 0.58+0.18*sin(time*1.6-j*0.4)
			if batch_segments:
				flow_points.append(points[j]-normal*half0*0.2)
				flow_colors.append(faded(Color(0.52,0.66,1.0,flow),alpha))
			else: canvas.draw_circle(points[j]-normal*half0*0.2,3.0,faded(Color(0.52,0.66,1.0,flow),alpha))
		if cosmic:
			if batch_segments:
				cosmic_left.append_array(PackedVector2Array([left0,left1]))
				cosmic_right.append_array(PackedVector2Array([right0,right1]))
			else:
				canvas.draw_line(left0,left1,faded(Color(0.55,0.42,1.0,0.7),alpha),5.0,false)
				canvas.draw_line(right0,right1,faded(Color(0.27,0.63,1.0,0.6),alpha),5.0,false)
	if batch_segments and not triangle_indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),triangle_indices,triangles,triangle_colors)
	if batch_segments:
		canvas.draw_multiline(right_lines,faded(Color("#211c39"),alpha),maxf(3.0,width*0.04),false)
		canvas.draw_multiline(left_lines,faded(Color(0.48,0.55,0.87,0.7),alpha),3.0,false)
		canvas.draw_multiline(rib_lines,faded(Color("#39314e"),alpha),3.0,false)
		if cosmic:
			canvas.draw_multiline(cosmic_left,faded(Color(0.55,0.42,1.0,0.7),alpha),5.0,false)
			canvas.draw_multiline(cosmic_right,faded(Color(0.27,0.63,1.0,0.6),alpha),5.0,false)
	if batch_segments:
		for j in flow_points.size(): canvas.draw_circle(flow_points[j],3.0,flow_colors[j])

static func _append_quad(points: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	_append_triangle(points,colors,indices,a,b,c,color)
	_append_triangle(points,colors,indices,a,c,d,color)

static func _append_triangle(points: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	if absf((b-a).cross(c-a))<=0.01: return
	var index := points.size()
	points.append_array(PackedVector2Array([a,b,c]))
	colors.append_array(PackedColorArray([color,color,color]))
	indices.append_array(PackedInt32Array([index,index+1,index+2]))

static func quad(canvas: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	triangle(canvas,a,b,c,color)
	triangle(canvas,a,c,d,color)

static func triangle(canvas: CanvasItem, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	if absf((b-a).cross(c-a))>0.01: canvas.draw_colored_polygon(PackedVector2Array([a,b,c]),color)

static func draw_head(canvas: CanvasItem, scale: float, mouth_open := 0.0, light := 1.0, alpha := 1.0, offset := Vector2.ZERO) -> void:
	canvas.draw_set_transform(offset,0.0,Vector2(scale * 1.12, scale * 0.72))
	var skull := PackedVector2Array([Vector2(-80,-60),Vector2(-38,-96),Vector2(24,-91),Vector2(76,-57),Vector2(103,-23),Vector2(110,0),Vector2(92,32),Vector2(55,62),Vector2(-8,87),Vector2(-66,65),Vector2(-95,21)])
	canvas.draw_colored_polygon(skull,faded(Color("#211d39"),alpha))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-76,-51),Vector2(-31,-84),Vector2(21,-78),Vector2(64,-49),Vector2(91,-20),Vector2(101,0),Vector2(75,21),Vector2(12,23),Vector2(-51,5)]),faded(Color("#77718f"),alpha))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-70,38),Vector2(0,58),Vector2(52,37),Vector2(91,8),Vector2(79,38),Vector2(48,64),Vector2(-8,77)]),faded(Color("#4a4567"),alpha))
	# Swept-back horns and a brow identify a dragon without adding forelegs.
	for side in [-1,1]:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-35,side*53),Vector2(-100,side*82),Vector2(-74,side*39),Vector2(-18,side*36)]),faded(Color("#625d7c"),alpha))
		canvas.draw_line(Vector2(-92,side*75),Vector2(-33,side*50),faded(Color("#aaa1bb"),alpha),3.0,false)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(18,side*36),Vector2(60,side*20),Vector2(75,side*30),Vector2(33,side*46)]),faded(Color("#19162a"),alpha))
		canvas.draw_line(Vector2(32,side*33),Vector2(61,side*27),faded(Color(1.0,0.13,0.32,light),alpha),7.0,false)
		canvas.draw_line(Vector2(31,side*30),Vector2(59,side*25),faded(Color(1.0,0.67,0.8,light),alpha),2.0,false)
		canvas.draw_circle(Vector2(83,side*13),4.0,faded(Color("#211d39"),alpha))
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
