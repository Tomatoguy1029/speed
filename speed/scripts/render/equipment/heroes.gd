## 英雄の力の表示。C++から受けた値と出来事だけを描く。
## ペルセウス座は、機体の手前に開くメドゥーサの目（hero_medusa）、開ききった瞬間の画面のブラーと闇のオーラ（hero_medusa_screen）、
## 石の敵が砕ける破片（StoneShards）を出す。石になった敵の色は、敵のベースと装甲の shader が描く（hero_stone.gdshaderinc）。
## しし座は、効いている間、機体の代わりに星の獅子（leo_lion.gd）を機体の位置と向きで描く（機体は run_frame_view が隠す）。
## ふたご座は光と影の兄弟（gemini_twins.gd）。描いている線を左右反転した影の経路を、線の下へ薄く予告する。
## ヘルクレス座は火の隕石群（hercules_meteors.gd）。
extends Node2D

const MEDUSA := preload("res://shaders/hero_medusa.gdshader")
const MEDUSA_SCREEN := preload("res://shaders/hero_medusa_screen.gdshader")
const NOISE := preload("res://assets/effects/build/burst_noise.tres")
const SHARDS := preload("res://scripts/render/fx/stone_shards.gd")
const PERSEUS: HeroDef = preload("res://data/heroes/perseus.tres")
const LEO: HeroDef = preload("res://data/heroes/leo.tres")
const GEMINI: HeroDef = preload("res://data/heroes/gemini.tres")
const HERCULES: HeroDef = preload("res://data/heroes/hercules.tres")
const GEMINI_SCREEN := preload("res://shaders/hero_gemini_screen.gdshader")
const HERCULES_SCREEN := preload("res://shaders/hero_hercules_screen.gdshader")
## 画面の演出は、発動からこの秒で現れ、終わりのこの秒で消える
const SCREEN_IN := 0.6
const SCREEN_OUT := 0.5
## ヘルクレス座の画面は発動からこの秒でほぼすぐ現れる（発動の熾火は hero_hercules_screen.gdshader が since から進める）
const FIRE_IN := 0.05
const LION := preload("res://scripts/render/equipment/leo_lion.gd")
const TWINS := preload("res://scripts/render/equipment/gemini_twins.gd")
const METEORS := preload("res://scripts/render/equipment/hercules_meteors.gd")
## ふたご座の線の粉の色。影は深紫から明るい紫、光は橙金から白
const TWIN_SHADOW_POWDER := [Color(0.07, 0.02, 0.13), Color(0.2, 0.07, 0.34), Color(0.36, 0.15, 0.6), Color(0.55, 0.3, 0.88), Color(0.13, 0.04, 0.22)]
const TWIN_LIGHT_POWDER := [Color(0.98, 0.6, 0.16), Color(1.0, 0.8, 0.32), Color(1.0, 0.9, 0.55), Color(1.0, 0.72, 0.25)]
const POWDER_SHADER := preload("res://shaders/hero_twin_powder.gdshader")
## 描いている間の予告の粉の濃さ（見える粒の割合）
const TWIN_PREVIEW_FADE := 0.45
## 粉の下にぼんやり光るかすみ：線の中心が TWIN_HAZE_ALPHA の濃さで、幅の TWIN_HAZE_WIDTH 倍の端まで透明へなめらかに薄れる
const TWIN_HAZE_WIDTH := 1.5
const TWIN_HAZE_ALPHA := 0.34
const TWIN_LIGHT_HAZE := Color(1.0, 0.72, 0.28)
const TWIN_SHADOW_HAZE := Color(0.5, 0.24, 0.85)
## 線が消えたあとの跡が薄れる秒（機体の線と影の線で同じ）
const TWIN_TRAIL_FADE := 0.6
## 獅子が現れる・消える秒
const LION_FADE := 0.3
## 獅子の駆け足の速さの割合が 1 になる機体の速さ
const LION_STRIDE_SPEED := 350.0
## 目の横幅の半分のドット数。まぶたの縁や虹彩の筋をドット単位で描くので、ドット数で形を決める
const EYE_CELLS := 42.0
var petrified := PackedFloat32Array()
var unit := 1.0
var fire := {}
var world_time := 0.0
var px := 1.82
var _eye: MeshInstance2D
var _eye_material: ShaderMaterial
var _screen: ColorRect
var _screen_material: ShaderMaterial
var _shards: StoneShards
var _last_stone := PackedFloat32Array()
var _lion: Node2D
var _twins: Node2D
var _meteors: Node2D
## ふたご座・ヘルクレス座の、効いている間の画面全体の演出（世界より上・HUD より下）
var _twin_screen: ColorRect
var _fire_screen: ColorRect
## ふたご座の線：drawing なら描いている線（light）と機体の位置・向き、突進中なら本体と影の経路（light・shadow）
var twin_preview := {}
var _twin_trails: Array[Dictionary] = []
## いま出している光と影の線（light・shadow）。粉の MultiMesh とシェーダーの値を持つ
var _twin_live := {}
var _powder_root: Node2D
## 画面全体の歪み（RenderPipeline）。しし座の変身の波に使う
var pipeline: Object

