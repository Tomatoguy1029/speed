## 仮の図形の半人半馬。攻撃の向き・時間は役者から読み、演出だけを差し替える。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
@export var pixel_size := 3.0
@export var sail_star_scale := 1.0
@export var sail_star_color := Color("#fff6c8")
@export var open_color := Color("#9fe8ff")
var actor: CentaurusBoss
var hit := 0.0
var pulse := 0.0
var gait := 0.0
const OUTLINE := Color("#1a1928")
const COAT := Color("#8f6f58")
const SHADE := Color("#5c4a48")
const SKIN := Color("#e4c39c")
const BOW := Color("#d8b46a")
const STRING := Color("#f4ecd8")
const WARNING := Color("#f2b567")
const DANGER := Color("#ff667d")
const SAIL := Color("#e6ecf7")
const SAIL_SHADE := Color("#a9b6d0")
## 背後攻撃の予告で本体に掛ける色
const REAR_GLOW := Color(1.9, 0.35, 0.35)
const LIGHT_ARROW := preload("res://scripts/render/attacks/light_arrow.gd")
## 矢の雨の矢の向き（画面の下向きから少し傾ける）
const RAIN_ANGLE := PI * 0.5 - 0.35
func _ready() -> void:
	EFFECT_SETTINGS.apply_key(self, "boss/body/centaurus")
func bind_centaurus(owner_actor: CentaurusBoss) -> void:
	actor = owner_actor
	actor.presentation_event.connect(_event)
	actor.presentation_advanced.connect(_advance)
	z_index = 1

func _event(event: Dictionary) -> void:
	if event.cue == &"hit": hit = 0.18
	if event.cue in [&"alert", &"released", &"rain_started", &"phase_changed"]: pulse = 0.3
	queue_redraw()

func _advance(dt: float) -> void:
	hit = maxf(0.0, hit - dt)
	pulse = maxf(0.0, pulse - dt)
	gait += dt * (16.0 if actor.mode == &"retreat" else 7.0)
	queue_redraw()

func _poly(points: Array, color: Color) -> void:
	var packed := PackedVector2Array()
	for p: Vector2 in points: packed.append(p.snapped(Vector2.ONE * pixel_size))
	draw_colored_polygon(packed, color)
	packed.append(packed[0])
	draw_polyline(packed, OUTLINE, pixel_size, false)

func _oval(center: Vector2, radius: Vector2, color: Color, segments := 14) -> void:
	var points := []
	for j in segments:
		var a := TAU * j / segments
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	_poly(points, color)

## 帆を広げた割合（0〜1）。第2形態への移行の間に広げ、そのあとは広げたまま。
func sail_fraction() -> float:
	if actor.phase < 2: return 0.0
	if actor.mode != &"phase": return 1.0
	var f := 1.0 - actor.phase_time / maxf(float(actor.def.params.phase_time), 0.001)
	return 1.0 - pow(1.0 - clampf(f, 0.0, 1.0), 3.0)

## 馬の背に、ほ座の帆を左右へ広げる。風を受けて後ろへふくらみ、四隅の星が瞬く。
func _draw_sail(open: float) -> void:
	if open <= 0.0: return
	var half := 84.0 * open
	var belly := 34.0 * open
	var yard := -14.0
	var cloth := []
	for j in 9:
		var f := lerpf(-1.0, 1.0, j / 8.0)
		cloth.append(Vector2(yard, f * half))
	for j in 9:
		var f := lerpf(1.0, -1.0, j / 8.0)
		cloth.append(Vector2(yard - 14.0 - belly * (1.0 - f * f), f * half * 0.9))
	_poly(cloth, SAIL)
	# 縫い目：帆桁から後ろの縁へ。
	for f in [-0.5, 0.0, 0.5]:
		var back := Vector2(yard - 14.0 - belly * (1.0 - f * f), f * half * 0.9)
		draw_line(Vector2(yard, f * half).snapped(Vector2.ONE * pixel_size), back.snapped(Vector2.ONE * pixel_size), SAIL_SHADE, pixel_size)
	draw_line(Vector2(yard, -half - 6.0), Vector2(yard, half + 6.0), OUTLINE, pixel_size * 3.0)
	draw_line(Vector2(yard, -half - 6.0), Vector2(yard, half + 6.0), BOW, pixel_size * 1.5)
	var twinkle := 0.6 + 0.4 * sin(actor.clock * 6.0)
	for corner in [Vector2(yard, -half), Vector2(yard, half), Vector2(yard - 14.0, -half * 0.9), Vector2(yard - 14.0, half * 0.9)]:
		draw_circle(corner, 7.0 * open * sail_star_scale, Color(sail_star_color, 0.35 * twinkle))
		draw_circle(corner, 3.5 * open * sail_star_scale, sail_star_color)

