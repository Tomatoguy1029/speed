## ヘルクレス座の火の隕石群。C++ の falls（落ちてくる位置と残り秒）と burns（焼け跡の位置と残り秒）、meteor_impact の出来事だけを描く。
## 隕石は焦げた岩で、どれも同じ向きから斜めにまっすぐ落ち、炎の尾・煙・火の粉を引く。
## 地面に当たると短く光り、岩が大小の破片に割れて飛び散り、火の粉が散って、破片が減速して消え、煙が薄れる。
## 当たった所には赤熱した亀裂の焼け跡が残り、地表で小さな炎が揺れ、冷えて暗くなって消える。
## 落ちる岩・破片・煙・光は敵より上（sky）、焼け跡と落ちる影は敵より下（ground）へ描く。
extends Node2D

const SHADER := preload("res://shaders/hero_hercules.gdshader")
const NOISE := preload("res://assets/effects/build/burst_noise.tres")
const HERCULES: HeroDef = preload("res://data/heroes/hercules.tres")
## 隕石が来る向き（画面の左上から右下へ）と、落ち始めの高さ（世界の距離）
const FALL_DIR := Vector2(0.42, 1.0)
const FALL_HEIGHT := 560.0
## 隕石の岩の半径（ドット）
const ROCK := 15.0
## 炎の尾の長さ（岩の半径の倍）
const PLUME := 3.4
const FLAME := [Color("#fff6d8"), Color("#ffd27a"), Color("#ff8a24"), Color("#d8400e"), Color("#7a1c08")]
const SMOKE := Color("#2a2523")
## 着弾の閃光と照り返しの秒
const FLASH_TIME := 0.18
const GLOW_TIME := 0.5

var px := 1.82
var _sky: MultiMeshInstance2D
var _ground: MultiMeshInstance2D
var _dots: MultiMeshInstance2D
var _material: ShaderMaterial
var _seeds := {}
var _shards: Array[Dictionary] = []
var _puffs: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _glows: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _time := 0.0

## ground は敵より下に描く親。
func setup(cell: float, ground: Node2D) -> void:
	px = cell
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("value_noise", NOISE.get_meta("texture"))
	_ground = _multimesh(true, 128)
	ground.add_child(_ground)
	_dots = _multimesh(false, 4096)
	add_child(_dots)
	_sky = _multimesh(true, 256)
	add_child(_sky)

func _multimesh(shaded: bool, count: int) -> MultiMeshInstance2D:
	var node := MultiMeshInstance2D.new()
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	if shaded:
		mm.use_custom_data = true
		mm.mesh = FireBursts._mesh()
		node.material = _material
	else:
		mm.use_colors = true
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		mm.mesh = quad
	mm.instance_count = count
	mm.visible_instance_count = 0
	node.multimesh = mm
	return node

## 当たった瞬間：閃光、大小の破片、火の粉、煙を出す。
func impact(at: Vector2, radius: float) -> void:
	_flashes.append({"pos": at, "age": 0.0, "seed": randf() * 9.0})
	_glows.append({"pos": at, "age": 0.0, "seed": randf() * 9.0, "half": radius * 1.5 / px})
	var dir := FALL_DIR.normalized()
	for i in randi_range(26, 36):
		var angle := randf() * TAU
		var out := Vector2.from_angle(angle)
		# 落ちてきた向きへ少し多く飛ぶ
		var speed := randf_range(160.0, 720.0) * (1.0 + 0.6 * maxf(0.0, out.dot(dir)))
		var big := randf() < 0.3
		_shards.append({"pos": at + out * randf_range(2.0, 18.0), "vel": out * speed, "half": randf_range(5.0, 8.5) if big else randf_range(1.5, 4.0),
			"spin": randf() * TAU, "turn": randf_range(-9.0, 9.0), "age": 0.0, "life": randf_range(0.6, 1.1), "seed": randf() * 9.0})
	for i in 150:
		var out := Vector2.from_angle(randf() * TAU)
		_sparks.append({"pos": at, "vel": out * randf_range(250.0, 1100.0), "age": 0.0, "life": randf_range(0.3, 0.9), "drag": randf_range(2.0, 4.5), "kind": 0})
	# 飛び散る溶岩のしずく：大きめの粒が遅めに飛んで冷えていく
	for i in 26:
		var out := Vector2.from_angle(randf() * TAU)
		_sparks.append({"pos": at + out * randf_range(0.0, 20.0), "vel": out * randf_range(120.0, 420.0), "age": 0.0, "life": randf_range(0.6, 1.2), "drag": 2.2, "kind": 0, "size": 2.0})
	for i in 14:
		var out := Vector2.from_angle(randf() * TAU)
		_puffs.append({"pos": at + out * randf_range(0.0, radius * 0.35), "vel": out * randf_range(30.0, 90.0), "half": randf_range(12.0, 22.0), "age": -randf() * 0.15, "life": randf_range(1.2, 1.9), "seed": randf() * 9.0})