## sky は敵より上の親、ground は敵より下の親。cell は1ドットの世界での幅。
func setup(cell: float, sky: Node2D, ground: Node2D) -> void:
	px = cell
	_eye = MeshInstance2D.new()
	_eye.mesh = FireBursts._mesh()
	_eye.scale = Vector2.ONE * EYE_CELLS * 1.5 * px
	_eye.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_eye_material = ShaderMaterial.new()
	_eye_material.shader = MEDUSA
	_eye_material.set_shader_parameter("value_noise", NOISE.get_meta("texture"))
	_eye_material.set_shader_parameter("half_cells", EYE_CELLS * 1.5)
	_eye_material.set_shader_parameter("eye_size", EYE_CELLS)
	_eye_material.set_shader_parameter("life", PERSEUS.duration)
	_eye_material.set_shader_parameter("open_to", float(PERSEUS.params.open_delay))
	_eye.material = _eye_material
	_eye.hide()
	_shards = SHARDS.new()
	_shards.setup(px)
	sky.add_child(_shards)
	var layer := CanvasLayer.new()
	layer.layer = sky.get_parent().layer + 1 if sky.get_parent() is CanvasLayer else 64
	add_child(layer)
	# 前の層で取り込まれた画面には目が写っていないので、目まで描いたあとの画面をここで取り込み直す
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(copy)
	_screen = ColorRect.new()
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_material = ShaderMaterial.new()
	_screen_material.shader = MEDUSA_SCREEN
	_screen_material.set_shader_parameter("value_noise", NOISE.get_meta("texture"))
	_screen.material = _screen_material
	_screen.hide()
	layer.add_child(_screen)
	# 目は画面のオーラと機体より上の層に置き、ブラーにも機体にも隠れないようにする
	var eye_layer := CanvasLayer.new()
	eye_layer.layer = layer.layer + 1
	eye_layer.follow_viewport_enabled = true
	add_child(eye_layer)
	eye_layer.add_child(_eye)
	# 獅子は敵より上に描き、画面全体の演出は世界より上・HUD より下へ重ねる
	_lion = LION.new()
	sky.add_child(_lion)
	_lion.setup(px, layer.layer)
	_lion.visible = false
	_twins = TWINS.new()
	sky.add_child(_twins)
	_twins.setup()
	_meteors = METEORS.new()
	sky.add_child(_meteors)
	_meteors.setup(px, ground)
	var hero_screen := CanvasLayer.new()
	hero_screen.layer = layer.layer
	add_child(hero_screen)
	var hero_copy := BackBufferCopy.new()
	hero_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	hero_screen.add_child(hero_copy)
	_twin_screen = _screen_rect(GEMINI_SCREEN, hero_screen)
	_fire_screen = _screen_rect(HERCULES_SCREEN, hero_screen)

func _screen_rect(shader: Shader, parent: CanvasLayer) -> ColorRect:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("value_noise", NOISE.get_meta("texture"))
	rect.material = material
	rect.hide()
	parent.add_child(rect)
	return rect

