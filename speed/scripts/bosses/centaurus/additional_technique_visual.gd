## 追加技の仮表示。円と扇は戦闘処理と同じ中心・半径・角度・世界時刻から描く。
extends Node2D
@export var technique_id: StringName
var visual_kind: StringName
var actor: CentaurusBoss
const GOLD := Color("#f2b567")
const RED := Color("#ff667d")
const ARROW := preload("res://scripts/render/attacks/light_arrow.gd")

func update_technique() -> void:
	top_level = true
	global_transform = Transform2D.IDENTITY

func _draw() -> void:
	if actor == null or not actor.has_body() or actor.technique != technique_id: return
	var r := actor.rule()
	if visual_kind == &"arrow_shower":
		_draw_shower(r)
	elif visual_kind == &"stomp" and actor.mode in [&"windup", &"strike"]:
		# 動作の見た目は未決。仮表示。
		var center := actor.stomp_center()
		var angle := actor.table.facing[actor.body]
		var half := deg_to_rad(float(r.half_angle))
		var radius := float(r.range_radius)
		var points := PackedVector2Array([center])
		for j in 25: points.append(center + Vector2.from_angle(angle - half + half * 2.0 * j / 24.0) * radius)
		draw_colored_polygon(points, Color(RED, 0.12 if actor.mode == &"windup" else 0.28))
		if actor.mode == &"strike":
			var age: float = actor.clock - actor._runner.started_at - float(r.warn)
			draw_arc(center, radius * clampf(age / maxf(float(r.active), 0.001), 0.0, 1.0), angle - half, angle + half, 24, RED, 3.0)
	elif visual_kind == &"fan_volley" and actor.mode == &"windup":
		ARROW.draw_arrow(self, actor.bow_mouth(), actor.table.facing[actor.body], 10.0 + actor.table.charge[actor.body] * 6.0, false, actor.clock)

func _draw_shower(r: Dictionary) -> void:
	if actor.mode != &"rain": return
	for mark: Dictionary in actor._runner.marks:
		var age := actor.clock - float(mark.at)
		var warning := maxf(float(r.mark_time), 0.001)
		var active_age := age - warning
		if age < 0.0 or active_age >= float(r.rain_time): continue
		var center: Vector2 = mark.center
		var radius := float(r.radius)
		draw_arc(center, radius, 0.0, TAU, 32, Color(GOLD, 0.8), 2.0)
		if active_age < 0.0:
			var k := clampf(age / warning, 0.0, 1.0)
			draw_circle(center, radius * lerpf(1.0, 0.15, k), Color(GOLD, lerpf(0.08, 0.35, k)))
			if k >= 0.7:
				for j in 3:
					var target := center + Vector2((j - 1) * radius * 0.45, 0.0)
					_draw_falling_arrow(target, (k - 0.7) / 0.3)
		else:
			draw_circle(center, radius, Color(GOLD, 0.16))
			for j in 3:
				var fall := fposmod(active_age * 4.0 + j * 0.3, 1.0)
				_draw_falling_arrow(center + Vector2((j - 1) * radius * 0.45, 0.0), fall)
			if active_age < 0.3: draw_arc(center, radius * (0.5 + active_age * 2.3), 0.0, TAU, 24, Color(GOLD, 1.0 - active_age / 0.3), 2.0)

func _draw_falling_arrow(target: Vector2, progress: float) -> void:
	var origin := fall_origin(self, target)
	ARROW.draw_arrow(self, origin.lerp(target, progress * progress), (target - origin).angle(), 18.0, false, actor.clock, 1.0, Color.WHITE, 150.0)

## カメラの拡大率・移動・画面サイズに合わせ、画面上端の外を降下の始点にする。
static func fall_origin(canvas: CanvasItem, target: Vector2, minimum_height := 0.0) -> Vector2:
	var transform := canvas.get_canvas_transform()
	var screen := transform * target
	var origin := transform.affine_inverse() * Vector2(screen.x, -160.0)
	var toward := (target - origin).normalized()
	return target - toward * maxf(target.distance_to(origin), minimum_height)
