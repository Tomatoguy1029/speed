## W26の編隊と実際の並走経路を描く。白い芯・青緑の段階発光・角のある光片。
extends Node2D

const DRONE := preload("res://assets/pixel/drone.png")
var _weapon: WeaponBehavior
var _scale := 1.0
var _pixel := 2.0

func step(weapon: WeaponBehavior, cfg: GameConfig, zoom: float) -> void:
	_weapon = weapon
	_scale = cfg.character_scale
	_pixel = maxf(_scale * 2.0, 2.0 / maxf(zoom, 0.01))
	queue_redraw()

func _draw() -> void:
	if _weapon == null:
		return
	var cyan := Color(0.35, 1.6, 1.9)
	for d in _weapon.drones:
		var points: Array = d.trail
		var remaining: float = _weapon.level_value("tail_by_level") * _scale
		for i in range(points.size() - 1, 0, -1):
			if not points[i].join:
				continue
			var a: Vector2 = points[i].pos
			var b: Vector2 = points[i - 1].pos
			var distance := a.distance_to(b)
			if distance < 0.01:
				continue
			b = a.move_toward(b, minf(distance, remaining))
			var alpha: float = clampf(points[i].life / 0.22, 0.0, 1.0) * minf(1.0, remaining / (30.0 * _scale))
			draw_line(a, b, Color(cyan, alpha * 0.12), _pixel * (4.0 + _weapon.level * 0.4), false)
			draw_line(a, b, Color(cyan, alpha * 0.6), _pixel * 2.2, false)
			draw_line(a, b, Color(1.8, 2.1, 2.2, alpha), _pixel, false)
			if i % 3 == 0:
				var chip := b + Vector2(-d.dir.y, d.dir.x) * _pixel * (3 if i % 2 else -3)
				draw_rect(Rect2(chip.snapped(Vector2.ONE * _pixel), Vector2.ONE * _pixel), Color(cyan, alpha * 0.65))
			remaining -= distance
			if remaining <= 0.0:
				break
		var dir: Vector2 = d.dir
		draw_set_transform(d.pos, dir.angle() + PI / 2.0, Vector2.ONE * _scale)
		var size := DRONE.get_size()
		draw_texture_rect(DRONE, Rect2(-size / 2.0, size), false, Color(0.9, 1.1, 1.15))
		# 機体の両翼・後部エンジンを四角い画素で強調し、点ではなく機体に見せる。
		var boost := 1.0 if _weapon.active else 0.28
		draw_rect(Rect2(-8, -1, 4, 3), Color(0.4, 1.5, 1.8, boost))
		draw_rect(Rect2(4, -1, 4, 3), Color(0.4, 1.5, 1.8, boost))
		draw_rect(Rect2(-2, 8, 4, 5 if _weapon.active else 2), Color(1.6, 2.0, 2.1, boost))
		draw_set_transform(Vector2.ZERO)