## 石だった敵の kill なら破片を出して true を返す（通常の撃破の火花は出さない）。
func frame_event(event: Dictionary) -> bool:
	if event.type == &"hero_power" and StringName(event.get("id", &"")) == &"perseus":
		_eye_material.set_shader_parameter("seed", randf() * 9.0)
	elif event.type == &"meteor_impact":
		_meteors.impact(event.pos, float(event.get("radius", 110.0)))
	elif event.type == &"kill":
		for i in range(0, _last_stone.size(), 3):
			if Vector2(_last_stone[i], _last_stone[i + 1]).distance_to(event.pos) <= _last_stone[i + 2] + 4.0:
				_shards.burst(event.pos, _last_stone[i + 2])
				return true
	return false

## しし座が効いていて、機体の代わりに獅子を描くか。
static func lion_active(hero: Dictionary) -> bool:
	return StringName(hero.get("power", &"")) == &"leo" and float(hero.get("active", 0.0)) > 0.0

## dt は演出の秒、ship は機体の表示位置、hero は C++ の英雄の値。目の進みは効いている時間の残りから求める。
## heading と velocity は機体の向きと速さ（獅子の向きと駆け足に使う）。ship_xf は機体の絵の変形（ふたご座の影に使う）。
## escort の drones は外に付ける武器のドローン（エスコートウィングと迎撃ドローン）。影に付くものを、影の粒が集まって形づくる演出に使う。
func frame_tick(dt: float, ship: Vector2, hero: Dictionary, heading := Vector2.RIGHT, velocity := Vector2.ZERO, ship_xf := Transform2D.IDENTITY, escort := {}) -> void:
	_last_stone = petrified
	var hdr := get_viewport().use_hdr_2d
	for mat: ShaderMaterial in [_eye_material, _screen_material, _shards.material]:
		mat.set_shader_parameter("linear_output", hdr)
	_shards.step(dt)
	_tick_lion(dt, ship, hero, heading, velocity)
	_twins.tick(dt, ship_xf, hero, Array(escort.get("drones", [])).filter(func(d): return d.get("twin", false)))
	_tick_twin_trails(dt)
	_tick_screens(hero, ship)
	_meteors.tick(dt, hero.get("hercules", {}))
	var active := float(hero.get("active", 0.0))
	if StringName(hero.get("power", &"")) != &"perseus" or active <= 0.0:
		_eye.hide()
		_screen.hide()
		return
	var age := PERSEUS.duration - active
	_eye.show()
	_eye.position = (ship / px).round() * px
	_eye_material.set_shader_parameter("age", age)
	var since := age - float(PERSEUS.params.open_delay)
	_screen.visible = since >= 0.0 and since < 1.6
	if _screen.visible:
		var size := get_viewport().get_visible_rect().size
		var canvas := get_viewport().get_canvas_transform()
		_screen_material.set_shader_parameter("since", since)
		_screen_material.set_shader_parameter("rect_size", size)
		_screen_material.set_shader_parameter("cell_px", px * canvas.get_scale().x)
		_screen_material.set_shader_parameter("center", (canvas * ship) / size)

## 獅子は効き始めに変身して現れ（leo_lion.gd）、終わりに LION_FADE 秒でふっと消える。駆け足は機体の速さに合わせる。
func _tick_lion(dt: float, ship: Vector2, hero: Dictionary, heading: Vector2, velocity: Vector2) -> void:
	if not lion_active(hero):
		_lion.visible = false
		return
	var active := float(hero.get("active", 0.0))
	var strength := clampf(active / LION_FADE, 0.0, 1.0)
	var stride := clampf(velocity.length() / LION_STRIDE_SPEED, 0.3, 1.2)
	var direction := heading if heading.length_squared() > 0.0 else Vector2.RIGHT
	_lion.pipeline = pipeline
	_lion.tick(dt, ship, direction.angle(), strength, stride, LEO.duration - active)

## ふたご座の光の機体の濃さ（0〜1）。0.5 を超えると本物の機体を隠す。
func twin_light() -> float:
	return _twins.light

