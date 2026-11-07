## しし座の力：機体が真上から見た星の獅子になる（shaders/hero_leo.gdshader）。たてがみの先・尾の先・足から星くずがこぼれ、
## 駆ける摩擦で出た金の火花がたてがみの上を後ろへ飛んで、たてがみを金にきらめかせる。
## 獅子は1枚の四角に描き、星くずと火花は1ドットの四角を MultiMesh にまとめる（火花は獅子の手前）。位置は世界座標。
## 変身：機体が金の星くずになり、渦を巻いて獅子の輪郭へ移る（GATHER 秒）。そろった瞬間に獅子が金に光り（変身の閃光）、
## 本体は MATERIALIZE 秒までに4段階で今の見た目になる。走り出すと、粒子の演出が EFFECTS_FROM〜EFFECTS_TO 秒に4段階で流れ出す。
extends Node2D

const SHADER := preload("res://shaders/hero_leo.gdshader")
const BLUR := preload("res://shaders/hero_leo_blur.gdshader")
const SCREEN := preload("res://shaders/hero_leo_screen.gdshader")
## モーションブラーの長さ（機体のドット、駆ける速さの割合 1 のとき）
const SMEAR := 40.0
## ぶれの、元の形のすぐ後ろでの濃さ（離れるほど段々薄れる）。オーラのぶれは薄く短くして、本体のぶれを見せる
const TRAIL_DENSITY := 0.8
const AURA_TRAIL_DENSITY := 0.3
const AURA_SMEAR := 0.5
const NOISE := preload("res://assets/effects/build/burst_noise.tres")
const BODY := preload("res://assets/pixel/leo/lion_body.png")
const AUX := preload("res://assets/pixel/leo/lion_aux.png")
const HALF := 95.0
## 絵の中で機体の位置にあたる点と、機体の1ドットに入る絵のドット数（shader と同じ）
const PIVOT := Vector2(60.0, 100.0)
const ART_PER_CELL := 1.65
## 火花の生え際（絵の y、顔のマスクの後ろのふち）。これより前には火花を出さない
const SPARK_ROOT := 42.0
## 空気が左右に分かれる鼻先（絵の座標）
const WAKE_FOCUS := Vector2(59.0, 2.0)
## たてがみの根元と長さ（絵のドット。shader の MANE_ROOT・mane_length と同じ）
const MANE_ROOT := 34.0
const MANE_LENGTH := 98.0
## 駆ける脚のコマと、1歩の中で切り替わる時期（0〜1）：集める→中→伸ばす（宙に浮く間なので長め）→中
const STRIDE := [1, 0, 2, 0]
const STRIDE_AT := [0.0, 0.26, 0.42, 0.84]
## 1秒あたりの歩数（駆ける速さの割合 1 のとき）
const STRIDE_RATE := 1.6
const GOLD := [Color("#d98f28"), Color("#ffc652"), Color("#ffeead"), Color("#fffbf4")]
## 絵の座標で、星くずがこぼれる場所（たてがみの先・尾の先・後ろ足・脇腹）。
## 変身の時間割（発動からの秒）
const GATHER := 0.55
const MATERIALIZE := 0.95
const EFFECTS_FROM := 0.95
const EFFECTS_TO := 1.75
## 閃光の秒と、輪郭の星くずが消える秒
const FLASH := 0.15
const OUTLINE_FADE := 0.45
## 星くずが出る機体の形（世界の幅：前後の長さ、左右の幅）
const SHIP_SIZE := Vector2(70.0, 30.0)
const SOURCES := [Vector2(48.0, 126.0), Vector2(70.0, 126.0), Vector2(59.0, 132.0), Vector2(108.0, 196.0), Vector2(96.0, 186.0), Vector2(28.0, 150.0), Vector2(92.0, 150.0), Vector2(22.0, 112.0), Vector2(98.0, 112.0)]

