## 突進と滑走の残光。移動履歴と実速度を読むだけで、機体の運動は変えない。
extends Node2D

## 長さ・太さは character_scale を掛ける前の世界単位。
@export_range(20.0, 300.0, 1.0) var max_length := 150.0
@export_range(2.0, 40.0, 0.5) var half_width := 18.0
@export_range(0.05, 0.5, 0.01) var persistence := 0.20
@export_range(0.0, 1.0, 0.01) var opacity := 0.55
@export_range(1.0, 30.0, 0.5) var response := 14.0

var _samples: Array[Vector2] = []
var _ages: Array[float] = []
var _intensity := 0.0
var _clock := 0.0
var _scale := 1.0
var _head := Vector2.ZERO
var _heading := Vector2.UP

func step(dt: float, state: RunState, cfg: GameConfig, sonic: bool) -> void:
	# 残光もポーズ・強化選択・ヒットストップ中は止める。
	if dt <= 0.0 or state.hitstop > 0.0:
		return
	var alive := state.phase == RunState.Phase.PLAY or state.phase == RunState.Phase.FINISHING
	if not alive or state.drawing:
		_samples.clear()
		_ages.clear()
		_intensity = 0.0
		queue_redraw()
		return
	_scale = cfg.character_scale
	_head = state.ship_pos
	_heading = state.ship_heading
	var speed := state.ship_vel.length()
	var cruise := state.stats.max_speed * cfg.steer_cruise
	var excess := clampf((speed - cruise) / maxf(cruise, 1.0), 0.0, 1.0)
	var target := smoothstep(0.0, 1.0, excess) if state.tracing or state.glide else 0.0
	_intensity = lerpf(_intensity, target, 1.0 - exp(-response * dt))
	_clock += dt * lerpf(0.4, 1.8, excess)
	for i in _ages.size():
		_ages[i] += dt
	while not _ages.is_empty() and _ages[0] >= persistence:
		_ages.pop_front()
		_samples.pop_front()
	var tail := _head - _heading * 20.0 * _scale
	if not _samples.is_empty() and tail.distance_to(_samples.back()) > maxf(max_length * _scale * 2.0, speed * dt * 3.0):
		_samples.clear()
		_ages.clear()
	if _intensity > 0.001 and (_samples.is_empty() or tail.distance_to(_samples.back()) > _scale):
		_samples.append(tail)
		_ages.append(0.0)
		if _samples.size() > 48:
			_samples.pop_front()
			_ages.pop_front()
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("flow_time", _clock)
	mat.set_shader_parameter("sonic", sonic)
	queue_redraw()

func _draw() -> void:
	if _intensity < 0.001:
		return
	var reach := max_length * _scale * sqrt(_intensity)
	var width := half_width * _scale * lerpf(0.3, 1.0, _intensity)
	var distance := 0.0
	# 実際に通った場所へ帯を置き、隣接点の向きで両端をそろえて旋回時も帯をつなぐ。
	for i in range(_samples.size() - 1, 0, -1):
		var head := _samples[i]
		var back := _samples[i - 1]
		var segment := head.distance_to(back)
		if segment < 0.01 or distance >= reach:
			continue
		back = head.lerp(back, minf(1.0, (reach - distance) / segment))
		segment = head.distance_to(back)
		if segment < 0.25 * _scale:
			break
		var normal := (_samples[mini(i + 1, _samples.size() - 1)] - _samples[i - 1]).normalized().orthogonal()
		var back_normal := (_samples[i] - _samples[maxi(0, i - 2)]).normalized().orthogonal()
		back_normal = normal.lerp(back_normal, segment / head.distance_to(_samples[i - 1])).normalized()
		var u0 := distance / reach
		var u1 := (distance + segment) / reach
		var w0 := width * (1.0 - u0 * 0.8)
		var w1 := width * (1.0 - u1 * 0.8)
		var a0 := _intensity * opacity * pow(1.0 - _ages[i] / persistence, 1.5)
		var a1 := _intensity * opacity * pow(1.0 - _ages[i - 1] / persistence, 1.5)
		draw_primitive(PackedVector2Array([head + normal * w0, back + back_normal * w1, back - back_normal * w1, head - normal * w0]),
			PackedColorArray([Color(1, 0, 0, a0), Color(1, 0, 0, a1), Color(1, 0, 0, a1), Color(1, 0, 0, a0)]),
			PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)]))
		distance += segment
	# 機体の輪郭を覆わず、両脇から後方へ流れる薄い圧縮光。
	draw_set_transform(_head, _heading.angle())
	var r := Rect2(Vector2(-52, -30) * _scale, Vector2(86, 60) * _scale)
	draw_primitive(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]),
		PackedColorArray([Color(1, 0, 1, _intensity * opacity)]),
		PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))
	draw_set_transform(Vector2.ZERO)
