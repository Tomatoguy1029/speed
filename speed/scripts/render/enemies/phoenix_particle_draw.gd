## 鳳凰の粒・煙・燃え残りと、粒が通った範囲の焦げ跡。
## pixelFX src/core/sim.js（Copyright 2026 Hugo Duprez、MIT）の描画式を含む。
## 帰属とライセンス: assets/ui/rewards/pixelfx_NOTICE.txt・pixelfx_LICENSE.txt。
extends RefCounted

const DENSITY := preload("res://scripts/render/enemies/phoenix_density.gd")
const SPARK := 0
const EMBER := 7
const BACK := 4
const FIRE_RAMP := ["#ffffff", "#fff1c4", "#ffd77a", "#ffa24a", "#ff6a3a", "#e8333f", "#b01a45", "#6e1238", "#36091f"]
const SPARK_RAMP := ["#fff1c4", "#ffb35a", "#e8333f", "#7a1430"]
const FLAME_RAMP := [["#e8333f", "#7a1430"], ["#ff7a3a", "#c42340"], ["#fff1c4", "#ff9a3a"]]
const HOT := [Color("#fff3a6"), Color("#ffe26b"), Color("#ff8a2a"), Color("#f2561d")]

var _density = DENSITY.new()
var _fire: Array[Color] = []
var _spark: Array[Color] = []
var _flame: Array = []
var smoke_color := Color("#3a2230")
var _base_color := Color("#ff6a3a")

func configure(color: Color) -> void:
	_base_color = color
	_fire.clear()
	_spark.clear()
	_flame.clear()
	for c in FIRE_RAMP:
		_fire.append(_tint(Color(c), color))
	for c in SPARK_RAMP:
		_spark.append(_tint(Color(c), color))
	for pair in FLAME_RAMP:
		_flame.append([_tint(Color(pair[0]), color), _tint(Color(pair[1]), color)])
	smoke_color = _tint(Color("#3a2230"), color)

func fire_colors() -> Array[Color]:
	return _fire

func spark_colors() -> Array[Color]:
	return _spark

func colorize(color: Color) -> Color:
	return _tint(color, _base_color)

func draw_back(painter, simulation, clock: float, burst_age: float, timing: float, pixel_size: float) -> void:
	if simulation.scorch_size > 0:
		_draw_scorch(painter, simulation, burst_age / timing)
	_draw_other_particles(painter, simulation, true)
	_density.draw(painter, simulation.particles, true, clock, burst_age, pixel_size, _flame)
	for blaze in simulation.blazes:
		var k: float = blaze.life / blaze.max
		var pos: Vector2 = blaze.pos
		var color: Color = (HOT[1] if sin(blaze.life * 31 + pos.x) > 0 else HOT[2]) if k > 0.4 else HOT[3]
		painter.px(pos.x, pos.y, color)
		painter.glow(pos.x, pos.y, 6 + 5 * k * blaze.power, HOT[2], 0.3 * k * blaze.power)

func draw_front(painter, simulation, clock: float, burst_age: float, pixel_size: float) -> void:
	_draw_other_particles(painter, simulation, false)
	_density.draw(painter, simulation.particles, false, clock, burst_age, pixel_size, _flame)

