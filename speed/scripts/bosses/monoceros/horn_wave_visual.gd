## 仮表示。正式は shader。判定と同じ弧・幅・寿命で衝撃波を描く。
extends Node2D
const ENERGY := preload("res://scripts/bosses/monoceros/technique_visual.gd").ENERGY
@export var technique_id: StringName = &"horn_wave"
var actor: MonocerosBoss
var rings: Array[Dictionary] = []
var retained: bool:
	get: return actor != null and not actor.horn_waves.is_empty()

func on_event(event: Dictionary) -> void:
	if event.cue in [&"defeated", &"final_strike"]:
		rings.clear()
	elif event.technique == technique_id and event.cue == &"wave_release":
		rings.append({"center": actor.horn_points()[1], "time": 0.0})

func advance(dt: float) -> void:
	for index in range(rings.size() - 1, -1, -1):
		rings[index].time = float(rings[index].time) + dt
		if float(rings[index].time) >= 0.3: rings.remove_at(index)

func _body_point(world_point: Vector2) -> Vector2:
	return (world_point - actor.table.pos[actor.body]).rotated(-actor.table.facing[actor.body])

func _draw() -> void:
	if actor == null or not actor.has_body(): return
	var color := ENERGY.lerp(Color.WHITE, 0.5)
	for wave: Dictionary in actor.horn_waves:
		var facing := float(wave.angle) - actor.table.facing[actor.body]
		draw_arc(_body_point(wave.center), float(wave.radius), facing - float(wave.half), facing + float(wave.half), 48, Color(color, 1.0 - float(wave.radius) / maxf(float(wave.max), 0.001)), float(wave.width), false)
	for ring: Dictionary in rings:
		var t := clampf(float(ring.time) / 0.3, 0.0, 1.0)
		draw_arc(_body_point(ring.center), lerpf(10.0, 60.0, t), 0.0, TAU, 32, Color(ENERGY, 1.0 - t), 3.0, false)
	if actor.technique == technique_id and actor.mode in [&"windup", &"active"]:
		var points := actor.horn_points()
		draw_line(_body_point(points[0]), _body_point(points[1]), Color(ENERGY, float(actor._runner.glow_level)), 7.0, false)
