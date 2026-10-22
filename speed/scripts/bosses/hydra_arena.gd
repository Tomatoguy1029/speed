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
	_clear_footprint(actor)
	queue_redraw()

func clamp_point(at: Vector2, margin: float) -> Vector2:
	var safe := bounds.grow(-margin)
	return at.clamp(safe.position,safe.end)

## 外周と天体を同時に満たす最寄りの候補へ退避する。
func safe_point(at: Vector2, margin: float) -> Vector2:
	var point:=clamp_point(at,margin)
	for pass_index in 4:
		var changed:=false
		for obstacle in field.bodies:
			var radius: float=obstacle.r+margin+1.0
			if point.distance_squared_to(obstacle.pos)>=radius*radius:continue
			var angle: float=(point-obstacle.pos).angle()
			var best:=point
			var distance:=INF
			for i in 64:
				var candidate: Vector2=obstacle.pos+Vector2.from_angle(angle+TAU*i/64.0)*radius
				if not bounds.grow(-margin).has_point(candidate):continue
				if candidate.distance_squared_to(at)<distance:
					best=candidate
					distance=candidate.distance_squared_to(at)
			if best!=point:
				point=best
				changed=true
		if not changed:break
	return point

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
