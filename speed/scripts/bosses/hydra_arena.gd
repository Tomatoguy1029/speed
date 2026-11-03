## 戦闘開始時から置く固定瓦礫。敵表に入れず、位置・回転・寿命を持つ飛翔瓦礫と分ける。
extends Node2D
var bounds := Rect2()
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
