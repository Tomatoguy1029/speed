## 猟犬と守る雑魚の口元の光と、発動時の6本の火花。
extends RefCounted

const ANGLES := [-0.05, -0.42, -0.92, 0.37, 0.78, 1.12]
const LENGTHS := [25.0, 17.0, 12.0, 14.0, 10.0, 8.0]
const POWERS := [1.0, 0.76, 0.68, 0.55, 0.6, 0.53]
const WIDTHS := [1.9, 1.5, 1.2, 1.4, 1.1, 0.9]
const SNAP := 0.034
const DURATION := 0.11

var _sparks: Array = []
var _epoch := -1
var _sequence := 0
var _last_time := -1.0

func render(rows: Array, events: Array, canvas, world_time: float) -> void:
	if _last_time >= 0.0 and world_time < _last_time:
		_sparks.clear()
		_sequence = 0
	_last_time = world_time
	for event: Dictionary in events:
		if event.get("type") != &"biter_cue": continue
		var epoch := int(event.get("epoch", 0))
		if epoch != _epoch:
			_epoch = epoch
			_sequence = 0
			_sparks.clear()
		var sequence := int(event.get("sequence", 0))
		if sequence > 0 and sequence <= _sequence: continue
		_sequence = sequence
		_sparks.append(event)
	for row: Dictionary in rows:
		var charge := float(row.charge)
		if charge <= 0.0: continue
		var mouth: Vector2 = row.pos + Vector2.from_angle(float(row.angle)) * float(row.radius)
		var p: Vector2 = canvas.to_logical(mouth)
		canvas.front.glow(p.x, p.y, 3.0 + 4.0 * charge, Color("ffb347"), 0.5 * charge)
	var alive: Array = []
	for event: Dictionary in _sparks:
		var elapsed := world_time - float(event.get("world_t", world_time))
		if elapsed < SNAP + DURATION:
			alive.append(event)
			if elapsed >= SNAP: _draw_sparks(event, canvas, (elapsed - SNAP) / DURATION)
	_sparks = alive

func _draw_sparks(event: Dictionary, canvas, phase: float) -> void:
	var angle := float(event.angle)
	var sprite_radius := float(event.sprite_radius)
	var scale := sprite_radius / 17.0
	var mouth: Vector2 = event.pos + Vector2.from_angle(angle) * (sprite_radius * 16.0 / 17.0 + 6.0 * scale)
	var origin: Vector2 = canvas.to_logical(mouth)
	var unit: float = 0.5 * scale * canvas.world_scale
	var t := clampf(phase / 0.22, 0.0, 1.0)
	var stretch := t * t * (3.0 - 2.0 * t)
	var orange := Color8(int(lerpf(255, 255, phase)), int(lerpf(158, 74, phase)), int(lerpf(41, 9, phase)))
	var yellow := Color("ffe070")
	var white := Color("fffbe8")
	var p = canvas.front
	for j in range(ANGLES.size()):
		var a: float = angle + ANGLES[j]
		var ax := cos(a)
		var ay := sin(a)
		var tip: float = LENGTHS[j] * (0.18 + 0.82 * stretch)
		var d: float = LENGTHS[j] * pow(phase, 1.4) * 0.86
		var power: float = POWERS[j] * pow(1.0 - phase, 0.55)
		while d < tip:
			var width: float = WIDTHS[j] * maxf(0.08, 1.0 - d / maxf(tip, 0.01))
			var x := origin.x + ax * d * unit
			var y := origin.y + ay * d * unit
			var q := -width * 1.2
			while q <= width * 1.2:
				var distance := absf(q)
				var color: Color = white if distance < width * 0.4 and phase < 0.6 else (yellow if distance < width else orange)
				p.dot(x - ay * q * unit, y + ax * q * unit, color, minf(1.0, power * (1.0 if distance < width else 0.5)))
				q += 0.5
			if (roundi(d) & 3) == 0: p.light(x, y, orange, 0.3 * power)
			d += 0.5
