## 固定試作 fxlib.js の論理画素用の共通描画。
## pixelFX の作例に基づく。帰属・ライセンス: assets/ui/rewards/pixelfx_NOTICE.txt・pixelfx_LICENSE.txt。
extends RefCounted
static var _raster := SpeedFxRaster.new()

static func hash_value(n: float) -> float:
	var value := sin(n * 127.1 + 311.7) * 43758.5453
	return value - floorf(value)

static func ramp(color: Color) -> Array[Color]:
	var result: Array[Color] = []
	for pair: Vector2 in [Vector2(0.35, 0), Vector2(0.6, 0), Vector2(1, 0), Vector2(1, 0.45)]:
		result.append(Color(
			roundf(lerpf(color.r * pair.x, 1, pair.y) * 255) / 255,
			roundf(lerpf(color.g * pair.x, 1, pair.y) * 255) / 255,
			roundf(lerpf(color.b * pair.x, 1, pair.y) * 255) / 255))
	result.append(Color.WHITE)
	return result

## 位置・速さは試作の論理画素、時間は秒。direction=null は全方位。
static func sparks(painter, origin: Vector2, time: float, seed: float, count: int, color: Color, speed := 40.0, life := 0.35, direction = null, spread := PI) -> void:
	var palette := ramp(color)
	for i in count:
		var lifetime := life * lerpf(0.6, 1.2, hash_value(seed + i * 1.7))
		if time > lifetime or time < 0:
			continue
		var angle: float = hash_value(seed * 5 + i) * TAU if direction == null else float(direction) + (hash_value(seed * 5 + i) - 0.5) * 2 * spread
		var velocity := speed * lerpf(0.5, 1.3, hash_value(seed * 9 + i))
		var progress := time / lifetime
		var distance := velocity * time * (1 - progress * 0.4)
		var x := origin.x + cos(angle) * distance
		var y := origin.y + sin(angle) * distance + 20 * time * time
		var tail := minf(4, 1 + velocity * 0.03 * (1 - progress))
		painter.line(x - cos(angle) * tail, y - sin(angle) * tail, x, y, func(u: float): return (palette[4] if progress < 0.4 else palette[3]) if u > 0.5 else palette[2], 1 - progress * 0.6)
		painter.light(x, y, palette[2], 0.3 * (1 - progress))

static func _smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3 - 2 * t)