## ふたご座の光と影の線は、帯ではなく機体からこぼれた粉で描く。影は暗い紫の粉、光は金の光の粒がまたたく。
## 描いている間は、描いた線（光）とそれを機体の位置・向きで反転した影の経路を、薄い粉で予告する。
## 突進中は、それぞれの機体が通ったところまでに粉を出す。線が消えたあとも粉は少しずつ外へ漂い、一粒ずつ消えていく（影の粉は長く残る）。
## 粉の粒は線ができたときに1回だけ並べ（MultiMesh）、漂い・消え方・出る範囲・またたきは hero_twin_powder.gdshader が決める。
## ここ（線の描画）では、粉の後ろの背景をぼんやり光らせるかすみだけを描く。
func draw_fire(canvas: CanvasItem) -> void:
	if _powder_root == null:
		_powder_root = Node2D.new()
		canvas.add_child.call_deferred(_powder_root)
	var width: float = twin_preview.get("width", 16.0)
	for line in _twin_trails:
		_draw_haze(canvas, line.shown, width * TWIN_HAZE_WIDTH, Color(TWIN_LIGHT_HAZE if line.light else TWIN_SHADOW_HAZE, TWIN_HAZE_ALPHA * (1.0 - line.age / line.life)))
	for line: Dictionary in _twin_live.values():
		_draw_haze(canvas, line.shown, width * TWIN_HAZE_WIDTH, Color(TWIN_LIGHT_HAZE if line.light else TWIN_SHADOW_HAZE, TWIN_HAZE_ALPHA * line.fade))

## いま出す光と影の線。light・shadow は粉を並べる線全体、light_cut・shadow_cut は機体が通ったところまで（描いている間は全体）。出さないときは空
func _twin_lines() -> Dictionary:
	if twin_preview.is_empty(): return {}
	var light: PackedVector2Array = twin_preview.get("light", PackedVector2Array())
	var shadow: PackedVector2Array = twin_preview.get("shadow", PackedVector2Array())
	var preview: bool = twin_preview.get("drawing", false)
	if preview and light.size() >= 1:
		var origin: Vector2 = twin_preview.ship
		var axis: Vector2 = twin_preview.heading.normalized()
		light = PackedVector2Array([origin]) + light
		shadow = PackedVector2Array()
		for p in light:
			var d := p - origin
			shadow.append(origin + axis * d.dot(axis) * 2.0 - d)
	if light.size() < 2 or shadow.size() < 2: return {}
	var light_cut := light if preview else _cut(light, twin_preview.get("ship", Vector2.INF))
	var shadow_cut := shadow if preview else _cut(shadow, twin_preview.get("twin", Vector2.INF))
	if light_cut.size() < 2 or shadow_cut.size() < 2: return {}
	return {"light": light, "shadow": shadow, "light_cut": light_cut, "shadow_cut": shadow_cut, "preview": preview}

## 線を、at にいちばん近い点までで切る
static func _cut(points: PackedVector2Array, at: Vector2) -> PackedVector2Array:
	if points.size() < 2 or not at.is_finite(): return points
	var best := INF
	var best_i := 1
	var best_p := points[0]
	for i in range(1, points.size()):
		var p := Geometry2D.get_closest_point_to_segment(at, points[i - 1], points[i])
		var d := p.distance_squared_to(at)
		if d < best:
			best = d
			best_i = i
			best_p = p
	var out := points.slice(0, best_i)
	out.append(best_p)
	return out

