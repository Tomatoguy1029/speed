## ぼうえんきょう座の照射と、照射後に残る細い光。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
var _settings: Dictionary = SETTINGS.for_id("G12-telescope")
var _beams := {}
var _last_time := -1.0

func render(beams: Array, events: Array, canvas, clock: float) -> void:
	if _last_time >= 0.0 and clock < _last_time: _beams.clear()
	_last_time = clock
	var color := Color(_settings.color)
	var intensity := float(_settings.intensity)
	var timing := float(_settings.timing)
	var present := {}
	for row: Dictionary in beams:
		var id := int(row.order)
		present[id] = true
		_beams[id] = {"row": row, "clock": clock}
		var t := float(row.time) - float(row.delay)
		if t < 0: continue
		var active := float(row.active)
		var remaining := active - t
		var fade := (1.0 - clampf(t / active, 0.0, 1.0) * 0.6) * _smooth(0.0, minf(0.08, active), remaining)
		var head := minf(1.0, _smooth(0.0, 0.06 * timing, t)) * 0.999 + 0.001
		var direction := Vector2.from_angle(float(row.angle))
		var origin: Vector2 = canvas.to_logical(row.pos)
		var end: Vector2 = canvas.to_logical(row.pos + direction * float(row.length))
		FX.beam(canvas.front, origin, end, {"color": color, "w": float(row.half_width) * canvas.world_scale, "time": clock, "alpha": minf(1.0, fade * 1.3 * intensity), "to": head, "taper": 10.0 * float(_settings.size)})
		if t < 0.08: FX.flare(canvas.front, origin, 16.0 * float(_settings.size) * canvas.world_scale, color, clock, 1.0 - t / 0.08, 6)
	for event: Dictionary in events:
		if event.get("type") != &"attack_retired": continue
		var id := int(event.id)
		if not _beams.has(id): continue
		if event.reason != "lifetime":
			_beams.erase(id)
			continue
		var saved: Dictionary = _beams[id]
		var row: Dictionary = saved.row
		saved.end_time = float(saved.clock) - float(row.time) + float(row.delay) + float(row.active)
	for id in _beams.keys():
		if present.has(id): continue
		var saved: Dictionary = _beams[id]
		if not saved.has("end_time"): continue
		var elapsed := clock - float(saved.end_time)
		var duration := 0.3 * timing
		if elapsed >= duration:
			_beams.erase(id)
		elif elapsed > 0.0:
			var row: Dictionary = saved.row
			var origin: Vector2 = canvas.to_logical(row.pos)
			var end: Vector2 = canvas.to_logical(row.pos + Vector2.from_angle(float(row.angle)) * float(row.length))
			FX.warn_rail(canvas.back, origin, end, {"color": color, "k": 0.2, "time": clock, "seed": 6, "rail": 1, "intensity": (1.0 - elapsed / duration) * intensity})
			FX.sparks(canvas.front, origin, elapsed, 9, 8, color, 35, 0.3, float(row.angle), 0.6)

func _smooth(a: float, b: float, value: float) -> float:
	var k := clampf((value - a) / (b - a), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)
