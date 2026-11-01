extends WeaponVisual
## 震空：触れた点へ空間が一瞬引き込まれ（0.08秒）、白い閃光ととげの形の線がはじけ、空間そのものが外へ押し広げられる。
## 歪みは画面全体の処理（RenderPipeline.add_ripple）で、敵・機体・星をまとめて歪ませる。色のついた輪は出さない。

const PINCH := 0.08
const LIFE := 0.5
## 戦闘エフェクトツールで調整する shader
const TUNED_SHADERS := [preload("res://shaders/space_ripple.gdshader")]
var quakes: Array[Dictionary] = []
var sparks := PixelSparks.new()

func on_event(ev: Dictionary) -> void:
	if ev.type != &"space_quake": return
	var spikes: Array[Dictionary] = []
	for i in 9: spikes.append({"a": i / 9.0 * TAU + randf() * 0.5, "l": 8.0 + randf() * 10.0})
	quakes.append({"pos": ev.pos, "age": 0.0, "spikes": spikes, "burst": false})
	rm.pipeline.add_ripple(ev.pos, float(ev.radius), 1.82 * cfg.character_scale)

func tick(_dt: float) -> void:
	var dt := world_dt()
	tune(rm.pipeline.ripple_material())
	var p := painter()
	p.begin()
	for w in quakes:
		w.age += dt
		if w.age < PINCH:
			p.dot(w.pos, Color.WHITE)
			continue
		if not w.burst:
			w.burst = true
			sparks.add(w.pos, 10, 0.0, 7.0, 60.0, 140.0, 0.22, [Color.WHITE, Color("#e8f6ff"), Color("#9fb4c8")])
		var q: float = (w.age - PINCH) / LIFE
		if q >= 0.2: continue
		var k := q / 0.2
		for s in w.spikes:
			var u := Vector2.from_angle(s.a)
			var length: float = s.l * (1.0 if k < 0.5 else 0.6)
			p.line(w.pos + u * 2.0 * p.px, w.pos + u * length * p.px, Color.WHITE if k < 0.5 else Color("#e8f6ff"))
			if k < 0.5: p.line(w.pos, w.pos + u * length * 0.45 * p.px, Color.WHITE, 2)
		if k < 0.5: p.disk(w.pos, 3.0, Color.WHITE)
	quakes = quakes.filter(func(w): return w.age < PINCH + LIFE)
	sparks.draw(p, dt)
	p.end()
