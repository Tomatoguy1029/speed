## ふたご座の光と影の兄弟。発動すると機体が金の光の機体と影の機体に粘りながら裂けて分かれ（どちらも機体の形だけを残す。本物の機体は run_frame_view が隠す）、
## 影は光の横に寄り添って並走する。突進では影が描いた線を左右反転した経路（C++ の twin）を同時に走り、
## 走り終えると影が崩れて糸や断片になり、光へ吸い寄せられて戻る。効いている間は短く再形成して、また並走する。
## 絵は機体の絵（airship.png）の1ドット＝1セルで描き、機体の変形（向き・大きさ）にそのまま合わせる。
extends Node2D

const SHADER := preload("res://shaders/hero_gemini.gdshader")
const SPLIT_SHADER := preload("res://shaders/hero_gemini_split.gdshader")
const NOISE := preload("res://assets/effects/build/burst_noise.tres")
const SHIP := preload("res://assets/pixel/airship.png")
const SHIP_SIZE := Vector2(31.0, 70.0)
## 絵のまわりへ広げるセル数（hero_gemini.gdshaderinc の PAD と同じ）
const PAD := 16
## 機体の絵の中心から見た、機体の位置（Sprite2D の offset の逆）
const OFFSET := Vector2(0.0, 5.0)
## 並走するときの、光と影の中心の間（絵のセル）
const SIDE := 40.0
## 最初の分裂と、突進のあとの再形成の秒
const SPLIT_TIME := 1.15
const REFORM_TIME := 0.42
## 影が崩れて光へ戻る秒
const MERGE_TIME := 0.5
## 光の機体の色が変わりきる秒
const LIGHT_IN := 0.35
## 突進中の残光・残像を置く間隔と寿命
const STAMP_EVERY := 0.03
const STAMP_LIFE := 0.32
## 影の残像は崩れながら長めに残る
const SHADOW_STAMP_LIFE := 0.7
## ドローン1機に集まる影の粒の数
const ASSEMBLE_DOTS := 16
const SHADOW_DOTS := [Color("#2a0f45"), Color("#4a1f78"), Color("#8f52db")]
const LIGHT_DOTS := [Color("#f0a030"), Color("#ffd870"), Color("#fffbe8")]

## 光の機体の濃さ（0〜1）。0.5 を超えると run_frame_view が本物の機体を隠す
var light := 0.0
var _ships: MultiMeshInstance2D
var _split: MeshInstance2D
var _split_material: ShaderMaterial
var _dots: MultiMeshInstance2D
var _materials: Array[ShaderMaterial] = []
var _state := &"off"
var _age := 0.0
var _since := 0.0
var _seed := 0.0
var _shadow := Vector2.INF
var _shadow_velocity := Vector2.ZERO
var _shadow_angle := 0.0
var _last_twin := Vector2.INF
var _stamp_wait := 0.0
var _stamps: Array[Dictionary] = []
var _flecks: Array[Dictionary] = []
var _fragments: Array[Dictionary] = []
var _outline := PackedVector2Array()
var _last_scale := 1.0
## 崩れはじめた影の変形（崩れる間はその場に残す）
var _shadow_merge_from := Transform2D.IDENTITY
var _time := 0.0
## 影の外に付ける武器（ドローン）を、影の粒が集まって形づくる演出。drones は C++ の影のドローン（位置と現れる進み）
var _drones: Array = []
var _assembled := false

func setup() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sdf := _bake_distance()
	var material := ShaderMaterial.new()
	material.shader = SHADER
	_ships = MultiMeshInstance2D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.mesh = FireBursts._mesh()
	mm.instance_count = 64
	mm.visible_instance_count = 0
	_ships.multimesh = mm
	_ships.material = material
	add_child(_ships)
	_split = MeshInstance2D.new()
	_split.mesh = FireBursts._mesh()
	_split_material = ShaderMaterial.new()
	_split_material.shader = SPLIT_SHADER
	_split.material = _split_material
	_split.visible = false
	add_child(_split)
	_dots = MultiMeshInstance2D.new()
	var dm := MultiMesh.new()
	dm.transform_format = MultiMesh.TRANSFORM_2D
	dm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	dm.mesh = quad
	dm.instance_count = 1024
	dm.visible_instance_count = 0
	_dots.multimesh = dm
	add_child(_dots)
	_materials = [material, _split_material]
	for m in _materials:
		m.set_shader_parameter("value_noise", NOISE.get_meta("texture"))
		m.set_shader_parameter("ship_tex", SHIP)
		m.set_shader_parameter("sdf_tex", sdf)
	visible = false

