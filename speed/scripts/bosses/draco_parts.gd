## Authored armor follows the existing spine; the final two pieces are reserved for the tail.
extends Node2D
const FORM = preload("res://scripts/bosses/draco_form.gd")
const ARM_ROOT := Vector2(11, 5)
const ARM_WRIST := Vector2(27, 33)
const SHADER = preload("res://shaders/draco_part.gdshader")
const PICARO_SHADER = preload("res://shaders/picaro.gdshader")
const PICARO_LOOK = preload("res://scripts/render/picaro_look.gd")
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
var _entrance_materials := {}
var _entrance_distances := {}
var _entrance_length := 1.0
var _lighting: ShaderMaterial

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _lighting == null:
		_lighting = ShaderMaterial.new()
		_lighting.shader = SHADER
	_lighting.set_shader_parameter("linear_target",get_viewport().use_hdr_2d)
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

## 全身複製はピカロの一種なので、全部の部位を敵のピカロと同じシェーダーで描く。
## 絵の腕だけを根元から回す量（ラジアン）。
var arm_turns := [0.0,0.0,0.0,0.0]
func use_picaro(seed: float) -> void:
	var noise: Texture2D = PICARO_LOOK.noise_texture()
	_lighting = ShaderMaterial.new()
	_lighting.shader = PICARO_SHADER
	_lighting.set_shader_parameter("noise_smooth", noise)
	_lighting.set_shader_parameter("noise_dots", noise)
	_lighting.set_shader_parameter("seed", seed)
	if is_inside_tree(): _lighting.set_shader_parameter("linear_target",get_viewport().use_hdr_2d)
	for child in get_children():
		if child is Sprite2D: child.material = _lighting

## 決着の閃光のあいだだけ、竜の色と切り口を決着の表示から受け取る。
func set_finale_tone(tone: Dictionary) -> void:
	_lighting.set_shader_parameter("finale_tone",tone.get("on",false))
	_lighting.set_shader_parameter("finale_gray",tone.get("gray",0.0))
	_lighting.set_shader_parameter("finale_lit",tone.get("lit",0.0))
	_lighting.set_shader_parameter("finale_gap",tone.get("gap",0.0))
	_lighting.set_shader_parameter("finale_center",tone.get("center",Vector2.ZERO))

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
	_entrance_length = maxf(1.0,total)
	_entrance_distances.clear()
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
		for sprite in _segments:
			_entrance_materials.erase(sprite.get_instance_id())
			sprite.free()
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
		_entrance_distances[sprite] = distances[i]
		var t := distances[i] / maxf(1.0, total)
		var at := samples[i + 1]
		var direction := at - samples[i]
		# The final authored arrow points up; all preceding plates point down.
		sprite.rotation = direction.angle() + (PI * 0.5 if i == count - 1 else -PI * 0.5)
		var part_width := float(sprite.texture.get_width())
		sprite.scale = Vector2.ONE * width * FORM.taper(t) / part_width
		sprite.position = _split(at, split_origin, split_axis)
	_entrance_distances[_head] = 0.0
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
		arm.rotation = direction.angle() - wrist.angle() + arm_turns[i]
		arm.scale = Vector2(-side, 1) * unit
		arm.position = _split(samples[1] + normal * side * width * FORM.taper(distance / maxf(1.0, total)) * 0.32, split_origin, split_axis)
		_entrance_distances[arm] = distance
		var claw := _claws[i]
		_entrance_distances[claw] = distance
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

## 頭から尾まで順に奥行きを抜ける。色の透明度は使わず、位置・大きさ・遮蔽で見せる。
func entrance(intro: Dictionary, portal: Vector2, quiet: float) -> void:
	var active: bool = intro.get("active",false)
	for sprite: Sprite2D in _entrance_distances:
		if not active:
			sprite.material = _lighting
			sprite.visible = true
			continue
		var id := sprite.get_instance_id()
		if not _entrance_materials.has(id):
			_entrance_materials[id] = _lighting.duplicate()
		var mat: ShaderMaterial = _entrance_materials[id]
		sprite.material = mat
		var along := float(_entrance_distances[sprite])/_entrance_length
		var travel := clampf(float(intro.emerged)*1.8-along*0.8,0.0,1.0)
		var depth := smoothstep(0.0,1.0,travel)
		var head := sprite==_head
		sprite.visible = float(intro.time)>=quiet+0.35 and (head or travel>0.0)
		var target := sprite.position
		sprite.position = portal.lerp(target,depth)
		sprite.scale *= lerpf(0.16,1.0,depth)
		mat.set_shader_parameter("entrance",true)
		mat.set_shader_parameter("entrance_head",head)
		mat.set_shader_parameter("entrance_depth",depth)
		mat.set_shader_parameter("entrance_eyes",float(intro.eyes))
		mat.set_shader_parameter("entrance_portal",to_global(portal))
		mat.set_shader_parameter("entrance_open",float(intro.rift))
