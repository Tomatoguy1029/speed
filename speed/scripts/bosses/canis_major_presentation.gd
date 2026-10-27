## 仮の図形の大型の猟犬。攻撃の向き・時間は役者から読み、演出だけを差し替える。
extends Node2D
@export var pixel_size := 3.0
var actor: CanisMajorBoss
var hit := 0.0
var pulse := 0.0
var gait := 0.0
const OUTLINE := Color("#1a1928")
const COAT := Color("#7a6f8f")
const SHADE := Color("#4d4660")
const MUZZLE := Color("#a99cc0")
const SIRIUS := Color("#e8f6ff")
const WARNING := Color("#f2b567")
const DANGER := Color("#ff667d")
const OPEN := Color("#9fe8ff")
## 号令で飛び出している猟犬の軌跡に残す位置の数
const LUNGE_TRAIL := 6
## 号令で飛び出している猟犬の光と軌跡を描く層。本体の回転に付いていかないよう、ワールド座標で描く。
var _pack_layer := Node2D.new()
## 飛び出している猟犬の行 → 最近の位置（古い順）
var _trails: Dictionary = {}

func bind_canis_major(owner_actor: CanisMajorBoss) -> void:
	actor = owner_actor
	actor.presentation_event.connect(_event)
	actor.presentation_advanced.connect(_advance)
	z_index = 1
	_pack_layer.top_level = true
	_pack_layer.draw.connect(_draw_lunge)
	add_child(_pack_layer)

func _event(event: Dictionary) -> void:
	if event.cue == &"hit": hit = 0.18
	if event.cue in [&"aim_locked", &"pounce", &"command", &"sirius", &"phase_changed", &"howl"]: pulse = 0.35
	queue_redraw()

func _advance(dt: float) -> void:
	hit = maxf(0.0, hit - dt)
	pulse = maxf(0.0, pulse - dt)
	gait += dt * (18.0 if actor.mode == &"active" else 9.0)
	_track_lunge()
	queue_redraw()
	_pack_layer.queue_redraw()

## シリウスの輝きの強さ（0〜1）。第2形態への移行の間に強め、そのあとは強いまま。
func blaze() -> float:
	if actor.phase < 2: return 0.0
	if actor.mode != &"phase": return 1.0
	var f := 1.0 - actor.phase_time / maxf(float(actor.def.params.phase_time), 0.001)
	return 1.0 - pow(1.0 - clampf(f, 0.0, 1.0), 3.0)

## 飛び出している猟犬の位置を軌跡へ足す。飛び出しが終わった猟犬の軌跡は消す。
func _track_lunge() -> void:
	var t := actor.table
	for i in _trails.keys():
		if not actor.lunging.has(i): _trails.erase(i)
	for i in actor.lunging:
		if t.alive[i] == 0 or t.dead[i] != 0: continue
		var points: PackedVector2Array = _trails.get(i, PackedVector2Array())
		points.append(t.pos[i])
		if points.size() > LUNGE_TRAIL: points = points.slice(points.size() - LUNGE_TRAIL)
		_trails[i] = points

## 飛び出している猟犬の後ろに短い軌跡を引き、体のまわりを光らせる。遠吠えの囲みの間は、今の囲みの半径を薄い円で示す。
func _draw_lunge() -> void:
	var t := actor.table
	var radius := actor.ring_radius()
	if radius > 0.0:
		_pack_layer.draw_arc(actor.ring_center, radius, 0.0, TAU, 96, Color(WARNING, 0.35), pixel_size, true)
	for i in _trails:
		var points: PackedVector2Array = _trails[i]
		if points.size() < 1 or t.alive[i] == 0 or t.dead[i] != 0: continue
		var r := t.r[i]
		for j in range(1, points.size()):
			var f := float(j) / (points.size() - 1)
			_pack_layer.draw_line(points[j - 1], points[j], Color(DANGER, 0.15 + 0.55 * f), r * (0.4 + 0.9 * f), true)
		var at := t.pos[i]
		var flicker := 0.75 + 0.25 * sin(actor.clock * 40.0 + float(i))
		_pack_layer.draw_circle(at, r * 1.9, Color(DANGER, 0.22 * flicker))
		_pack_layer.draw_circle(at, r * 1.3, Color(WARNING, 0.35 * flicker))
		_pack_layer.draw_arc(at, r * 1.3, 0.0, TAU, 20, Color(SIRIUS, 0.8 * flicker), pixel_size * 0.7, true)

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

