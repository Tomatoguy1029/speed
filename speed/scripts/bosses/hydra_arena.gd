## 戦闘開始時から置く固定瓦礫。敵表に入れず、位置・回転・寿命を持つ飛翔瓦礫と分ける。
extends Node2D
var bounds := Rect2()
var field: FieldManager
var owner_id := -1
var thickness := 160.0
var pieces: Array[PackedVector2Array] = []
var shades: Array[Color] = []
var rocks: Array[Dictionary] = []
var rubble_mesh: ArrayMesh
static var rubble_atlas: ImageTexture
static var rubble_regions: Array[Rect2] = []
static var solid_uv := Vector2.ZERO
const ROCK_TEXTURES := [preload("res://assets/pixel/meteor_0.png"),preload("res://assets/pixel/meteor_1.png")]

func bind(actor: BossActor) -> void:
	top_level = true
	position = Vector2.ZERO
	z_index = 3
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	field = actor.manager.field
	var size: Vector2 = actor.def.params.arena_size
	var center := (actor.table.pos[actor.body]+actor.run_state.ship_pos)*0.5
	# 出現地点と自機を囲み、戦闘開始中の機体を壁の外へ取り残さない。
	size = size.max((actor.table.pos[actor.body]-actor.run_state.ship_pos).abs()+Vector2.ONE*900.0)
	bounds = Rect2(center-size*0.5,size)
	thickness = float(actor.def.params.arena_wall_thickness)
	owner_id = actor.table.id[actor.body]
	field.battle_arenas[owner_id] = bounds
	# 出現前に測った天体までの余裕を、新しい外周にも流用しない。
	actor.table.body_gap.fill(-1.0)
	actor.manager.projectiles.hostile_gap.fill(0.0)
	_build_rubble()
	_build_mesh()
	_clear_footprint(actor)
	queue_redraw()

func clamp_point(at: Vector2, margin: float) -> Vector2:
	var safe := bounds.grow(-margin)
	return at.clamp(safe.position,safe.end)

## 外周と天体を同時に満たす最寄りの候補へ退避する。
func safe_point(at: Vector2, margin: float) -> Vector2:
	var safe:=bounds.grow(-margin)
	var point:=at.clamp(safe.position,safe.end)
	for pass_index in 4:
		var changed:=false
		for obstacle in field.bodies:
			var radius: float=obstacle.r+margin+1.0
			if point.distance_squared_to(obstacle.pos)>=radius*radius:continue
			var direction: Vector2=(at-obstacle.pos).normalized()
			if direction.is_zero_approx():direction=Vector2.RIGHT
			var radial: Vector2=obstacle.pos+direction*(radius+0.01)
			if _inside(radial,safe):
				point=radial
				changed=true
				continue
			var best:=point
			var distance:=INF
			# 最近点は円の放射方向か、円と囲いの辺の交点に限られる。
			for axis in 2:
				for edge in [safe.position[axis],safe.end[axis]]:
					var offset: float=edge-obstacle.pos[axis]
					var squared: float=(radius+0.01)*(radius+0.01)-offset*offset
					if squared<0.0:continue
					var span:=sqrt(squared)
					for side in [-1.0,1.0]:
						var candidate: Vector2=obstacle.pos
						candidate[axis]=edge
						candidate[1-axis]+=span*side
						if not _inside(candidate,safe):continue
						var cost:=candidate.distance_squared_to(at)
						if cost<distance:
							best=candidate
							distance=cost
			if best!=point:
				point=best
				changed=true
		if not changed:break
	return point

func _inside(at: Vector2,rect: Rect2)->bool:
	return at.x>=rect.position.x-0.001 and at.y>=rect.position.y-0.001 and at.x<=rect.end.x+0.001 and at.y<=rect.end.y+0.001

## 壁の厚みと重なる物を、回収・戦闘可能な内側へずらす。
func _clear_footprint(actor: BossActor)->void:
	var t:=actor.table
	# 岩の配置元も更新し、次のstream更新で壁の中へ戻ることを防ぐ。
	for rock in field.rocks:
		if rock.destroyed:continue
		var current: Vector2=field._rock_at(rock,actor.run_state.world_time)[0]
		var cleared:=_clear_point(current,rock.size)
		if cleared==current:continue
		rock.pos=cleared
		rock.vel=Vector2.ZERO
	for i in t.alive.size():
		if not t.alive[i] or t.dead[i] or i==actor.body:continue
		var at:=_clear_point(t.pos[i],t.r[i])
		if at!=t.pos[i]:
			t.pos[i]=at
			t.vel[i]=Vector2.ZERO
	var pickups: PickupManager=actor.manager.projectiles.combat.pickups
	for i in pickups.gem_alive.size():
		if pickups.gem_alive[i]:
			var at:=_clear_point(pickups.gem_pos[i],12.0)
			if at!=pickups.gem_pos[i]:
				pickups.gem_pos[i]=at
				pickups.gem_vel[i]=Vector2.ZERO
	for i in pickups.coin_alive.size():
		if pickups.coin_alive[i]:pickups.coin_pos[i]=_clear_point(pickups.coin_pos[i],12.0)
	for capsule: Pickup in pickups.capsules:capsule.pos=_clear_point(capsule.pos,24.0)

