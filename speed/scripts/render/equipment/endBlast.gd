extends WeaponVisual
## エンドブラスト：pixelfx の plasma-explosion を元にした紫のプラズマの爆発。白く光って十字の光が走り、プラズマの球が
## 一気に膨らむ。球は内側から中空の殻になり、渦の向きにねじれた欠片に裂けて消える（plasma_burst）。中心と殻から稲妻が
## 走り、光の筋・星屑・きらめきが散る。Lv3からの外周の小さな爆発も同じ見た目を半径に合わせて縮めて描く。
## 大きい爆発ほど画面が強く揺れる。

const C := [Color("#0e0620"), Color("#2a0a5a"), Color("#5a1eb0"), Color("#8a3ce0"), Color("#b070ff"), Color("#e6d2ff"), Color.WHITE]
const V := [Color("#1a0838"), Color("#4a1a9c"), Color("#8a4cf0"), Color("#c8a0ff"), Color("#f0e4ff")]
## 球が消えきる秒・爆発全体の秒・稲妻の量
const BALL := 0.42
const LIFE := 0.95
const ARCS := 1.4
const CROSS := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
const DIAG := [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]
enum { MOTE, FLAKE, STAR }
## 戦闘エフェクトツールで調整する shader
const TUNED_SHADERS := [preload("res://shaders/plasma_burst.gdshader")]
var booms: Array[Dictionary] = []
var _plasmas: PlasmaBursts

func dispose() -> void:
	if is_instance_valid(_plasmas): _plasmas.queue_free()
	super()

## プラズマの球。初めて使うときに演出の層へ置く。
func plasmas() -> PlasmaBursts:
	if _plasmas == null:
		_plasmas = PlasmaBursts.new()
		_plasmas.setup(1.82 * cfg.character_scale)
		_plasmas.key = _effect_key()
		_plasmas.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
		_plasmas.modulate = RenderPipeline.plain_color(rm._layers.fx, visual_color(Color.WHITE))
		rm._layers.fx.add_child(_plasmas)
	return _plasmas

func claims(ev: Dictionary) -> bool:
	return ev.type == &"explode" and ev.get("cause", &"") == &"endBlast"