func _draw() -> void:
	if actor == null or not actor.has_body(): return
	var r := actor.table.r[actor.body]
	var k := r / 100.0
	var moving := actor.table.vel[actor.body].length() > 5.0
	var charge := actor.table.charge[actor.body]
	# 飛びかかりの構えは着地点までの線を描く。狙いが固定されると赤くする。
	if actor.technique == &"pounce" and actor.mode == &"windup":
		var reach := actor.table.pos[actor.body].distance_to(actor.aim_point)
		var color := DANGER if actor.locked else WARNING
		draw_line(Vector2(r, 0.0), Vector2(maxf(r, reach), 0.0), Color(color, 0.35 + charge * 0.4), pixel_size * (2.0 if actor.locked else 1.0))
		draw_arc(Vector2(reach, 0.0), r * 0.5, 0.0, TAU, 24, Color(color, 0.6), pixel_size)
	# シリウスの光の溜めは、口元から射線を細く示す。向きが固定されると光の太さの赤い線にする。
	if actor.technique == &"sirius" and actor.mode == &"windup":
		var from := Vector2(r * CanisMajorBoss.MOUTH_REACH, 0.0)
		var length := float(actor.rule().get("beam_length", 1400.0))
		var color := DANGER if actor.locked else WARNING
		var width := float(actor.rule().get("beam_width", 50.0)) if actor.locked else pixel_size * 1.5
		draw_line(from, from + Vector2(length, 0.0), Color(color, 0.35 if actor.locked else 0.25 + charge * 0.3), width)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * k)
	modulate = Color(1.6, 1.6, 1.6) if hit > 0.0 else Color.WHITE
	# 身を低くする：構えるほど胴を短く太く、脚を外へ開く。
	var crouch := charge if actor.technique == &"pounce" and actor.mode == &"windup" else 0.0
	var stretch := 1.15 if actor.mode == &"active" and actor.technique == &"pounce" else 1.0 - crouch * 0.15
	for j in 4:
		var side := -1.0 if j % 2 == 0 else 1.0
		var x := (-48.0 if j < 2 else 22.0) * stretch
		var swing := sin(gait + j * 1.7) * (14.0 if moving else 2.0)
		var spread := 30.0 + crouch * 10.0
		_poly([Vector2(x + swing - 8, side * spread), Vector2(x + swing + 8, side * spread), Vector2(x + swing + 6, side * (spread + 20)), Vector2(x + swing - 6, side * (spread + 20))], SHADE)
	_poly([Vector2(-70 * stretch, -5), Vector2(-104 * stretch, -10 + sin(gait) * 7.0), Vector2(-106 * stretch, 2 + sin(gait) * 7.0), Vector2(-70 * stretch, 6)], SHADE)
	_oval(Vector2(-14 * stretch, 0), Vector2(62 * stretch, 34 + crouch * 6.0), COAT)
	_oval(Vector2(46 * stretch, 0), Vector2(26, 24), COAT)
	_poly([Vector2(40 * stretch, -20), Vector2(30 * stretch, -36), Vector2(52 * stretch, -24)], SHADE)
	_poly([Vector2(40 * stretch, 20), Vector2(30 * stretch, 36), Vector2(52 * stretch, 24)], SHADE)
	_oval(Vector2(70 * stretch, 0), Vector2(16, 12), MUZZLE)
	# 口元のシリウス。号令の構えでは強く瞬き、輪を広げる。
	var mouth := Vector2(84 * stretch, 0)
	var shout := actor.technique == &"command" and actor.mode == &"windup"
	var howl := actor.technique == &"howl" and actor.mode == &"windup"
	var gather := actor.technique == &"sirius" and actor.mode == &"windup"
	var strong := blaze()
	var glow := 6.0 + 6.0 * strong + (8.0 * charge if shout else 18.0 * charge if gather else (1.5 + 2.0 * strong) * sin(actor.clock * 5.0))
	# 第2形態では、口元のまわりに大きな光の暈と十字の光芒を足す。
	if strong > 0.0:
		var flare := (1.0 + 0.15 * sin(actor.clock * 9.0)) * strong
		draw_circle(mouth, glow + 18.0 * flare, Color(OPEN, 0.18))
		for ray in 4:
			var u := Vector2.from_angle(ray * PI / 2.0 + actor.clock * 0.6) * (glow + 34.0 * flare)
			draw_line(mouth - u, mouth + u, Color(SIRIUS, 0.55 * strong), pixel_size)
	draw_circle(mouth, glow + 4.0, Color(OPEN, 0.35))
	draw_circle(mouth, glow, SIRIUS)
	# 移行の間は、口元から光の輪を広げる。
	if actor.mode == &"phase":
		for ring in 2:
			var grow := fmod(strong * 1.5 + ring * 0.5, 1.0)
			draw_arc(mouth, 20.0 + grow * 140.0, 0.0, TAU, 32, Color(SIRIUS, 0.9 * (1.0 - grow)), pixel_size * 2.0)
	# 遠吠えは、口元から大きな輪を次々に広げる。
	if howl:
		for ring in 3:
			var grow := fmod(actor.clock * 1.8 + ring / 3.0, 1.0)
			draw_arc(mouth, 30.0 + grow * 220.0, -1.2, 1.2, 32, Color(OPEN, 0.9 * (1.0 - grow)), pixel_size * 2.0)
	if shout:
		for ring in 2:
			var grow := fmod(actor.clock * 2.5 + ring * 0.5, 1.0)
			draw_arc(mouth, 20.0 + grow * 90.0, 0.0, TAU, 32, Color(WARNING, 1.0 - grow), pixel_size)
	if actor.mode == &"recovery":
		var a := 0.45 + sin(actor.clock * 14.0) * 0.25
		draw_arc(Vector2(-6, 0), 106.0, 0.0, TAU, 32, Color(OPEN, a), pixel_size * 2.0)
	if pulse > 0.0:
		draw_arc(mouth, 24.0 + (0.35 - pulse) * 120.0, 0.0, TAU, 24, Color(SIRIUS, pulse * 2.4), pixel_size)
	draw_set_transform(Vector2.ZERO)
