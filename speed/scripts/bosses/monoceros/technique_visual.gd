## 角・蹄の予告と、連続突進・薙ぎ・乱舞の仮表示。体のパーツは本体の表示が描く。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
@export var technique_id: StringName
@export var pixel_size := 3.0
var actor: MonocerosBoss
const WARNING := Color("#f2b567")
const ENERGY := Color("#9fe8ff")
func _ready() -> void:
	EFFECT_SETTINGS.apply_to(self)
func _draw() -> void:
	if actor == null or not actor.has_body(): return
	if actor.technique != technique_id: return
	if technique_id == &"return_charge" and actor._runner != null and actor._runner.stage == &"brake":
		_reverse_jet(clampf(actor._runner.stage_time / maxf(float(actor.rule().brake_time), 0.001), 0.0, 1.0))
	if technique_id == &"sweep":
		if actor.mode not in [&"windup", &"active"]: return
		if actor._runner.stage == &"stop":
			_reverse_jet(clampf(actor._runner.stage_time / maxf(float(actor.rule().stop_time), 0.001), 0.0, 1.0))
		return
	# 角の光は本体の表示へまとめる。技側には進路と後ろ蹴りの予告だけを残す。
	if actor.mode in [&"windup", &"active"]:
		var points := actor.horn_points()
		var a := _body_point(points[0])
		var b := _body_point(points[1])
		if technique_id in [&"charge", &"return_charge"] and actor.mode == &"windup" and (technique_id != &"return_charge" or actor._runner.stage == &"aim"):
			draw_line(a, _body_point(actor.warning_points()[1]), Color(WARNING, 0.3), 6.0, false)
		if technique_id == &"kick" and actor.mode == &"windup":
			draw_line(a, b, Color(WARNING, 0.3), float(actor.def.params.horn_width), false)
			draw_line(a, b, WARNING, 7.0, false)
			if actor.locked: draw_rect(Rect2(b - Vector2(6, 6), Vector2(12, 12)), WARNING)
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
