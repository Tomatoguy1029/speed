## レチクル座の照準と、岩を撃ったときの光と破片。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
var _settings: Dictionary = SETTINGS.for_id("G12-reticle")
var _shots: Array = []
var _last_time := -1.0
var _epoch := -1
var _sequence := 0

func render(rows: Array, events: Array, canvas, clock: float) -> void:
	if _last_time >= 0 and clock < _last_time:
		_shots.clear()
		_sequence = 0
	_last_time = clock
	var color := Color(_settings.color)
	var intensity := float(_settings.intensity)
	var palette := FX.ramp(color)
	for row: Dictionary in rows:
		var k := float(row.charge)
		var size: float = float(row.target_radius) * (1.6 - 0.5 * k) * canvas.world_scale * float(_settings.size)
		var spin := PI / 4.0 * (1.0 - k)
		var center: Vector2 = canvas.to_logical(row.target)
		for q in range(4):
			var angle := spin + q * PI / 2.0
			var pos := center + Vector2.from_angle(angle) * size * 1.2
			_arc(canvas.front, pos - Vector2.from_angle(angle) * size * 0.4, size * 0.4, angle - 0.6, angle + 0.6, palette[3], 0.6 + 0.4 * k)
			canvas.front.dot(pos.x, pos.y, palette[4], k)
		canvas.front.ring(center.x, center.y, size * (0.5 + 0.5 * (1.0-k)), 1, palette[2], 0.4 * k)
		canvas.front.glow(center.x, center.y, size, palette[2], 0.25 * k * intensity)
		var lens: Vector2 = canvas.to_logical(row.pos + Vector2.from_angle(float(row.angle)) * float(row.radius))
		FX.warn_rail(canvas.front, lens, center, {"color": color, "k": k, "time": clock, "seed": 5, "rail": 1.2, "intensity": intensity})
	for event: Dictionary in events:
		if event.get("type") != &"beam" or event.get("visual_key", "") != "enemy/reticle": continue
		var epoch := int(event.get("epoch", 0))
		if epoch != _epoch:
			_epoch = epoch
			_sequence = 0
			_shots.clear()
		var sequence := int(event.get("sequence", 0))
		if sequence > 0 and sequence <= _sequence: continue
		_sequence = sequence
		_shots.append(event)
	var live: Array = []
	for shot: Dictionary in _shots:
		var t := clock - float(shot.get("world_t", clock))
		if t < maxf(0.6, 0.22 * float(_settings.timing)):
			live.append(shot)
			if t >= 0.0: _draw_shot(shot, t, canvas, clock, color, intensity)
	_shots = live

func _draw_shot(shot: Dictionary, t: float, canvas, clock: float, color: Color, _intensity: float) -> void:
	var origin: Vector2 = canvas.to_logical(shot["from"])
	var target: Vector2 = canvas.to_logical(shot["to"])
	var duration := 0.22 * float(_settings.timing)
	if t < duration:
		FX.beam(canvas.front, origin, target, {"color": color, "w": 5.0 * canvas.world_scale, "time": clock, "alpha": 1.0-t/duration, "source": true})
	FX.sparks(canvas.front, target, t, 51, 18, Color("ffd9a8"), 70, 0.5)
	if t < 0.6:
		for i in range(10):
			var angle := FX.hash_value(i * 2.1) * TAU
			var distance := 130.0 * t * (0.4 + FX.hash_value(i+5))
			var point: Vector2 = canvas.to_logical(shot["to"] + Vector2.from_angle(angle) * distance)
			canvas.front.circle(point.x, point.y, 1.5 * (1.0-t/0.6) + 0.6, Color("7d6a5c"))
			canvas.front.dot(point.x-0.5, point.y-0.5, Color("b39b86"))
	if t < 0.12: FX.flare(canvas.front, target, 14.0 * canvas.world_scale, Color.WHITE, clock, 1.0-t/0.12, 5)

func _arc(p, center: Vector2, radius: float, a0: float, a1: float, color: Color, alpha: float) -> void:
	p.shade(center.x-radius, center.y-radius, center.x+radius, center.y+radius, func(x: float, y: float, out: Dictionary):
		var d := Vector2(x, y) - center
		var length := d.length()
		if length <= radius and length >= radius-1.0 and fposmod(d.angle()-a0, TAU) <= a1-a0:
			out.c = color
			out.a = alpha)
