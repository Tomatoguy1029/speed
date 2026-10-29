## 角・蹄の予告と光の槍の残光。体のパーツは本体の表示が描く。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
@export var technique_id: StringName
@export var pixel_size := 3.0
var actor: MonocerosBoss
var lance_afterglow := 0.0
var lance_launched := false
var lance_points := PackedVector2Array()
var retained: bool:
	get: return lance_afterglow > 0.0
const WARNING := Color("#f2b567")
const DANGER := Color("#ff667d")
const ENERGY := Color("#9fe8ff")
func _ready() -> void:
	EFFECT_SETTINGS.apply_to(self)
func on_event(event: Dictionary) -> void:
	if technique_id != &"lance": return
	if event.technique == &"lance":
		if event.cue == &"telegraph": lance_launched = false
		if event.cue == &"attack_started": lance_launched = true
	if event.cue == &"recovery_started" and event.technique == &"lance" and lance_launched:
		lance_launched = false
		lance_points = actor.horn_points()
		lance_afterglow = float(actor.def.params.get("lance_hold", 0.12)) + float(actor.def.params.get("lance_fade", 0.45))
func advance(dt: float) -> void:
	lance_afterglow = maxf(0.0, lance_afterglow - dt)
func _draw() -> void:
	if actor == null or not actor.has_body(): return
	if actor.technique != technique_id:
		_lance_remnants()
		return
	# 正確な攻撃線をワールド→役者座標へ戻す。警告と攻撃の幅は共通。
	draw_set_transform(Vector2.ZERO)
	_lance_remnants()
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
		if actor.technique == &"kick" and actor.mode == &"active": return
		if actor.technique in [&"charge", &"return_charge", &"lance"] and actor.mode==&"windup":
			# 薄い進路は移動後の角先、太い角の光は実際の攻撃形状を示す。
			draw_line(a,_body_point(actor.warning_points()[1]),Color(color,0.3),6.0,false)
		draw_line(a,b,Color(color,0.3),width,false)
		draw_line(a,b, ENERGY if actor.technique==&"lance" else color, 7.0 if actor.mode==&"windup" else 13.0,false)
		if actor.locked:
			draw_rect(Rect2(b-Vector2(6,6),Vector2(12,12)),color)
	if actor.mode==&"stuck":
		var at := _body_point(actor.table.pos[actor.body]+actor.direction*actor.horn_length())
		for j in 3:
			draw_line(at+Vector2(-15,j*10-10),at+Vector2(15,j*10-10),WARNING,3.0,false)

func _body_point(world_point: Vector2) -> Vector2:
	# 旋回したフレームも、役者ノードの描画更新を待たず戦闘方向を使う。
	return (world_point - actor.table.pos[actor.body]).rotated(-actor.table.facing[actor.body])

func _lance_remnants() -> void:
	if lance_afterglow <= 0.0 or lance_points.size() != 2: return
	var fade := maxf(0.01, float(actor.def.params.get("lance_fade", 0.45)))
	var a := _body_point(lance_points[0])
	var b := _body_point(lance_points[1])
	if lance_afterglow > fade:
		draw_line(a, b, Color("#eaffff"), 13.0, false)
		return
	var progress := 1.0 - lance_afterglow / fade
	var side := (b-a).normalized().orthogonal()
	for j in 32:
		var t := float(j) / 31.0
		var spread := sin(float(j) * 17.3) * 90.0 * progress
		var at := (a.lerp(b,t) + side * spread).snapped(Vector2.ONE * pixel_size)
		draw_rect(Rect2(at,Vector2.ONE * (6.0 - progress * 3.0)), Color(ENERGY, 1.0-progress))