static func _packets(seed: float, time: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i in 11:
		var key := seed * 3.17 + i * 19.13
		var phase := hash_value(key + 1)
		var speed := 1.0 if hash_value(key + 2) < 0.5 else 2.0
		result.append(Vector3(fposmod(phase + speed * time, 1.0), lerpf(0.035, 0.102, hash_value(key + 5)), lerpf(0.22, 0.67, hash_value(key + 7))))
	return result

static func _flow(packets: Array[Vector3], along: float) -> float:
	var strength := 0.0
	for packet in packets:
		var distance := fposmod(along - packet.x + 0.5, 1.0) - 0.5
		strength += exp(-pow(distance / packet.y, 2)) * packet.z
	return 1 - exp(-strength * 0.9)

## 始点・終点は論理画素。options は固定試作の warnRail と同じ名前を使う。
static func warn_rail(painter, a: Vector2, b: Vector2, options: Dictionary) -> void:
	if painter.tx != 0.0 or painter.ty != 0.0 or painter.fx != 1.0 or painter.cs != 1.0 or painter.sn != 0.0:
		warn_rail_transformed(painter, a, b, options)
		return
	_raster.begin_painter(painter, 1.0, Vector2.ZERO, true, true)
	_raster.ruler_rail(a, b, options, painter.fade, painter.light_strength)
	_finish(painter)

static func warn_rail_transformed(painter, a: Vector2, b: Vector2, options: Dictionary) -> void:
	var palette := ramp(options.color)
	var delta := b - a
	var length := delta.length()
	if length < 1:
		return
	var direction := delta / length
	var normal := Vector2(-direction.y, direction.x)
	var k := clampf(float(options.k), 0.0, 1.0)
	var packets := _packets(float(options.get("seed", 0)), float(options.get("time", 0)) / 4)
	var side := float(options.get("rail", 2.2)) * (0.6 + 0.4 * k)
	var intensity := float(options.get("intensity", 1))
	var d := 0.0
	while d <= length:
		var envelope := _smooth(0, 6, d) * _smooth(0, 14, length - d)
		if options.has("reveal"):
			envelope *= _smooth(float(options.reveal) * length, float(options.reveal) * length - 8, d)
		if envelope > 0.04:
			var flow := _flow(packets, (d + float(options.get("offset", 0))) / float(options.get("path", length)))
			var point := a + direction * d
			var brightness := envelope * (0.35 + 0.65 * k) * (0.7 + 0.6 * flow) * intensity
			var level := 4 if brightness > 0.95 else (3 if brightness > 0.62 else (2 if brightness > 0.3 else 1))
			painter.px(point.x, point.y, palette[mini(int(options.get("maxLv", 4)), level)])
			painter.light(point.x, point.y, palette[2], 0.16 * envelope * (0.4 + k) * (0.6 + flow) * intensity)
			var positive := point + normal * side
			var negative := point - normal * side
			painter.light(positive.x, positive.y, palette[2], 0.22 * envelope * (0.3 + 0.7 * k) * (0.6 + 0.6 * flow) * intensity)
			painter.light(negative.x, negative.y, palette[1], 0.18 * envelope * (0.3 + 0.7 * k) * (0.6 + 0.6 * flow) * intensity)
		d += 1
	painter.glow_line(a.x, a.y, b.x, b.y, 2.5 + 2 * k, palette[2], 0.10 * k * intensity)

static func flare(painter, origin: Vector2, radius: float, color: Color, time: float, alpha := 1.0, rays := 4) -> void:
	var palette := ramp(color)
	var flicker := radius * (1 + 0.12 * sin(time * 60))
	for i in rays:
		var angle := time * 15 + i * TAU / rays
		var length := radius * 1.8 + radius * 0.6 * sin(time * 36 + i)
		var target := origin + Vector2.from_angle(angle) * length
		painter.line(origin.x, origin.y, target.x, target.y, func(u: float): return palette[4] if u < 0.5 else palette[3], func(u: float): return alpha if u < 0.6 else alpha * (1.6 - u))
	painter.circle(origin.x, origin.y, flicker + 1.2, palette[2], alpha)
	painter.circle(origin.x, origin.y, flicker * 0.75, palette[3], alpha)
	painter.circle(origin.x, origin.y, flicker * 0.45, palette[4], alpha)
	painter.glow(origin.x, origin.y, radius * 5 + 4, palette[2], 0.6 * alpha)
	painter.glow(origin.x, origin.y, radius * 2 + 2, palette[4], 0.4 * alpha)

static func gather(painter, origin: Vector2, radius: float, strength: float, color: Color, time: float, count := 14, seed := 1.0) -> void:
	var palette := ramp(color)
	for i in count:
		var lifetime := lerpf(0.35, 0.7, hash_value(seed + i))
		var phase := fposmod(time / lifetime + hash_value(seed * 7 + i), 1.0)
		var angle := hash_value(seed * 3 + i) * TAU + time * 0.7
		var distance := radius * (1 - phase) * lerpf(0.7, 1.15, hash_value(i + seed * 11)) + 1
		var point := origin + Vector2.from_angle(angle) * distance
		var tail := minf(4, 1 + radius * 0.08)
		var end := point + Vector2.from_angle(angle) * tail
		painter.line(point.x, point.y, end.x, end.y, palette[4] if phase > 0.7 else palette[3], strength * (0.4 + 0.6 * phase))
		painter.light(point.x, point.y, palette[2], 0.25 * strength * phase)
	painter.glow(origin.x, origin.y, radius * 0.35 * (0.4 + strength) + 2, palette[2], 0.55 * strength)
	painter.circle(origin.x, origin.y, 1 + 2.2 * strength, palette[3], strength)
	painter.circle(origin.x, origin.y, 0.6 + 1.2 * strength, palette[4], strength)

## 先端・後端と、内側から外側の5色の帯を試作どおりに描く。
static func beam(painter, a: Vector2, b: Vector2, options: Dictionary) -> void:
	if painter.tx != 0.0 or painter.ty != 0.0 or painter.fx != 1.0 or painter.cs != 1.0 or painter.sn != 0.0:
		beam_transformed(painter, a, b, options)
		return
	_raster.begin_painter(painter, 1.0, Vector2.ZERO, true, true)
	var settings := options
	if painter.fade != 1.0 or painter.light_strength != 1.0:
		settings = options.duplicate()
		settings.fade = painter.fade
		settings.light_strength = painter.light_strength
	_raster.reference_beam(a, b, PackedColorArray(ramp(options.color)), settings)
	_finish(painter)
	if a.distance_to(b) >= 1.0 and bool(options.get("source", true)) and float(options.get("from", 0)) <= 0.0:
		flare(painter, a, float(options.w)*1.3, options.color, float(options.get("time", 0)), clampf(float(options.get("alpha", 1)), 0.0, 1.0))

static func beam_transformed(painter, a: Vector2, b: Vector2, options: Dictionary) -> void:
	var palette := ramp(options.color)
	var delta := b - a
	var length := delta.length()
	if length < 1:
		return
	var direction := delta / length
	var normal := Vector2(-direction.y, direction.x)
	var time := float(options.get("time", 0))
	var alpha := clampf(float(options.get("alpha", 1)), 0.0, 1.0)
	var width := float(options.w)
	var levels := [palette[4], palette[3], palette[2], palette[1], palette[0]]
	var d0 := float(options.get("from", 0)) * length
	var d1 := float(options.get("to", 1)) * length
	var taper := float(options.get("taper", 0))
	var d := d0
	while d <= d1:
		var ends: float
		if taper != 0:
			ends = pow(minf(1, minf((d - d0) / taper * (1 if d0 > 0 else 3), (d1 - d) / taper)), 0.8)
		elif bool(options.get("round", false)):
			ends = minf(1, sqrt(maxf(0, minf(d, length - d)) / (width * 0.9 + 0.01)))
		else:
			ends = minf(1, (d + 2) / 4)
		var w := width * (1 + 0.1 * sin(d * 0.35 - time * 40)) * ends
		var pulse := 1 if fposmod(d * 0.03 - time * 3, 1.0) < 0.06 else 0
		var point := a + direction * d
		var q0 := -w * 1.25
		while q0 <= w * 1.25:
			var q := absf(q0) / maxf(w, 0.01)
			var level := 0 if q < 0.25 else (1 if q < 0.45 else (2 if q < 0.7 else (3 if q < 0.95 else 4)))
			level = maxi(0, level - pulse)
			var pixel := point + normal * q0
			painter.dot(pixel.x, pixel.y, levels[level], alpha * (0.45 if level == 4 else 1))
			q0 += 0.5
		if (floori(d * 2 + 0.5) & 5) == 0:
			painter.light(point.x, point.y, palette[2], 0.25 * alpha * float(options.get("intensity", 1)))
		d += 0.5
	var start := a + direction * d0
	var end := a + direction * d1
	painter.glow_line(start.x, start.y, end.x, end.y, width * 2.6 + 3, palette[2], 0.35 * alpha * float(options.get("intensity", 1)))
	if bool(options.get("source", true)) and d0 <= 0:
		flare(painter, a, width * 1.3, options.color, time, alpha)

## 三日月の両端を head / tail で切り、残光を色段階のまま冷ます。
static func crescent(painter, center: Vector2, radius: float, from_angle: float, to_angle: float, head: float, tail: float, thickness: float, color: Color, alpha := 1.0) -> void:
	var palette := ramp(color)
	var span := to_angle - from_angle
	var steps := maxf(8, absf(span) * radius * 1.4)
	var step := 0
	while step <= steps:
		var progress := step / steps
		if progress <= head and progress >= tail:
			var angle := from_angle + span * progress
			var age := (head - progress) / maxf(0.001, head - tail + 0.001)
			var width := thickness * (0.35 + 0.65 * sin(PI * minf(1, progress * 1.05))) * (1 - 0.6 * age)
			var q := -width
			while q <= width:
				var r := radius + q
				var x := center.x + cos(angle) * r
				var y := center.y + sin(angle) * r
				var edge := absf(q) / maxf(width, 0.01)
				var level := 4
				if age >= 0.7:
					level = 2 if edge < 0.4 else 1
				elif age >= 0.35:
					level = 3 if edge < 0.4 else 2
				elif age >= 0.12:
					level = 4 if edge < 0.5 else 3
				var amount := alpha * (1 - age * 0.55)
				level = maxi(0, level - floori((1 - amount) * 3.2))
				if level < palette.size():
					if amount > 0.18 or edge < 0.5:
						painter.px(x, y, palette[level])
					else:
						painter.dot(x, y, palette[level], amount * 3)
				q += 0.5
			if step % 3 == 0:
				painter.light(center.x + cos(angle) * radius, center.y + sin(angle) * radius, palette[2], 0.3 * alpha * (1 - age))
		step += 1

static func _finish(painter) -> void:
	painter.colors = _raster.take_colors()
	painter.lights = _raster.take_lights()
	painter.has_color = painter.has_color or _raster.has_color()
	painter.has_light = painter.has_light or _raster.has_light()
