## 光の槍の描画。通常の機体・滑走残光へ独立した層として重ねる。
## ゲーム用の乱数・攻撃判定を持たず、命中イベントも表示だけに使う。
extends Node2D

const SHADER := preload("res://shaders/light_lance.gdshader")
var _body: DrawLayer
var _tail: DrawLayer
var _flash: DrawLayer
var _points: Array[Vector2] = []
var _ages: Array[float] = []
var _hits: Array[Dictionary] = []
var _active := false
var _level := 1
var _head := Vector2.ZERO
var _dir := Vector2.RIGHT
var _scale := 1.0
var _tip := 50.0
var _reach := 24.0
var _clock := 0.0
var _dash := -1

func _ready() -> void:
	_tail = _layer(_draw_tail, 1.0)
	_body = _layer(_draw_body, 0.0)
	_flash = _layer(_draw_hits, 2.0)

func _layer(draw_fn: Callable, mode: float) -> DrawLayer:
	var layer := DrawLayer.new()
	layer.draw_fn = draw_fn
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("mode", mode)
	layer.material = mat
	add_child(layer)
	return layer

func hit(event: Dictionary) -> void:
	_hits.append({"pos": event.pos, "dir": event.dir, "life": 0.13, "max": 0.13, "level": event.level})
	if _hits.size() > 24:
		_hits.pop_front()

func step(dt: float, state: RunState, cfg: GameConfig, weapon, zoom: float) -> void:
	if dt <= 0.0 or state.hitstop > 0.0:
		return
	_scale = cfg.character_scale
	_head = state.ship_pos
	_dir = state.ship_heading
	_active = weapon != null and state.tracing and state.phase == RunState.Phase.PLAY
	if state.phase not in [RunState.Phase.PLAY, RunState.Phase.FINISHING]:
		_points.clear()
		_ages.clear()
		_hits.clear()
	if weapon == null:
		_points.clear()
		_ages.clear()
		_hits.clear()
	if _active:
		_level = weapon.level
		_tip = weapon.reach() / _scale
		_reach = weapon.level_value("tail_by_level") * _scale
		if _dash != state.dash_id:
			_points.clear()
			_ages.clear()
			_dash = state.dash_id
	_clock += dt
	for i in _ages.size():
		_ages[i] += dt
	while not _ages.is_empty() and _ages[0] > 0.24:
		_ages.pop_front()
		_points.pop_front()
	if _active:
		var back := _head - _dir * 30.0 * _scale
		if not _points.is_empty() and back.distance_to(_points.back()) > maxf(_reach * 2.0, state.ship_vel.length() * dt * 3.0):
			_points.clear()
			_ages.clear()
		if _points.is_empty() or back.distance_to(_points.back()) >= _scale:
			_points.append(back)
			_ages.append(0.0)
			if _points.size() > 64:
				_points.pop_front()
				_ages.pop_front()
	for effect in _hits:
		effect.life -= dt
	_hits = _hits.filter(func(effect): return effect.life > 0.0)
	for layer in [_body, _tail, _flash]:
		var mat := layer.material as ShaderMaterial
		mat.set_shader_parameter("clock", _clock)
		mat.set_shader_parameter("pixel", maxf(1.0, 2.0 / maxf(zoom * _scale, 0.01)))
		mat.set_shader_parameter("level", float(_level))
		layer.queue_redraw()
	var body_mat := _body.material as ShaderMaterial
	body_mat.set_shader_parameter("extent", Vector2(_tip + 42.0, 64.0))
	body_mat.set_shader_parameter("left_edge", -42.0)
	body_mat.set_shader_parameter("tip", _tip)
	for layer in [_tail, _flash]:
		var mat := layer.material as ShaderMaterial
		mat.set_shader_parameter("extent", Vector2(128.0, 32.0))
		mat.set_shader_parameter("left_edge", 0.0)
		mat.set_shader_parameter("tip", 128.0)

func _quad(c: CanvasItem, rect: Rect2, alpha: float) -> void:
	c.draw_primitive(PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end,
		rect.position + Vector2(0, rect.size.y)]), PackedColorArray([Color(1, 1, 1, alpha)]),
		PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]))

func _draw_body(c: CanvasItem) -> void:
	if not _active:
		return
	c.draw_set_transform(_head, _dir.angle(), Vector2.ONE * _scale)
	_quad(c, Rect2(-42, -32, _tip + 42, 64), 1.0)
	c.draw_set_transform(Vector2.ZERO)

func _draw_tail(c: CanvasItem) -> void:
	var distance := 0.0
	for i in range(_points.size() - 1, 0, -1):
		var front := _points[i]
		var back := _points[i - 1]
		var length := front.distance_to(back)
		if length < 0.01 or distance >= _reach:
			continue
		back = front.lerp(back, minf(1.0, (_reach - distance) / length))
		length = front.distance_to(back)
		var alpha := (1.0 - distance / maxf(_reach, 1.0)) * (1.0 - _ages[i] / 0.24)
		c.draw_set_transform(front, (back - front).angle(), Vector2.ONE * _scale)
		_quad(c, Rect2(0, -16, length / _scale, 32), alpha * (0.5 if _level < 3 else 0.85))
		distance += length
	c.draw_set_transform(Vector2.ZERO)

func _draw_hits(c: CanvasItem) -> void:
	for effect in _hits:
		var alpha: float = effect.life / effect.max
		var length := 28.0 if effect.level < 5 else 104.0
		c.draw_set_transform(effect.pos, effect.dir.angle(), Vector2.ONE * _scale)
		_quad(c, Rect2(0, -16, length, 32), alpha)
	c.draw_set_transform(Vector2.ZERO)
