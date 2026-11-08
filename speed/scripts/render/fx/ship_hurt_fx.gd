## 機体の被弾を目立たせる演出（仕様書 16）。
##
## 被弾の瞬間：機体を短く白く光らせ、画面の縁を赤く光らせる。
## HPが少ない間：画面の縁を心音に合わせて赤く脈打たせ、機体の後ろから煙と火の粉を出し、心音をループで鳴らす。
## 戦闘の状態は読むだけで、時間は表示の実時間で進める。
extends Node2D

const EDGE_SHADER := preload("res://shaders/ship_hurt_edge.gdshader")
## 被弾直後に機体を白く光らせる時間（実秒）。そのあとは機体の赤（config.ship_hurt_time）に戻る。
const WHITE_TIME := 0.06
## 被弾で画面の縁を赤く光らせる時間（実秒）と、その最大の濃さ。
const FLASH_TIME := 0.28
const FLASH_STRENGTH := 0.75
const FLASH_COLOR := Color(1.0, 0.16, 0.2)
const FLASH_INNER := 0.55
## 被弾の火花。
const SPARK_COUNT := 14
const SPARK_SPEED := 400.0
const SPARK_COLOR := Color(1.0, 0.9, 0.6)
## HPが最大HPのこの割合以下になると、HPが少ない状態の演出を出す。
const LOW_RATIO := 0.3
## HPが少ない間の縁の濃さ。拍のない間の濃さと、拍で足す濃さ。
const LOW_BASE := 0.18
const LOW_BEAT := 0.32
const LOW_COLOR := Color(0.78, 0.0, 0.12)
const LOW_INNER := 0.6
## 心音の2つ目の拍（ドクンの「クン」）が、拍の間隔のどこで鳴るか。
const LOW_SECOND_BEAT := 0.32
## 心音が鳴らないときに縁を脈打たせる間隔（実秒）。
const LOW_FALLBACK_PERIOD := 1.125
const Phase := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.Phase

var _white := 0.0
var _flash := 0.0
var _clock := 0.0
var _low := false
var _overlay: CanvasLayer
var _flash_rect: ColorRect
var _low_rect: ColorRect
var _smoke: CPUParticles2D
var _embers: CPUParticles2D

func setup(world_layer: Node2D) -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 9
	add_child(_overlay)
	_low_rect = _edge_rect(LOW_COLOR, LOW_INNER)
	_flash_rect = _edge_rect(FLASH_COLOR, FLASH_INNER)
	_smoke = _particles(world_layer, 26, 0.9, Color(0.47, 0.47, 0.53, 0.35), true, 12.0, 24.0, 20.0)
	_embers = _particles(world_layer, 5, 0.6, Color(1.0, 0.75, 0.35, 1.0), false, 3.0, 3.0, 40.0)

func _edge_rect(color: Color, inner: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = EDGE_SHADER
	material.set_shader_parameter(&"tint", color)
	material.set_shader_parameter(&"inner", inner)
	material.set_shader_parameter(&"strength", 0.0)
	rect.material = material
	rect.visible = false
	_overlay.add_child(rect)
	return rect

## 煙は柔らかい丸、火の粉は四角い点。大きさは世界の単位の直径。
func _particles(parent: Node2D, amount: int, lifetime: float, color: Color, soft: bool, size_min: float, size_max: float, speed: float) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.emitting = false
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 0.0
	particles.initial_velocity_max = speed
	particles.damping_min = speed*0.5
	particles.damping_max = speed
	var texture_size := 1.0
	if soft:
		var puff := GradientTexture2D.new()
		puff.width = 16
		puff.height = 16
		puff.fill = GradientTexture2D.FILL_RADIAL
		puff.fill_from = Vector2(0.5, 0.5)
		puff.fill_to = Vector2(1.0, 0.5)
		var falloff := Gradient.new()
		falloff.set_color(0, Color.WHITE)
		falloff.set_color(1, Color(1, 1, 1, 0))
		puff.gradient = falloff
		particles.texture = puff
		texture_size = 16.0
	particles.scale_amount_min = size_min/texture_size
	particles.scale_amount_max = size_max/texture_size
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.6))
	grow.add_point(Vector2(1.0, 1.4))
	particles.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	particles.color_ramp = fade
	parent.add_child(particles)
	return particles

## 被弾したときに呼ぶ。火花は呼び出し側の火花の仕組みで出す。
func hurt() -> void:
	_white = WHITE_TIME
	_flash = FLASH_TIME

## 機体の白い光の強さ（0〜1）。
func white_strength() -> float:
	return 1.0 if _white > 0.0 else 0.0

func clear() -> void:
	_white = 0.0
	_flash = 0.0
	_set_low(false)

func update(ui: Dictionary, dt: float, ship_position: Vector2, ship_visible: bool) -> void:
	var frozen: bool = ui.get("presentation_frozen", not ui.get("input_enabled", true))
	var step := 0.0 if frozen else dt
	# 被弾の光は止まった画面でも引かせ、ポーズや敗北の静止で残さない。
	_white = maxf(0.0, _white - dt)
	_flash = maxf(0.0, _flash - dt)
	_clock += step
	var max_hp := maxf(1.0, float(ui.get("max_hp", 1.0)))
	var hp := float(ui.get("hp", max_hp))
	var low := int(ui.get("phase", -1)) == Phase.Play and hp > 0.0 and hp/max_hp <= LOW_RATIO
	_set_low(low)
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x/maxf(1.0, size.y)
	_apply_edge(_flash_rect, FLASH_STRENGTH*_flash/FLASH_TIME, aspect)
	_apply_edge(_low_rect, LOW_BASE + LOW_BEAT*_beat() if low else 0.0, aspect)
	var heading: Vector2 = ui.get("ship", {}).get("ship_heading", Vector2.UP)
	var rear := ship_position - heading*float(ui.get("ship_radius", 26.0))*0.4
	for particles: CPUParticles2D in [_smoke, _embers]:
		particles.global_position = rear
		particles.emitting = low and ship_visible and not frozen
		particles.speed_scale = 0.0 if frozen else 1.0

func _set_low(low: bool) -> void:
	if low == _low: return
	_low = low
	AudioManager.set_heartbeat(low)

## 心音の拍に合わせた脈の強さ（0〜1）。拍ごとに強く光り、すぐ引く。
func _beat() -> float:
	var phase := AudioManager.heartbeat_phase()
	if phase < 0.0: phase = fposmod(_clock, LOW_FALLBACK_PERIOD)/LOW_FALLBACK_PERIOD
	var pulse := exp(-phase*5.0)
	if phase > LOW_SECOND_BEAT: pulse += 0.6*exp(-(phase - LOW_SECOND_BEAT)*6.0)
	return minf(1.0, pulse)

func _apply_edge(rect: ColorRect, strength: float, aspect: float) -> void:
	rect.visible = strength > 0.001
	if not rect.visible: return
	var material := rect.material as ShaderMaterial
	material.set_shader_parameter(&"strength", strength)
	material.set_shader_parameter(&"aspect", aspect)

func _exit_tree() -> void:
	if _low: AudioManager.set_heartbeat(false)
	_low = false
