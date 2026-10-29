## 技の予告・猟犬の軌跡・号令と遠吠えの輪。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
@export var technique_id: StringName
var visual_kind: StringName
@export var pixel_size := 3.0
var actor: CanisMajorBoss
var _pack_layer := Node2D.new()
var _trails: Dictionary = {}
var retained: bool:
	get: return visual_kind == &"howl" and actor != null and actor.ring_started >= 0.0
const OUTLINE := Color("#1a1928")
const COAT := Color("#7a6f8f")
const SHADE := Color("#4d4660")
const MUZZLE := Color("#a99cc0")
const SIRIUS := Color("#e8f6ff")
const WARNING := Color("#f2b567")
const DANGER := Color("#ff667d")
const OPEN := Color("#9fe8ff")
const LUNGE_TRAIL := 6
func _ready() -> void:
	EFFECT_SETTINGS.apply_to(self)
	_pack_layer.top_level = true
	_pack_layer.draw.connect(_draw_lunge)
	add_child(_pack_layer)
func update_technique() -> void:
	if visual_kind == &"command": _track_lunge()
	_pack_layer.queue_redraw()
func _draw() -> void:
	if actor == null or not actor.has_body() or actor.technique != technique_id: return
	var r := actor.table.r[actor.body]
	var charge := actor.table.charge[actor.body]
	# 飛びかかりの構えは着地点までの線を描く。狙いが固定されると赤くする。
	if visual_kind == &"pounce" and actor.mode == &"windup":
		var reach := actor.table.pos[actor.body].distance_to(actor.aim_point)
		var color := DANGER if actor.locked else WARNING
		draw_line(Vector2(r, 0.0), Vector2(maxf(r, reach), 0.0), Color(color, 0.35 + charge * 0.4), pixel_size * (2.0 if actor.locked else 1.0))
		draw_arc(Vector2(reach, 0.0), r * 0.5, 0.0, TAU, 24, Color(color, 0.6), pixel_size)
	# シリウスの光の溜めは、口元から射線を細く示す。向きが固定されると光の太さの赤い線にする。
	if visual_kind == &"sirius" and actor.mode == &"windup":
		var from := Vector2(r * CanisMajorBoss.MOUTH_REACH, 0.0)
		var length := float(actor.rule().get("beam_length", 1400.0))
		var color := DANGER if actor.locked else WARNING
		var width := float(actor.rule().get("beam_width", 50.0)) if actor.locked else pixel_size * 1.5
		draw_line(from, from + Vector2(length, 0.0), Color(color, 0.35 if actor.locked else 0.25 + charge * 0.3), width)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (r / 100.0))
	var mouth := Vector2(84.0, 0.0)
	var howl := visual_kind == &"howl" and actor.mode == &"windup"
	var shout := visual_kind == &"command" and actor.mode == &"windup"
	# 遠吠えは、口元から大きな輪を次々に広げる。
	if howl:
		for ring in 3:
			var grow := fmod(actor.clock * 1.8 + ring / 3.0, 1.0)
			draw_arc(mouth, 30.0 + grow * 220.0, -1.2, 1.2, 32, Color(OPEN, 0.9 * (1.0 - grow)), pixel_size * 2.0)
	if shout:
		for ring in 2:
			var grow := fmod(actor.clock * 2.5 + ring * 0.5, 1.0)
			draw_arc(mouth, 20.0 + grow * 90.0, 0.0, TAU, 32, Color(WARNING, 1.0 - grow), pixel_size)
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
	if visual_kind == &"howl" and radius > 0.0:
		_pack_layer.draw_arc(actor.ring_center, radius, 0.0, TAU, 96, Color(WARNING, 0.35), pixel_size, true)
	if visual_kind != &"command": return
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