## dt は演出の秒。fire は C++ の hercules の値。
func tick(dt: float, fire: Dictionary) -> void:
	_time += dt
	_material.set_shader_parameter("time", _time)
	_material.set_shader_parameter("linear_output", get_viewport().use_hdr_2d)
	var falls: PackedFloat64Array = fire.get("falls", PackedFloat64Array())
	var burns: PackedFloat64Array = fire.get("burns", PackedFloat64Array())
	var fall_time := float(HERCULES.params.fall_time)
	var burn_time := float(HERCULES.params.burn_time)
	var radius := float(HERCULES.params.radius)
	var dir := FALL_DIR.normalized()
	var sky := _sky.multimesh
	var ground := _ground.multimesh
	var ns := 0
	var ng := 0
	var live := {}
	# 焼け跡は古いほど下へ重ね、新しい焼け跡の亀裂が上に見える
	for i in range(0, burns.size(), 3):
		var at := Vector2(burns[i], burns[i + 1])
		var key := _key(at)
		var heat := clampf(burns[i + 2] / burn_time, 0.0, 1.0)
		ng = _put(ground, ng, at, radius * 0.9 / px, 1, _seed(key, live), heat, 0.0)
		# 焼け跡の上で小さな炎が揺れて立ち、すぐ消える
		if heat > 0.15 and randf() < 30.0 * heat * dt:
			var spot := at + Vector2.from_angle(randf() * TAU) * radius * 0.45 * sqrt(randf())
			_sparks.append({"pos": spot, "vel": Vector2(randf_range(-8.0, 8.0), randf_range(-40.0, -15.0)), "age": 0.0, "life": randf_range(0.2, 0.4), "drag": 1.0, "kind": 2})
	for g in _glows: g.age += dt
	_glows = _glows.filter(func(g): return g.age < GLOW_TIME)
	for g in _glows:
		ng = _put(ground, ng, g.pos, g.half, 6, g.seed, g.age / GLOW_TIME, 0.0)
	for i in range(0, falls.size(), 3):
		var at := Vector2(falls[i], falls[i + 1])
		var key := _key(at)
		var seed := _seed(key, live)
		var left := clampf(falls[i + 2] / fall_time, 0.0, 1.0)
		ng = _put(ground, ng, at, ROCK, 4, seed, 1.0 - left, _time * 3.0 + seed, dir.angle(), false)
		# まっすぐ落ちる：落ち始めの高さから、同じ向きに同じ速さで近づく。高いほど少し大きく見える
		var rock_at := at - dir * FALL_HEIGHT * left
		var size := ROCK * (1.0 + 0.3 * left)
		var plume := roundf(size * PLUME)
		ns = _put(sky, ns, rock_at + dir * (size * 1.6 - plume) * px, plume, 5, seed, 1.0, size, dir.angle(), false)
		ns = _put(sky, ns, rock_at, size, 0, seed, 1.0, _time * 3.0 + seed, dir.angle(), false)
		_emit_tail(dt, rock_at, dir, size)
	for key in _seeds.keys():
		if not live.has(key): _seeds.erase(key)
	for f in _flashes: f.age += dt
	_flashes = _flashes.filter(func(f): return f.age < FLASH_TIME)
	for f in _flashes:
		ns = _put(sky, ns, f.pos, 62.0, 2, f.seed, f.age / FLASH_TIME, 0.0)
	for s in _shards:
		s.age += dt
		s.pos += s.vel * dt
		s.vel *= exp(-4.5 * dt)
		s.spin += s.turn * dt
		s.turn *= exp(-2.0 * dt)
		# 熱い破片は煙の筋を少し引く
		if s.half > 3.0 and s.age < 0.4 and randf() < 0.5: _sparks.append({"pos": s.pos, "vel": Vector2.ZERO, "age": 0.0, "life": 0.4, "drag": 1.0, "kind": 1})
	_shards = _shards.filter(func(s): return s.age < s.life)
	for s in _shards:
		var k: float = s.age / s.life
		# 減速しながら冷え、最後は小さく欠けて消える
		var half: float = s.half * (1.0 if k < 0.7 else 1.0 - (k - 0.7) / 0.3 * 0.6)
		ns = _put(sky, ns, s.pos, maxf(1.0, half), 0, s.seed, maxf(0.0, 0.9 - k * 1.2), s.spin, s.vel.angle(), false)
	for p in _puffs:
		p.age += dt
		p.pos += p.vel * dt
		p.vel *= exp(-1.5 * dt)
	_puffs = _puffs.filter(func(p): return p.age < p.life)
	for p in _puffs:
		if p.age < 0.0: continue
		var k: float = p.age / p.life
		ns = _put(sky, ns, p.pos, p.half * (1.0 + 0.8 * k), 3, p.seed, k, 0.0)
	sky.visible_instance_count = ns
	ground.visible_instance_count = ng
	_tick_sparks(dt)

