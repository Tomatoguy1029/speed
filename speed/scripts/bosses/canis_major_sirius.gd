## 星の画像は拡大せず、世界時間で明滅・向きの揺れ・同じ粒度の光粒を動かす。
extends Node2D
const STAR = preload("res://assets/pixel/canis_major/star.png")
const LARGE = preload("res://assets/pixel/canis_major/large_star.png")
var clock := 0.0
var strength := 0.0
var charge := 0.0
var pulse := 0.0
func set_state(time: float, phase_strength: float, windup: float, flash: float) -> void:
	clock = time
	strength = phase_strength
	charge = windup
	pulse = flash
	queue_redraw()
func _draw() -> void:
	# A slow beat with occasional brief wavering, rather than continuous spinning.
	var beat := fmod(clock, 3.8)
	var flutter := sin(clampf((beat - 1.6) / 0.9, 0.0, 1.0) * PI)
	var angle := deg_to_rad(roundf((sin(clock * 2.1) * 2.0 + sin(clock * 8.0) * flutter * 4.0) * 2.0) * 0.5)
	var light: float = [0.82, 1.0, 1.12, 1.0][int(clock * 5.0) % 4]
	var large_alpha := clampf(strength * 0.75 + charge * 0.7 + pulse * 1.5 + flutter * 0.22, 0.0, 0.95)
	# Discrete brightness steps keep the two authored silhouettes readable.
	large_alpha = floorf(large_alpha * 4.0) / 4.0
	draw_set_transform(Vector2.ZERO, angle * -0.65)
	if large_alpha > 0.0:
		draw_texture(LARGE, -LARGE.get_size() * 0.5 + Vector2(0, 1), Color(1, 1, 1, large_alpha))
	draw_set_transform(Vector2.ZERO, angle)
	draw_texture(STAR, -STAR.get_size() * 0.5 + Vector2(0.5, -0.5), Color(light, light, light))
	draw_set_transform(Vector2.ZERO)
	var count := 6 if strength < 0.5 else 10
	for i in count:
		var life := fposmod(clock * 0.55 + i * 0.618, 1.0)
		var direction := Vector2.from_angle(i * 2.399 + sin(clock * 0.6 + i) * 0.18)
		var radius := lerpf(9.0, 26.0 + strength * 8.0, 1.0 - life if charge > 0.25 else life)
		var at := (direction * radius).snapped(Vector2.ONE)
		var color := Color("#fff1db") if life < 0.25 else Color("#ffa3a3") if life < 0.6 else Color("#c64450")
		color.a = 0.85 if life < 0.6 else 0.45
		var side := 2.0 if i % 3 == 0 else 1.0
		draw_rect(Rect2(at, Vector2.ONE * side), color)
