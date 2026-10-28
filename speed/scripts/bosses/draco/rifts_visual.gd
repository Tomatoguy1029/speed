## 技に合わせた予告とエフェクト。
extends "res://scripts/bosses/draco/technique_visual.gd"

func _draw() -> void:
	if actor == null or not actor.has_body(): return
	super()
	_draw_residual_rifts()

func _draw_residual_rifts() -> void:
	var hazards: Array[int] = []
	if actor.technique == &"rifts" and actor._driver != null:
		for h: int in actor._driver.walls: hazards.append(h)
	for closing: Dictionary in actor.closing_walls:
		if not int(closing.h) in hazards: hazards.append(int(closing.h))
	var ps := actor.ctx.projectiles
	for h: int in hazards:
		if not ps.owns_hazard(h,actor.body,actor.body_id): continue
		var from: Vector2 = ps.hazard_pos[h]
		var length: float = ps.hazard_len[h]
		var width: float = ps.hazard_width[h]
		if length < 1.0 or width < 0.5: continue
		var axis := Vector2.from_angle(ps.hazard_angle[h])
		var normal := axis.orthogonal()
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var count := maxi(3,ceili(length/24.0))
		for j in count+1:
			var t := float(j)/float(count)
			var point := from+axis*length*t
			var notch := sin(float(j)*2.7+float(h)*0.31)*width*0.13
			left.append(actor.to_local(point+normal*(width*0.34+notch)).snapped(Vector2(2,2)))
			right.append(actor.to_local(point-normal*(width*0.34-notch)).snapped(Vector2(2,2)))
		for j in count:
			FORM.quad(self,left[j],left[j+1],right[j+1],right[j],Color("#050410"))
		# The torn lips stay within the solid width; repair shrinks the same
		# hazard from both ends, closing the void and its collision together.
		draw_polyline(left,Color("#8770cb"),3.0,false)
		draw_polyline(right,Color("#40315f"),3.0,false)
		for j in range(0,count,3):
			var at := left[j].lerp(right[j],0.25)
			draw_line(at,left[j+1],Color(0.68,0.74,1.0,0.45),2.0,false)
