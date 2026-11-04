## じょうぎ座の各砲口から始まる予告と光の壁。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
var _settings: Dictionary = SETTINGS.for_id("G12-ruler")
var _walls := {}
var _last_time := -1.0

func render(rows: Array, events: Array, canvas, clock: float) -> void:
	if _last_time >= 0.0 and clock < _last_time: _walls.clear()
	_last_time = clock
	var color := Color(_settings.color)
	var intensity := float(_settings.intensity)
	var timing := float(_settings.timing)
	var present := {}
	for row: Dictionary in rows:
		var side := float(row.side)
		var direction := Vector2.from_angle(float(row.angle))
		var normal := Vector2(-direction.y, direction.x)
		var origin: Vector2 = canvas.to_logical(row.pos)
		var end: Vector2 = canvas.to_logical(row.pos + direction * float(row.length))
		if bool(row.windup):
			var charge := float(row.charge)
			FX.warn_rail(canvas.back, origin, end, {"color": color, "k": charge, "time": clock, "seed": 30 + side, "intensity": intensity, "reveal": clampf(0.35 + 0.65 * charge * 1.4, 0.0, 1.0)})
			FX.gather(canvas.front, origin, float(row.radius) * 1.8 * float(_settings.size) * canvas.world_scale, charge * intensity, color, clock, 12, 7 + side)
			continue
		if not row.has("order"): continue
		var id := int(row.order)
		present[id] = true
		_walls[id] = {"row": row, "clock": clock}
		var t := float(row.time)
		var left := float(row.active) - t
		var fin := clampf(t / (0.12 * timing), 0.0, 1.0)
		var fout := clampf(left / (0.3 * timing), 0.0, 1.0)
		if fin * fout > 0.0:
			FX.beam(canvas.front, origin, end, {"color": color, "w": float(row.width) * 0.5 * (0.4 + 0.6 * fout) * canvas.world_scale, "time": clock + side, "alpha": minf(1.0, fin * (0.5 + 0.5 * fout) * intensity)})
			for offset in [-1.0, 1.0]:
				var shift: Vector2 = normal * offset * float(row.width) * 1.1 * canvas.world_scale
				FX.warn_rail(canvas.back, origin + shift, end + shift, {"color": color, "k": 0.35 * fout, "time": clock * 2, "seed": 20 + offset + side, "rail": 0.8, "intensity": fin * fout * intensity})
		if left < 0.3 * timing: _sparks(row, canvas, 0.3 * timing - left, color)
	for event: Dictionary in events:
		if event.get("type") != &"attack_retired": continue
		var id := int(event.id)
		if not _walls.has(id): continue
		if event.reason != "lifetime" and event.reason != "technique_end":
			_walls.erase(id)
			continue
		var saved: Dictionary = _walls[id]
		saved.end_time = float(event.get("world_t", clock))
	for id in _walls.keys():
		if present.has(id): continue
		var saved: Dictionary = _walls[id]
		if not saved.has("end_time"): continue
		var elapsed := clock - float(saved.end_time)
		if elapsed >= 0.3:
			_walls.erase(id)
		elif elapsed > 0.0:
			_sparks(saved.row, canvas, 0.3 * timing + elapsed, color)

func _sparks(row: Dictionary, canvas, elapsed: float, color: Color) -> void:
	FX.sparks(canvas.front, canvas.to_logical(row.pos), elapsed, 40 + float(row.side), 10, color, 40, 0.35, float(row.angle), 0.5)