## 機体の絵の外の各セルについて、絵までのおおよその距離（2回なめるチャンファー距離）を求めて画像にする。
func _bake_distance() -> ImageTexture:
	var image := SHIP.get_image()
	if image.is_compressed(): image.decompress()
	var w := int(SHIP_SIZE.x) + PAD * 2
	var h := int(SHIP_SIZE.y) + PAD * 2
	var far := 999.0
	var dist := PackedFloat32Array()
	dist.resize(w * h)
	for y in h:
		for x in w:
			var sx := x - PAD
			var sy := y - PAD
			var inside := sx >= 0 and sy >= 0 and sx < int(SHIP_SIZE.x) and sy < int(SHIP_SIZE.y) and image.get_pixel(sx, sy).a >= 0.5
			dist[y * w + x] = 0.0 if inside else far
			if inside:
				var edge := false
				for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = sx + o.x
					var ny: int = sy + o.y
					if nx < 0 or ny < 0 or nx >= int(SHIP_SIZE.x) or ny >= int(SHIP_SIZE.y) or image.get_pixel(nx, ny).a < 0.5: edge = true
				if edge: _outline.append(Vector2(sx, sy))
	for pass_index in 2:
		var ys := range(h) if pass_index == 0 else range(h - 1, -1, -1)
		var xs := range(w) if pass_index == 0 else range(w - 1, -1, -1)
		var s := 1 if pass_index == 0 else -1
		for y: int in ys:
			for x: int in xs:
				var i := y * w + x
				var best := dist[i]
				for o in [Vector2i(-s, 0), Vector2i(0, -s), Vector2i(-s, -s), Vector2i(s, -s)]:
					var nx: int = x + o.x
					var ny: int = y + o.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h: continue
					best = minf(best, dist[ny * w + nx] + (1.0 if o.x == 0 or o.y == 0 else 1.41))
				dist[i] = best
	var out := Image.create(w, h, false, Image.FORMAT_RF)
	for y in h:
		for x in w:
			out.set_pixel(x, y, Color(minf(dist[y * w + x], float(PAD)) / float(PAD), 0.0, 0.0))
	return ImageTexture.create_from_image(out)

