## ドット単位の火花。出た向きへ飛び、毎秒 0.04 倍に減速し、寿命の4割までは2ドット角、そのあと1ドットで描く。
class_name PixelSparks
extends RefCounted

var _items: Array[Dictionary] = []

## pos は世界座標、速さはドット毎秒。寿命は life の 0.6〜1.2 倍でばらつかせる。
func add(pos: Vector2, count: int, angle: float, spread: float, v0: float, v1: float, life: float, colors: Array) -> void:
	for i in count:
		var a := angle + (randf() - 0.5) * spread
		var v := v0 + randf() * (v1 - v0)
		_items.append({"pos": pos, "vel": Vector2.from_angle(a) * v, "age": 0.0,
			"life": life * (0.6 + randf() * 0.6), "color": colors[randi() % colors.size()]})

func draw(painter: PixelPainter, dt: float) -> void:
	var damping := pow(0.04, dt)
	for p in _items:
		p.age += dt
		if p.age >= p.life: continue
		p.pos += p.vel * painter.px * dt
		p.vel *= damping
		painter.dot(p.pos, p.color, 2 if p.age < p.life * 0.4 else 1)
	_items = _items.filter(func(p): return p.age < p.life)

func clear() -> void:
	_items.clear()
