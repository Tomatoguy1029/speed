## 低解像度の関節付き仮アート。攻撃形状は役者から読み、演出だけを差し替える。
extends Node2D
@export var body_texture: Texture2D
@export var head_texture: Texture2D
@export var hoof_texture: Texture2D
@export var pixel_size := 3.0
var actor: MonocerosBoss
var hit := 0.0
var pulse := 0.0
var gait := 0.0
const OUTLINE := Color("#1a1928")
const HULL := Color("#ae9b87")
const SHADE := Color("#68647c")
const LIGHT := Color("#ede1ba")
const WARNING := Color("#f2b567")
const DANGER := Color("#ff667d")
const ENERGY := Color("#9fe8ff")

func bind_monoceros(owner_actor: MonocerosBoss) -> void:
	actor = owner_actor
	actor.presentation_event.connect(_event)
	actor.presentation_advanced.connect(_advance)
	z_index = 1

func _event(event: Dictionary) -> void:
	if event.cue == &"hit": hit = 0.18
	if event.cue in [&"aim_locked", &"horn_stuck", &"phase_changed"]: pulse = 0.35
	queue_redraw()

func _advance(dt: float) -> void:
	hit = maxf(0.0, hit - dt)
	pulse = maxf(0.0, pulse - dt)
	gait += dt * (15.0 if actor.mode == &"active" else 7.0)
	queue_redraw()

func _poly(points: Array, color: Color) -> void:
	var packed := PackedVector2Array()
	for p: Vector2 in points: packed.append(p.snapped(Vector2.ONE * pixel_size))
	draw_colored_polygon(packed, color)
	packed.append(packed[0])
	draw_polyline(packed, OUTLINE, pixel_size, false)

func _limb(root: Vector2, knee: Vector2, hoof: Vector2, width: float, color: Color) -> void:
	var side := (hoof - root).normalized().orthogonal() * width
	_poly([root-side, knee-side, hoof-side, hoof+side, knee+side, root+side], color)
	if hoof_texture != null:
		draw_texture_rect(hoof_texture, Rect2(hoof - Vector2(12, 10), Vector2(24, 20)), false)
	else:
		_poly([hoof+Vector2(-9,-8),hoof+Vector2(12,-8),hoof+Vector2(12,8),hoof+Vector2(-9,8)], LIGHT)

