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
var flash := 0.0
var frame := {}
var world_clock := -1.0
var rng := RandomNumberGenerator.new()
var particles: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var gather_emit := 0.0
var retained: bool:
	get: return not particles.is_empty() or not rings.is_empty()

func apply_frame(rows: Array, clock: float) -> void:
	var dt := maxf(0.0,clock-world_clock) if world_clock>=0.0 else 0.0
	if clock<world_clock: reset_frame()
	world_clock = clock
	frame = {}
	for row: Dictionary in rows:
		if row.get("technique","")=="lance" and row.stage<3: frame = row
	advance(dt)
	queue_redraw()

func reset_frame() -> void:
	particles.clear()
	rings.clear()
	flash = 0.0
	frame = {}
	world_clock = -1.0
	gather_emit = 0.0

func frame_event(event: Dictionary) -> void:
	if event.type==&"lance_launch":
		flash = maxf(flash,0.8)
		rings.append({"center":event.pos,"angle":0.0,"age":0.0,"life":0.35,"sonic":false})
	if event.type==&"sonic_boom": rings.append({"center":event.pos,"angle":Vector2(event.direction).angle(),"age":0.0,"life":0.4,"sonic":true})
	if event.type==&"lance_shatter":
		for j in shard_count:
			particles.append({"kind":&"shard","from":event.horn[0].lerp(event.horn[1],float(j)/maxf(1.0,shard_count-1.0)),"velocity":Vector2.from_angle(rng.randf_range(0.0,TAU))*rng.randf_range(80.0,240.0)*shard_speed_scale,"age":0.0,"life":rng.randf_range(0.6,0.9)})
	if event.type in [&"boss_defeated",&"boss_cancelled",&"final_strike"]: reset_frame()

func _ready() -> void:
	rng.randomize()

func advance(dt: float) -> void:
	flash = maxf(0.0,flash-dt*2.0)
	for index in range(particles.size() - 1, -1, -1):
		particles[index].age = float(particles[index].age) + dt
		if float(particles[index].age) >= float(particles[index].life): particles.remove_at(index)
	for index in range(rings.size() - 1, -1, -1):
		rings[index].age = float(rings[index].age) + dt
		if float(rings[index].age) >= float(rings[index].life): rings.remove_at(index)
	var gathering: bool = not frame.is_empty() and frame.stage==0 and frame.sequence_stage==0
	if not gathering:
		gather_emit = 0.0
		return
	gather_emit += gather_rate * dt
	var points: PackedVector2Array = frame.horn
	while gather_emit >= 1.0:
		gather_emit -= 1.0
		var from := points[1] + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(140.0, 260.0)
		particles.append({"kind": &"gather", "from": from, "to": points[0].lerp(points[1], 0.5), "age": 0.0, "life": gather_lifetime})

func _body_point(world_point: Vector2) -> Vector2:
	return world_point

func _draw() -> void:
	if flash>0.0:
		var inverse := get_canvas_transform().affine_inverse()
		var bounds := get_viewport_rect()
		draw_colored_polygon(PackedVector2Array([inverse*bounds.position,inverse*Vector2(bounds.end.x,bounds.position.y),inverse*bounds.end,inverse*Vector2(bounds.position.x,bounds.end.y)]),Color(1,1,1,flash*0.5))

	for ring: Dictionary in rings:
		var t := clampf(float(ring.age) / float(ring.life), 0.0, 1.0)
		if ring.sonic:
			var back := float(ring.angle) + PI - 0.0
			draw_arc(_body_point(ring.center), lerpf(40.0, 190.0, t), back - 0.9, back + 0.9, 32, Color(ENERGY, 0.5 * (1.0 - t)), ring_width * (1.0 - t) + 1.0, false)
		else:
			draw_arc(_body_point(ring.center), lerpf(40.0, 220.0, t), 0.0, TAU, 48, Color(ENERGY, 1.0 - t), ring_width, false)
	for particle: Dictionary in particles:
		var t := clampf(float(particle.age) / float(particle.life), 0.0, 1.0)
		var point: Vector2 = Vector2(particle.from).lerp(particle.to, t) if particle.kind == &"gather" else Vector2(particle.from) + Vector2(particle.velocity) * float(particle.age)
		draw_circle(_body_point(point), 2.5, Color(ENERGY, 1.0 - t))
	if frame.is_empty(): return

	var form: float = frame.form
	if form <= 0.0: return
	var points: PackedVector2Array = frame.horn
	var u := Vector2.from_angle(frame.facing)
	var head: float = (frame.head_length) * form
	# 判定線の先端が穂先。元の角先を引いて、表示だけ二重に伸ばさない。
	var tip := points[1]
	var horn_tip := tip - u * head
	draw_line(_body_point(points[0]), _body_point(horn_tip), HORN_LIGHT, (12.0 + 28.0 * form) * beam_width_scale, false)
	draw_line(_body_point(points[0]), _body_point(horn_tip), Color.WHITE, (7.0 + 5.0 * form) * beam_width_scale, false)
	var side := u.orthogonal() * 18.0 * form
	draw_colored_polygon(PackedVector2Array([_body_point(tip), _body_point(horn_tip + side), _body_point(horn_tip - u * head * 0.35), _body_point(horn_tip - side)]), HORN_LIGHT.lightened(0.8))
