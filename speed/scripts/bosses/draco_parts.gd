## Authored armor follows the existing spine; the final two pieces are reserved for the tail.
extends Node2D
const FORM = preload("res://scripts/bosses/draco_form.gd")
const ARM_ROOT := Vector2(11, 5)
const ARM_WRIST := Vector2(27, 33)
const SHADER = preload("res://shaders/draco_part.gdshader")
const TEXTURES = {
	&"head": [preload("res://assets/pixel/draco/head.png"), preload("res://assets/pixel/draco/head_normal.png")],
	&"arm": [preload("res://assets/pixel/draco/arm.png"), preload("res://assets/pixel/draco/arm_normal.png")],
	&"claw": [preload("res://assets/pixel/draco/claw.png"), preload("res://assets/pixel/draco/claw_normal.png")],
	&"body_a": [preload("res://assets/pixel/draco/body_a.png"), preload("res://assets/pixel/draco/body_a_normal.png")],
	&"body_b": [preload("res://assets/pixel/draco/body_b.png"), preload("res://assets/pixel/draco/body_b_normal.png")],
	&"body_c": [preload("res://assets/pixel/draco/body_c.png"), preload("res://assets/pixel/draco/body_c_normal.png")],
	&"body_d": [preload("res://assets/pixel/draco/body_d.png"), preload("res://assets/pixel/draco/body_d_normal.png")],
	&"body_e": [preload("res://assets/pixel/draco/body_e.png"), preload("res://assets/pixel/draco/body_e_normal.png")],
	&"tail_joint": [preload("res://assets/pixel/draco/tail_joint.png"), preload("res://assets/pixel/draco/tail_joint_normal.png")],
	&"tail_tip": [preload("res://assets/pixel/draco/tail_tip.png"), preload("res://assets/pixel/draco/tail_tip_normal.png")],
}
var _segments: Array[Sprite2D] = []
var _head: Sprite2D
var _arms: Array[Sprite2D] = []
var _claws: Array[Sprite2D] = []
var _lighting: ShaderMaterial

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_lighting = ShaderMaterial.new()
	_lighting.shader = SHADER
	_head = _sprite(&"head")
	_head.z_index = 1
	# The snout stays aligned with the existing mouth origin (120 * head_scale).
	_head.offset = Vector2(0, 14)
	# Keep limbs on the body layer: negative Z falls behind the combat background.
	for _i in 4:
		var arm := _sprite(&"arm")
		arm.centered = false
		arm.offset = -ARM_ROOT
		_arms.append(arm)
		var claw := _sprite(&"claw")
		claw.centered = false
		claw.offset = -Vector2(13, 16)
		_claws.append(claw)

func _sprite(part: StringName) -> Sprite2D:
	var sprite := Sprite2D.new()
	var texture := CanvasTexture.new()
	texture.diffuse_texture = TEXTURES[part][0]
	texture.normal_texture = TEXTURES[part][1]
	sprite.texture = texture
	if part == &"tail_tip": sprite.offset.y = texture.get_height() * 0.5
	sprite.material = _lighting
	sprite.set_meta(&"part", part)
	add_child(sprite)
	return sprite

func pose(points: PackedVector2Array, width: float, head_scale: float, alpha := 1.0, cosmic := false, hit := 0.0, split_origin := Vector2.ZERO, split_axis := Vector2.ZERO) -> void:
	visible = points.size() >= 2 and alpha > 0.001
	if not visible: return
	modulate.a = alpha
	_lighting.set_shader_parameter("cosmic", cosmic)
	_lighting.set_shader_parameter("boss_hit_white", hit)
	var total := FORM.length(points)
	var distances := PackedFloat32Array()
	var body_end := maxf(0.0, total - width * 0.70)
	var cursor := minf(body_end, width * 0.43)
	while cursor < body_end:
		distances.append(cursor)
		cursor += maxf(1.0, width * 0.43 * FORM.taper(cursor / maxf(1.0, total)))
	if distances.is_empty() or body_end - distances[-1] > width * 0.08:
		distances.append(body_end)
	distances.append(maxf(body_end, total - width * 0.42))
	distances.append(total)
	var count := distances.size()
	if _segments.size() != count:
		for sprite in _segments: sprite.free()
		_segments.clear()
		for i in count:
			var part: StringName
			if i == count - 1: part = &"tail_tip"
			elif i == count - 2: part = &"tail_joint"
			else: part = [&"body_e", &"body_c", &"body_b", &"body_a", &"body_d"][mini(4, int(i * 5.0 / maxi(1, count - 2)))]
			_segments.append(_sprite(part))
	var samples := _sample_positions(points, distances)
	for i in count:
		var sprite := _segments[i]
		var t := distances[i] / maxf(1.0, total)
		var at := samples[i + 1]
		var direction := at - samples[i]
		# The final authored arrow points up; all preceding plates point down.
		sprite.rotation = direction.angle() + (PI * 0.5 if i == count - 1 else -PI * 0.5)
		var part_width := float(sprite.texture.get_width())
		sprite.scale = Vector2.ONE * width * FORM.taper(t) / part_width
		sprite.position = _split(at, split_origin, split_axis)
	_head.position = _split(points[0], split_origin, split_axis)
	_head.rotation = -PI * 0.5
	_head.scale = Vector2.ONE * head_scale * 2.0
	_pose_arms(points, width, total, split_origin, split_axis)

func _pose_arms(points: PackedVector2Array, width: float, total: float, split_origin: Vector2, split_axis: Vector2) -> void:
	for i in 4:
		var distance := minf(total, width * 0.9) if i < 2 else total * 0.66
		var samples := _sample_positions(points, PackedFloat32Array([distance, minf(total, distance + 2.0)]))
		var tangent := (samples[2] - samples[1]).normalized()
		var normal := tangent.orthogonal()
		var unit := width * FORM.taper(distance / maxf(1.0, total)) / 57.0
		var side := -1.0 if i % 2 == 0 else 1.0
		var arm := _arms[i]
		var direction := (normal * side - tangent * 0.3).normalized()
		var wrist := (ARM_WRIST - ARM_ROOT) * Vector2(-side, 1)
		arm.rotation = direction.angle() - wrist.angle()
		arm.scale = Vector2(-side, 1) * unit
		arm.position = _split(samples[1] + normal * side * width * FORM.taper(distance / maxf(1.0, total)) * 0.32, split_origin, split_axis)
		var claw := _claws[i]
		claw.rotation = arm.rotation
		claw.scale = arm.scale
		claw.position = arm.position + wrist.rotated(arm.rotation) * unit

func _split(point: Vector2, origin: Vector2, axis: Vector2) -> Vector2:
	return point + axis * (-1.0 if (point - origin).dot(axis) < 0.0 else 1.0)

## One pass over the spine keeps the narrow tail plates close without repeated path scans.
func _sample_positions(points: PackedVector2Array, distances: PackedFloat32Array) -> PackedVector2Array:
	var result := PackedVector2Array([points[0]])
	var segment := 0
	var traversed := 0.0
	for distance in distances:
		var span := points[segment].distance_to(points[segment + 1])
		while segment < points.size() - 2 and distance > traversed + span:
			traversed += span
			segment += 1
			span = points[segment].distance_to(points[segment + 1])
		result.append(points[segment].lerp(points[segment + 1], clampf((distance - traversed) / maxf(0.001, span), 0.0, 1.0)))
	return result