func _draw() -> void:
	if actor == null or not actor.has_body(): return
	var r := actor.table.r[actor.body]
	var k := r / 96.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * k)
	var moving := actor.table.vel[actor.body].length() > 5.0
	var turning := clampf(actor.turn_motion / maxf(actor.def.turn, 0.001), -1.0, 1.0)
	var braced := actor.mode in [&"windup", &"stuck", &"recovery", &"phase"]
	var strain := sin(actor.clock * 22.0) * 3.0 if actor.mode == &"stuck" else 0.0
	# 四肢の根元、膝、蹄を別々に動かす。向き直りは外脚を踏み替える。
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			var wave := sin(gait + (0.0 if x*y > 0 else PI))
			var stride := wave * (25.0 if moving else absf(turning) * 20.0)
			var root := Vector2(x * 42.0, y * 30.0)
			var knee := Vector2(x * 48.0 + stride * 0.5, y * (51.0 if braced else 46.0))
			var foot := Vector2(x * 58.0 + stride, y * (69.0 if braced else 60.0))
			if x < 0 and actor.technique == &"kick":
				if actor.mode == &"windup": foot.x += 24.0
				elif actor.mode == &"active": foot = Vector2(-float(actor.rule().reach)/k, y * 13.0)
			_limb(root, knee, foot, 7.0, SHADE if y < 0 else HULL)
	# 船尾の装甲を背負う馬。装甲の見た目は両形態で保つ。
	var breathe := sin(actor.clock * 4.0) * (3.0 if actor.mode == &"recovery" else 1.0)
	if body_texture != null:
		draw_texture_rect(body_texture, Rect2(-82,-42,150,84), false)
	else:
		_poly([Vector2(-80,-24),Vector2(-62,-40-breathe),Vector2(30,-38-breathe),Vector2(62,-25),Vector2(64,25),Vector2(28,39+breathe),Vector2(-62,40+breathe),Vector2(-80,24)], LIGHT if hit > 0 else HULL)
		_poly([Vector2(-70,-26),Vector2(-22,-32),Vector2(-6,0),Vector2(-22,32),Vector2(-70,26)], SHADE)
		_poly([Vector2(-58,-28),Vector2(-44,-28),Vector2(-44,28),Vector2(-58,28)], HULL)
		_poly([Vector2(-20,-23),Vector2(23,-23),Vector2(35,0),Vector2(23,23),Vector2(-20,23)], SHADE)
		_poly([Vector2(-8,-15),Vector2(20,-15),Vector2(27,0),Vector2(20,15),Vector2(-8,15)], HULL)
	# たてがみと尻尾。燃焼は形態表現に使わない。
	_poly([Vector2(-76,-10),Vector2(-109,-18),Vector2(-125,-5),Vector2(-103,7),Vector2(-77,10)], SHADE)
	var neck_angle := 0.0
	if actor.technique == &"sweep" and actor.mode in [&"windup", &"active"]:
		neck_angle = (actor.horn_points()[1]-actor.table.pos[actor.body]).angle()-actor.table.facing[actor.body]
	elif braced: neck_angle = sin(actor.clock * 8.0) * 0.06
	draw_set_transform(Vector2(46+strain, 0)*k, neck_angle, Vector2.ONE*k)
	_poly([Vector2(-8,-20),Vector2(20,-28),Vector2(54,-17),Vector2(54,17),Vector2(20,28),Vector2(-8,20)], HULL)
	_poly([Vector2(-5,-25),Vector2(17,-39),Vector2(37,-29),Vector2(19,-24)], SHADE)
	_poly([Vector2(-5,25),Vector2(17,39),Vector2(37,29),Vector2(19,24)], SHADE)
	if head_texture != null:
		draw_texture_rect(head_texture, Rect2(30,-22,52,44),false)
	else:
		_poly([Vector2(28,-19),Vector2(57,-17),Vector2(78,-10),Vector2(80,10),Vector2(57,17),Vector2(28,19)], LIGHT if hit>0 else HULL)
		draw_rect(Rect2(42,-15,9,6), ENERGY if actor.phase==2 else WARNING)
		draw_rect(Rect2(42,9,9,6), ENERGY if actor.phase==2 else WARNING)
	_poly([Vector2(74,-7),Vector2(actor.horn_length()/k-46,0),Vector2(74,7)], ENERGY if actor.phase==2 else LIGHT)
	# 正確な攻撃線をワールド→役者座標へ戻す。警告と攻撃の幅は共通。
	draw_set_transform(Vector2.ZERO)
	if actor.mode in [&"windup", &"active"]:
		var color := DANGER if actor.mode==&"active" else WARNING
		var width := float(actor.def.params.horn_width)
		if actor.technique==&"sweep" and actor.mode==&"windup":
			var arc := PackedVector2Array()
			for j in 25:
				var points := actor.horn_points(float(j)/24.0)
				arc.append(actor.to_local(points[-1]))
			draw_polyline(arc, Color(color,0.65), 7.0, false)
			for f in [0.0,1.0]:
				var edge := actor.horn_points(f)
				draw_line(actor.to_local(edge[0]),actor.to_local(edge[1]),Color(color,0.5),4.0,false)
		var points := actor.horn_points()
		var a := actor.to_local(points[0])
		var b := actor.to_local(points[1])
		if actor.technique in [&"charge", &"return_charge"] and actor.mode==&"windup":
			var end := actor.table.pos[actor.body]+actor.direction*float(actor.rule().distance)
			# 薄い進路は移動方向、太い角の光は実際の攻撃形状を示す。
			draw_line(a,actor.to_local(end),Color(color,0.3),6.0,false)
		draw_line(a,b,Color(color,0.3),width,false)
		draw_line(a,b, ENERGY if actor.technique==&"lance" else color, 7.0 if actor.mode==&"windup" else 13.0,false)
		if actor.locked:
			draw_rect(Rect2(b-Vector2(6,6),Vector2(12,12)),color)
	if actor.mode==&"stuck":
		var at := actor.to_local(actor.table.pos[actor.body]+actor.direction*actor.horn_length())
		for j in 3:
			draw_line(at+Vector2(-15,j*10-10),at+Vector2(15,j*10-10),WARNING,3.0,false)
