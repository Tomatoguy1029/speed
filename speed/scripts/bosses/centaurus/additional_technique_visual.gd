## 追加技の仮表示。円と扇は戦闘処理と同じ中心・半径・角度・世界時刻から描く。
extends Node2D
@export var technique_id: StringName
var visual_kind: StringName
var actor: CentaurusBoss
var _marks: Array[Dictionary] = []
var _shower_rule := {}
var _arrow_count := 2
var retained: bool:
	get: return not _marks.is_empty()
const FADE := 0.15
const WAVE_INTERVAL := 0.65
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
const GOLD := Color("#f2b567")
const RED := Color("#ff667d")
const ARROW := preload("res://scripts/render/attacks/light_arrow.gd")

func update_technique() -> void:
	top_level = true
	global_transform = Transform2D.IDENTITY
	if not actor.body_alive() or actor.mode in [&"final", &"defeated"]:
		_marks.clear()
		return
	if actor.technique == technique_id and visual_kind == &"arrow_shower" and actor.mode == &"rain":
		_marks = actor._runner.marks.duplicate()
		_shower_rule = actor.rule()
		_arrow_count = 2 if actor.phase == 1 else 3
	if not _shower_rule.is_empty():
		_marks = _marks.filter(func(mark): return actor.clock < float(mark.at) + float(_shower_rule.mark_time) + float(_shower_rule.rain_time) + float(_shower_rule.linger) + FADE)

func _draw() -> void:
	if actor == null or not actor.has_body(): return
	if visual_kind == &"arrow_shower":
		if not _shower_rule.is_empty(): _draw_shower(_shower_rule)
		return
	if actor.technique != technique_id: return
	var r := actor.rule()
	if visual_kind == &"stomp" and actor.mode in [&"windup", &"strike"]:
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
	for mark: Dictionary in _marks:
		var age := actor.clock - float(mark.at)
		var warning := maxf(float(r.mark_time), 0.001)
		var active_age := age - warning
		if age < 0.0: continue
		var center: Vector2 = mark.center
		var radius := float(r.radius)
		if active_age < float(r.rain_time):
			draw_arc(center, radius, 0.0, TAU, 32, Color(GOLD, 0.8), 2.0)
			if active_age < 0.0:
				var k := clampf(age / warning, 0.0, 1.0)
				draw_circle(center, radius * lerpf(1.0, 0.15, k), Color(GOLD, lerpf(0.08, 0.35, k)))
			else:
				draw_circle(center, radius, Color(GOLD, 0.16))
				if active_age < 0.3: draw_arc(center, radius * (0.5 + active_age * 2.3), 0.0, TAU, 24, Color(GOLD, 1.0 - active_age / 0.3), 2.0)
		# 各波の着弾後も同じ位置へ残す。残った矢には当たり判定を追加しない。
		var fall := warning * 0.3
		var last_wave := maxi(0, ceili(float(r.rain_time) / WAVE_INTERVAL) - 1)
		for wave in range(maxi(0, floori((active_age - float(r.linger) - FADE) / WAVE_INTERVAL)), mini(last_wave, floori((active_age + fall) / WAVE_INTERVAL)) + 1):
			var landed_age := active_age - wave * WAVE_INTERVAL
			var opacity := 1.0 - clampf((landed_age - float(r.linger)) / FADE, 0.0, 1.0)
			if opacity <= 0.0: continue
			for j in _arrow_count:
				var target := center + Vector2((j - (_arrow_count - 1) * 0.5) * radius * 0.6, 0.0)
				var origin := fall_origin(self, target)
				var progress := clampf((landed_age + fall) / fall, 0.0, 1.0)
				draw_rain_arrow(self, actor, origin.lerp(target, progress * progress), (target - origin).angle(), opacity)

## 扇状連射と同じ描画・寸法・色を使う。
static func draw_rain_arrow(canvas: CanvasItem, owner_actor: CentaurusBoss, at: Vector2, angle: float, opacity: float) -> void:
	var fan: Dictionary = owner_actor._rules[&"fan_volley"]
	var scene: PackedScene = fan.get("shot_visual")
	var tint: Color = EFFECT_SETTINGS.values_for(scene.resource_path).get("effect_tint", Color.WHITE) if scene != null else Color.WHITE
	ARROW.draw_arrow(canvas, at, angle, float(fan.radius), false, owner_actor.clock, opacity, tint, float(fan.length))

## カメラの拡大率・移動・画面サイズに合わせ、画面上端の外を降下の始点にする。
static func fall_origin(canvas: CanvasItem, target: Vector2, minimum_height := 0.0) -> Vector2:
	var transform := canvas.get_canvas_transform()
	var screen := transform * target
	var origin := transform.affine_inverse() * Vector2(screen.x, -160.0)
	var toward := (target - origin).normalized()
	return target - toward * maxf(target.distance_to(origin), minimum_height)
