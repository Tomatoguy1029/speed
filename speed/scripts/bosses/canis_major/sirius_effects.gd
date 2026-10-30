## おおいぬ座だけが持つ、技の終了後も残る炎。更新・判定は世界時間、描画は同じ状態を読む。
extends Node2D
const BEAM_VISUAL := preload("res://scenes/attacks/canis_flame_beam.tscn")
const BEAM_CANVAS := preload("res://scripts/render/attacks/canis_flame_beam.gd")
var tints: Dictionary = {}
var nova: RefCounted
var flash: ColorRect
var burning: Dictionary = {}
var transfers: Array = []
var particles: Array = []
var particle_canvas: ParticleCanvas
var actor: CanisMajorBoss
var trails: Array = []
var warnings: Array = []
var beam_canvas: Node2D

func bind(host: CanisMajorBoss) -> void:
	actor = host
	top_level = true
	position = Vector2.ZERO
	rotation = 0.0
	beam_canvas = BEAM_CANVAS.BeamCanvas.new()
	add_child(beam_canvas)
	particle_canvas = ParticleCanvas.new()
	add_child(particle_canvas)
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	flash = ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1,1,1,0)
	layer.add_child(flash)

func fire_beam(from: Vector2, angle: float, length: float, width: float, duration: float, damage: float) -> Dictionary:
	var direction := Vector2.from_angle(angle)
	var hit = actor.ctx.field.first_body_hit(from, from + direction * length, width * 0.5)
	if hit != null: length *= float(hit.t)
	var row: int = actor.ctx.projectiles.emit_attack(&"beam", [from, angle, length, width, 0.0, duration, damage * actor.ctx.cfg.atk_scale, actor.SIRIUS_COLOR], actor.rule().get("beam_visual", BEAM_VISUAL))
	if row >= 0: actor.ctx.projectiles.attach_hazard(row, actor.body)
	return {"from": from, "angle": angle, "length": length, "width": width, "row": row}

func add_trail(beam: Dictionary, r: Dictionary) -> void:
	var trail := beam.duplicate()
	trail.merge({"age": 0.0, "delay": r.trail_delay, "life": r.trail_time, "width": r.trail_width, "damage": r.trail_damage}, true)
	trails.append(trail)

func tick(dt: float) -> void:
	if nova != null:
		nova.update_effect(actor)
		if nova.finished(actor): nova = null
	flash.size = get_viewport_rect().size
	var flash_age: float = actor.clock - nova.started - float(nova.values.warn) if nova != null else -1.0
	flash.color.a = 0.7 * (1.0-flash_age/0.25) if flash_age >= 0.0 and flash_age < 0.25 else 0.0
	_tick_burning(dt)
	_tick_tints()
	_tick_particles(dt)
	for trail in trails:
		trail.age = float(trail.age) + dt
		if float(trail.age) < float(trail.delay) or float(trail.age) >= float(trail.life): continue
		var end: Vector2 = trail.from + Vector2.from_angle(float(trail.angle)) * float(trail.length)
		var reach := float(trail.width) * 0.5 + actor.ctx.cfg.ship_radius
		if Geometry2D.get_closest_point_to_segment(actor.run_state.ship_pos, trail.from, end).distance_to(actor.run_state.ship_pos) < reach:
			actor.ctx.ship.damage(float(trail.damage) * actor.ctx.cfg.atk_scale, 0.0, &"sirius_trail", &"canis_major")
	trails = trails.filter(func(trail): return float(trail.age) < float(trail.life))
	beam_canvas.beams.clear()
	for trail in trails:
		var visual: Dictionary = trail.duplicate()
		visual.width = 20.0
		visual.alpha = 0.65 * (1.0 - float(trail.age) / maxf(float(trail.life), 0.001))
		beam_canvas.beams.append(visual)
	beam_canvas.clock = actor.run_state.world_time
	beam_canvas.queue_redraw()
	queue_redraw()

func clear() -> void:
	if nova != null: nova.cancel(actor)
	for i: int in tints:
		if _valid(i,tints[i].id): actor.table.color[i] = tints[i].base
	tints.clear()
	if flash != null: flash.color.a = 0.0
	for i: int in burning:
		var entry: Dictionary = burning[i]
		if _valid(i, entry.id):
			actor._hounds().release_order(i)
			actor._set_max_hp(i, float(entry.base_hp))
			actor.table.color[i] = entry.base_color
	burning.clear()
	transfers.clear()
	trails.clear()
	particles.clear()
	if particle_canvas != null:
		particle_canvas.particles.clear()
		particle_canvas.queue_redraw()
	warnings.clear()
	if beam_canvas != null:
		beam_canvas.beams.clear()
		beam_canvas.queue_redraw()
	queue_redraw()

