## 差し替え可能な格子配置。射線を壊さず通れる一筆を発動前に検証する。
extends RefCounted
static func region(player: Vector2,rect: Rect2)->StringName:
	var rel: Vector2=(player-rect.get_center())/(rect.size*0.5)
	if absf(rel.x)<=0.25 and absf(rel.y)<=0.25:return &"center"
	if absf(rel.x)>absf(rel.y):return &"right" if rel.x>0.0 else &"left"
	return &"down" if rel.y>0.0 else &"up"
static func build(rect: Rect2,player: Vector2,count: int,p: Dictionary,radius: float,budget: float)->Dictionary:
	if count<int(p.grid_minimum) or not rect.has_area():return {}
	var name: StringName=p.grid_regions.get(region(player,rect),&"provisional")
	var layout: Dictionary=p.grid_layouts.get(name,{})
	if layout.is_empty():return {}
	var slots: Array=layout.slots.duplicate(true)
	slots.sort_custom(func(a,b):return int(a.priority)<int(b.priority))
	slots=slots.slice(0,mini(count,slots.size()))
	var preferred: float={&"right":PI,&"left":0.0,&"up":PI*0.5,&"down":-PI*0.5}.get(region(player,rect),0.0)
	for rotation in [preferred,preferred+PI*0.5,preferred-PI*0.5,preferred+PI]:
		for scale in [1.0,0.9,0.8]:
			var offsets:=PackedVector2Array()
			for point in layout.path:offsets.append((point*scale).rotated(rotation))
			for slot in slots:
				offsets.append((slot.from*scale).rotated(rotation))
				offsets.append((slot.to*scale).rotated(rotation))
			var extent:=Rect2(offsets[0],Vector2.ZERO)
			for point in offsets:extent=extent.expand(point)
			var safe: Rect2=rect.grow(-radius-float(p.beam_width)*0.5-8.0)
			if extent.size.x>safe.size.x or extent.size.y>safe.size.y:continue
			# 壁際では配置全体を内側へ寄せ、自機からの接続区間も一筆として検証する。
			var origin:=player.clamp(safe.position-extent.position,safe.end-extent.end)
			var path:=PackedVector2Array([player])
			for point in layout.path:
				var at: Vector2=origin+(point*scale).rotated(rotation)
				if path[-1].distance_to(at)>0.01:path.append(at)
			var beams: Array[PackedVector2Array]=[]
			for slot in slots:beams.append(PackedVector2Array([origin+(slot.from*scale).rotated(rotation),origin+(slot.to*scale).rotated(rotation)]))
			var inside:=true
			for line in beams:
				for point in line:
					if not safe.has_point(point):inside=false
			for point in path:
				if not safe.has_point(point):inside=false
			var length:=0.0
			for i in range(1,path.size()):length+=path[i-1].distance_to(path[i])
			if inside and length<=budget and path_clear(path,beams,radius+float(p.beam_width)*0.5+float(p.grid_clearance)):
				return {"name":name,"region":region(player,rect),"path":path,"beams":beams,"bearer":path[-1],"length":length}
	return {}
static func path_clear(path: PackedVector2Array,beams: Array,radius: float)->bool:
	for i in range(1,path.size()):
		for beam in beams:
			if Geometry2D.segment_intersects_segment(path[i-1],path[i],beam[0],beam[1])!=null:return false
			for pair in [[path[i-1],beam[0],beam[1]],[path[i],beam[0],beam[1]],[beam[0],path[i-1],path[i]],[beam[1],path[i-1],path[i]]]:
				if Geometry2D.get_closest_point_to_segment(pair[0],pair[1],pair[2]).distance_to(pair[0])<radius:return false
	return true
