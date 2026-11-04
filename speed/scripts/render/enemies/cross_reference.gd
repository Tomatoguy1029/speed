## 十字レーザーの予告、照射、自然終了後の余光。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
var _settings: Dictionary = SETTINGS.for_id("G12-cross")
var _beams := {}
var _last_time := -1.0

func render(actors: Array, beams: Array, events: Array, canvas, world_time: float) -> void:
	if _last_time >= 0.0 and world_time < _last_time: _beams.clear()
	_last_time = world_time
	var color := Color(_settings.color)
	var intensity := float(_settings.intensity)
	for actor: Dictionary in actors:
		var origin: Vector2 = canvas.to_logical(actor.pos)
		var charge := float(actor.charge)
		for q in range(4):
			var end: Vector2 = canvas.to_logical(actor.pos + Vector2.from_angle(q * PI / 2.0) * float(actor.length) * (0.25 + 0.75 * charge))
			FX.warn_rail(canvas.back, origin, end, {"color": color, "k": charge, "time": world_time, "seed": q + 1, "intensity": intensity})
		FX.gather(canvas.front, origin, float(actor.radius) * 2.4 * float(_settings.size) * canvas.world_scale, charge * intensity, color, world_time, 18, 3)
	var present := {}
	for row: Dictionary in beams:
		var id := int(row.order)
		present[id] = true
		_beams[id] = {"row": row, "clock": world_time}
		if float(row.time) < float(row.delay): continue
		var u := (float(row.time) - float(row.delay)) / float(row.active)
		var k := clampf((u - 0.75) / 0.25, 0.0, 1.0)
		var alpha := minf(1.0, (1.0 - k * k * (3.0 - 2.0 * k)) * intensity)
		var origin: Vector2 = canvas.to_logical(row.pos)
		var end: Vector2 = canvas.to_logical(row.pos + Vector2.from_angle(float(row.angle)) * float(row.length))
		var q := posmod(roundi(float(row.angle) / (PI / 2.0)), 4)
		FX.beam(canvas.front, origin, end, {"color": color, "w": float(row.half_width) * canvas.world_scale, "time": world_time + q, "alpha": alpha, "source": false})
		if q == 0: FX.flare(canvas.front, origin, 16.0 * float(_settings.size) * canvas.world_scale, color, world_time, alpha, 4)
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
		var elapsed := world_time - float(saved.end_time)
		var duration := 0.25 * float(_settings.timing)
		if elapsed >= duration:
			_beams.erase(id)
		elif elapsed > 0.0:
			var row: Dictionary = saved.row
			var origin: Vector2 = canvas.to_logical(row.pos)
			var end: Vector2 = canvas.to_logical(row.pos + Vector2.from_angle(float(row.angle)) * float(row.length) * 0.6)
			var q := posmod(roundi(float(row.angle) / (PI / 2.0)), 4)
			FX.warn_rail(canvas.back, origin, end, {"color": color, "k": 0.2, "time": world_time, "seed": 7 + q, "intensity": (1.0 - elapsed / duration) * intensity, "rail": 1})