func _draw() -> void:
	_draw_nova()
	for transfer in transfers:
		if not _valid(transfer.row, transfer.id): continue
		var at: Vector2 = Vector2(transfer.from).lerp(actor.table.pos[transfer.row], clampf(float(transfer.age) / maxf(float(transfer.life),0.001),0,1))
		draw_circle(at, 8.0, Color(actor.SIRIUS_COLOR,0.3))
		draw_circle(at, 3.0, Color.WHITE)
	for i: int in burning:
		if not _valid(i, burning[i].id): continue
		# 燃える猟犬の正式な見た目は未決。既存の体色と仮の火の粉で示す。
		for k in 5:
			var life := fposmod(actor.clock * 2.0 + k * 0.618, 1.0)
			var at := actor.table.pos[i] + Vector2(sin(k * 2.4 + actor.clock) * 12.0, -life * 30.0)
			draw_circle(at, 2.5 * (1.0-life), Color(1.0,0.4+life*0.3,0.1,1.0-life))
	for warning in warnings:
		var direction := Vector2.from_angle(float(warning.angle))
		var length := float(warning.length)
		var hit = actor.ctx.field.first_body_hit(warning.from, warning.from + direction * length)
		if hit != null: length *= float(hit.t)
		var color := Color("#ff667d") if warning.locked else actor.SIRIUS_COLOR
		color.a = 0.35 if warning.locked else lerpf(0.12, 0.45, float(warning.progress))
		draw_line(warning.from, warning.from + direction * length, color, float(warning.width) if warning.locked else lerpf(1.0, 3.0, float(warning.progress)))

func flame_particle(at: Vector2, angle: float, r: Dictionary, harmful: bool) -> void:
	var spread := actor.run_state.rng.randf_range(-float(r.spread), float(r.spread)) * 0.5 if harmful else sin(actor.clock * 39.0) * 20.0
	var speed := float(r.particle_speed) * actor.run_state.rng.randf_range(0.9, 1.1) if harmful else 100.0
	particles.append({"pos": at, "vel": Vector2.from_angle(angle + deg_to_rad(spread)) * speed, "age": 0.0, "life": float(r.life) if harmful else 0.3, "r_start": float(r.r_start) if harmful else 4.0, "r_end": float(r.r_end) if harmful else 9.0, "drag": r.drag, "hit_scale": r.hit_scale, "damage": r.damage, "harmful": harmful})

func _tick_particles(dt: float) -> void:
	for particle in particles:
		particle.age = float(particle.age) + dt
		var from: Vector2 = particle.pos
		particle.vel *= exp(-float(particle.drag) * dt)
		particle.pos += particle.vel * dt
		var ratio := clampf(float(particle.age) / float(particle.life), 0.0, 1.0)
		particle.radius = lerpf(float(particle.r_start), float(particle.r_end), ratio)
		if actor.ctx.field.first_body_hit(from, particle.pos, float(particle.radius) * float(particle.hit_scale)) != null:
			particle.age = particle.life
		if particle.harmful and float(particle.age) < float(particle.life):
			if Vector2(particle.pos).distance_to(actor.run_state.ship_pos) < float(particle.radius) * float(particle.hit_scale) + actor.ctx.cfg.ship_radius:
				actor.ctx.ship.damage(float(particle.damage) * actor.ctx.cfg.atk_scale, 0.0, &"sirius_flame", &"canis_major")
	particles = particles.filter(func(particle): return float(particle.age) < float(particle.life))
	particle_canvas.particles = particles
	particle_canvas.queue_redraw()

class ParticleCanvas extends Node2D:
	var particles: Array = []
	func _ready() -> void:
		var shader_material := ShaderMaterial.new()
		shader_material.shader = preload("res://shaders/canis_flame_particle.gdshader")
		material = shader_material
	func _draw() -> void:
		for p in particles:
			var at: Vector2 = p.pos
			var r := float(p.get("radius", p.r_start))
			var alpha := (1.0 - float(p.age) / float(p.life)) * 0.48
			draw_primitive(PackedVector2Array([at+Vector2(-r,-r),at+Vector2(r,-r),at+Vector2(r,r),at+Vector2(-r,r)]), PackedColorArray([Color(1,1,1,alpha)]), PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]))

func _valid(i: int, id: int) -> bool:
	return actor.table.alive[i] != 0 and actor.table.dead[i] == 0 and actor.table.id[i] == id

func ignite(i: int, values: Dictionary) -> void:
	actor.led.erase(i)
	actor._led_ids.erase(i)
	actor._toughen_pack()
	var entry := {"id": actor.table.id[i], "base_hp": actor.table.max_hp[i], "base_color": actor.table.color[i], "age": 0.0, "blink_age": -1.0, "r": values}
	burning[i] = entry
	actor._set_max_hp(i, actor.ram_power() * 0.5)
	actor.table.color[i] = Color("#ff713d")
	actor._hounds().release_order(i)
	actor._cue(&"blaze_ignite", actor.table.pos[i])

