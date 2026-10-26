## パーツの走りは世界時間、向きは役者と同じ戦闘方向へ同期する。
extends Node2D
const PartsVisual = preload("res://scripts/bosses/monoceros_parts.gd")
const WARNING := Color("#f2b567")
const DANGER := Color("#ff667d")
const ENERGY := Color("#9fe8ff")
var actor: MonocerosBoss
var hit := 0.0
@onready var parts: PartsVisual = $Parts

func bind_monoceros(owner_actor: MonocerosBoss) -> void:
	actor = owner_actor
	actor.presentation_event.connect(_event)
	actor.presentation_advanced.connect(_advance)
	z_index = 1
	_sync_parts(0.0)

func _event(event: Dictionary) -> void:
	if event.cue == &"hit": hit = 0.18
	queue_redraw()

func _advance(dt: float) -> void:
	hit = maxf(0.0, hit - dt)
	_sync_parts(dt)
	queue_redraw()

func _sync_parts(dt: float) -> void:
	if actor == null or not actor.has_body(): return
	var k := actor.table.r[actor.body] / 96.0
	parts.scale = Vector2.ONE * k
	# 元絵の下向きを役者の前方（+X）へ合わせ、胴体の中心を判定円へ置く。
	parts.position = Vector2(37.0 * k, 0.0)
	parts.rotation = -PI * 0.5
	parts.modulate = Color(1.35, 1.35, 1.35) if hit > 0.0 else Color.WHITE
	var moving := actor.table.vel[actor.body].length_squared() > 25.0
	parts.advance_gait(dt, moving and actor.mode not in [&"windup", &"stuck", &"phase", &"final", &"defeated"])
	var neck_angle := 0.0
	if actor.technique == &"sweep" and actor.mode in [&"windup", &"active"]:
		var points := actor.horn_points()
		neck_angle = angle_difference(actor.table.facing[actor.body], (points[1] - actor.table.pos[actor.body]).angle())
	parts.get_node("Head").rotation = neck_angle

func _body_point(world_point: Vector2) -> Vector2:
	# 旋回したフレームも、役者ノードの描画更新を待たず戦闘方向を使う。
	return (world_point - actor.table.pos[actor.body]).rotated(-actor.table.facing[actor.body])

func _draw() -> void:
	if actor == null or not actor.has_body(): return
	# 正確な攻撃線をワールド→役者座標へ戻す。警告と攻撃の幅は共通。
	draw_set_transform(Vector2.ZERO)
	if actor.mode in [&"windup", &"active"]:
		var color := DANGER if actor.mode==&"active" else WARNING
		var width := float(actor.def.params.horn_width)
		if actor.technique==&"sweep" and actor.mode==&"windup":
			var arc := PackedVector2Array()
			for j in 25:
				var points := actor.horn_points(float(j)/24.0)
				arc.append(_body_point(points[-1]))
			draw_polyline(arc, Color(color,0.65), 7.0, false)
			for f in [0.0,1.0]:
				var edge := actor.horn_points(f)
				draw_line(_body_point(edge[0]),_body_point(edge[1]),Color(color,0.5),4.0,false)
		var points := actor.horn_points()
		var a := _body_point(points[0])
		var b := _body_point(points[1])
		if actor.technique in [&"charge", &"return_charge"] and actor.mode==&"windup":
			var end := actor.table.pos[actor.body]+actor.direction*float(actor.rule().distance)
			# 薄い進路は移動方向、太い角の光は実際の攻撃形状を示す。
			draw_line(a,_body_point(end),Color(color,0.3),6.0,false)
		draw_line(a,b,Color(color,0.3),width,false)
		draw_line(a,b, ENERGY if actor.technique==&"lance" else color, 7.0 if actor.mode==&"windup" else 13.0,false)
		if actor.locked:
			draw_rect(Rect2(b-Vector2(6,6),Vector2(12,12)),color)
	if actor.mode==&"stuck":
		var at := _body_point(actor.table.pos[actor.body]+actor.direction*actor.horn_length())
		for j in 3:
			draw_line(at+Vector2(-15,j*10-10),at+Vector2(15,j*10-10),WARNING,3.0,false)
