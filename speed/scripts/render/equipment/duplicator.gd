extends WeaponVisual
## デュプリケーター：弾・破片・光の槍が分かれる瞬間に、黄みの白い光がふわっと広がって消え、
## 分かれた向きの間に短い光の筋が2本走る。

var splits: Array[Dictionary] = []

func on_event(ev: Dictionary) -> void:
	if ev.type != &"duplicate": return
	var sum := Vector2.ZERO
	for v in ev.directions: sum += (v as Vector2).normalized()
	splits.append({"pos": ev.pos, "angle": sum.angle(), "age": 0.0})

func tick(_dt: float) -> void:
	var dt := world_dt()
	var p := painter()
	p.begin()
	for s in splits:
		s.age += dt
		var k: float = s.age / 0.25
		if k >= 1.0: continue
		_glow(p, s.pos, 6.0 + 16.0 * k, 0.9 * (1.0 - k))
		var l := 4.0 + 10.0 * k
		for side in [-1.0, 1.0]:
			var u := Vector2.from_angle(s.angle + side * 0.5)
			p.line(s.pos + u * l * 0.4 * p.px, s.pos + u * l * p.px, Color(1.0, 250.0 / 255.0, 220.0 / 255.0, 1.0 - k))
	splits = splits.filter(func(s): return s.age < 0.25)
	p.end()

## 中心ほど濃い光を、Bayer の網点でドットに置き換える。
func _glow(p: PixelPainter, pos: Vector2, radius: float, alpha: float) -> void:
	if radius <= 0.0 or alpha <= 0.0: return
	var c := p.cell(pos).round()
	var big := ceili(radius)
	var cx := int(c.x)
	var cy := int(c.y)
	# 同じしきい値のセルは4ドットおき。各行の通過区間だけを描き、四角全体を走査しない。
	for phase_y in 4:
		for phase_x in 4:
			var threshold := PixelPainter.bayer(phase_x, phase_y)
			var reach := radius * (1.0 - threshold / (alpha * 16.0))
			if reach <= 0.0: continue
			# 式の変形の丸めで境界を落とさないよう1ドット広げ、端は元の式で確かめる。
			var extent := mini(big, ceili(reach) + 1)
			var first_y := -extent + posmod(phase_y - cy + extent, 4)
			for y in range(first_y, extent + 1, 4):
				var width := mini(big, floori(sqrt(maxf(0.0, reach * reach - y * y))) + 1)
				var first_x := -width + posmod(phase_x - cx + width, 4)
				var last_x := width - posmod(cx + width - phase_x, 4)
				while first_x <= last_x and not _glow_contains(first_x, y, radius, alpha, threshold):
					first_x += 4
				while last_x >= first_x and not _glow_contains(last_x, y, radius, alpha, threshold):
					last_x -= 4
				for x in range(first_x, last_x + 1, 4):
					p.fill(cx + x, cy + y, Color(1.0, 240.0 / 255.0, 170.0 / 255.0))

func _glow_contains(x: int, y: int, radius: float, alpha: float, threshold: int) -> bool:
	var d := sqrt(float(x * x + y * y)) / radius
	return d < 1.0 and (1.0 - d) * alpha * 16.0 > threshold