func _tick_burning(dt: float) -> void:
	for transfer in transfers: transfer.age = float(transfer.age) + dt
	transfers = transfers.filter(func(t): return float(t.age) < float(t.life) and _valid(t.row,t.id))
	for i: int in burning.keys():
		var entry: Dictionary = burning[i]
		if not _valid(i, entry.id):
			burning.erase(i)
			continue
		var r: Dictionary = entry.r
		entry.age = float(entry.age) + dt
		var cfg: Dictionary = actor._rules[&"bay"].duplicate()
		cfg.max_speed = r.run_speed
		var blinking := float(entry.blink_age) >= 0.0
		if not blinking and (actor.table.pos[i].distance_to(actor.run_state.ship_pos) < float(r.stop_dist) or float(entry.age) >= float(r.max_run)):
			entry.blink_age = 0.0
			blinking = true
			actor._cue(&"blaze_blink", actor.table.pos[i])
		var goal: Vector2 = actor.table.pos[i] if blinking else actor.run_state.ship_pos
		actor._hounds().steer_follow(i, goal, actor.run_state.ship_pos, actor.run_state.world_time + actor.FOLLOW_HOLD, cfg)
		if not blinking: continue
		entry.blink_age = float(entry.blink_age) + dt
		var progress := clampf(float(entry.blink_age) / maxf(float(r.blink),0.001),0,1)
		actor.table.flash[i] = 0.05 if sin(progress * (3.0 + progress * 5.0) * TAU) > 0 else 0.0
		if float(entry.blink_age) >= float(r.blink):
			actor.ctx.projectiles.fire_zone(actor.table.pos[i], float(r.explode_radius), 0.0, float(r.damage) * actor.ctx.cfg.atk_scale, ProjectileSystem.HazardStyle.BLAST, actor.table.color[i])
			actor._cue(&"blaze_explode", actor.table.pos[i])
			actor.ctx.enemies.mark_dead(i)
			burning.erase(i)

func _draw_nova() -> void:
	if nova == null: return
	var r: Dictionary = nova.values
	var age: float = actor.clock-float(nova.started)
	var source := actor.mouth()
	var light := clampf((age-0.4)/maxf(float(r.warn)-0.4,0.001),0,1) if age < float(r.warn) else maxf(0.0,1.0-(age-float(r.warn))/maxf(float(r.after),0.001))
	for k in range(6,0,-1): draw_circle(source,900.0*k/6.0,Color(actor.SIRIUS_COLOR,light*0.022))
	for shadow in nova.shadows:
		var polygon := PackedVector2Array()
		for k in 13:
			var angle := float(shadow.angle)+lerpf(-float(shadow.half),float(shadow.half),k/12.0)
			polygon.append(source+Vector2.from_angle(angle)*float(shadow.near))
		for k in range(12,-1,-1):
			var angle := float(shadow.angle)+lerpf(-float(shadow.half),float(shadow.half),k/12.0)
			polygon.append(source+Vector2.from_angle(angle)*maxf(900.0,float(r.ring_end)))
		draw_colored_polygon(polygon,Color(0.0,0.01,0.025,light*0.65))
	for ring in int(r.rings):
		var elapsed: float = age-float(r.warn)-ring*float(r.ring_gap)
		if elapsed < 0: continue
		var radius: float = 30.0+float(r.ring_speed)*elapsed
		if radius > float(r.ring_end): continue
		for k in 256:
			var a := TAU*k/256.0
			var b := TAU*(k+1)/256.0
			if nova.in_shadow(actor,source+Vector2.from_angle((a+b)*0.5)*radius,0.0): continue
			draw_line(source+Vector2.from_angle(a)*radius,source+Vector2.from_angle(b)*radius,Color(actor.SIRIUS_COLOR,0.75),float(r.ring_band)*2.0)

func tint_hound(i: int, until: float, color: Color) -> void:
	var base: Color = tints[i].base if tints.has(i) and tints[i].id == actor.table.id[i] else actor.table.color[i]
	tints[i] = {"id": actor.table.id[i], "until": until, "color": color, "base": base}
	actor.table.color[i] = color

func _tick_tints() -> void:
	for i: int in tints.keys():
		var entry: Dictionary = tints[i]
		if not _valid(i,entry.id):
			tints.erase(i)
		elif actor.run_state.world_time >= float(entry.until):
			actor.table.color[i] = entry.base
			tints.erase(i)
		else: actor.table.color[i] = entry.color
