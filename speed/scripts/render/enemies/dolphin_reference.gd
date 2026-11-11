## いるか座の口元の音波と、先頭・後続の波紋。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
var _settings: Dictionary = SETTINGS.for_id("G12-dolphin")
var _waves := {}
var _last_time := -1.0
var _raster := SpeedFxRaster.new()

func render(actors: Array, waves: Array, events: Array, canvas, clock: float) -> void:
	if _last_time >= 0.0 and clock < _last_time: _waves.clear()
	_last_time = clock
	var color := Color(_settings.color)
	var pal := FX.ramp(color)
	for actor: Dictionary in actors:
		var k := float(actor.charge)
		var angle := float(actor.angle)
		var arc := float(actor.arc)
		var mouth: Vector2 = canvas.to_logical(actor.pos + Vector2.from_angle(angle) * float(actor.radius))
		for n in range(3):
			var fr := 1.0 - fposmod(k * 1.6 + float(n) / 3.0, 1.0)
			_arc(canvas.front, mouth, float(actor.radius) * (0.6 + 2.6 * fr) * canvas.world_scale * float(_settings.size), angle - arc * 0.8, angle + arc * 0.8, pal[3], (1.0 - fr) * k * float(_settings.intensity))
		FX.gather(canvas.front, mouth, float(actor.radius) * 1.4 * canvas.world_scale, k * float(_settings.intensity), color, clock, 10, 13)
	var present := {}
	for row: Dictionary in waves:
		var id := int(row.order)
		present[id] = true
		_waves[id] = {"row": row, "clock": clock}
		_draw_wave(row, float(row.time), canvas, pal)
	for event: Dictionary in events:
		if event.get("type") != &"attack_retired": continue
		var id := int(event.id)
		if not _waves.has(id): continue
		if event.reason != "lifetime":
			_waves.erase(id)
			continue
		var saved: Dictionary = _waves[id]
		var row: Dictionary = saved.row
		saved.end_time = float(saved.clock) - float(row.time) + float(row.radius) / float(row.speed)
	for id in _waves.keys():
		if present.has(id): continue
		var saved: Dictionary = _waves[id]
		if not saved.has("end_time"): continue
		var row: Dictionary = saved.row
		var elapsed := clock - float(saved.end_time)
		var tail_time := 3.0 * float(row.width) * 1.6 / float(row.speed) + 0.25 * float(_settings.timing)
		if elapsed >= tail_time:
			_waves.erase(id)
		elif elapsed > 0.0:
			_draw_wave(row, float(row.radius) / float(row.speed) + elapsed, canvas, pal)

func _arc(p, center: Vector2, radius: float, a0: float, a1: float, color: Color, alpha: float) -> void:
	_raster.begin_painter(p, 1.0, Vector2.ZERO, true, false)
	var flags := _raster.dolphin_arc(center, radius, a0, a1, color, alpha, p.fade)
	p.colors = _raster.take_colors()
	p.has_color = p.has_color or (flags & 1) != 0

func _draw_wave(row: Dictionary, time: float, canvas, pal: Array[Color]) -> void:
	var speed := float(row.speed)
	var width := float(row.width)
	var max_radius := float(row.radius)
	var radius := time * speed
	var fade := (1.0 - 0.5 * clampf(radius / max_radius, 0.0, 1.0)) * minf(1.0, float(_settings.intensity))
	var fade_length := speed * 0.25 * float(_settings.timing)
	var center: Vector2 = canvas.to_logical(row.pos)
	var a0 := float(row.angle) - float(row.arc)
	var a1 := float(row.angle) + float(row.arc)
	var edge := Color8(int(lerpf(pal[2].r * 255.0, 255, 0.35)), int(lerpf(pal[2].g * 255.0, 244, 0.35)), int(lerpf(pal[2].b * 255.0, 224, 0.35)))
	for n in range(3, -1, -1):
		var rb := radius - n * width * 1.6
		var dissolve := clampf((rb - max_radius) / fade_length, 0.0, 1.0)
		if rb <= 0.0 or dissolve >= 1.0: continue
		var r: float = rb * canvas.world_scale
		var w: float = width * canvas.world_scale
		if n == 0:
			_band(canvas.front, center, r, a0, a1, minf(w * 0.5, r * 0.3), [edge, pal[2], pal[1]], fade * (1.0 - 0.4 * dissolve), dissolve)
			var angle := a0 + 0.1
			while angle <= a1 - 0.1 + 0.000001:
				canvas.front.glow(center.x + cos(angle) * r, center.y + sin(angle) * r, w * 0.9 + 3.0, pal[2], 0.16 * fade * (1.0 - dissolve))
				angle += 0.12
		else:
			_band(canvas.front, center, r, a0 + 0.03 * n, a1 - 0.03 * n, maxf(0.9, w * 0.22), [pal[2], pal[1], pal[0]], fade * (0.7 - n * 0.15) * (1.0 - 0.4 * dissolve), dissolve)

func _band(p, center: Vector2, radius: float, a0: float, a1: float, width: float, colors: Array, alpha: float, dissolve: float) -> void:
	if radius <= 0 or width <= 0 or alpha <= 0: return
	_raster.begin_painter(p, 1.0, Vector2.ZERO, true, false)
	var flags := _raster.dolphin_band(center, radius, a0, a1, width, PackedColorArray(colors), alpha, dissolve, p.fade)
	p.colors = _raster.take_colors()
	p.has_color = p.has_color or (flags & 1) != 0
