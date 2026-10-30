## 角・蹄の予告と、連続突進・薙ぎ・乱舞の仮表示。体のパーツは本体の表示が描く。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
@export var technique_id: StringName
@export var pixel_size := 3.0
var actor: MonocerosBoss
const WARNING := Color("#f2b567")
const DANGER := Color("#ff667d")
const ENERGY := Color("#9fe8ff")
func _ready() -> void:
	EFFECT_SETTINGS.apply_to(self)
func _draw() -> void:
	if actor == null or not actor.has_body(): return
	if actor.technique != technique_id: return
	if technique_id == &"horn_dance":
		if actor.mode in [&"windup", &"active"]:
			# 仮表示。正式は shader。角の光だけを描き、軌跡の線は残さない。
			var points := actor.horn_points()
			var glow_level := float(actor._runner.glow_level)
			draw_line(_body_point(points[0]), _body_point(points[1]), Color(ENERGY, glow_level), 12.0, false)
			if actor._runner.stage == &"end": draw_circle(_body_point(points[1]), 6.0 + 10.0 * glow_level, Color.WHITE)
		return
	if technique_id == &"return_charge" and actor._runner != null and actor._runner.stage == &"brake":
		_reverse_jet(clampf(actor._runner.stage_time / maxf(float(actor.rule().brake_time), 0.001), 0.0, 1.0))
	if technique_id == &"sweep":
		if actor.mode not in [&"windup", &"active"]: return
		if actor._runner.stage == &"stop":
			_reverse_jet(clampf(actor._runner.stage_time / maxf(float(actor.rule().stop_time), 0.001), 0.0, 1.0))
		if actor._runner.stage == &"swing":
			var points := actor.horn_points()
			draw_line(_body_point(points[0]), _body_point(points[1]), Color(DANGER, 0.3), float(actor.def.params.horn_width), false)
			draw_line(_body_point(points[0]), _body_point(points[1]), DANGER, 13.0, false)
		return
	# 正確な攻撃線をワールド→役者座標へ戻す。警告と攻撃の幅は共通。
	draw_set_transform(Vector2.ZERO)
	if actor.mode in [&"windup", &"active"]:
		var color := DANGER if actor.mode==&"active" else WARNING
		var width := float(actor.def.params.horn_width)

		var points := actor.horn_points()
		var a := _body_point(points[0])
		var b := _body_point(points[1])
		if actor.technique == &"kick" and actor.mode == &"active": return
		if actor.technique in [&"charge", &"return_charge", &"lance"] and actor.mode==&"windup" and (technique_id != &"return_charge" or actor._runner.stage == &"aim"):
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

## 仮表示。正式は shader。前向きの噴射を、広がって薄くなる3つの円で示す。
func _reverse_jet(k: float) -> void:
	var forward := Vector2.from_angle(actor.table.facing[actor.body])
	var at := actor.table.pos[actor.body] + forward * actor.table.r[actor.body] * 0.65
	for j in 3:
		var offset := forward * float(j) * 8.0 + forward.orthogonal() * float(j - 1) * 8.0
		draw_circle(_body_point(at + offset), lerpf(10.0, 24.0, k), Color(ENERGY, 0.35 * (1.0 - k)))

func _body_point(world_point: Vector2) -> Vector2:
	# 旋回したフレームも、役者ノードの描画更新を待たず戦闘方向を使う。
	return (world_point - actor.table.pos[actor.body]).rotated(-actor.table.facing[actor.body])
