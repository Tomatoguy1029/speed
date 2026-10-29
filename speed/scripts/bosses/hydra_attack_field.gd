## Hydraが所有する攻撃形状。表示・掃引判定・世界時間の正を共有する。
extends Node2D
var actor: Node
var effects: Array[Dictionary] = []
var serial := 0
var visuals: Dictionary={}
var ship_previous := Vector2.ZERO
var white: Texture2D
const FX := preload("res://shaders/hydra_energy.gdshader")
func bind(owner_actor: Node) -> void:
	actor = owner_actor
	top_level = true
	global_position = Vector2.ZERO
	ship_previous = actor.run_state.ship_pos
	var pixels := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	white = ImageTexture.create_from_image(pixels)
func add_shape(points: PackedVector2Array, width: float, delay: float, life: float, damage: float,
		kind: StringName, owner := -1, velocity := Vector2.ZERO, persistent := false) -> Dictionary:
	serial += 1
	var scene: PackedScene = preload("res://scenes/attacks/hydra_shape.tscn")
	var id: StringName = actor.tech if "tech" in actor else &""
	if "necks" in actor:
		for neck in actor.necks:
			if neck.row == owner and actor.move_settings(neck.mode) != null: id = neck.mode
	if actor.has_method("move_settings"):
		var settings: Resource = actor.move_settings(id)
		if settings != null and settings.has_field("shot_visual"): scene = settings.field("shot_visual")
	var line := scene.instantiate() as Node2D
	add_child(line)
	line.configure(actor, kind, points, white)
	var effect := {"id": serial, "points": points, "width": width, "delay": delay, "life": life,
		"age": 0.0, "damage": damage, "kind": kind, "owner": owner,
		"owner_id": actor.table.id[owner] if owner >= 0 else -1, "velocity": velocity,
		"persistent": persistent, "hit": false}
	visuals[serial]=line
	effects.append(effect)
	return effect
func remove_owner(row: int) -> void:
	for e in effects:
		if e.owner == row and not e.persistent: e.life = 0.0
func clear_effects() -> void:
	for e in effects:
		if visuals.has(e.id):visuals[e.id].queue_free()
	effects.clear()
	visuals.clear()
func intersects(points: PackedVector2Array, width: float, a: Vector2, b: Vector2) -> bool:
	var radius: float = width * 0.5 + actor.ctx.cfg.ship_radius
	for i in range(points.size() - 1):
		var p := points[i]
		var q := points[i + 1]
		if Geometry2D.segment_intersects_segment(a, b, p, q) != null: return true
		for pair in [[a,p,q], [b,p,q], [p,a,b], [q,a,b]]:
			if Geometry2D.get_closest_point_to_segment(pair[0], pair[1], pair[2]).distance_squared_to(pair[0]) <= radius * radius: return true
	return false
func tick(dt: float) -> void:
	if dt <= 0.0: return
	var ship: Vector2 = actor.run_state.ship_pos
	for e in effects.duplicate():
		var prior: PackedVector2Array = e.get("previous_points",e.points).duplicate()
		e.age += dt
		var alive: bool = e.owner < 0 or e.persistent or (actor.ctx.enemies.is_same(e.owner,e.owner_id) and actor.table.dead[e.owner] == 0)
		if not alive or e.age >= e.delay + e.life:
			actor.ctx.projectiles.end_attack_visual(StringName(visuals[e.id].scene_file_path), "Fade", e.points[0])
			visuals[e.id].queue_free()
			visuals.erase(e.id)
			effects.erase(e)
			continue
		if e.has("follow_row"):
			if not actor.ctx.enemies.is_same(e.follow_row,e.follow_id) or actor.table.dead[e.follow_row]:
				e.life=0.0
				continue
			var at: Vector2 = actor.table.pos[e.follow_row]
			e.points=PackedVector2Array([at,at+Vector2(0.1,0)])
		if e.age >= e.delay:
			for i in e.points.size(): e.points[i] += e.velocity * dt
			var touching := intersects(e.points,e.width,ship_previous,ship) or intersects(prior,e.width,ship_previous,ship)
			# Moving projectiles sweep their front and back edges too.
			if not touching and prior.size()==e.points.size():
				for i in range(e.points.size()-1):
					var swept:=PackedVector2Array([prior[i],prior[i+1],e.points[i+1],e.points[i]])
					if Geometry2D.is_point_in_polygon(ship,swept) or Geometry2D.is_point_in_polygon(ship_previous,swept):touching=true
				for i in e.points.size():
					if intersects(PackedVector2Array([prior[i],e.points[i]]),e.width,ship_previous,ship): touching = true
			if touching and e.kind == &"wind":
				if not actor.run_state.tracing and not actor.run_state.glide and actor.run_state.ship_vel.length() < actor.run_state.stats.max_speed:
					actor.run_state.ship_vel += (e.points[-1]-e.points[0]).normalized() * float(e.get("wind_force", actor.def.params.wind_force)) * dt
			elif touching and not e.hit and e.damage > 0.0:
				actor.ctx.projectiles.end_attack_visual(StringName(visuals[e.id].scene_file_path), "Hit", ship)
				actor.ctx.projectiles.ship.damage(e.damage * actor.ctx.cfg.atk_scale,0.0,e.kind,&"hydra")
				e.hit = true
		e.previous_points=e.points.duplicate()
		var line: Node2D=visuals[e.id]
		line.update_effect(e, actor._time)
	ship_previous = ship

func _length(points: PackedVector2Array)->float:
	var result:=0.0
	for i in range(1,points.size()):result+=points[i-1].distance_to(points[i])
	return result