## 弓を引く割合（0〜1）。
func draw_fraction() -> float:
	return float(actor.technique_pose.get("pull", 0.0))

func _draw() -> void:
	if actor == null or not actor.has_body(): return
	var r := actor.table.r[actor.body]
	var k := r / 90.0
	var moving := actor.table.vel[actor.body].length() > 5.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * k)
	var tint := Color(1.6, 1.6, 1.6) if hit > 0.0 else Color.WHITE
	if actor.technique_pose.get("tint", Color.WHITE) != Color.WHITE: tint = actor.technique_pose.tint
	modulate = tint
	# 脚：走っている間は前後に振る。
	for j in 4:
		var side := -1.0 if j % 2 == 0 else 1.0
		var x := -58.0 if j < 2 else 18.0
		var swing := sin(gait + j * 1.7) * (12.0 if moving else 2.0)
		_poly([Vector2(x + swing - 8, side * 26), Vector2(x + swing + 8, side * 26), Vector2(x + swing + 6, side * 46), Vector2(x + swing - 6, side * 46)], SHADE)
	# 尾と馬の胴
	_poly([Vector2(-82, -6), Vector2(-112, -14 + sin(gait) * 6.0), Vector2(-116, 4 + sin(gait) * 6.0), Vector2(-82, 8)], SHADE)
	_oval(Vector2(-22, 0), Vector2(64, 32), COAT)
	_draw_sail(sail_fraction())
	# 人の上半身と頭
	_oval(Vector2(36, 0), Vector2(22, 26), SKIN)
	_oval(Vector2(46, 0), Vector2(13, 13), Color("#c99c74"))
	# 弓：機体の方へ向けた弧。引くほど弦が後ろへ下がる。
	var bow := []
	for j in 9:
		var a := lerpf(-1.1, 1.1, j / 8.0)
		bow.append(Vector2(62.0 + cos(a) * 26.0, sin(a) * 52.0))
	var packed := PackedVector2Array()
	for p: Vector2 in bow: packed.append(p.snapped(Vector2.ONE * pixel_size))
	draw_polyline(packed, OUTLINE, pixel_size * 3.0, false)
	draw_polyline(packed, BOW, pixel_size * 1.5, false)
	var pull := Vector2(62.0 + cos(1.1) * 26.0 - draw_fraction() * 34.0, 0.0)
	draw_polyline(PackedVector2Array([packed[0], pull, packed[packed.size() - 1]]), STRING, pixel_size, false)
	# 攻めどき（射終わりの硬直）は縁を光らせる。
	if actor.mode == &"recovery":
		var a := 0.45 + sin(actor.clock * 14.0) * 0.25
		draw_arc(Vector2(-6, 0), 96.0, 0.0, TAU, 32, Color(open_color, a), pixel_size * 2.0)
	# 帆を広げる間は、帆のまわりへ光の輪を広げる。
	if actor.mode == &"phase":
		var grow := sail_fraction()
		draw_arc(Vector2(-14, 0), 60.0 + grow * 90.0, 0.0, TAU, 32, Color(sail_star_color, 0.8 * (1.0 - grow)), pixel_size * 2.0)
	if pulse > 0.0:
		draw_arc(Vector2(62, 0), 30.0 + (0.3 - pulse) * 80.0, 0.0, TAU, 20, Color(STRING, pulse * 2.5), pixel_size)
	draw_set_transform(Vector2.ZERO)
