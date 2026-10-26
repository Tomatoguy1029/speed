## 仮の図形の半人半馬。攻撃の向き・時間は役者から読み、演出だけを差し替える。
extends Node2D
@export var pixel_size := 3.0
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
const OPEN := Color("#9fe8ff")

func bind_centaurus(owner_actor: CentaurusBoss) -> void:
	actor = owner_actor
	actor.presentation_event.connect(_event)
	actor.presentation_advanced.connect(_advance)
	z_index = 1

func _event(event: Dictionary) -> void:
	if event.cue == &"hit": hit = 0.18
	if event.cue in [&"alert", &"released"]: pulse = 0.3
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

## 弓を引く割合（0〜1）。
func draw_fraction() -> float:
	if actor.mode == &"windup": return actor.table.charge[actor.body]
	return 0.0

func _draw() -> void:
	if actor == null or not actor.has_body(): return
	var r := actor.table.r[actor.body]
	var k := r / 90.0
	var moving := actor.table.vel[actor.body].length() > 5.0
	# 照準線は本体の縮尺と別に、実際の射程で描く。
	if actor.mode == &"windup" and actor.technique == &"power_shot":
		var reach := float(actor.rule().get("travel", 1600.0))
		var width := float(actor.rule().get("radius", 30.0)) * 2.0
		var from := Vector2(r * float(actor.def.params.bow_reach), 0.0)
		var color := DANGER if actor.alerting else WARNING
		color.a = 0.85 if actor.alerting else 0.35 + draw_fraction() * 0.35
		draw_line(from, from + Vector2(reach, 0.0), color, width if actor.alerting else pixel_size * 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * k)
	var tint := Color(1.6, 1.6, 1.6) if hit > 0.0 else Color.WHITE
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
	if actor.mode == &"windup":
		var glow := DANGER if actor.alerting else WARNING
		var length := 40.0 if actor.technique == &"power_shot" else 26.0
		draw_line(pull, pull + Vector2(length + 30.0, 0.0), glow, pixel_size * (3.0 if actor.technique == &"power_shot" else 1.5))
	# 攻めどき（射終わりの硬直）は縁を光らせる。
	if actor.mode == &"recovery":
		var a := 0.45 + sin(actor.clock * 14.0) * 0.25
		draw_arc(Vector2(-6, 0), 96.0, 0.0, TAU, 32, Color(OPEN, a), pixel_size * 2.0)
	if pulse > 0.0:
		draw_arc(Vector2(62, 0), 30.0 + (0.3 - pulse) * 80.0, 0.0, TAU, 20, Color(STRING, pulse * 2.5), pixel_size)
	draw_set_transform(Vector2.ZERO)