## 線が変わったら粉を並べ直し、毎フレームはシェーダーの値（漂い・消え方・出る範囲・時刻）だけを進める。
## 線が消えたら、最後の形を粉の跡として残す
func _tick_twin_trails(dt: float) -> void:
	for line in _twin_trails:
		line.age += dt
		line.material.set_shader_parameter("age", line.age)
		line.material.set_shader_parameter("fade", 1.0 - line.age / line.life)
		line.material.set_shader_parameter("time", world_time)
	for line in _twin_trails.filter(func(l): return l.age >= l.life): line.node.queue_free()
	_twin_trails = _twin_trails.filter(func(l): return l.age < l.life)
	if _powder_root == null: return
	var lines := _twin_lines()
	if lines.is_empty():
		for line: Dictionary in _twin_live.values():
			if line.preview: line.node.queue_free()
			else:
				line.age = 0.0
				line.life = TWIN_TRAIL_FADE
				_twin_trails.append(line)
		_twin_live = {}
		return
	var width: float = twin_preview.get("width", 16.0)
	var preview: bool = lines.preview
	for kind in ["light", "shadow"]:
		var full: PackedVector2Array = lines[kind]
		var line: Dictionary = _twin_live.get(kind, {})
		if line.is_empty() or line.preview != preview or line.full != full:
			if not line.is_empty(): line.node.queue_free()
			line = _build_powder(full, width, kind == "light", preview)
			_twin_live[kind] = line
		var cut: PackedVector2Array = lines[kind + "_cut"]
		line.shown = cut
		line.fade = TWIN_PREVIEW_FADE if preview else 1.0
		line.material.set_shader_parameter("fade", line.fade)
		line.material.set_shader_parameter("reveal", 1e9 if preview else _lengths(cut)[cut.size() - 1] + 0.01)
		line.material.set_shader_parameter("time", world_time)

## 線にそって、中心が color の濃さで左右の端（中心から half）と両端の先で透明になる、境目のないかすみの帯を描く
static func _draw_haze(canvas: CanvasItem, points: PackedVector2Array, half: float, color: Color) -> void:
	var count := points.size()
	if count < 2: return
	var lengths := _lengths(points)
	var total: float = lengths[count - 1]
	var normals := PackedVector2Array()
	for i in count:
		var before := (points[i] - points[maxi(i - 1, 0)]).normalized()
		var after := (points[mini(i + 1, count - 1)] - points[i]).normalized()
		var n := (before + after).normalized() if (before + after).length_squared() > 0.0001 else after
		normals.append(n.orthogonal() if n.length_squared() > 0.0 else Vector2.UP)
	var clear := Color(color, 0.0)
	for i in range(1, count):
		# 両端は半幅ぶんの長さで薄れる
		var c0 := Color(color, color.a * clampf(minf(lengths[i - 1], total - lengths[i - 1]) / maxf(half, 0.001), 0.0, 1.0))
		var c1 := Color(color, color.a * clampf(minf(lengths[i], total - lengths[i]) / maxf(half, 0.001), 0.0, 1.0))
		var p0 := points[i - 1]
		var p1 := points[i]
		for side in [1.0, -1.0]:
			var e0: Vector2 = p0 + normals[i - 1] * half * side
			var e1: Vector2 = p1 + normals[i] * half * side
			# 急な曲がりで四角がねじれても描けるよう、三角2枚で描く
			canvas.draw_primitive(PackedVector2Array([p0, p1, e1]), PackedColorArray([c0, c1, clear]), PackedVector2Array())
			canvas.draw_primitive(PackedVector2Array([p0, e1, e0]), PackedColorArray([c0, clear, clear]), PackedVector2Array())

static func _lengths(points: PackedVector2Array) -> PackedFloat32Array:
	var out := PackedFloat32Array([0.0])
	for i in range(1, points.size()): out.append(out[i - 1] + points[i].distance_to(points[i - 1]))
	return out

static func _hash(x: float) -> float:
	var v := sin(x * 12.9898) * 43758.5453
	return v - floorf(v)

