## Hydraが所有する攻撃形状。表示・掃引判定・世界時間の正を共有する。
extends Node2D
var actor: Node
var effects: Array[Dictionary] = []
var serial := 0
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
	var line := Line2D.new()
	line.texture = white
	line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.material = ShaderMaterial.new()
	line.material.shader = FX
	add_child(line)
	var effect := {"id": serial, "points": points, "width": width, "delay": delay, "life": life,
		"age": 0.0, "damage": damage, "kind": kind, "owner": owner,
		"owner_id": actor.table.id[owner] if owner >= 0 else -1, "velocity": velocity,
		"persistent": persistent, "hit": false, "line": line}
	effects.append(effect)
	return effect
func remove_owner(row: int) -> void:
	for e in effects:
		if e.owner == row and not e.persistent: e.life = 0.0
func clear_effects() -> void:
	for e in effects:
		if is_instance_valid(e.line): e.line.queue_free()
	effects.clear()
func intersects(points: PackedVector2Array, width: float, a: Vector2, b: Vector2) -> bool:
	var radius: float = width * 0.5 + actor.manager.cfg.ship_radius
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
		var prior: PackedVector2Array = e.points.duplicate()
		e.age += dt
		var alive: bool = e.owner < 0 or e.persistent or (actor.manager.enemies.is_same(e.owner,e.owner_id) and actor.table.dead[e.owner] == 0)
		if not alive or e.age >= e.delay + e.life:
			e.line.queue_free()
			effects.erase(e)
			continue
		if e.has("follow_row"):
			if not actor.manager.enemies.is_same(e.follow_row,e.follow_id) or actor.table.dead[e.follow_row]:
				e.life=0.0
				continue
			var at: Vector2 = actor.table.pos[e.follow_row]
			e.points=PackedVector2Array([at,at+Vector2(0.1,0)])
		if e.age >= e.delay:
			for i in e.points.size(): e.points[i] += e.velocity * dt
			var touching := intersects(e.points,e.width,ship_previous,ship) or intersects(prior,e.width,ship_previous,ship)
			# Moving projectiles sweep their front and back edges too.
			if not touching:
				for i in e.points.size():
					if intersects(PackedVector2Array([prior[i],e.points[i]]),e.width,ship_previous,ship): touching = true
			if touching and e.kind == &"wind":
				if not actor.run_state.tracing and not actor.run_state.glide and actor.run_state.ship_vel.length() < actor.run_state.stats.max_speed:
					actor.run_state.ship_vel += (e.points[-1]-e.points[0]).normalized() * float(actor.def.params.wind_force) * dt
			elif touching and not e.hit and e.damage > 0.0:
				actor.manager.projectiles.ship.damage(e.damage * actor.manager.cfg.atk_scale,0.0,e.kind,&"hydra")
				e.hit = true
		e.line.points = e.points
		e.line.width = e.width
		var color: Color = {&"rubble": Color(0.55,0.44,0.3), &"wind": Color(0.25,0.9,0.75), &"wind_blade": Color(0.3,1,0.8), &"lightning": Color(0.4,0.75,1), &"bite": Color(1,0.45,0.18)}.get(e.kind,Color(1,0.25,0.4))
		e.line.material.set_shader_parameter("tint", color)
		e.line.material.set_shader_parameter("clock", actor._time)
		e.line.material.set_shader_parameter("warning", e.age < e.delay)
		e.line.material.set_shader_parameter("span", maxf(1.0,e.points[0].distance_to(e.points[-1])))
		e.line.material.set_shader_parameter("thickness", e.width)
	ship_previous = ship