var px := 1.82
var _lion: MeshInstance2D
var _material: ShaderMaterial
var _aura: MeshInstance2D
## 効いている間、画面を魔法の力に包まれたようにする（外側の星雲の光・十字のきらめき）
var _screen: ShaderMaterial
var _screen_rect: ColorRect
## オーラと、本体・オーラのぶれの元の材質（本体の材質と同じ形・同じ動きにそろえる）
var _painted: Array[ShaderMaterial] = []
## 後ろへ流れるぶれ（オーラの分、本体の分）
var _trails: Array[MeshInstance2D] = []
var _aura_material: ShaderMaterial
var _dust: MultiMeshInstance2D
var _sparks: MultiMeshInstance2D
var _flecks: Array[Dictionary] = []
var _spark_emit := 0.0
var _wake: Array[Dictionary] = []
var _wake_emit := 0.0
var _motes: Array[Dictionary] = []
var _emit := 0.0
var _time := 0.0
var _stride := 0.0
## 獅子の輪郭の点（絵の座標）と、変身の星くず
var _outline: PackedVector2Array
var _forming: Array[Dictionary] = []
var _formed := false
## 形がそろった瞬間に、空間をゆがませる波を出す先（RenderPipeline。無ければ出さない）
var pipeline: Object

## cell は1ドットの世界での幅、screen_layer は画面全体の演出を重ねる層（世界より上、HUD より下）。
func setup(cell: float, screen_layer := 60) -> void:
	px = cell
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_dust = MultiMeshInstance2D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * px
	mm.mesh = quad
	mm.instance_count = 2048
	mm.visible_instance_count = 0
	_dust.multimesh = mm
	add_child(_dust)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("value_noise", NOISE.get_meta("texture"))
	_material.set_shader_parameter("body_tex", BODY)
	_material.set_shader_parameter("aux_tex", AUX)
	_material.set_shader_parameter("half_cells", HALF)
	_material.set_shader_parameter("art_per_cell", ART_PER_CELL)
	_aura_material = _material.duplicate()
	_aura_material.set_shader_parameter("layer", 2)
	# モーションブラー：本体とオーラは、それぞれ小さな画面へ1ドット＝1テクセルで描き、そこから後ろへ流れるぶれを別々につくる。
	# 本体のぶれの元には、ふちの金と目の光をのせない
	var body_paint: ShaderMaterial = _material.duplicate()
	body_paint.set_shader_parameter("layer", 3)
	var aura_paint: ShaderMaterial = _aura_material.duplicate()
	_painted = [_aura_material, body_paint, aura_paint]
	_material.set_shader_parameter("layer", 1)
	# 重なり：奥からオーラのぶれ、本体のぶれ、本体、オーラ。本体とオーラはぶらさない
	_trails = [_trail(aura_paint, AURA_TRAIL_DENSITY), _trail(body_paint, TRAIL_DENSITY)]
	_lion = _mesh(_material)
	_aura = _mesh(_aura_material)
	# 魔法の力に包まれた画面：世界を描いたあとの画面を写して、外側ほどぼかし、星雲の光・きらめきを足す
	var layer := CanvasLayer.new()
	layer.layer = screen_layer
	add_child(layer)
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(copy)
	_screen_rect = ColorRect.new()
	_screen_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen = ShaderMaterial.new()
	_screen.shader = SCREEN
	_screen.set_shader_parameter("value_noise", NOISE.get_meta("texture"))
	_screen_rect.material = _screen
	layer.add_child(_screen_rect)
	_sparks = MultiMeshInstance2D.new()
	var smm := MultiMesh.new()
	smm.transform_format = MultiMesh.TRANSFORM_2D
	smm.use_colors = true
	smm.mesh = quad
	smm.instance_count = 2048
	smm.visible_instance_count = 0
	_sparks.multimesh = smm
	add_child(_sparks)
	_outline = _outline_points()