func _draw_other_particles(painter, simulation, behind: bool) -> void:
	for q in simulation.particles:
		if q.delay > 0 or (q.kind != SPARK and q.kind != EMBER) or (((int(q.flags) & BACK) != 0) != behind):
			continue
		var k: float = q.life / q.max
		var pos: Vector2 = q.pos
		if q.kind == SPARK:
			var velocity: Vector2 = q.velocity
			var speed := velocity.length()
			var direction := velocity / speed if speed > 0 else Vector2.ZERO
			var head: Color = _spark[0] if k > 0.6 else (_spark[1] if k > 0.3 else _spark[2])
			var length := minf(9, 1 + speed * 0.022)
			var start := pos - direction * length
			var middle := pos - direction * length * 0.4
			painter.line(start.x, start.y, middle.x, middle.y, head if k > 0.5 else _spark[3])
			start = pos - direction * length * 0.45
			painter.line(start.x, start.y, pos.x, pos.y, head)
			painter.glow(pos.x, pos.y, 3, head, 0.45 * k)
		else:
			if k < 0.25 and sin(simulation.time * 40 + q.seed) < 0:
				continue
			var color: Color = _spark[0] if k > 0.6 else (_spark[1] if k > 0.3 else _spark[2])
			painter.px(pos.x, pos.y, color)
			if q.size > 1.5:
				painter.px(pos.x, pos.y + 1, _spark[3])
			painter.glow(pos.x, pos.y, 3 + q.size, color, 0.35 * k)

func _draw_scorch(painter, simulation, age: float) -> void:
	var fade := 1.0 - smoothstep(1.6, 3.2, age)
	if fade <= 0:
		return
	for y in simulation.scorch_size:
		for x in simulation.scorch_size:
			var m: float = simulation.scorch[y * simulation.scorch_size + x]
			if m < 0.35:
				continue
			var lx: int = x - simulation.scorch_radius
			var ly: int = y - simulation.scorch_radius
			var k := _hash(lx * 31.7 + ly * 7.3)
			if k > fade * minf(1, (m - 0.35) * 2.5):
				continue
			var heat := pow(clampf(1 - age / 1.4, 0.0, 1.0), 1.3) * minf(1.2, m * 0.5) - k * 0.4
			if heat > 0.08:
				var index := mini(_fire.size() - 1, floori((1 - minf(1, heat)) * (_fire.size() - 1)))
				painter.px(lx, ly, _fire[_fire.size() - 1 - index])
				if (lx & 3) == 0 and (ly & 3) == 0:
					painter.glow(lx, ly, 5, _fire[_fire.size() - 1 - 5], 0.2 * heat * fade)
			else:
				painter.blend(lx, ly, Color("#140a0e") if k < 0.5 else Color("#22131a"), 0.7)

func _hash(n: float) -> float:
	var value := sin(n * 127.1 + 311.7) * 43758.5453
	return value - floorf(value)

func _hsl(color: Color) -> Vector3:
	var high := maxf(color.r, maxf(color.g, color.b))
	var low := minf(color.r, minf(color.g, color.b))
	var light := (high + low) * 0.5
	var delta := high - low
	if delta == 0:
		return Vector3(0, 0, light)
	var saturation := delta / (1 - absf(2 * light - 1))
	var hue := 0.0
	if high == color.r:
		hue = fposmod((color.g - color.b) / delta + 6, 6)
	elif high == color.g:
		hue = (color.b - color.r) / delta + 2
	else:
		hue = (color.r - color.g) / delta + 4
	return Vector3(hue * 60, saturation, light)

func _tint(color: Color, base: Color) -> Color:
	var original := _hsl(Color("#ff6a3a"))
	var wanted := _hsl(base)
	var hsl := _hsl(color)
	var h := fposmod(hsl.x + wanted.x - original.x, 360.0)
	var s := clampf(hsl.y * (wanted.y / original.y if original.y != 0 else 1.0), 0.0, 1.0)
	var c := (1 - absf(2 * hsl.z - 1)) * s
	var x := c * (1 - absf(fposmod(h / 60.0, 2.0) - 1))
	var m := hsl.z - c * 0.5
	var channel: Vector3
	match floori(h / 60.0):
		0: channel = Vector3(c, x, 0)
		1: channel = Vector3(x, c, 0)
		2: channel = Vector3(0, c, x)
		3: channel = Vector3(0, x, c)
		4: channel = Vector3(x, 0, c)
		_: channel = Vector3(c, 0, x)
	return Color(roundf((channel.x + m) * 255) / 255, roundf((channel.y + m) * 255) / 255, roundf((channel.z + m) * 255) / 255)
