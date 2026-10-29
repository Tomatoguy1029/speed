extends WeaponVisual
## エンドブラスト：終点で紫のピクセル炎が爆発し、白から紫へ変わる破片が外へ飛び、遅れて紫の火の粉が漂って昇る。
## Lv3からの外周の小さな爆発は炎だけ。大きい爆発ほど画面が強く揺れる。

const VIOLET := [Color.WHITE, Color("#e6d2ff"), Color("#b070ff"), Color("#5a1eb0")]
var booms: Array[Dictionary] = []

func claims(ev: Dictionary) -> bool:
	return ev.type == &"explode" and ev.get("cause", &"") == &"endBlast"

func on_event(ev: Dictionary) -> void:
	if not claims(ev): return
	var px := painter().px
	# 試作は倒す範囲が半径の 1.3 倍、炎は半径の 1.25 倍
	var radius: float = float(ev.radius) / px / 1.3
	var main: bool = float(ev.radius) >= behavior.area(behavior.at_level("radius_by_level")) * 0.9
	fires().add(ev.pos, radius * 1.25, 0.55, VIOLET)
	if not main: return
	rm.shake = maxf(rm.shake, 7.0 if int(behavior.at_level("secondary_by_level")) > 0 else 4.0)
	var debris: Array[Dictionary] = []
	for i in roundi(radius * 0.72): debris.append({"dir": Vector2.from_angle(randf() * TAU), "v": 50.0 + randf() * 120.0})
	var embers: Array[Dictionary] = []
	for i in roundi(radius * 0.5):
		embers.append({"dir": Vector2.from_angle(randf() * TAU), "v": 10.0 + randf() * 40.0, "size": 1 + randi() % 2, "life": 0.5 + randf() * 0.6})
	booms.append({"pos": ev.pos, "radius": radius, "age": 0.0, "debris": debris, "embers": embers})

func tick(_dt: float) -> void:
	var dt := world_dt()
	var p := painter()
	p.begin()
	for b in booms:
		b.age += dt
		var a: float = b.age
		var q := a / 0.5
		if q < 1.0:
			for d in b.debris:
				p.dot(b.pos + d.dir * d.v * q * (1.0 - 0.4 * q) * p.px, Color.WHITE if q < 0.5 else Color("#b48cff"))
		if a >= 0.15:
			for e in b.embers:
				var k: float = (a - 0.15) / e.life
				if k >= 1.0: continue
				var at: Vector2 = b.pos + (e.dir * (b.radius * 0.5 + e.v * k) - Vector2(0.0, k * 8.0)) * p.px
				var color := Color("#e6d2ff") if k < 0.4 else Color("#9a5cf0") if k < 0.75 else Color("#4a1e8c")
				p.dot(at, color, e.size)
	booms = booms.filter(func(b): return b.age < 1.3)
	fires().step(dt)
	p.end()
