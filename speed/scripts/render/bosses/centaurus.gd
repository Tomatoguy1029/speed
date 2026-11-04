## 攻撃の向きと進行を読み、パーツの弓差分を表示する。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
const REFERENCE_WHITE := preload("res://shaders/fx_reference_white.gdshader")
const REFERENCE_CUT := preload("res://scripts/render/bosses/centaurus_reference_cut.gd")
@export var pixel_size := 3.0
@export var sail_star_scale := 1.0
@export var sail_star_color := Color("#fff6c8")
@export var open_color := Color("#9fe8ff")
const PARTS = preload("res://scenes/bosses/centaurus_parts.tscn")
var _shower_visual: Node2D
var _rain_visual: Node2D
var _parts: Node2D
var _reference_white := 0.0
var _white_material: ShaderMaterial
var _white_sprites: Array[Dictionary] = []
var state := {}
var technique := {}
var _world_clock := -1.0
var _technique_id := 0
var _technique_key := ""
var _released := 0
var _alerting := false
var _leaping := false
var _phase := 1
var _raining := false
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
func frame_event(event: Dictionary) -> void:
	if event.get("type",&"")==&"combat_damage":
		hit = 0.18
		queue_redraw()

## 表示用の値だけを読み、敵表や役者を参照しない。
func apply_frame(body: Dictionary, attack: Dictionary = {}, _appearance: Dictionary = {}) -> void:
	var dt := maxf(0.0,float(body.clock)-_world_clock) if _world_clock>=0.0 else 0.0
	if _leaping and not bool(body.get("leaping",false)): leap_ring = 0.3
	_leaping = bool(body.get("leaping",false))
	if int(body.phase)>_phase: pulse = 0.3
	_phase = int(body.phase)
	var raining: bool = attack.get("technique","")=="rain" and int(attack.get("stage",5))==1
	if raining and not _raining: pulse = 0.3
	_raining = raining
	state = body
	if _technique_id!=int(attack.get("id",0)) or _technique_key!=String(attack.get("technique","")):
		_technique_id = int(attack.get("id",0))
		_technique_key = String(attack.get("technique",""))
		_released = 0
	if _rain_visual==null:
		_rain_visual = preload("res://scripts/render/bosses/centaurus_rain.gd").new()
		add_child(_rain_visual)
	_rain_visual.apply_frame(attack.get("rain",{}) if int(attack.get("stage",5))==1 else {},float(body.clock))
	if _shower_visual==null:
		_shower_visual = preload("res://scripts/render/bosses/centaurus_shower.gd").new()
		add_child(_shower_visual)
	_shower_visual.apply_frame(attack.get("shower",{}) if int(attack.get("stage",5))==1 else {},body)
	if bool(attack.get("alerting",false)) and not _alerting: pulse = 0.3
	_alerting = bool(attack.get("alerting",false))
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
		_create_reference_white()
	hit = maxf(float(body.flash),hit-dt)
	leap_ring = maxf(0.0,leap_ring-dt)
	pulse = maxf(0.0,pulse-dt)
	if int(attack.get("released",0))>_released:
		_parts.release_bow(float(attack.get("interval",0.4)))
		if attack.get("technique","")=="volley" or attack.get("technique","")=="power_shot": pulse = 0.3
		_released = int(attack.released)
	_parts.visible = visible
	_parts.scale = Vector2.ONE*float(body.radius)/135.0
	_parts.position = Vector2.ZERO
	if bool(body.get("leaping",false)):
		var height := sin(PI*float(body.get("leap_progress",0.0)))
		_parts.scale *= 1.0+0.12*height
		_parts.position = Vector2(0.0,-65.0*height).rotated(-global_rotation)
	_parts.set_bow_pose(StringName(technique.get("technique","")),_mode(),float(body.charge),dt,float(technique.get("pose_time",-1.0)))
	_sync_reference_white()
	queue_redraw()

## 同じ進路を本体全体に通し、現在の見た目の入口・出口を返す。
func reference_cut(from: Vector2, direction: Vector2) -> Dictionary:
	if state.is_empty() or _white_sprites.is_empty(): return {}
	return REFERENCE_CUT.cut(_white_sprites, state.position, float(state.radius), from, direction)

## 停止中と停止後の白を、本体の描画とは別の加算層で受ける。
func set_reference_hit(white: float) -> void:
	_reference_white = clampf(white, 0.0, 1.0)
	_sync_reference_white()

func _collect_reference_sprites(node: Node, result: Array[Sprite2D]) -> void:
	for child in node.get_children():
		if child is Sprite2D: result.append(child)
		_collect_reference_sprites(child, result)

func _create_reference_white() -> void:
	_white_material = ShaderMaterial.new()
	_white_material.shader = REFERENCE_WHITE
	var sources: Array[Sprite2D] = []
	_collect_reference_sprites(_parts, sources)
	for source: Sprite2D in sources:
		var overlay := Sprite2D.new()
		overlay.material = _white_material
		overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		source.add_child(overlay)
		_white_sprites.append({"source":source,"overlay":overlay})
	_sync_reference_white()