func _clear_point(at: Vector2, radius: float)->Vector2:
	var outer:=bounds.grow(thickness+80.0+radius)
	if not outer.has_point(at):return at
	if bounds.has_point(at):return safe_point(at,radius+12.0)
	var inner:=bounds.grow(-radius-12.0)
	var inward:=at.clamp(inner.position,inner.end)
	# 壁のすぐ外の物も回収・戦闘可能な内側へ退避する。遠方の物には触れない。
	return safe_point(inward,radius+12.0)

func release() -> void:
	if field != null: field.battle_arenas.erase(owner_id)
	visible = false

func _exit_tree() -> void:
	release()

func _build_rubble() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 419
	var corners := [bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]
	for side in 4:
		var start: Vector2 = corners[side]
		var finish: Vector2 = corners[(side+1)%4]
		var along := (finish-start).normalized()
		var outward := Vector2(along.y,-along.x)
		var count := ceili(start.distance_to(finish)/80.0)
		for i in count:
			var a := start.lerp(finish,float(i)/count)
			var b := start.lerp(finish,float(i+1)/count)
			var depth := thickness*rng.randf_range(0.8,1.2)
			var polygon := PackedVector2Array([a,b,b+outward*depth*0.65,b+outward*depth-along*18.0,a+outward*depth+along*12.0,a+outward*depth*0.6])
			for j in polygon.size(): polygon[j]=polygon[j].snapped(Vector2(4,4))
			pieces.append(polygon)
			shades.append(Color("#645b50").lightened(rng.randf_range(-0.15,0.12)))
			for layer in 2:
				var radius := rng.randf_range(68.0,82.0) if layer==0 else rng.randf_range(45.0,62.0)
				var at := (a+b)*0.5+along*rng.randf_range(-12,12)+outward*(radius+4.0 if layer==0 else depth*0.9)
				rocks.append({"pos":at.snapped(Vector2(4,4)),"radius":radius,"angle":rng.randf()*TAU,"texture":rng.randi_range(0,1),"shade":rng.randf_range(0.72,1.0)})

## 石と影を同じアトラスへ入れ、元の重なり順のまま固定メッシュにする。
func _build_mesh()->void:
	if rubble_atlas==null:
		var atlas_size:=Vector2i(8,4)
		for texture: Texture2D in ROCK_TEXTURES:
			atlas_size.x+=texture.get_width()+4
			atlas_size.y=maxi(atlas_size.y,texture.get_height()+4)
		var atlas:=Image.create(atlas_size.x,atlas_size.y,false,Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		var x:=2
		for texture: Texture2D in ROCK_TEXTURES:
			var pixels:=texture.get_image()
			if pixels.is_compressed():pixels.decompress()
			atlas.blit_rect(pixels,Rect2i(Vector2i.ZERO,pixels.get_size()),Vector2i(x,2))
			rubble_regions.append(Rect2(Vector2(x,2)/Vector2(atlas_size),Vector2(pixels.get_size())/Vector2(atlas_size)))
			x+=pixels.get_width()+4
		atlas.fill_rect(Rect2i(atlas_size-Vector2i(4,4),Vector2i(4,4)),Color.WHITE)
		solid_uv=Vector2(atlas_size-Vector2i(2,2))/Vector2(atlas_size)
		rubble_atlas=ImageTexture.create_from_image(atlas)
	var vertices:=PackedVector2Array()
	var colors:=PackedColorArray()
	var uvs:=PackedVector2Array()
	var indices:=PackedInt32Array()
	for i in pieces.size():
		var polygon := pieces[i]
		var start:=vertices.size()
		for at in polygon:
			vertices.append(at)
			colors.append(shades[i].darkened(0.5))
			uvs.append(solid_uv)
		for index in Geometry2D.triangulate_polygon(polygon):indices.append(start+index)
	for rock in rocks:
		var size := Vector2.ONE*float(rock.radius)
		var region: Rect2=rubble_regions[rock.texture]
		var transform:=Transform2D(rock.angle,rock.pos)
		for layer in 2:
			var offset:=Vector2(4,8) if layer==0 else Vector2.ZERO
			var color:=Color(0.08,0.07,0.08,1) if layer==0 else Color(rock.shade,rock.shade,rock.shade,1)
			var start:=vertices.size()
			for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				vertices.append(transform*(corner*size+offset))
				colors.append(color)
				uvs.append(region.position+(corner+Vector2.ONE)*0.5*region.size)
			for index in [0,1,2,0,2,3]:indices.append(start+index)
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_INDEX]=indices
	rubble_mesh=ArrayMesh.new()
	rubble_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)

func _draw() -> void:
	if rubble_mesh!=null:draw_mesh(rubble_mesh,rubble_atlas)
