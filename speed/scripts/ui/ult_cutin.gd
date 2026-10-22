## 仮カットインの差し替え口。setup(HeroDef) と set_progress(0..1) を受け取る。
## 正式素材は reward_presentation / HUD の ult_cutin_scene に別の Control シーンを指定する。
extends Control

var _hero: HeroDef
var _progress := 0.0
const PIXEL := 1.25 # 800×450 の差し替え座標で、HUDの1画素に相当する幅。

func setup(definition: HeroDef) -> void:
	_hero = definition

func set_progress(value: float) -> void:
	_progress = value
	($Light.material as ShaderMaterial).set_shader_parameter("progress", value)
	queue_redraw()

func _draw() -> void:
	if _hero == null or _hero.stars.is_empty():
		return
	var bounds := Rect2(_hero.stars[0], Vector2.ZERO)
	for point in _hero.stars:
		bounds = bounds.expand(point)
	var factor := 190.0 / maxf(1.0, maxf(bounds.size.x, bounds.size.y))
	var center := Vector2(400, 220)
	var gold := Color("#efcb70")
	gold.a = floorf(smoothstep(0.05, 0.45, _progress) * (1.0 - smoothstep(0.8, 1.0, _progress)) * 4.0) / 4.0
	for i in range(0, _hero.links.size(), 2):
		var a := center + (_hero.stars[_hero.links[i]] - bounds.get_center()) * factor
		var b := center + (_hero.stars[_hero.links[i + 1]] - bounds.get_center()) * factor
		var reveal := clampf(_progress * 3.0 - float(i) / _hero.links.size(), 0.0, 1.0)
		_pixel_line(a, a.lerp(b, reveal), gold)
	for point in _hero.stars:
		var at := ((center + (point - bounds.get_center()) * factor) / PIXEL).round() * PIXEL
		draw_rect(Rect2(at - Vector2(4, 1) * PIXEL, Vector2(9, 3) * PIXEL), Color(gold, gold.a * 0.4))
		draw_rect(Rect2(at - Vector2(1, 4) * PIXEL, Vector2(3, 9) * PIXEL), Color(gold, gold.a * 0.4))
		draw_rect(Rect2(at - Vector2.ONE * PIXEL, Vector2.ONE * PIXEL * 3.0), Color(Color("#d5dbea"), gold.a))

func _pixel_line(from: Vector2, to: Vector2, color: Color) -> void:
	var start := (from / PIXEL).round()
	var end := (to / PIXEL).round()
	var steps := maxi(1, int(maxf(absf(end.x - start.x), absf(end.y - start.y))))
	for i in range(steps + 1):
		var point := start.lerp(end, float(i) / steps).round() * PIXEL
		draw_rect(Rect2(point, Vector2.ONE * PIXEL), color)
