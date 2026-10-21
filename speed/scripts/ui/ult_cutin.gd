## 仮カットインの差し替え口。setup(HeroDef) と set_progress(0..1) を受け取る。
## 正式素材は reward_presentation / HUD の ult_cutin_scene に別の Control シーンを指定する。
extends Control

var _hero: HeroDef
var _progress := 0.0

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
	var gold := Color("#ffdf94")
	gold.a = smoothstep(0.05, 0.45, _progress) * (1.0 - smoothstep(0.8, 1.0, _progress))
	for i in range(0, _hero.links.size(), 2):
		var a := center + (_hero.stars[_hero.links[i]] - bounds.get_center()) * factor
		var b := center + (_hero.stars[_hero.links[i + 1]] - bounds.get_center()) * factor
		var reveal := clampf(_progress * 3.0 - float(i) / _hero.links.size(), 0.0, 1.0)
		draw_line(a, a.lerp(b, reveal), Color(gold, gold.a * 0.18), 8.0, true)
		draw_line(a, a.lerp(b, reveal), gold, 1.5, true)
	for point in _hero.stars:
		var at := center + (point - bounds.get_center()) * factor
		draw_circle(at, 7.0, Color(gold, gold.a * 0.16))
		draw_circle(at, 2.5, Color(1.0, 0.97, 0.83, gold.a))
