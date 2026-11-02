## 攻撃の向きと進行を読み、パーツの弓差分を表示する。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
@export var pixel_size := 3.0
@export var sail_star_scale := 1.0
@export var sail_star_color := Color("#fff6c8")
@export var open_color := Color("#9fe8ff")
const PARTS = preload("res://scenes/bosses/centaurus_parts.tscn")
var _parts: Node2D
var state := {}
var technique := {}
var _world_clock := -1.0
var _technique_id := 0
var _released := 0
var hit := 0.0
var pulse := 0.0
var leap_ring := 0.0
const BOW := Color("#d8b46a")
const OUTLINE := Color("#1a1928")
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
## 表示用の値だけを読み、敵表や役者を参照しない。
func apply_frame(body: Dictionary, attack: Dictionary = {}, _appearance: Dictionary = {}) -> void:
	var dt := maxf(0.0,float(body.clock)-_world_clock) if _world_clock>=0.0 else 0.0
	state = body
	if _technique_id!=int(attack.get("id",0)):
		_technique_id = int(attack.get("id",0))
		_released = 0
	technique = attack
	_world_clock = float(body.clock)
	position = body.position
	rotation = body.facing
	visible = body.mode<4
	if _parts==null:
		z_index = 1
		_parts = PARTS.instantiate()
		_parts.rotation = -PI*0.5
		add_child(_parts)
	hit = float(body.flash)
	leap_ring = maxf(0.0,leap_ring-dt)
	pulse = maxf(0.0,pulse-dt)
	if int(attack.get("released",0))>_released:
		_parts.release_bow(float(attack.get("interval",0.4)))
		_released = int(attack.released)
	_parts.visible = visible
	_parts.scale = Vector2.ONE*float(body.radius)/135.0
	_parts.position = Vector2.ZERO
	_parts.set_bow_pose(StringName(technique.get("technique","")),_mode(),float(body.charge),dt,float(technique.get("pose_time",-1.0)))
	queue_redraw()

func _mode() -> StringName:
	if state.mode==0: return &"entrance"
	if state.mode==2: return &"phase"
	if state.mode==3: return &"final"
	if state.mode>=4: return &"defeated"
	if state.get("leaping",false): return &"leap"
	return [&"windup",&"shooting",&"recovery",&"idle",&"idle",&"idle",&"idle",&"idle"][int(technique.get("stage",5))]

func _poly(points: Array, color: Color) -> void:
	var packed := PackedVector2Array()
	for p: Vector2 in points: packed.append(p.snapped(Vector2.ONE * pixel_size))
	draw_colored_polygon(packed, color)
	packed.append(packed[0])
	draw_polyline(packed, OUTLINE, pixel_size, false)

## 帆を広げた割合（0〜1）。第2形態への移行の間に広げ、そのあとは広げたまま。
func sail_fraction() -> float:
	if state.phase < 2: return 0.0
	if _mode() != &"phase": return 1.0
	var f := float(state.phase_progress)
	return 1.0 - pow(1.0 - clampf(f, 0.0, 1.0), 3.0)

## 正式な帆の絵が追加されるまでの仮表示。素材が用意できたら差し替える。
## 馬の背に帆を広げ、ふくらみと四隅の星で動きを確認する。
func _draw_sail(open: float) -> void:
	if open <= 0.0: return
	var half := 84.0 * open
	var fullness := 1.0
	if StringName(technique.get("technique","")) == &"sail_run":
		if _mode() == &"windup": fullness += 0.6 * float(state.charge)
		elif _mode() == &"sail": fullness = 1.6
		elif _mode() == &"recovery": fullness += 0.6 * float(technique.get("recovery_fraction",0.0))
	var belly := 34.0 * open * fullness
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
	var twinkle := 0.6 + 0.4 * sin(float(state.clock) * 6.0)
	for corner in [Vector2(yard, -half), Vector2(yard, half), Vector2(yard - 14.0, -half * 0.9), Vector2(yard - 14.0, half * 0.9)]:
		draw_circle(corner, 7.0 * open * sail_star_scale, Color(sail_star_color, 0.35 * twinkle))
		draw_circle(corner, 3.5 * open * sail_star_scale, sail_star_color)

## 弓を引く割合（0〜1）。
func draw_fraction() -> float:
	return float(state.get("charge", 0.0))

func _draw() -> void:
	if leap_ring > 0.0: draw_arc(Vector2.ZERO, 30.0 + (0.3 - leap_ring) * 160.0, 0.0, TAU, 24, Color(BOW, leap_ring / 0.3), pixel_size)
	if state.is_empty(): return
	var r := float(state.radius)
	var k := r / 90.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * k)
	var tint := Color(1.6, 1.6, 1.6) if hit > 0.0 else Color.WHITE
	if technique.get("tint", Color.WHITE) != Color.WHITE: tint = technique.tint
	modulate = tint
	_draw_sail(sail_fraction())
	# 攻めどき（射終わりの硬直）は縁を光らせる。
	if _mode() == &"recovery":
		var a := 0.45 + sin(float(state.clock) * 14.0) * 0.25
		draw_arc(Vector2(-6, 0), 96.0, 0.0, TAU, 32, Color(open_color, a), pixel_size * 2.0)
	# 帆を広げる間は、帆のまわりへ光の輪を広げる。
	if _mode() == &"phase":
		var grow := sail_fraction()
		draw_arc(Vector2(-14, 0), 60.0 + grow * 90.0, 0.0, TAU, 32, Color(sail_star_color, 0.8 * (1.0 - grow)), pixel_size * 2.0)
	if pulse > 0.0:
		draw_arc(Vector2(62, 0), 30.0 + (0.3 - pulse) * 80.0, 0.0, TAU, 20, Color(STRING, pulse * 2.5), pixel_size)
	if _mode()==&"windup" and technique.get("technique","")=="volley":
		var pull := Vector2(62.0+cos(1.1)*26.0-float(state.charge)*34.0,0.0)
		draw_line(pull,pull+Vector2(56.0,0.0),WARNING,pixel_size*1.5)
	draw_set_transform(Vector2.ZERO)