## dt は演出の秒。strength は 0〜1 の濃さ、stride は駆ける速さの割合。age は発動からの秒（INF なら変身を省く）。
func tick(dt: float, pos: Vector2, heading: float, strength: float, stride: float, age := INF) -> void:
	_time += dt
	_stride = fmod(_stride + dt * STRIDE_RATE * stride, 1.0)
	visible = strength > 0.0
	# 駆け足の強弱：機体は一定の速さで進むが、獅子は蹴り出して伸びるとき前へ出て、脚を集めるとき遅れる。宙に浮く間は少し大きい
	var forward := Vector2.from_angle(heading)
	var surge := sin((_stride - 0.3) * TAU) * 12.0 * stride
	_lion.position = ((pos + forward * surge) / px).round() * px
	_material.set_shader_parameter("lift", 1.0 + 0.035 * maxf(0.0, sin((_stride - 0.42) * TAU / 0.84)) * stride)
	_material.set_shader_parameter("time", _time)
	_material.set_shader_parameter("heading", heading)
	# 変身：本体は輪郭がそろってから段階的に現れ、粒子の演出はそのあと段階的に流れ出す
	var body := strength * _steps(age, GATHER, MATERIALIZE)
	var effects := strength * _steps(age, EFFECTS_FROM, EFFECTS_TO)
	var flash := clampf(1.0 - (age - GATHER) / FLASH, 0.0, 1.0) if age >= GATHER else 0.0
	_material.set_shader_parameter("strength", body)
	_material.set_shader_parameter("flash", flash)
	_aura_material.set_shader_parameter("flash", flash)
	var step := 0
	for i in STRIDE_AT.size():
		if _stride >= STRIDE_AT[i]: step = i
	_material.set_shader_parameter("frame", STRIDE[step])
	# 集めるとき縮み、伸ばすとき伸びる。腰は1歩に1往復しなる
	_material.set_shader_parameter("stretch", 1.0 + 0.06 * sin((_stride - 0.38) * TAU))
	_material.set_shader_parameter("bend", 3.0 * sin(_stride * TAU))
	var viewport := get_viewport()
	var hdr := viewport != null and viewport.use_hdr_2d
	_material.set_shader_parameter("linear_output", hdr)
	_screen_rect.visible = effects > 0.0
	_screen.set_shader_parameter("strength", effects)
	_screen.set_shader_parameter("time", _time)
	_screen.set_shader_parameter("cell_px", px * (viewport.get_canvas_transform().get_scale().x if viewport != null else 1.0))
	_screen.set_shader_parameter("linear_output", hdr)
	# オーラとぶれの元は、本体と同じ形・同じ動きで描く。小さな画面は HDR を使わず sRGB の色のまま描き、
	# ぶれを出すときに表示先が HDR ならリニアへ直す
	_aura.position = _lion.position
	for m: ShaderMaterial in _painted:
		for key in ["lift", "time", "heading", "strength", "frame", "stretch", "bend"]:
			m.set_shader_parameter(key, _material.get_shader_parameter(key))
	# ぶれの元は粒子の演出と一緒に流れ出す
	for i in range(1, _painted.size()): _painted[i].set_shader_parameter("strength", effects)
	_aura_material.set_shader_parameter("linear_output", hdr)
	for i in _trails.size():
		var trail := _trails[i]
		trail.position = _lion.position
		var m: ShaderMaterial = trail.material
		m.set_shader_parameter("linear_output", hdr)
		m.set_shader_parameter("forward", forward)
		m.set_shader_parameter("smear", SMEAR * stride * (AURA_SMEAR if i == 0 else 1.0))
	var right := forward.orthogonal() * -1.0
	_emit += dt * 110.0 * effects * (0.4 + 0.6 * stride)
	while _emit >= 1.0:
		_emit -= 1.0
		var art: Vector2 = SOURCES[randi() % SOURCES.size()] + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
		var local := (art - PIVOT) / ART_PER_CELL * px
		var at := pos + right * local.x - forward * local.y
		var drift := -forward * randf_range(40.0, 110.0) + Vector2.from_angle(randf() * TAU) * randf_range(4.0, 18.0)
		_motes.append({"pos": at, "vel": drift, "life": randf_range(0.5, 1.3), "age": 0.0,
			"kind": 2 if randf() < 0.15 else (1 if randf() < 0.3 else 0)})
	var mm := _dust.multimesh
	var n := 0
	for mote in _motes:
		mote.age += dt
		mote.vel *= exp(-2.5 * dt)
		mote.pos += mote.vel * dt
		var k: float = 1.0 - mote.age / mote.life
		if k <= 0.0: continue
		var cell: Vector2 = (mote.pos / px).round() * px
		var color: Color = GOLD[3] if mote.kind == 1 else GOLD[clampi(int(k * 3.0), 0, 2)]
		color.a = effects
		# 消えぎわは2コマに1回だけ光らせて、またたきながら消える
		if k < 0.3 and int(mote.age * 30.0) % 2 == 0: continue
		n = _put(mm, n, cell, color)
		if mote.kind == 2 and k > 0.4:
			var arm := Color(GOLD[1], effects * 0.8)
			for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				n = _put(mm, n, cell + d * px, arm)
	mm.visible_instance_count = n
	_motes = _motes.filter(func(mote): return mote.age < mote.life)
	_tick_sparks(dt, pos, forward, right, effects, stride)
	_tick_wake(dt, forward, right, effects, stride)
	_tick_forming(dt, pos, forward, right, strength, age)

