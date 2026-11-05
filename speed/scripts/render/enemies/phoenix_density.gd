## 鳳凰の炎と煙を、粒ごとの3層の密度からひとつの面にする。
## 固定試作の phxSplat / phxDrawParticles を移植。座標は着地点からの論理画素。
extends RefCounted

const FIRE := 9
const SMOKE := 8
const BIG := 2
const PAD := 6
const THRESHOLD := 0.32
const DEFORMATION := 1.4
const FPS := 30.0
const SMOKE_YOUNG := Color("#5d5660")
const SMOKE_OLD := Color("#2b2630")

var _field := PackedFloat32Array()
var _width := 0
var _height := 0
var _origin := Vector2i.ZERO

func draw(painter, particles: Array[Dictionary], smoke: bool, clock: float, burst_age: float, pixel_size: float, flame_colors: Array) -> void:
	var kind := SMOKE if smoke else FIRE
	var list: Array[Dictionary] = []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in particles:
		if q.kind != kind or q.delay > 0:
			continue
		list.append(q)
		var radius: float = q.size * 2
		var pos: Vector2 = q.pos
		lo.x = minf(lo.x, pos.x - radius)
		lo.y = minf(lo.y, pos.y - radius)
		hi.x = maxf(hi.x, pos.x + radius)
		hi.y = maxf(hi.y, pos.y + radius)
	if list.is_empty():
		return
	_origin = Vector2i(floori(lo.x) - PAD, floori(lo.y) - PAD)
	_width = ceili(hi.x) - _origin.x + PAD
	_height = ceili(hi.y) - _origin.y + PAD
	_field.resize(_width * _height * 3)
	_field.fill(0.0)
	for q in list:
		var age: float = 1.0 - q.life / q.max
		var pos: Vector2 = q.pos
		if q.has("channel"):
			_splat(pos, q.size, q.channel)
		elif not smoke:
			var base: float = q.size * 1.25 * pow(1 - age, 0.6) * (0.7 + 0.3 * smoothstep(0.0, 0.08, age))
			_splat(pos, base, 0)
			if age < 0.62:
				_splat(pos - Vector2(0, base * 0.1), base * 0.7, 1)
			if age < 0.3:
				_splat(pos - Vector2(0, base * 0.15), base * 0.44, 2)
		else:
			var big := (int(q.flags) & BIG) != 0
			var r: float = q.size * (0.65 + minf(1, age * 2.5) * 0.45 + age * (0.5 if big else 0.4)) * 1.2
			_splat(pos, r, 0)
			if age < 0.5:
				_splat(pos, r * 0.6, 1)
			_splat(pos, r, 2, age)
	var t := floorf(clock * FPS) / FPS
	var cool := clampf(burst_age / 1.3, 0.0, 1.0)
	var colors: Array[Color] = []
	if not smoke:
		for pair in flame_colors:
			colors.append(_mix_8bit(pair[0], pair[1], cool))
	for j in _height:
		for i in _width:
			var x := i + _origin.x
			var y := j + _origin.y
			var wx := x * pixel_size
			var wy := y * pixel_size
			var u := (sin(wy * 0.075 - t * 4.4) + sin(wx * 0.11 + wy * 0.033 + t * 2.1)) * DEFORMATION
			var v := cos(wx * 0.08 + t * 3.0) * 0.55 * DEFORMATION
			var outer := _read(i + u, j + v, 0)
			if outer < THRESHOLD:
				continue
			var inner := _read(i + u, j + v, 1) >= THRESHOLD
			if smoke:
				var oldness := _read(i + u, j + v, 2) / maxf(0.0001, outer)
				var gone := smoothstep(0.45, 0.95, oldness)
				if _hash(x * 12.9898 + y * 78.233) < gone:
					continue
				painter.blend(x, y, SMOKE_YOUNG if inner else SMOKE_OLD, (0.55 if inner else 0.4) * (1 - gone * 0.35))
			else:
				var core := inner and _read(i + u, j + v, 2) >= THRESHOLD
				var color: Color = colors[2] if core else (colors[1] if inner else colors[0])
				painter.px(x, y, color)
				if (x & 3) == 0 and (y & 3) == 0:
					painter.glow(x, y, 5, color, 0.3 if core else (0.18 if inner else 0.08))

func _splat(pos: Vector2, radius: float, channel: int, weight := 1.0) -> void:
	if radius < 0.3:
		return
	var x0 := maxi(0, floori(pos.x - radius - _origin.x))
	var x1 := mini(_width - 1, ceili(pos.x + radius - _origin.x))
	var y0 := maxi(0, floori(pos.y - radius - _origin.y))
	var y1 := mini(_height - 1, ceili(pos.y + radius - _origin.y))
	for j in range(y0, y1 + 1):
		for i in range(x0, x1 + 1):
			var dx := (i + _origin.x + 0.5 - pos.x) / radius
			var dy := (j + _origin.y + 0.5 - pos.y) / radius
			var d2 := dx * dx + dy * dy
			if d2 < 1:
				var index := (j * _width + i) * 3 + channel
				_field[index] += weight * exp(-d2 * 3.2) * (1 - smoothstep(0.72, 1.0, sqrt(d2)))

func _read(x: float, y: float, channel: int) -> float:
	var i := clampi(floori(x + 0.5), 0, _width - 1)
	var j := clampi(floori(y + 0.5), 0, _height - 1)
	return _field[(j * _width + i) * 3 + channel]

func _hash(n: float) -> float:
	var s := sin(n * 127.1 + 311.7) * 43758.5453
	return s - floorf(s)

func _mix_8bit(a: Color, b: Color, k: float) -> Color:
	return Color(floorf(lerpf(a.r, b.r, k) * 255) / 255, floorf(lerpf(a.g, b.g, k) * 255) / 255, floorf(lerpf(a.b, b.b, k) * 255) / 255)