## dt は演出の秒。ship は本物の機体の絵の変形（位置・向き・大きさ）、hero は C++ の英雄の値。
## drones はエスコートウィングのドローンのうち影に付くもの（twin・appear を持つ）。
func tick(dt: float, ship: Transform2D, hero: Dictionary, drones: Array = []) -> void:
	_drones = drones
	_time += dt
	var active := StringName(hero.get("power", &"")) == &"gemini" and float(hero.get("active", 0.0)) > 0.0
	var twin: Dictionary = hero.get("twin", {})
	var tracing := bool(twin.get("tracing", false))
	var twin_at: Vector2 = twin.get("position", Vector2.ZERO)
	var right := ship.x.normalized()
	var scale_px := ship.x.length()
	var side_at := ship * Vector2(SIDE, 0.0)
	_age += dt
	if _state == &"off":
		if not active:
			light = maxf(0.0, light - dt / LIGHT_IN)
			_tick_dots(dt, ship)
			visible = light > 0.0 or not _flecks.is_empty() or not _fragments.is_empty()
			_ships.multimesh.visible_instance_count = 0
			_split.visible = false
			return
		_begin(&"split")
		_since = 0.0
	_since += dt
	visible = true
	light = minf(1.0, light + dt / LIGHT_IN) if active else maxf(0.0, light - dt / LIGHT_IN)
	match _state:
		&"split", &"reform":
			var length := SPLIT_TIME if _state == &"split" else REFORM_TIME
			if _age >= length:
				_shadow = side_at
				_shadow_velocity = Vector2.ZERO
				_shadow_angle = ship.get_rotation()
				_begin(&"follow")
		&"follow":
			if not active:
				_begin_merge()
			elif tracing:
				_last_twin = twin_at
				_begin(&"dash")
			else:
				# 寄り添う：機体の横へばねで追い、少し遅れて有機的に揺れる
				var sway := right * sin(_time * 2.3) * 2.5 * scale_px - ship.y.normalized() * sin(_time * 1.7 + 1.0) * 3.0 * scale_px
				var goal := side_at + sway
				var omega := 11.0
				var accel := (goal - _shadow) * omega * omega - _shadow_velocity * 2.0 * omega
				_shadow_velocity += accel * dt
				_shadow += _shadow_velocity * dt
				_shadow_angle = lerp_angle(_shadow_angle, ship.get_rotation(), 1.0 - exp(-8.0 * dt))
				_emit_flecks(ship, _shadow_xf(scale_px), dt, false)
		&"dash":
			if not tracing:
				_begin_merge()
			else:
				_shadow = _shadow.lerp(twin_at, 1.0 - exp(-40.0 * dt))
				var move := twin_at - _last_twin
				if move.length_squared() > 0.25: _shadow_angle = move.angle() + PI * 0.5
				_last_twin = twin_at
				_stamp_wait -= dt
				if _stamp_wait <= 0.0:
					_stamp_wait = STAMP_EVERY
					_stamps.append({"xf": ship, "kind": 2, "age": 0.0, "life": STAMP_LIFE, "seed": randf() * 9.0})
					_stamps.append({"xf": _shadow_xf(scale_px), "kind": 3, "age": 0.0, "life": SHADOW_STAMP_LIFE, "seed": randf() * 9.0})
				_emit_flecks(ship, _shadow_xf(scale_px), dt)
		&"merge":
			_tick_fragments(dt, ship)
			if _age >= MERGE_TIME and _fragments.is_empty():
				if active: _begin(&"reform")
				else:
					_state = &"off"
					_shadow = Vector2.INF
	_draw_ships(dt, ship, scale_px, active)
	_tick_dots(dt, ship)

func _begin(state: StringName) -> void:
	_state = state
	_age = 0.0
	_seed = randf() * 9.0

func _shadow_xf(scale_px: float) -> Transform2D:
	return Transform2D(_shadow_angle, Vector2.ONE * scale_px, 0.0, _shadow)

## 影の輪郭のドットを、少しずつ遅れて光の機体へ吸い寄せられる断片にする。
func _begin_merge() -> void:
	_begin(&"merge")
	_fragments.clear()
	if not _shadow.is_finite(): return
	_shadow_merge_from = _shadow_xf(_last_scale)
	for i in range(0, _outline.size(), 2):
		var local: Vector2 = _outline[i] - SHIP_SIZE * 0.5 + Vector2(0.5, 0.5) + OFFSET
		_fragments.append({"from": _shadow_merge_from * local, "local": local, "delay": randf() * 0.22, "t": 0.0, "bend": randf_range(-1.0, 1.0), "color": SHADOW_DOTS[randi() % 3]})

## 断片は崩れた影の位置から、光の機体の同じ場所へ弧を描いて吸い込まれる。途中で細い糸を引く
func _tick_fragments(dt: float, ship: Transform2D) -> void:
	for f in _fragments:
		f.t += dt
	_fragments = _fragments.filter(func(f): return f.t - f.delay < 0.38)

