## 英雄の星座を解放したときの獲得演出。報酬表示（reward_presentation.gd）が止めた時間の中で、フィールドの星座の上に描く。
## 流れ（長さ 2.3 秒を基準に、設定の長さへ伸び縮みする）：
## ① 0〜0.3：カメラが星座全体の入るところまで引く（camera_view）。
## ② 0.3〜1.0：星座の線が強く光り、星図の線画が最初の星から描き出される（hero_acquire_art.gdshader）。
## ③ 1.0〜1.6：線画が英雄の色で光り、英雄の色の粒が立ちのぼる。
## ④ 1.6〜2.3：線画が散って粒になり、機体へ流れ込む。流れ込みきると機体から光の粒が散り、カメラが戻る。
## 線画は星座の星の範囲に MARGIN の余白を足し、星座の座標の1を ART_SCALE 画素にした絵（speed/assets/heroes/acquire/<id>.png）。
## フィールドの星座は回転・拡大して置かれるので、星の位置から同じ回転・拡大を求めて重ねる。
extends Node2D

const BASE := 2.3
const ART_SCALE := 3.0
const MARGIN := 160.0
const ART_DIR := "res://assets/heroes/acquire/%s.png"
const ART_SHADER := preload("res://shaders/hero_acquire_art.gdshader")
const NOISE := preload("res://assets/effects/build/burst_noise.tres")
## 英雄ごとの色：暗い色・中の色・明るい色（各ULTの演出の色）
const PALETTE := {
	&"perseus": [Color("#2a1440"), Color("#8e5cd9"), Color("#e2ccff")],
	&"leo": [Color("#8a5a12"), Color("#f0b840"), Color("#fff1b8")],
	&"gemini": [Color("#5b2f9e"), Color("#f0c860"), Color("#fff4cc")],
	&"hercules": [Color("#8a1f12"), Color("#ff8a2a"), Color("#fff3a6")],
}
## 粒が立ちのぼる数（毎秒）と、機体へ流れ込む粒の数
const RISE_RATE := 260.0
const FLOW_COUNT := 420
## 画面での1ドット（run_frame_view の画素）
var px := 2.0

var _id: StringName = &""
var _art: Sprite2D
var _material: ShaderMaterial
var _stars := PackedVector2Array()
var _links := PackedInt32Array()
var _palette: Array = []
var _time := 0.0
var _unit := 1.0
var _ship := Vector2.ZERO
var _rise: Array[Dictionary] = []
var _flow: Array[Dictionary] = []
var _flow_started := false
## 流れ込みきったときに機体から散る粒
var _burst: Array[Dictionary] = []
var _burst_started := false
var _rise_carry := 0.0

func _ready() -> void:
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_art = Sprite2D.new()
	_art.centered = false
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_material = ShaderMaterial.new()
	_material.shader = ART_SHADER
	_material.set_shader_parameter("value_noise", NOISE.get_meta("texture"))
	_art.material = _material
	_art.hide()
	add_child(_art)
	hide()

## state は reward_presentation.acquire_state()（{id, time, seconds}、演出の外では空）、hero は C++ の英雄の値（星の位置・線）。
func tick(dt: float, state: Dictionary, hero: Dictionary, ship: Vector2, unit: float) -> void:
	if state.is_empty() or hero.get("stars", PackedVector2Array()).is_empty():
		if visible: _stop()
		return
	if StringName(state.id) != _id: _begin(StringName(state.id), hero)
	if _id == &"": return
	_time = float(state.time) / maxf(float(state.seconds), 0.01) * BASE
	_unit = unit
	_ship = ship
	_step_particles(dt)
	_step_burst(dt)
	var reveal := smoothstep(0.3, 1.0, _time)
	var dissolve := smoothstep(1.6, 2.15, _time)
	_material.set_shader_parameter("reveal", reveal)
	_material.set_shader_parameter("dissolve", dissolve)
	_material.set_shader_parameter("glow", 0.9 + 1.4 * smoothstep(1.0, 1.4, _time) * (1.0 - dissolve))
	_material.set_shader_parameter("linear_output", get_viewport().use_hdr_2d)
	_art.visible = _time > 0.3 and dissolve < 1.0
	queue_redraw()

## 獲得演出の間のカメラ：星座全体（と機体）が入るまで引き、終わりに元へ戻す。演出の外では空。
func camera_view(center: Vector2, zoom: float, screen: Vector2) -> Dictionary:
	if not visible or _stars.is_empty(): return {}
	var bounds := Rect2(_stars[0], Vector2.ZERO)
	for star in _stars: bounds = bounds.expand(star)
	bounds = bounds.expand(_ship).grow(160.0)
	var fit := minf(screen.x / bounds.size.x, screen.y / bounds.size.y)
	var target := minf(zoom, fit)
	var k := smoothstep(0.0, 0.3, _time) * (1.0 - smoothstep(1.9, BASE, _time))
	return {"center": center.lerp(bounds.get_center(), k), "zoom": lerpf(zoom, target, k)}

