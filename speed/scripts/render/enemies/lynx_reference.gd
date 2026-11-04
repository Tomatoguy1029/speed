## やまねこの爪先の予兆と、外から内へ伸びる3本の傷。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
const FROM := [0.03, 0.0, 0.05]
const TO := [0.9, 1.0, 0.86]
var _settings: Dictionary = SETTINGS.for_id("G12-lynx")

func render(shots: Array, actors: Array, canvas, world_time: float) -> void:
	var color := Color(_settings.color)
	var palette := FX.ramp(color)
	var span := deg_to_rad(float(_settings.span))
	var multiplier := float(_settings.maxSize) * float(_settings.size)
	var initial := float(_settings.start)
	var grow := maxf(0.01, float(_settings.grow) * float(_settings.timing))
	var cut_time := maxf(0.01, float(_settings.cutT) * float(_settings.timing))
	canvas.front.place(0, 0)
	for shot: Dictionary in shots:
		var age := float(shot.age)
		var fraction := clampf(age / grow, 0.0, 1.0)
		var ease := 1.0 - pow(1.0 - fraction, 3.0)
		var full := float(shot.size) * multiplier
		var size := full * lerpf(initial, 1.0, ease)
		if size <= 0:
			continue
		var initial_size := full * initial
		var shift: Vector2 = (shot.paw - _at(Vector2.ZERO, float(shot.angle), float(shot.side), initial_size, span, 0.0, 0.0)) * (initial_size / size)
		var origin: Vector2 = shot.pos + shift
		for k in 3:
			_scratch(canvas, origin, float(shot.angle), float(shot.side), size, span, k, minf(1, age / cut_time), palette, minf(1, float(_settings.intensity)))
	for actor: Dictionary in actors:
		var angle := float(actor.angle)
		var side := float(actor.side)
		var radius := float(actor.radius)
		var charge := float(actor.charge)
		var forward := Vector2.from_angle(angle)
		var across := Vector2(-forward.y, forward.x)
		var paw: Vector2 = actor.pos + forward * (radius * 0.55) + across * (side * radius * 0.6)
		var initial_size := float(actor.slash_size) * multiplier * initial
		var raw_mouth: Vector2 = actor.pos + forward * radius
		var shift := paw - raw_mouth - _at(Vector2.ZERO, angle, side, initial_size, span, 0.0, 0.0)
		var origin := raw_mouth + shift
		for k in 3:
			var tip: Vector2 = canvas.to_logical(_mark(origin, angle, side, initial_size, span, float(_settings.gap), k, FROM[k]))
			var flicker := 0.6 + 0.4 * sin(world_time * 40 + k * 2)
			canvas.front.glow(tip.x, tip.y, 3 + 3 * charge, palette[4], charge * flicker * float(_settings.intensity))
			canvas.front.px(tip.x, tip.y, palette[4] if charge > 0.6 else palette[3])

func _at(origin: Vector2, angle: float, side: float, size: float, span: float, gap: float, progress: float) -> Vector2:
	var forward := Vector2.from_angle(angle)
	var across := Vector2(-forward.y, forward.x) * side
	var center := origin + (across * (0.12 + gap) - forward * 0.70) * size
	var phi := -PI / 2 + span * (1 - progress)
	return center + (across * 1.15 * cos(phi) - forward * 0.85 * sin(phi)) * size

func _mark(origin: Vector2, angle: float, side: float, size: float, span: float, gap: float, k: int, progress: float) -> Vector2:
	var before := _at(origin, angle, side, size, span, gap, maxf(0, progress - 0.01))
	var after := _at(origin, angle, side, size, span, gap, minf(1, progress + 0.01))
	var tangent := (after - before).normalized()
	var normal := Vector2(-tangent.y, tangent.x)
	var spacing := lerpf(float(_settings.space0), float(_settings.space1), progress)
	return _at(origin, angle, side, size, span, gap, progress) + normal * ((k - 1) * spacing * size)

func _scratch(canvas, origin: Vector2, angle: float, side: float, size: float, span: float, k: int, cut: float, palette: Array[Color], alpha: float) -> void:
	var count := maxi(10, floori(size * canvas.world_scale * 1.6 + 0.5))
	var thickness: float = 0.07 * size * canvas.world_scale * 0.9
	for i in count:
		var m := float(i) / count
		var a := lerpf(FROM[k], TO[k], m)
		var b := lerpf(FROM[k], TO[k], float(i + 1) / count)
		if a > cut:
			break
		var start: Vector2 = canvas.to_logical(_mark(origin, angle, side, size, span, float(_settings.gap), k, a))
		var end: Vector2 = canvas.to_logical(_mark(origin, angle, side, size, span, float(_settings.gap), k, minf(cut, b)))
		var width: float = thickness * smoothstep(0.0, 0.1, m) * pow(1 - m, 0.7) * (0.85 + 0.3 * FX.hash_value(k * 17 + floorf(m * 9)))
		if width < 0.25:
			canvas.front.dot(start.x, start.y, palette[3], alpha * 0.8)
			continue
		var direction := end - start
		var normal := Vector2(-direction.y, direction.x).normalized()
		var q := -width
		while q <= width:
			var edge := absf(q) / width
			var point := start + normal * q
			canvas.front.dot(point.x, point.y, palette[4] if edge < 0.4 else (palette[3] if edge < 0.75 else palette[2]), alpha)
			q += 0.5
		if i % 3 == 0:
			canvas.front.light(start.x, start.y, palette[2], 0.25 * alpha)
	if cut < TO[k] and cut > FROM[k]:
		var tip: Vector2 = canvas.to_logical(_mark(origin, angle, side, size, span, float(_settings.gap), k, cut))
		canvas.front.glow(tip.x, tip.y, 4, palette[4], 0.6 * alpha)
