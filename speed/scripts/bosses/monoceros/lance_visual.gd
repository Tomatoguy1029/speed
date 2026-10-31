## 仮表示。正式は shader。槍の判定線を使い、光粒・輪・砕ける粒は表示だけで保持する。
extends Node2D
const HORN_LIGHT := preload("res://scripts/bosses/monoceros/technique_visual.gd").WARNING
const ENERGY := preload("res://scripts/bosses/monoceros/technique_visual.gd").ENERGY
@export var technique_id: StringName = &"lance"
@export_range(0.0, 160.0, 1.0) var gather_rate := 54.0
@export_range(0.05, 1.0, 0.05) var gather_lifetime := 0.4
@export_range(0, 64, 1) var shard_count := 20
@export_range(0.25, 3.0, 0.05) var shard_speed_scale := 1.0
@export_range(0.5, 8.0, 0.25) var ring_width := 3.0
@export_range(0.25, 3.0, 0.05) var beam_width_scale := 1.0
var actor: MonocerosBoss
var rng := RandomNumberGenerator.new()
var particles: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var gather_emit := 0.0
var retained: bool:
	get: return not particles.is_empty() or not rings.is_empty()

func _ready() -> void:
	rng.randomize()

func on_event(event: Dictionary) -> void:
	if event.cue in [&"defeated", &"final_strike"]:
		particles.clear()
		rings.clear()
		return
	if event.technique != technique_id: return
	var u := Vector2.from_angle(actor.table.facing[actor.body])
	match event.cue:
		&"lance_launch":
			rings.append({"center": actor.table.pos[actor.body], "angle": 0.0, "age": 0.0, "life": 0.35, "sonic": false})
			_existing_screen_flash()
		&"sonic_boom":
			rings.append({"center": actor.table.pos[actor.body] + u * float(actor.rule().boom_ahead), "angle": u.angle(), "age": 0.0, "life": 0.4, "sonic": true})
		&"lance_shatter":
			var points := actor.horn_points()
			# formが0へ戻った瞬間なので、砕ける前の穂先までを復元する。
			var tip := actor.table.pos[actor.body] + u * (actor.horn_length() + float(actor.rule().head_length))
			for j in shard_count:
				particles.append({"kind": &"shard", "from": points[0].lerp(tip, float(j) / maxf(1.0, shard_count - 1.0)), "velocity": Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(80.0, 240.0) * shard_speed_scale, "age": 0.0, "life": rng.randf_range(0.6, 0.9)})

func _existing_screen_flash() -> void:
	var parent := actor.get_parent()
	if parent == null or parent.get_parent() == null: return
	var display := parent.get_parent().get_node_or_null("RunPresentation") as RunPresentation
	if display != null and display.run != null and display.run.ctx == actor.ctx:
		# 既存の白い光は毎秒2ずつ減るので、0.4秒分を渡す。
		display.flash = maxf(display.flash, 0.4 * 2.0)

func advance(dt: float) -> void:
	for index in range(particles.size() - 1, -1, -1):
		particles[index].age = float(particles[index].age) + dt
		if float(particles[index].age) >= float(particles[index].life): particles.remove_at(index)
	for index in range(rings.size() - 1, -1, -1):
		rings[index].age = float(rings[index].age) + dt
		if float(rings[index].age) >= float(rings[index].life): rings.remove_at(index)
	if actor == null or actor.technique != technique_id or actor.mode != &"windup" or actor._runner.stage != &"gather":
		gather_emit = 0.0
		return
	gather_emit += gather_rate * dt
	var points := actor.horn_points()
	while gather_emit >= 1.0:
		gather_emit -= 1.0
		var from := points[1] + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(140.0, 260.0)
		particles.append({"kind": &"gather", "from": from, "to": points[0].lerp(points[1], 0.5), "age": 0.0, "life": gather_lifetime})

func _body_point(world_point: Vector2) -> Vector2:
	return (world_point - actor.table.pos[actor.body]).rotated(-actor.table.facing[actor.body])

func _draw() -> void:
	if actor == null or not actor.has_body(): return
	for ring: Dictionary in rings:
		var t := clampf(float(ring.age) / float(ring.life), 0.0, 1.0)
		if ring.sonic:
			var back := float(ring.angle) + PI - actor.table.facing[actor.body]
			draw_arc(_body_point(ring.center), lerpf(40.0, 190.0, t), back - 0.9, back + 0.9, 32, Color(ENERGY, 0.5 * (1.0 - t)), ring_width * (1.0 - t) + 1.0, false)
		else:
			draw_arc(_body_point(ring.center), lerpf(40.0, 220.0, t), 0.0, TAU, 48, Color(ENERGY, 1.0 - t), ring_width, false)
	for particle: Dictionary in particles:
		var t := clampf(float(particle.age) / float(particle.life), 0.0, 1.0)
		var point: Vector2 = Vector2(particle.from).lerp(particle.to, t) if particle.kind == &"gather" else Vector2(particle.from) + Vector2(particle.velocity) * float(particle.age)
		draw_circle(_body_point(point), 2.5, Color(ENERGY, 1.0 - t))
	if actor.technique != technique_id or actor.mode not in [&"windup", &"active"]: return
	var form := float(actor._runner.form)
	if form <= 0.0: return
	var points := actor.horn_points()
	var u := Vector2.from_angle(actor.table.facing[actor.body])
	var head := float(actor.rule().head_length) * form
	# 判定線の先端が穂先。元の角先を引いて、表示だけ二重に伸ばさない。
	var tip := points[1]
	var horn_tip := tip - u * head
	draw_line(_body_point(points[0]), _body_point(horn_tip), HORN_LIGHT, (12.0 + 28.0 * form) * beam_width_scale, false)
	draw_line(_body_point(points[0]), _body_point(horn_tip), Color.WHITE, (7.0 + 5.0 * form) * beam_width_scale, false)
	var side := u.orthogonal() * 18.0 * form
	draw_colored_polygon(PackedVector2Array([_body_point(tip), _body_point(horn_tip + side), _body_point(horn_tip - u * head * 0.35), _body_point(horn_tip - side)]), HORN_LIGHT.lightened(0.8))
