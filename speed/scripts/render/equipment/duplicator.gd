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
	var c := p.cell(pos).round()
	var big := ceili(radius)
	for y in range(-big, big + 1):
		for x in range(-big, big + 1):
			var d := sqrt(float(x * x + y * y)) / radius
			if d >= 1.0: continue
			if (1.0 - d) * alpha * 16.0 <= PixelPainter.bayer(int(c.x) + x, int(c.y) + y): continue
			p.fill(c.x + x, c.y + y, Color(1.0, 240.0 / 255.0, 170.0 / 255.0))
