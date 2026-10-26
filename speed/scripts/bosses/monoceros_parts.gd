extends Node2D

const LEG_PATHS := ["FrontLeftLeg", "FrontRightLeg", "RearLeftLeg", "RearRightLeg"]
@export var gait: SpriteFrames
var _feet: Array[Sprite2D] = []
var _elapsed := 0.0


func _ready() -> void:
	for path in LEG_PATHS:
		_feet.append(get_node(path + "/Foot/Sprite") as Sprite2D)


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
	sprite.texture = gait.get_frame_texture(&"run", frame)
	sprite.position = Vector2(-floorf(sprite.texture.get_width() * 0.5), -6)