## 線に沿って粉の粒を並べた MultiMesh を作る。粒の位置・色・大きさ・消える順番は線上の位置ごとに決まった乱数で選ぶ。
## 予告（preview）では、予告の濃さで見える粒だけを並べる
func _build_powder(points: PackedVector2Array, width: float, light: bool, preview: bool) -> Dictionary:
	var colors: Array = TWIN_LIGHT_POWDER if light else TWIN_SHADOW_POWDER
	var step := px * (1.0 if light else 0.8)
	var keep := TWIN_PREVIEW_FADE if preview else 1.0
	var centers := PackedVector2Array()
	var sizes := PackedByteArray()
	var customs := PackedColorArray()
	var tints := PackedColorArray()
	var along := 0.0
	var walked := 0.0
	var i := 0
	for s in range(1, points.size()):
		var a := points[s - 1]
		var b := points[s]
		var length := a.distance_to(b)
		if length < 0.001: continue
		var u := (b - a) / length
		var normal := u.orthogonal()
		while along <= length:
			var base := a + u * along
			for j in 6:
				var h := float(i * 6 + j)
				var h1 := _hash(h)
				var h2 := _hash(h + 0.37)
				var h3 := _hash(h + 0.71)
				if h3 > keep: continue
				# 中心ほど密に、外ほどまばらに
				var side := h1 * 2.0 - 1.0
				side = signf(side) * pow(absf(side), 1.3) * width * 0.6
				var size := 2 if h1 * h3 > 0.55 else 1
				# 消える前の粉は外へ漂い、少し後ろへ流れる（1秒あたり）
				var drift := normal * signf(side) * px * (4.0 + 10.0 * h2) - u * px * 3.0 * h1
				centers.append(((base + normal * side) / px).floor() * px + Vector2.ONE * px * size * 0.5)
				sizes.append(size)
				customs.append(Color(drift.x, drift.y, -h3 if size == 2 else h3, walked + along))
				tints.append(colors[int(h2 * colors.size()) % colors.size()])
			i += 1
			along += step
		along -= length
		walked += length
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = centers.size()
	for n in centers.size():
		mm.set_instance_transform_2d(n, Transform2D(0.0, Vector2.ONE * px * sizes[n], 0.0, centers[n]))
		mm.set_instance_color(n, tints[n])
		mm.set_instance_custom_data(n, customs[n])
	var material := ShaderMaterial.new()
	material.shader = POWDER_SHADER
	material.set_shader_parameter("px", px)
	material.set_shader_parameter("light", light)
	var node := MultiMeshInstance2D.new()
	node.multimesh = mm
	node.material = material
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 影の粉を奥、光の粒を手前に重ねる
	node.z_index = 1 if light else 0
	_powder_root.add_child(node)
	return {"node": node, "material": material, "full": points, "shown": points, "light": light, "preview": preview, "fade": keep, "age": 0.0, "life": 1.0}

## ふたご座・ヘルクレス座が効いている間だけ、画面全体の演出をかける。どちらも画面に固定し、機体の動きでは変えない（ヘルクレス座の発動の熾火だけ、機体の位置 ship から広がる）
func _tick_screens(hero: Dictionary, ship: Vector2) -> void:
	var power := StringName(hero.get("power", &""))
	var active := float(hero.get("active", 0.0))
	var hdr := get_viewport().use_hdr_2d
	var cell_px := px * get_viewport().get_canvas_transform().get_scale().x
	var gemini := 0.0
	var fire := 0.0
	if active > 0.0 and power == &"gemini":
		gemini = clampf((GEMINI.duration - active) / SCREEN_IN, 0.0, 1.0) * clampf(active / SCREEN_OUT, 0.0, 1.0)
	if active > 0.0 and power == &"hercules":
		var since := HERCULES.duration - active
		fire = clampf(since / FIRE_IN, 0.0, 1.0) * clampf(active / SCREEN_OUT, 0.0, 1.0)
		_fire_screen.material.set_shader_parameter("since", since)
		_fire_screen.material.set_shader_parameter("origin", (get_global_transform_with_canvas() * ship) / get_viewport().get_visible_rect().size)
	for item in [[_twin_screen, gemini], [_fire_screen, fire]]:
		var rect: ColorRect = item[0]
		var amount: float = item[1]
		rect.visible = amount > 0.0
		if not rect.visible: continue
		var material: ShaderMaterial = rect.material
		material.set_shader_parameter("strength", amount)
		material.set_shader_parameter("time", world_time)
		material.set_shader_parameter("cell_px", cell_px)
		material.set_shader_parameter("linear_output", hdr)