func on_event(ev: Dictionary) -> void:
	if not claims(ev): return
	# 球の半径は倒す範囲の 0.96 倍（ドット数）
	var rad: float = float(ev.radius) / painter().px * 0.96
	var main: bool = float(ev.radius) >= behavior.area(behavior.at_level("radius_by_level")) * 0.9
	plasmas().add(ev.pos, rad, BALL)
	if main: rm.shake = maxf(rm.shake, 7.0 if int(behavior.at_level("secondary_by_level")) > 0 else 4.0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var s := rad / 35.0
	var k := minf(1.0, rad / 90.0)
	var parts: Array[Dictionary] = []
	for i in roundi(60.0 * k):
		var dir := Vector2.from_angle(rng.randf() * TAU)
		parts.append(_part(MOTE, dir * 6.0, dir * rng.randf_range(140.0, 360.0) * s * 0.6, rng.randf_range(0.2, 0.42), _pick(rng, [C[6], C[5], C[4], V[3]]), rng.randf_range(0.8, 1.3), rng))
	for i in roundi(40.0 * k):
		var dir := Vector2.from_angle(rng.randf() * TAU)
		parts.append(_part(FLAKE, dir * 14.0, dir * rng.randf_range(40.0, 140.0) * s * 0.5, rng.randf_range(0.5, LIFE - 0.25), _pick(rng, [C[5], V[3], V[4]]), rng.randf_range(0.6, 1.8), rng))
	booms.append({"pos": ev.pos, "rad": rad, "age": 0.0, "parts": parts, "rng": rng, "seed": rng.randi()})

func tick(_dt: float) -> void:
	var dt := world_dt()
	var p := painter()
	p.begin()
	for b in booms:
		b.age += dt
		_step(b, dt)
		_draw(p, b)
	booms = booms.filter(func(b): return b.age < LIFE)
	if _plasmas != null: _plasmas.step(dt)
	p.end()

## 粒を進める。殻の膨らむあいだは殻から星屑がこぼれる。
func _step(b: Dictionary, dt: float) -> void:
	var t: float = b.age
	var rad: float = b.rad
	var rng: RandomNumberGenerator = b.rng
	if t > 0.1 and t < BALL * 1.4 and rng.randf() < 70.0 * minf(1.0, rad / 90.0) * dt:
		var dir := Vector2.from_angle(rng.randf() * TAU)
		b.parts.append(_part(STAR, dir * _shell(rad, t), dir * rng.randf_range(10.0, 40.0) * rad / 70.0, rng.randf_range(0.25, 0.5), C[5] if rng.randf() < 0.5 else V[4], rng.randf_range(0.6, 1.8), rng))
	var parts: Array[Dictionary] = b.parts
	var kept := 0
	for q in parts:
		q.life -= dt
		match q.kind:
			MOTE: q.vel -= q.vel * 0.6 * dt
			FLAKE:
				q.vel -= q.vel * 2.2 * dt
				q.vel.y += 35.0 * dt
				q.at.x += sin(t * 2.5 + q.seed) * 7.0 * dt
			STAR:
				q.vel -= q.vel * 1.6 * dt
				q.vel.y -= 5.0 * dt
		q.at += q.vel * dt
		# 試作の画面の外へ出た粒は消す。残る粒の順番を保ち、同じ列へ詰める。
		if q.life > 0.0 and (q.at as Vector2).length() < rad * 1.45:
			parts[kept] = q
			kept += 1
	parts.resize(kept)

func _draw(p: PixelPainter, b: Dictionary) -> void:
	var o: Vector2 = (b.pos / p.px).round()
	var t: float = b.age
	var rad: float = b.rad
	var s := rad / 35.0
	if t < 0.07: p.disk(o * p.px, (9.0 - t * 60.0) * s * 0.7, C[6])
	if t < 0.25: _flare(p, o, 52.0 * s * 0.8 * pow(1.0 - t / 0.25, 1.3), 1.0 - t / 0.25)
	# 稲妻：中心から走り、殻の上を這う。数フレームごとに打ち直し、球が消えるにつれて短く少なくなる
	var left := (1.0 - smoothstep(0.1, BALL * 1.3, t)) * ARCS
	if left > 0.0:
		var r := RandomNumberGenerator.new()
		r.seed = hash([b.seed, floori(t * 18.0)])
		for i in 2 + roundi(5.0 * left):
			var length := r.randf_range(26.0, 58.0) * s * 0.75 * (0.45 + 0.55 * left)
			var path := _bolt(r, Vector2.ZERO, Vector2.from_angle(r.randf() * TAU) * length, 0.28, 5)
			_arc(p, o, path, 0.8 * left)
			if r.randf() < 0.6: _arc(p, o, _fork(r, path, 14.0 * s * 0.7, 0.35), 0.5 * left)
		var rs := _shell(rad, t)
		for i in 5:
			var a := r.randf() * TAU
			_arc(p, o, _bolt(r, Vector2.from_angle(a) * rs, Vector2.from_angle(a + r.randf_range(0.2, 0.4)) * rs, 0.4, 4), 0.6 * left)
	for q in b.parts:
		var k: float = q.life / q.max
		var at: Vector2 = q.at
		var col: Color = q.col
		match q.kind:
			MOTE:
				var sp := maxf(1.0, (q.vel as Vector2).length())
				var u: Vector2 = q.vel / sp
				var length: float = minf(16.0, 0.5 + sp * 0.026) * q.size
				var a := k / 0.35 if k < 0.35 else 1.0
				_line(p, o, at - u * length, at - u * length * 0.35, _scaled(col, 0.55), a)
				_line(p, o, at - u * length * 0.4, at, col, a)
			FLAKE:
				var a := minf(1.0, k * 3.0)
				_dot(p, o, at, col, a)
				if q.size > 1.3:
					for d in CROSS: _dot(p, o, at + d, _scaled(col, 0.8), a * 0.8)
			STAR:
				var tw := 0.6 + 0.4 * sin(t * (8.0 + fmod(q.seed, 5.0)) + q.seed)
				if q.size < 1.0:
					if tw * k > 0.25: _dot(p, o, at, C[6] if tw > 0.8 else col)
				else:
					_sparkle(p, o, at, q.size * tw * minf(1.0, k * 3.0), col, _scaled(col, 0.75))

## 殻の半径（ドット）：一気に押し出してからゆるむ。
func _shell(rad: float, t: float) -> float:
	return rad * (0.14 + 0.86 * (1.0 - pow(1.0 - clampf(t / BALL, 0.0, 1.0), 3.0)))

func _part(kind: int, at: Vector2, vel: Vector2, life: float, col: Color, size: float, rng: RandomNumberGenerator) -> Dictionary:
	return {"kind": kind, "at": at, "vel": vel, "life": life, "max": life, "col": col, "size": size, "seed": rng.randf() * 100.0}

func _pick(rng: RandomNumberGenerator, list: Array) -> Color:
	return list[rng.randi() % list.size()]

func _scaled(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)

## 中心 o（ドット）からの位置 at に1ドット。a が1未満なら市松の順で間引いて薄くする。
func _dot(p: PixelPainter, o: Vector2, at: Vector2, col: Color, a := 1.0) -> void:
	if a <= 0.0: return
	var x := floorf(o.x + at.x)
	var y := floorf(o.y + at.y)
	if a < 1.0 and a <= (PixelPainter.bayer(int(x), int(y)) + 0.5) / 16.0: return
	p.fill(x, y, col)

func _line(p: PixelPainter, o: Vector2, a: Vector2, b: Vector2, col: Color, alpha := 1.0) -> void:
	var n := maxi(1, ceili(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	for i in n + 1:
		_dot(p, o, a.lerp(b, float(i) / n), col, alpha)

## 8本の光：横が長く、縦がその 0.6 倍、斜めが 0.3 倍。先へ行くほど薄れる。
func _flare(p: PixelPainter, o: Vector2, length: float, k: float) -> void:
	if length < 1.0: return
	for i in 8:
		var dir := Vector2.from_angle(i * PI / 4.0)
		var l := length if i % 4 == 0 else length * 0.6 if i % 2 == 0 else length * 0.3
		var d := 0.0
		while d <= l:
			var u := d / l
			_dot(p, o, dir * d, C[6] if u < 0.35 else C[5] if u < 0.7 else C[4], 1.0 if u < 0.6 else k * 1.5 * (1.0 - u) + 0.2)
			d += 0.5

## 十字のきらめき。腕の先は tip の色。
func _sparkle(p: PixelPainter, o: Vector2, at: Vector2, arm: float, col: Color, tip: Color) -> void:
	var n := roundi(arm)
	if n < 1: return
	var c := (o + at).floor() - o
	for d in range(1, n + 1):
		for e in CROSS: _dot(p, o, c + e * d, tip if d > n * 0.6 else col)
	if n >= 3:
		for e in DIAG: _dot(p, o, c + e, col)
	if n >= 6:
		for e in DIAG: _dot(p, o, c + e * 2.0, tip)
	_dot(p, o, c, C[6])

## 中点をずらして折る稲妻の道（ドット）。
func _bolt(r: RandomNumberGenerator, from: Vector2, to: Vector2, jag: float, depth: int) -> PackedVector2Array:
	var pts := PackedVector2Array([from, to])
	for level in depth:
		var next := PackedVector2Array([pts[0]])
		for i in range(1, pts.size()):
			var a := pts[i - 1]
			var b := pts[i]
			var l := maxf(a.distance_to(b), 0.0001)
			var off := (r.randf() * 2.0 - 1.0) * jag * l
			next.append((a + b) * 0.5 + (b - a).orthogonal() / l * off)
			next.append(b)
		pts = next
	return pts

## 稲妻の途中から斜めに分かれる枝。
func _fork(r: RandomNumberGenerator, path: PackedVector2Array, length: float, jag: float) -> PackedVector2Array:
	var i := 1 + floori(r.randf() * (path.size() - 2))
	var a := (path[i] - path[i - 1]).angle() + (-1.0 if r.randf() < 0.5 else 1.0) * 0.9 * (0.4 + 0.6 * r.randf())
	return _bolt(r, path[i], path[i] + Vector2.from_angle(a) * length * (0.4 + 0.6 * r.randf()), jag, 3)

## 稲妻1本：右へ1ドットずらした紫の線に、白い芯（先の4割は薄紫）。
func _arc(p: PixelPainter, o: Vector2, path: PackedVector2Array, k: float) -> void:
	if k <= 0.05: return
	for i in range(1, path.size()):
		_line(p, o, path[i - 1] + Vector2.RIGHT, path[i] + Vector2.RIGHT, C[4], k * 0.8)
		_line(p, o, path[i - 1], path[i], C[6] if i < path.size() * 0.6 else C[5], minf(1.0, k * 1.4))