## 岩の後ろへ：先に白熱した炎、橙、赤と冷えて煙になる粒。ときどき火の粉が横へ飛び離れる
func _emit_tail(dt: float, at: Vector2, dir: Vector2, size: float) -> void:
	var side := dir.orthogonal()
	for i in int(ceil(460.0 * dt)):
		var spread := randf_range(-1.0, 1.0)
		var from := at - dir * size * px * randf_range(0.2, 0.8) + side * spread * size * px * 0.7
		_sparks.append({"pos": from, "vel": -dir * randf_range(30.0, 140.0) + side * spread * randf_range(10.0, 80.0), "age": 0.0, "life": randf_range(0.2, 0.5), "drag": 3.0, "kind": 2, "size": 2.0 if randf() < 0.4 else 1.0})
	for i in int(ceil(40.0 * dt)):
		_sparks.append({"pos": at - dir * size * px * 0.8 + side * randf_range(-1.0, 1.0) * size * px * 0.5, "vel": -dir * randf_range(10.0, 40.0), "age": 0.0, "life": randf_range(0.5, 0.9), "drag": 1.5, "kind": 1})
	for i in (1 if randf() < 45.0 * dt else 0):
		var out := side * (1.0 if randf() < 0.5 else -1.0)
		_sparks.append({"pos": at, "vel": out * randf_range(120.0, 300.0) - dir * randf_range(50.0, 200.0), "age": 0.0, "life": randf_range(0.3, 0.6), "drag": 2.5, "kind": 0})

func _tick_sparks(dt: float) -> void:
	var mm := _dots.multimesh
	var n := 0
	for s in _sparks:
		s.age += dt
		s.pos += s.vel * dt
		s.vel *= exp(-s.drag * dt)
	_sparks = _sparks.filter(func(s): return s.age < s.life)
	if _sparks.size() > mm.instance_count: _sparks = _sparks.slice(_sparks.size() - mm.instance_count)
	for s in _sparks:
		var k: float = s.age / s.life
		var color: Color
		var size: float = px * s.get("size", 1.0)
		match int(s.kind):
			0: color = FLAME[clampi(int(k * 4.0), 0, 4)]
			1:
				color = Color(SMOKE, 0.5 * (1.0 - k))
				size = px * 2.0
			_: color = FLAME[clampi(int(k * 5.0), 0, 4)] if k < 0.75 else Color(SMOKE, 0.6)
		mm.set_instance_transform_2d(n, Transform2D(0.0, Vector2.ONE * size, 0.0, (s.pos / px).floor() * px + Vector2.ONE * size * 0.5))
		mm.set_instance_color(n, color)
		n += 1
	mm.visible_instance_count = n

func _key(at: Vector2) -> Vector2i:
	return Vector2i(roundi(at.x * 4.0), roundi(at.y * 4.0))

func _seed(key: Vector2i, live: Dictionary) -> float:
	live[key] = true
	if not _seeds.has(key): _seeds[key] = randf() * 9.0
	return _seeds[key]

## half はドットの数。snap すると世界のドットの格子へそろえる（回す四角はそろえない）
func _put(mm: MultiMesh, n: int, at: Vector2, half: float, kind: int, seed: float, k: float, w: float, angle := 0.0, snap := true) -> int:
	if n >= mm.instance_count: return n
	half = roundf(half)
	var pos := (at / px).round() * px if snap else at
	mm.set_instance_transform_2d(n, Transform2D(angle, Vector2.ONE * half * px, 0.0, pos))
	mm.set_instance_custom_data(n, Color(kind * 1000.0 + half, seed, k, w))
	return n + 1
