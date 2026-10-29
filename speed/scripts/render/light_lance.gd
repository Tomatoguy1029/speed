## T06の発動時だけ、白金色のピクセル調の槍を攻撃線に沿って飛ばす。
## 攻撃判定と乱数を持たず、既存の即時命中を視覚化する。
extends Node2D

const SHADER := preload("res://shaders/light_lance.gdshader")
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
const FLIGHT_TIME := 0.18
## 到達した槍を少し保ってから消す。攻撃は発動時に即時判定済み。
const HOLD_TIME := 0.18
const FADE_TIME := 0.14
const FADE_START := FLIGHT_TIME + HOLD_TIME
const TIP := 168.0
const BODY_LENGTH := TIP + 42.0
var shots: Array[Dictionary] = []
var _body: DrawLayer
var _tail: DrawLayer
var _scale := 1.0
var silhouette := false

func _ready() -> void:
	_tail = _layer(_draw_tail, 1.0)
	_body = _layer(_draw_body, 0.0)

func _layer(draw_fn: Callable, mode: float) -> DrawLayer:
	var layer := DrawLayer.new()
	layer.draw_fn = draw_fn
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("level", 5.0)
	mat.set_shader_parameter("extent", Vector2(BODY_LENGTH, 64.0) if mode == 0.0 else Vector2(128, 32))
	mat.set_shader_parameter("left_edge", -42.0 if mode == 0.0 else 0.0)
	mat.set_shader_parameter("tip", TIP if mode == 0.0 else 128.0)
	layer.material = mat
	add_child(layer)
	return layer

func fire(event: Dictionary) -> void:
	shots.append({"from": event.from, "to": event.to, "width": event.width, "age": 0.0})

func step(dt: float, character_scale: float, zoom: float) -> void:
	_scale = character_scale
	for shot in shots:
		shot.age += dt
	shots = shots.filter(func(shot): return shot.age < FADE_START + FADE_TIME)
	for layer in [_body, _tail]:
		var mat := layer.material as ShaderMaterial
		mat.set_shader_parameter("clock", shots.back().age if not shots.is_empty() else 0.0)
		mat.set_shader_parameter("pixel", 1.82 * EFFECT_SETTINGS.number("trait/critBeam", "pixel_scale", 1.0))
		mat.set_shader_parameter("silhouette", silhouette)
		layer.queue_redraw()

## 図鑑も同じshaderと飛行を使い、未入手なら静止したシルエットにする。
func preview(from: Vector2, to: Vector2, age: float, known: bool) -> void:
	silhouette = not known
	shots = [{"from": from, "to": to, "width": 24.0, "age": age}]
	step(0.0, 0.65, 1.0)

func _quad(c: CanvasItem, rect: Rect2, alpha: float) -> void:
	c.draw_primitive(PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end,
		rect.position + Vector2(0, rect.size.y)]), PackedColorArray([Color(1, 1, 1, alpha)]),
		PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]))

func _draw_body(c: CanvasItem) -> void:
	for shot in shots:
		var delta: Vector2 = shot.to - shot.from
		var progress := minf(1.0, shot.age / FLIGHT_TIME)
		var length := minf(BODY_LENGTH * _scale, delta.length() * progress)
		if length <= 0.0:
			continue
		var scale := Vector2(length / BODY_LENGTH, float(shot.width) / 39.0)
		var head: Vector2 = shot.from + delta * progress
		var alpha := 1.0 - clampf((shot.age - FADE_START) / FADE_TIME, 0.0, 1.0)
		c.draw_set_transform(head - delta.normalized() * TIP * scale.x, delta.angle(), scale)
		_quad(c, Rect2(-42, -32, BODY_LENGTH, 64), alpha)
	c.draw_set_transform(Vector2.ZERO)

func _draw_tail(c: CanvasItem) -> void:
	for shot in shots:
		var delta: Vector2 = shot.to - shot.from
		var traveled := delta.length() * minf(1.0, shot.age / FLIGHT_TIME)
		var body := minf(BODY_LENGTH * _scale, traveled)
		var length := minf(140.0 * _scale, traveled - body)
		if length <= 0.0:
			continue
		var head: Vector2 = shot.from + delta.normalized() * (traveled - body)
		var alpha := 1.0 - clampf((shot.age - FADE_START) / FADE_TIME, 0.0, 1.0)
		c.draw_set_transform(head, (-delta).angle(), Vector2(length / 128.0, _scale))
		_quad(c, Rect2(0, -16, 128, 32), alpha * 0.85)
	c.draw_set_transform(Vector2.ZERO)