func _draw_ships(dt: float, ship: Transform2D, scale_px: float, active: bool) -> void:
	_last_scale = scale_px
	var hdr := get_viewport().use_hdr_2d
	for m in _materials:
		m.set_shader_parameter("time", _time)
		m.set_shader_parameter("linear_output", hdr)
	for s in _stamps: s.age += dt / s.life
	_stamps = _stamps.filter(func(s): return s.age < 1.0)
	var mm := _ships.multimesh
	var n := 0
	var quad := Vector2.ONE * 0.5 * (SHIP_SIZE + Vector2.ONE * PAD * 2.0)
	for s in _stamps:
		n = _put_ship(mm, n, s.xf, quad, s.kind, s.age, 1.0, s.seed)
	var aura := clampf(_since / 0.4, 0.0, 1.0) * (1.0 if active else light)
	n = _put_ship(mm, n, ship, quad, 0, aura, 1.0, 0.0)
	if light > 0.0: n = _put_ship(mm, n, ship, quad, 5, 1.0, light, 0.0)
	_split.visible = false
	match _state:
		&"split", &"reform":
			var big := _state == &"split"
			var u := clampf(_age / (SPLIT_TIME if big else REFORM_TIME), 0.0, 1.0)
			_place_split(ship, u, big)
		&"follow", &"dash":
			n = _put_ship(mm, n, _shadow_xf(scale_px), quad, 1, 1.0, 1.0, _seed)
		&"merge":
			if _shadow.is_finite():
				var k := clampf(_age / (MERGE_TIME * 0.6), 0.0, 1.0)
				n = _put_ship(mm, n, _shadow_merge_from, quad, 4, k, 1.0, _seed)
	mm.visible_instance_count = n

func _put_ship(mm: MultiMesh, n: int, xf: Transform2D, quad: Vector2, kind: int, k: float, alpha: float, seed: float) -> int:
	if n >= mm.instance_count: return n
	mm.set_instance_transform_2d(n, xf * Transform2D(0.0, quad, 0.0, OFFSET))
	mm.set_instance_custom_data(n, Color(kind, k, alpha, seed))
	return n + 1

## 分裂の進み u（0〜1）から、離れ方・粘りの首の細さ・穴・糸のちぎれを決めて膜を置く。
## 離れ方は、はじめ粘って重く、ちぎれる直前に伸びきり、ちぎれると反動で少し戻って揺れる。
func _place_split(ship: Transform2D, u: float, big: bool) -> void:
	var tear := 0.78
	var stretch := pow(smoothstep(0.04, tear, u), 1.7)
	var sep := SIDE * (stretch * 1.12 if u < tear else 1.0 + 0.12 * exp(-(u - tear) * 9.0) * cos((u - tear) * 30.0))
	if not big: sep = SIDE * (smoothstep(0.0, 0.7, u) * 1.06 if u < 0.7 else 1.0 + 0.06 * cos((u - 0.7) * 25.0) * (1.0 - u) / 0.3)
	sep = roundf(sep)
	var size := Vector2(sep, 0.0) + SHIP_SIZE + Vector2.ONE * PAD * 2.0
	var center := Vector2(sep * 0.5, 0.0) + OFFSET
	_split.transform = ship * Transform2D(0.0, size * 0.5, 0.0, center)
	_split.visible = true
	_split_material.set_shader_parameter("sep", sep)
	_split_material.set_shader_parameter("join", lerpf(20.0, 3.0, smoothstep(0.1, 0.6, u)) * (1.0 if big else 0.7))
	_split_material.set_shader_parameter("holes", smoothstep(0.35, 0.72, u) if big else smoothstep(0.2, 0.55, u))
	_split_material.set_shader_parameter("cut", smoothstep(0.66, 0.84, u) if big else smoothstep(0.55, 0.75, u))
	_split_material.set_shader_parameter("seed", _seed)
	_split_material.set_shader_parameter("shadow_strength", smoothstep(0.0, 0.5, u))

## 光は細かい光の粒を、影は剥がれてこぼれる暗い粉を後ろへ残す。突進中（dash）は多く、並走中は少しだけこぼす
func _emit_flecks(ship: Transform2D, shadow: Transform2D, dt: float, dash := true) -> void:
	if _outline.is_empty(): return
	for i in (3 if dash else 0):
		var p: Vector2 = _outline[randi() % _outline.size()] - SHIP_SIZE * 0.5 + OFFSET
		_flecks.append({"pos": ship * p, "vel": ship.y.normalized() * randf_range(20.0, 60.0) + ship.x.normalized() * randf_range(-25.0, 25.0), "life": randf_range(0.25, 0.55), "age": 0.0, "colors": LIGHT_DOTS, "size": ship.x.length()})
	for i in (7 if dash else (1 if randf() < 0.6 else 0)):
		var p: Vector2 = _outline[randi() % _outline.size()] - SHIP_SIZE * 0.5 + OFFSET
		_flecks.append({"pos": shadow * p, "vel": shadow.y.normalized() * randf_range(5.0, 30.0) + shadow.x.normalized() * randf_range(-25.0, 25.0), "life": randf_range(0.6, 1.2), "age": 0.0, "colors": SHADOW_DOTS, "size": shadow.x.length() * (2.0 if randf() < 0.3 else 1.0)})

