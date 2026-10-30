## 仮表示。正式は shader。斬撃の判定線と、表示専用の乱数で針状の光を描く。
extends Node2D
@export var technique_id: StringName = &"sword_flash"
var actor: MonocerosBoss
var rng := RandomNumberGenerator.new()
var effects: Array[Dictionary] = []
var retained: bool:
	get: return not effects.is_empty()

func _ready() -> void:
	rng.randomize()

func on_event(event: Dictionary) -> void:
	if event.cue in [&"defeated", &"final_strike"]:
		effects.clear()
	elif event.technique == technique_id and event.cue == &"slash_release":
		var line := actor.last_slash.duplicate()
		var width := float(actor.rule().slash_width)
		effects.append({"line": line, "width": width, "age": 0.0, "life": 0.6})
		var heading := (line[1] - line[0]).angle()
		for j in 7:
			var center := line[0].lerp(line[1], rng.randf_range(0.15, 0.95))
			var u := Vector2.from_angle(heading + rng.randf_range(-0.25, 0.25))
			var half := rng.randf_range(120.0, 340.0) * 0.5
			effects.append({"line": PackedVector2Array([center - u * half, center + u * half]), "width": rng.randf_range(4.0, 8.0), "age": 0.0, "life": rng.randf_range(0.45, 0.65)})

func advance(dt: float) -> void:
	for index in range(effects.size() - 1, -1, -1):
		effects[index].age = float(effects[index].age) + dt
		if float(effects[index].age) >= float(effects[index].life): effects.remove_at(index)

func _body_point(world_point: Vector2) -> Vector2:
	return (world_point - actor.table.pos[actor.body]).rotated(-actor.table.facing[actor.body])

func _needle(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var center := (a + b) * 0.5
	var side := (b - a).normalized().orthogonal() * width * 0.5
	draw_colored_polygon(PackedVector2Array([a, center + side, b, center - side]), color)

func _draw() -> void:
	if actor == null or not actor.has_body(): return
	for effect: Dictionary in effects:
		var t := clampf(float(effect.age) / float(effect.life), 0.0, 1.0)
		var taper := 1.0 if t <= 0.25 else (1.0 - t) / 0.75
		var line: PackedVector2Array = effect.line
		var a := _body_point(line[0])
		var b := _body_point(line[1])
		_needle(a, b, float(effect.width) * 1.6 * taper, Color(Color("#c9a6ff"), 1.0 - t * t))
		_needle(a, b, float(effect.width) * 0.6 * taper, Color(Color.WHITE, 1.0 - t * t))
