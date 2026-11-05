## ビームの敵の砲口・予兆・照射。戦闘が出した長さ・幅・時刻を使う。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
var _settings: Dictionary = SETTINGS.for_id("G12-beamer")
var _last_world_time := -1.0
var _attacks := {}

func render(rows: Array, events: Array, canvas, world_time: float) -> void:
	if _last_world_time >= 0 and world_time < _last_world_time:
		_attacks.clear()
	_last_world_time = world_time
	var present := {}
	for row: Dictionary in rows:
		var id: int = row.order
		present[id] = true
		if not bool(row.get("owner_alive", true)) and _attacks.has(id):
			row = row.duplicate()
			row.enemy_radius = _attacks[id].row.enemy_radius
		_attacks[id] = {"row": row, "clock": world_time}
		_draw_active(row, canvas, world_time)
	for event: Dictionary in events:
		if event.get("type") != &"attack_retired":
			continue
		var id: int = event.id
		if not _attacks.has(id):
			continue
		if event.reason != "lifetime":
			_attacks.erase(id)
			continue
		var saved: Dictionary = _attacks[id]
		var row: Dictionary = saved.row
		saved.end_time = float(saved.clock) - float(row.time) + float(row.delay) + float(row.active)
	for id in _attacks.keys():
		if present.has(id):
			continue
		var saved: Dictionary = _attacks[id]
		if not saved.has("end_time"):
			continue
		var elapsed: float = world_time - float(saved.end_time)
		if elapsed >= 0.3 * float(_settings.timing):
			_attacks.erase(id)
		elif elapsed > 0:
			var row: Dictionary = saved.row
			FX.sparks(canvas.front, canvas.to_logical(row.pos), elapsed, 4, 8, Color(_settings.color), 30.0, 0.3)

func _draw_active(row: Dictionary, canvas, clock: float) -> void:
	var start: Vector2 = row.pos
	var end: Vector2 = start + Vector2.from_angle(float(row.angle)) * float(row.length)
	var a: Vector2 = canvas.to_logical(start)
	var b: Vector2 = canvas.to_logical(end)
	var time := float(row.time)
	var delay := float(row.delay)
	var active := float(row.active)
	var color := Color(_settings.color)
	var intensity := float(_settings.intensity)
	var size := float(_settings.size)
	var timing := float(_settings.timing)
	if time < delay:
		var charge := clampf(time / delay, 0.0, 1.0)
		FX.warn_rail(canvas.back, a, b, {"color": color, "k": charge, "time": clock, "seed": 3, "intensity": intensity, "maxLv": 2})
		FX.gather(canvas.front, a, float(row.enemy_radius) * 2.2 * size * canvas.world_scale, charge * intensity, color, clock, 16, 5)
	elif time <= delay + active:
		var elapsed := time - delay
		var left := active - elapsed
		var travel := maxf(0.001, float(_settings.travel) * timing)
		var head := minf(1.0, _smooth(0, travel, elapsed) * 1.0001)
		var tail := _smooth(travel, 0, left) if left < travel else 0.0
		if head > tail:
			FX.beam(canvas.front, a, b, {"color": color, "w": float(row.half_width) * canvas.world_scale, "time": clock, "alpha": minf(1, intensity), "from": tail, "to": head, "taper": 10 * size, "source": tail <= 0})
		if elapsed < travel * 1.5:
			FX.flare(canvas.front, a, 12 * size * canvas.world_scale, color, clock, 1 - elapsed / (travel * 1.5), 6)

func _smooth(a: float, b: float, value: float) -> float:
	var k := clampf((value - a) / (b - a), 0.0, 1.0)
	return k * k * (3 - 2 * k)