func _tick_dots(dt: float, ship: Transform2D) -> void:
	var mm := _dots.multimesh
	var n := 0
	n = _assemble(mm, n, ship)
	for f in _flecks:
		f.age += dt
		f.pos += f.vel * dt
		f.vel *= exp(-3.0 * dt)
	_flecks = _flecks.filter(func(f): return f.age < f.life)
	for f in _flecks:
		var k: float = f.age / f.life
		var colors: Array = f.colors
		var c: Color = colors[clampi(int((1.0 - k) * 3.0), 0, 2)]
		n = _dot(mm, n, f.pos, f.size, c)
	# 崩れた影の断片：光の機体の同じ場所へ弧を描いて吸い込まれ、通ったあとに細い糸を残す
	for f in _fragments:
		var t := clampf((f.t - f.delay) / 0.38, 0.0, 1.0)
		if t <= 0.0:
			n = _dot(mm, n, f.from, ship.x.length(), f.color)
			continue
		var to: Vector2 = ship * f.local
		var e := t * t * (3.0 - 2.0 * t)
		var mid: Vector2 = (f.from + to) * 0.5 + (to - f.from).orthogonal() * 0.25 * f.bend
		for j in 4:
			var s := maxf(0.0, e - j * 0.07)
			var at: Vector2 = f.from.lerp(mid, s).lerp(mid.lerp(to, s), s)
			n = _dot(mm, n, at, ship.x.length() * (1.0 if j == 0 else 0.8), f.color if j == 0 else SHADOW_DOTS[1])
	mm.visible_instance_count = n

func _dot(mm: MultiMesh, n: int, at: Vector2, size: float, color: Color) -> int:
	if n >= mm.instance_count: return n
	mm.set_instance_transform_2d(n, Transform2D(0.0, Vector2.ONE * size, 0.0, at))
	mm.set_instance_color(n, color)
	return n + 1

## 影のドローンが現れる間、影のまわりから小さな影の粒が渦を巻いて集まり、ドローンの形にまとまる。まとまった瞬間に紫の粒がはじける
func _assemble(mm: MultiMesh, n: int, ship: Transform2D) -> int:
	if _drones.is_empty() or not _shadow.is_finite():
		_assembled = false
		return n
	var size := ship.x.length()
	var appear := float(_drones[0].get("appear", 1.0))
	if appear >= 1.0:
		if not _assembled:
			_assembled = true
			for d in _drones:
				for i in 10:
					_flecks.append({"pos": d.pos, "vel": Vector2.from_angle(randf() * TAU) * randf_range(30.0, 90.0), "life": randf_range(0.2, 0.4), "age": 0.0, "colors": SHADOW_DOTS, "size": size})
		return n
	_assembled = false
	var e := appear * appear * (3.0 - 2.0 * appear)
	for k in _drones.size():
		var to: Vector2 = _drones[k].pos
		for i in ASSEMBLE_DOTS:
			var h := float(k * ASSEMBLE_DOTS + i)
			var angle := fposmod(sin(h * 12.9898) * 43758.5453, TAU)
			var reach := (36.0 + 50.0 * fposmod(sin(h * 78.233) * 9631.7, 1.0)) * size
			var from := _shadow + Vector2.from_angle(angle) * reach
			var swirl := (to - from).orthogonal() * 0.35 * sin(e * PI) * (1.0 if i % 2 == 0 else -1.0)
			var at := from.lerp(to, e) + swirl
			n = _dot(mm, n, at, size * (2.0 if i % 4 == 0 else 1.0), SHADOW_DOTS[i % 3])
	return n
