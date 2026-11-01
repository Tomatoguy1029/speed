## 速度計の表示だけを更新する。ゲームの速度・乱数・時計から独立した慣性を持つ。
extends Control

enum { NORMAL, FAST, BOOST }
const METER := preload("res://assets/ui/combat/speed_indicator_meter.png")
const NEEDLE := preload("res://assets/ui/combat/speed_indicator_needle.png")
const FILL_SHADER := preload("res://assets/ui/combat/speed_indicator_fill.gdshader")
const NEEDLE_MIN := -87.0 * PI / 180.0
const NEEDLE_MAX := -10.0 * PI / 180.0
const NEEDLE_PIVOT := Vector2(6.5, 36.5)
const NORMAL_COLOR := Color("#5fcde4")
const FAST_COLOR := Color("#dad688")
const BOOST_COLOR := Color("#da5c60")
const STEP := 1.0 / 200.0

var value := 1.45
var fill_color := NORMAL_COLOR
var rng := RandomNumberGenerator.new()
var _mode := NORMAL
var _velocity := 0.0
var _remainder := 0.0
var _goal_from := 1.45
var _goal := 1.9
var _goal_time := 0.0
var _goal_duration := 1.15
var _color_from := NORMAL_COLOR
var _color_value_from := 1.45
var _color_finish := 1.6
var _color_progress := 1.0
var _fill_material := ShaderMaterial.new()

func _init() -> void:
	show_behind_parent = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fill_material.shader = FILL_SHADER
	_fill_material.set_shader_parameter("fill_color", fill_color)
	material = _fill_material

func advance(mode: int, delta: float) -> void:
	if delta <= 0.0:
		return
	if mode != _mode:
		_mode = mode
		_goal_from = value
		_goal = 7.75 if mode == BOOST else 5.3 if mode == FAST else 1.5
		_goal_time = 0.0
		_goal_duration = 2.0 if mode == FAST else 2.2
		_color_from = fill_color
		_color_value_from = value
		_color_finish = lerpf(value, _goal, 0.96 if mode == BOOST else 0.84 if mode == FAST else 0.97)
		_color_progress = 0.0
	# 固定刻みで目標の切替・慣性・色を一緒に進め、描画FPSによる差を避ける。
	_remainder += delta
	while _remainder + 0.000000001 >= STEP:
		_step()
		_remainder = maxf(0.0, _remainder - STEP)
	_fill_material.set_shader_parameter("fill_color", fill_color)
	queue_redraw()

func _step() -> void:
	var target := 7.75
	if _mode != BOOST:
		_goal_time += STEP
		if _goal_time >= _goal_duration:
			_goal_time -= _goal_duration
			_goal_from = _goal
			_goal = rng.randf_range(4.7, 5.6) if _mode == FAST else rng.randf_range(1.1, 1.98)
			_goal_duration = rng.randf_range(1.1, 1.5)
		target = lerpf(_goal_from, _goal, _ease(_goal_time / _goal_duration))
	var omega := 7.0 if _mode == BOOST else 4.2 if _mode == FAST else 5.2
	_velocity += (omega * omega * (target - value) - 2.0 * omega * _velocity) * STEP
	value += _velocity * STEP
	var distance := _color_finish - _color_value_from
	var progress := (value - _color_value_from) / distance if absf(distance) > 0.05 else 1.0
	_color_progress = maxf(_color_progress, _ease(progress))
	var target_color := FAST_COLOR if _mode == FAST else NORMAL_COLOR
	if _mode == BOOST:
		# 水色の緑・青を先に引いて、赤への遷移途中の灰色・桃色の濁りを抑える。
		var cool := 1.0 - pow(1.0 - _color_progress, 2.0)
		target_color = Color(lerpf(_color_from.r, BOOST_COLOR.r, _color_progress),
				lerpf(_color_from.g, BOOST_COLOR.g, cool), lerpf(_color_from.b, BOOST_COLOR.b, cool))
	else:
		target_color = _color_from.lerp(target_color, _color_progress)
	fill_color = fill_color.lerp(target_color, 1.0 - exp(-10.0 * STEP))

func _ease(amount: float) -> float:
	var k := clampf(amount, 0.0, 1.0)
	return k * k * k * (10.0 + k * (-15.0 + 6.0 * k))

func _draw() -> void:
	draw_texture(METER, Vector2.ZERO)
	var angle := lerpf(NEEDLE_MIN, NEEDLE_MAX, clampf(value / 8.0, 0.0, 1.0))
	draw_set_transform(METER.get_size(), angle)
	draw_texture(NEEDLE, -NEEDLE_PIVOT)