## from〜to 秒の間に、0 から 1 へ4段階で上がる（age が INF なら 1）。
static func _steps(age: float, from: float, to: float) -> float:
	if age >= to: return 1.0
	if age < from: return 0.0
	return (floor((age - from) / (to - from) * 4.0) + 1.0) / 4.0

## 獅子の輪郭の点：胴・脚・顔と尾のふち（となりが空いているドット）を、3つに1つ拾う。
func _outline_points() -> PackedVector2Array:
	var body := BODY.get_image()
	var aux := AUX.get_image()
	var size := Vector2i(int(aux.get_width()), int(aux.get_height()))
	var filled := func(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= size.x or y >= size.y: return false
		return body.get_pixel(x, y).a > 0.5 or aux.get_pixel(x, y).b > 0.5
	var points := PackedVector2Array()
	var count := 0
	for y in size.y:
		for x in size.x:
			if not filled.call(x, y): continue
			if filled.call(x + 1, y) and filled.call(x - 1, y) and filled.call(x, y + 1) and filled.call(x, y - 1): continue
			count += 1
			if count % 3 == 0: points.append(Vector2(x, y) + Vector2(0.5, 0.5))
	return points

## 変身の星くず：発動した瞬間に機体の形に散り、渦を巻きながら獅子の輪郭の点へなめらかに移る。
## そろった瞬間に空間をゆがませる波を出し、輪郭の星くずは段階的に消える。
func _tick_forming(dt: float, pos: Vector2, forward: Vector2, right: Vector2, strength: float, age: float) -> void:
	if age == INF or age > GATHER + OUTLINE_FADE:
		_forming.clear()
		_formed = false
		return
	if _forming.is_empty() and age < GATHER:
		_formed = false
		for point in _outline:
			var start := Vector2(randf_range(-0.5, 0.5) * SHIP_SIZE.x, randf_range(-0.5, 0.5) * SHIP_SIZE.y)
			_forming.append({"target": point, "start": start, "swirl": randf_range(-1.0, 1.0), "glint": randf()})
	if age >= GATHER and not _formed:
		_formed = true
		if pipeline != null and pipeline.has_method("add_wave"): pipeline.add_wave(pos, 520.0, 0.9)
	var k := smoothstep(0.0, 1.0, clampf(age / GATHER, 0.0, 1.0))
	var fade := 1.0 - _steps(age, GATHER, GATHER + OUTLINE_FADE)
	var mm := _sparks.multimesh
	var n := mm.visible_instance_count
	var center: Vector2 = _lion.position
	for dot in _forming:
		var local: Vector2 = (dot.target - PIVOT) / ART_PER_CELL * px
		var target := center + right * local.x - forward * local.y
		var start: Vector2 = pos + forward * dot.start.x + right * dot.start.y
		# 渦：途中ほど大きく横へふくらむ
		var swirl: Vector2 = (target - start).orthogonal().normalized() * sin(PI * k) * 40.0 * float(dot.swirl)
		var at := start.lerp(target, k) + swirl
		var color: Color = GOLD[3] if dot.glint > 0.7 else (GOLD[2] if k < 1.0 else GOLD[1])
		color.a = strength * fade
		if color.a > 0.0: n = _put(mm, n, (at / px).round() * px, color)
	mm.visible_instance_count = n

## 金の火花：たてがみのように、顔（マスク）の生え際から後ろへ流れる。通り道は獅子に対して決まり、獅子と一緒に動く。
## 真ん中の火花はまっすぐ後ろへ、端の火花ほど外へ大きくふくらんでから後ろですぼまる。生え際より前には出ない。
## 細い線で、先ほど明るい金、後ろへ濃い金に冷めて薄れる。
func _tick_sparks(dt: float, pos: Vector2, forward: Vector2, right: Vector2, strength: float, stride: float) -> void:
	_spark_emit += dt * 70.0 * strength * stride
	while _spark_emit >= 1.0:
		_spark_emit -= 1.0
		_flecks.append({"side": randf_range(-1.0, 1.0), "reach": randf_range(60.0, 95.0),
			"life": randf_range(0.3, 0.55), "age": 0.0})
	var mm := _sparks.multimesh
	var n := 0
	var center: Vector2 = _lion.position
	for fleck in _flecks:
		fleck.age += dt
		var head_t: float = fleck.age / fleck.life
		if head_t >= 1.0: continue
		var tail_t := maxf(0.0, head_t - 0.22)
		var steps := 10
		for i in steps:
			var t := lerpf(head_t, tail_t, float(i) / float(steps - 1))
			var art := _spark_path(fleck.side, fleck.reach, t)
			var local := (art - PIVOT) / ART_PER_CELL * px
			var w := float(i) / float(steps - 1)
			var c: Color = GOLD[2] if w < 0.2 and head_t < 0.6 else (GOLD[1] if w < 0.55 else GOLD[0])
			c.a = strength * (1.0 - w * 0.7) * (1.0 - smoothstep(0.75, 1.0, head_t))
			n = _put(mm, n, ((center + right * local.x - forward * local.y) / px).round() * px, c)
	mm.visible_instance_count = n
	_flecks = _flecks.filter(func(fleck): return fleck.age < fleck.life)

## 火花の通り道（絵の座標）。side は -1〜1 の左右の位置、t は 0〜1 の進み。生え際（マスクの後ろのふち）から後ろへ流れ、
## 端ほど大きく外へふくらみ、後ろへ行くほど真ん中へすぼまる弧を描く。
func _spark_path(side: float, reach: float, t: float) -> Vector2:
	var bow := sin(PI * pow(t, 0.7))
	var x := PIVOT.x + side * (12.0 + 24.0 * absf(side) * bow) * (1.0 - 0.55 * t)
	var y := SPARK_ROOT + reach * t
	# たてがみと同じ波でたなびく（shader の mane_at と同じ式）
	var back := y - MANE_ROOT
	var k := clampf(back / MANE_LENGTH, 0.0, 1.0)
	x += sin(back * 0.05 - _time * 4.5) * 12.0 * k * k + sin(back * 0.12 - _time * 7.5) * 3.0 * k
	return Vector2(x, y)

## 体のまわりの空気の流れ：鼻先で左右に分かれた空気の粒が、放物線を描いて体にそって後ろへ流れる（船首の波）。
## 内側の流れほど体に沿って長く、粒が多く濃い。外側の流れほど大きく開き、短く、まばらで薄い。
## 通り道は獅子に対して決まる。粒は白〜淡い青紫で、明るさがばらつく。
func _tick_wake(dt: float, forward: Vector2, right: Vector2, strength: float, stride: float) -> void:
	_wake_emit += dt * 220.0 * strength * stride
	while _wake_emit >= 1.0:
		_wake_emit -= 1.0
		# 内側ほど多く生まれる
		var lane := randf() * randf()
		var speed := randf_range(330.0, 400.0)
		_wake.append({"side": 1.0 if randf() < 0.5 else -1.0, "lane": lane, "speed": speed,
			"life": _wake_reach(lane) / speed, "age": 0.0, "tint": randi() % 3, "glint": randf(),
			# ふちがくっきりした線に見えないよう、生まれる位置を少し前後と左右へばらつかせる
			"start": randf_range(0.0, 6.0), "off": randf_range(-2.0, 2.0)})
	# 体のふちに重なる内側の流れも見えるよう、獅子の手前（火花と同じ層）に描く
	var mm := _sparks.multimesh
	var n := mm.visible_instance_count
	var center: Vector2 = _lion.position
	for star in _wake:
		star.age += dt
		var k: float = star.age / star.life
		if k >= 1.0: continue
		var color: Color = [Color("#fffbf4"), Color("#c9d4ff"), Color("#f0c8f0")][star.tint]
		color.a = strength * (0.27 + 0.24 * star.glint) * (1.0 - 0.6 * star.lane) * (1.0 - smoothstep(0.6, 1.0, k)) * smoothstep(0.0, 0.06, k)
		var y: float = WAKE_FOCUS.y + star.start + star.age * star.speed
		# 内側の粒ほど尾が長い
		var length := 3 + int(round((1.0 - star.lane) * 5.0))
		for i in length:
			var art := _wake_path(star.side, star.lane, y - float(i) * 2.0) + Vector2(star.off * star.side, 0.0)
			var local := (art - PIVOT) / ART_PER_CELL * px
			n = _put(mm, n, ((center + right * local.x - forward * local.y) / px).round() * px, Color(color, color.a * (1.0 - float(i) / float(length) * 0.8)))
	mm.visible_instance_count = n
	_wake = _wake.filter(func(star): return star.age < star.life)

## 空気の流れの通り道（絵の座標）。side は左右、lane は 0（体の上を覆う）〜1（体の外側）。鼻先を頂点にした放物線で、
## 後ろへ行くほどゆるやかに広がる。外側の流れほど大きな放物線を描く。
func _wake_path(side: float, lane: float, y: float) -> Vector2:
	var width := lerpf(4.0, 130.0, lane)
	return Vector2(PIVOT.x + side * sqrt(maxf(0.0, y - WAKE_FOCUS.y) * width), y)

## その流れが鼻先から後ろへ届く長さ（絵のドット）。内側は尾の先まで、外側は肩のあたりまで。
func _wake_reach(lane: float) -> float:
	return lerpf(230.0, 70.0, lane)

## 獅子の四角を、世界の1ドットの格子で描く。
func _mesh(material: ShaderMaterial) -> MeshInstance2D:
	var mesh := MeshInstance2D.new()
	mesh.mesh = FireBursts._mesh()
	mesh.material = material
	mesh.scale = Vector2.ONE * HALF * px
	add_child(mesh)
	return mesh

## paint の絵を小さな画面へ1ドット＝1テクセルで描き、そこから後ろへ流れるぶれを出す四角をつくる。
func _trail(paint: ShaderMaterial, density: float) -> MeshInstance2D:
	paint.set_shader_parameter("linear_output", false)
	var canvas := SubViewport.new()
	canvas.size = Vector2i.ONE * int(HALF * 2.0)
	canvas.transparent_bg = true
	canvas.disable_3d = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(canvas)
	var painter := MeshInstance2D.new()
	painter.mesh = FireBursts._mesh()
	painter.material = paint
	painter.position = Vector2.ONE * HALF
	painter.scale = Vector2.ONE * HALF
	canvas.add_child(painter)
	var blur := ShaderMaterial.new()
	blur.shader = BLUR
	blur.set_shader_parameter("painted", canvas.get_texture())
	blur.set_shader_parameter("cells", HALF * 2.0)
	blur.set_shader_parameter("density", density)
	return _mesh(blur)

func _put(mm: MultiMesh, n: int, at: Vector2, color: Color) -> int:
	if n >= mm.instance_count: return n
	mm.set_instance_transform_2d(n, Transform2D(0.0, at + Vector2.ONE * px * 0.5))
	mm.set_instance_color(n, color)
	return n + 1