func _begin(id: StringName, hero: Dictionary) -> void:
	_stop()
	var definition: HeroDef = ContentManager.heroes.get(id)
	var art: Texture2D = load(ART_DIR % id) if ResourceLoader.exists(ART_DIR % id) else null
	if definition == null or definition.stars.size() < 2 or art == null: return
	_id = id
	_stars = hero.stars
	_links = hero.links
	_palette = PALETTE.get(id, PALETTE[&"leo"])
	# 定義の星の並びから、フィールドに置いた回転・拡大を求める
	var local: PackedVector2Array = definition.stars
	var a: Vector2 = local[1] - local[0]
	var b: Vector2 = _stars[1] - _stars[0]
	var turn := b.angle() - a.angle()
	var grow := b.length() / maxf(a.length(), 0.001)
	var low := local[0]
	for star in local: low = low.min(star)
	var corner := low - Vector2.ONE * MARGIN
	_art.texture = art
	_art.position = _stars[0] + (corner - local[0]).rotated(turn) * grow
	_art.rotation = turn
	_art.scale = Vector2.ONE * grow / ART_SCALE
	var size := art.get_size()
	var origin := (local[0] - corner) * ART_SCALE / size
	# 最初の星から一番遠い星までの距離（画像の高さを1とした長さ）。その少し外まで描き出す
	var reach := 0.0
	for star in local: reach = maxf(reach, (star - local[0]).length() * ART_SCALE / size.y)
	_material.set_shader_parameter("origin", origin)
	_material.set_shader_parameter("aspect", size.x / size.y)
	_material.set_shader_parameter("reach", reach + MARGIN * ART_SCALE / size.y)
	_material.set_shader_parameter("tint", _palette[1])
	_material.set_shader_parameter("hot", _palette[2])
	show()

func _stop() -> void:
	_id = &""
	_rise.clear()
	_flow.clear()
	_flow_started = false
	_burst.clear()
	_burst_started = false
	_rise_carry = 0.0
	_art.hide()
	hide()

## 星座線の上のランダムな点
func _on_links() -> Vector2:
	var i := randi_range(0, _links.size() / 2 - 1) * 2
	return _stars[_links[i]].lerp(_stars[_links[i + 1]], randf())

func _step_particles(dt: float) -> void:
	# ③ 線画が光る間、星座線から英雄の色の粒が立ちのぼる
	if _time > 1.0 and _time < 1.7:
		_rise_carry += RISE_RATE * dt
		while _rise_carry >= 1.0:
			_rise_carry -= 1.0
			_rise.append({"pos": _on_links() + Vector2(randf_range(-14, 14), randf_range(-14, 14)), "vel": Vector2(randf_range(-12, 12), -randf_range(30, 90)), "age": 0.0, "life": randf_range(0.5, 0.9), "color": _palette[1 + randi() % 2], "size": 2.0 if randf() < 0.6 else 3.0})
	for p in _rise:
		p.age += dt
		p.pos += p.vel * dt
	_rise = _rise.filter(func(p): return p.age < p.life)
	# ④ 線画が散る所から粒が出て、曲がりながら機体へ流れ込む
	if _time >= 1.6 and not _flow_started:
		_flow_started = true
		for i in FLOW_COUNT:
			var from := _on_links() + Vector2(randf_range(-40, 40), randf_range(-40, 40))
			var side := (_ship - from).orthogonal().normalized() * randf_range(-0.45, 0.45) * from.distance_to(_ship)
			_flow.append({"from": from, "bend": from.lerp(_ship, 0.4) + side, "start": randf_range(1.6, 2.0), "end": randf_range(2.08, 2.25), "color": _palette[1 + randi() % 2]})

func _step_burst(dt: float) -> void:
	if _time >= 2.1 and not _burst_started:
		_burst_started = true
		for i in 48:
			var dir := Vector2.from_angle(randf() * TAU)
			_burst.append({"pos": _ship + dir * randf_range(0.0, 10.0), "vel": dir * randf_range(60.0, 220.0), "age": 0.0, "life": randf_range(0.25, 0.5), "color": _palette[1 + randi() % 2]})
	for p in _burst:
		p.age += dt
		p.pos += p.vel * dt
		p.vel *= 1.0 - 4.0 * dt
	_burst = _burst.filter(func(p): return p.age < p.life)

func _draw() -> void:
	if _id == &"": return
	var cell := px * _unit
	# ② 星座の線が強く光る
	var lit := smoothstep(0.3, 0.7, _time) * (1.0 - smoothstep(1.7, 2.1, _time))
	if lit > 0.0:
		for i in range(0, _links.size(), 2):
			var a := _stars[_links[i]]
			var b := _stars[_links[i + 1]]
			draw_line(a, b, Color(_palette[0], 0.5 * lit), cell * 12.0)
			draw_line(a, b, Color(_palette[1], 0.6 * lit), cell * 5.0)
			draw_line(a, b, Color(_palette[2], lit), cell * 2.0)
		for star in _stars:
			draw_rect(Rect2(star - Vector2.ONE * cell * 2.0, Vector2.ONE * cell * 4.0), Color(_palette[2], lit))
	for p in _rise:
		var k: float = p.age / p.life
		draw_rect(Rect2(p.pos.snapped(Vector2.ONE * cell), Vector2.ONE * cell * float(p.size)), Color(p.color, 1.0 - k))
	for p in _flow:
		var k := clampf((_time - float(p.start)) / maxf(float(p.end) - float(p.start), 0.01), 0.0, 1.0)
		if k <= 0.0 or k >= 1.0: continue
		var e := k * k
		var at: Vector2 = (p.from as Vector2).lerp(p.bend, e).lerp((p.bend as Vector2).lerp(_ship, e), e)
		draw_rect(Rect2(at.snapped(Vector2.ONE * cell), Vector2.ONE * cell * (2.0 + 2.0 * (1.0 - k))), Color(p.color, 0.6 + 0.4 * k))
	# ④ 流れ込みきると、機体から光の粒が散る
	for p in _burst:
		var k: float = p.age / p.life
		draw_rect(Rect2(p.pos.snapped(Vector2.ONE * cell), Vector2.ONE * cell * (3.0 - 2.0 * k)), Color(p.color, 1.0 - k * k))
