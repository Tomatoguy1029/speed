## 戦闘開始時から置く固定瓦礫。敵表に入れず、位置・回転・寿命を持つ飛翔瓦礫と分ける。
extends Node2D
var bounds := Rect2()
var field: FieldManager
var owner_id := -1
var thickness := 160.0
var pieces: Array[PackedVector2Array] = []
var shades: Array[Color] = []
var rocks: Array[Dictionary] = []
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
	queue_redraw()

func clamp_point(at: Vector2, margin: float) -> Vector2:
	var safe := bounds.grow(-margin)
	return at.clamp(safe.position,safe.end)

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

func _draw() -> void:
	for i in pieces.size():
		var polygon := pieces[i]
		draw_colored_polygon(polygon,shades[i].darkened(0.5))
	for rock in rocks:
		var texture: Texture2D=ROCK_TEXTURES[rock.texture]
		var size := Vector2.ONE*float(rock.radius)
		draw_set_transform(rock.pos,rock.angle)
		draw_texture_rect(texture,Rect2(-size+Vector2(4,8),size*2.0),false,Color(0.08,0.07,0.08,1))
		draw_texture_rect(texture,Rect2(-size,size*2.0),false,Color(rock.shade,rock.shade,rock.shade,1))
	draw_set_transform(Vector2.ZERO)