func _sync_reference_white() -> void:
	if _white_material == null: return
	_white_material.set_shader_parameter("strength", _reference_white)
	for entry: Dictionary in _white_sprites:
		var source: Sprite2D = entry.source
		var overlay: Sprite2D = entry.overlay
		overlay.visible = _reference_white > 0.0 and source.texture != null
		if not overlay.visible: continue
		overlay.texture = source.texture
		overlay.centered = source.centered
		overlay.offset = source.offset
		overlay.flip_h = source.flip_h
		overlay.flip_v = source.flip_v
		overlay.frame = 0
		overlay.hframes = source.hframes
		overlay.vframes = source.vframes
		overlay.frame = source.frame
		overlay.region_enabled = source.region_enabled
		overlay.region_rect = source.region_rect
		overlay.self_modulate.a = source.self_modulate.a

func _mode() -> StringName:
	if technique.get("combo_waiting",false) and int(technique.get("stage",5))<5: return &"combo_gap"
	if state.mode==0: return &"entrance"
	if state.mode==2: return &"phase"
	if state.mode==3: return &"final"
	if state.mode>=4: return &"defeated"
	if state.get("leaping",false): return &"leap"
	if technique.get("technique","")=="sail_run" and int(technique.get("stage",5))==1: return &"sail"
	if technique.get("technique","") in ["rain","shower_chase","shower_wall","shower_path"] and int(technique.get("stage",5))==1: return &"rain"
	if technique.get("technique","") in ["rear_attack","stomp"] and int(technique.get("stage",5))==1: return &"strike"
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
	if _mode()==&"windup" and technique.get("technique","")=="power_shot":
		var mouth: Vector2 = technique.aim_origin
		var color := DANGER if bool(technique.alerting) else WARNING
		for offset in technique.offsets:
			var endpoint := mouth+Vector2.from_angle(float(technique.aim_angle)+offset)*float(technique.travel)
			var contact := Geom.seg_circle_t(mouth,endpoint,technique.ship_position,float(technique.ship_radius))
			if contact>=0.0: endpoint = mouth.lerp(endpoint,contact)
			var from := to_local(mouth)
			var end := to_local(endpoint)
			draw_line(from,end,Color(color,0.12),8.0)
			draw_line(from,end,Color(color,0.95 if bool(technique.alerting) else 0.6),2.0)
			draw_line(from,end,Color(1.0,0.75 if bool(technique.alerting) else 0.95,0.6,0.8),0.8)
	if technique.get("technique","")=="stomp" and int(technique.get("stage",5))<2:
		var points := PackedVector2Array([to_local(technique.center)])
		for i in 25: points.append(to_local(technique.center+Vector2.from_angle(float(state.facing)+lerpf(-float(technique.half_angle),float(technique.half_angle),i/24.0))*float(technique.range_radius)))
		var style := EFFECT_SETTINGS.resolved_values("boss/move/centaurus/stomp","res://scenes/bosses/centaurus/stomp_visual.tscn")
		draw_colored_polygon(points,Color(DANGER if int(technique.stage)==1 else WARNING,float(style.get("attack_opacity",0.28)) if int(technique.stage)==1 else float(style.get("warning_opacity",0.12))))
		if int(technique.stage)==1:
			var grow := clampf(float(technique.pose_time)/maxf(float(technique.active_duration),0.001),0.0,1.0)
			draw_arc(to_local(technique.center),float(technique.range_radius)*grow,-float(technique.half_angle),float(technique.half_angle),24,DANGER,float(style.get("line_width",3.0)))
	if technique.get("technique","")=="fan_volley" and _mode()==&"windup":
		LIGHT_ARROW.draw_arrow(self,to_local(technique.bow_mouth),0.0,10.0+float(state.charge)*6.0,false,float(state.clock))
	var r := float(state.radius)
	var k := r / 90.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * k)
	var tint := Color(1.6, 1.6, 1.6) if hit > 0.0 else Color.WHITE
	if technique.get("technique","")=="rear_attack" and int(technique.get("stage",5))<2:
		var blink := 1.0 if technique.stage==1 else 0.5+0.5*sin(float(state.clock)*TAU*6.0)
		tint = Color.WHITE.lerp(REAR_GLOW,blink)
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
	if _mode()==&"windup" and technique.get("technique","") in ["volley","rear_attack","rain","power_shot"]:
		var pull := Vector2(62.0+cos(1.1)*26.0-float(state.charge)*34.0,0.0)
		var power: bool = technique.get("technique","")=="power_shot"
		var glow := DANGER if bool(technique.get("alerting",false)) else WARNING
		draw_line(pull,pull+Vector2(70.0 if power else 56.0,0.0),glow,pixel_size*(3.0 if power else 1.5))
	draw_set_transform(Vector2.ZERO)
