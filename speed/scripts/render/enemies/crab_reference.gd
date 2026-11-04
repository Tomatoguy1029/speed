## かに座の爪先の溜めと、閉じる軌跡。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
var _settings: Dictionary = SETTINGS.for_id("G12-crab")

func render(rows: Array, canvas, clock: float) -> void:
	var color := Color(_settings.color)
	var intensity := float(_settings.intensity)
	var size := float(_settings.size)
	for row: Dictionary in rows:
		var origin: Vector2 = canvas.to_logical(row.pos)
		var radius := float(row.radius) * float(_settings.reachR) * size
		var forward := float(row.angle)
		if bool(row.windup):
			var k := float(row.charge)
			var claw := lerpf(1.25, 0.6, _smooth(0.0, 0.45, k)) if k < 0.45 else (0.6 if k < 0.7 else lerpf(0.6, 0.9, _smooth(0.7, 1.0, k)))
			var head := (1.25 - claw) / (1.25 - 0.03)
			for side in [-1.0, 1.0]:
				var tip: Vector2 = canvas.to_logical(row.pos + Vector2.from_angle(forward + side * claw) * radius)
				FX.gather(canvas.front, tip, float(row.radius) * 0.7 * canvas.world_scale, k * intensity, color, clock + side, 7, 11 + side)
				FX.crescent(canvas.back, origin, radius * canvas.world_scale, forward + side * 1.25, forward + side * 0.03, head, 0, 4 * canvas.world_scale, color, 0.3 + 0.4 * k * intensity)
		else:
			var t := float(row.age)
			var linger := float(_settings.linger) * float(_settings.timing)
			if t >= 0.12 + linger: continue
			var head := lerpf((1.25 - 0.9) / (1.25 - 0.03), 1.0, _smooth(0.0, 0.12, t))
			var fade := 1.0 if t < 0.12 else 1.0 - _smooth(0.0, 1.0, (t - 0.12) / linger)
			var tail := 0.0 if t < 0.12 else 0.25 * (t - 0.12) / linger
			for side in [-1.0, 1.0]:
				FX.crescent(canvas.front, origin, radius * canvas.world_scale, forward + side * 1.25, forward + side * 0.03, head, tail, 22 * size * canvas.world_scale, color, fade * minf(1.0, intensity))
			if t < 0.4:
				var tip: Vector2 = canvas.to_logical(row.pos + Vector2.from_angle(forward) * radius)
				FX.sparks(canvas.front, tip, t - 0.08, 21, 14, Color("ffe2b0"), 60, 0.35, forward, 1.2)

func _smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
