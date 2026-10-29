extends Node2D

const LEG_PATHS := ["FrontLeftLeg", "FrontRightLeg", "RearLeftLeg", "RearRightLeg"]
const LIGHTING = preload("res://data/visuals/enemy_lighting.tres")
@export var gait: SpriteFrames
var _feet: Array[Node2D] = []
var _elapsed := 0.0
var editable_parts: Dictionary = {}
var _defaults: Dictionary = {}
var _appearance: Dictionary = {}
var _appearance_hash := -1


func _ready() -> void:
	for path in LEG_PATHS:
		_feet.append(get_node(path + "/Foot/Sprite") as Node2D)
	_collect_parts(self)
	apply_appearance({})


func _collect_parts(parent: Node) -> void:
	for child in parent.get_children():
		if child is Node2D and child.has_meta("part_label"):
			var key := String(get_path_to(child))
			editable_parts[key] = child
			_defaults[key] = child.position
		if child is Sprite2D and child.material is ShaderMaterial:
			child.material = child.material.duplicate()
			var material := child.material as ShaderMaterial
			material.set_shader_parameter("normal_flip_x", child.flip_h)
			for field in ["ambient", "normal_strength", "key_energy", "fill_energy"]:
				material.set_shader_parameter(field, LIGHTING.get(field))
			for entry in [["key_direction", LIGHTING.key_angle], ["fill_direction", LIGHTING.fill_angle]]:
				var direction := Vector2.from_angle(deg_to_rad(float(entry[1])))
				material.set_shader_parameter(entry[0], Vector3(direction.x, direction.y, LIGHTING.height).normalized())
		_collect_parts(child)


func apply_appearance(values: Dictionary) -> void:
	if hash(values) == _appearance_hash: return
	_appearance_hash = hash(values)
	_appearance = values.duplicate(true)
	for key in editable_parts:
		var part: Node2D = editable_parts[key]
		part.position = _defaults[key] + part_offset(key)
		if part is Sprite2D:
			var paint: String = String(_appearance.get(key, {}).get("color", ""))
			var material := part.material as ShaderMaterial
			material.set_shader_parameter("painted", not paint.is_empty())
			material.set_shader_parameter("paint", Color.from_string(paint, Color.WHITE))


func part_offset(key: String) -> Vector2:
	var value: Array = _appearance.get(key, {}).get("offset", [0, 0])
	return Vector2(float(value[0]), float(value[1]))


func rest_position(key: String) -> Vector2:
	return _defaults[key] + part_offset(key)


func cycle_seconds() -> float:
	var total := 0.0
	for index in gait.get_frame_count(&"run"):
		total += gait.get_frame_duration(&"run", index) / gait.get_animation_speed(&"run")
	return total


func frame_at(time: float) -> int:
	var remaining := fmod(time, cycle_seconds())
	for index in gait.get_frame_count(&"run"):
		var duration := gait.get_frame_duration(&"run", index) / gait.get_animation_speed(&"run")
		if remaining < duration:
			return index
		remaining -= duration
	return 0


func show_gait(time: float) -> void:
	var first := frame_at(time)
	var opposite := frame_at(time + cycle_seconds() * 0.5)
	for index in _feet.size():
		_set_frame(index, first if index == 0 or index == 3 else opposite)


func advance_gait(dt: float, moving: bool) -> void:
	if moving:
		_elapsed = fmod(_elapsed + dt, cycle_seconds())
		show_gait(_elapsed)
	else:
		_elapsed = 0.0
		for index in _feet.size():
			_set_frame(index, 3)


func _set_frame(index: int, frame: int) -> void:
	var sprite := _feet[index]
	(sprite.get_parent() as Node2D).position = Vector2(-5 if index % 2 == 0 else 4, 40)
	var base := sprite.get_node("Base") as Sprite2D
	base.texture = gait.get_frame_texture(&"run", frame)
	(sprite.get_node("Armor") as Sprite2D).texture = gait.get_frame_texture(&"armor", frame)
	sprite.position = Vector2(-floorf(base.texture.get_width() * 0.5), -6) + part_offset(String(get_path_to(sprite)))
