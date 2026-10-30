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
		# 予兆は着弾前に消し、矢が残る間に追加の予兆を出さない。
		if active_age < 0.0:
			var strength := clampf(age / 0.12, 0.0, 1.0) * clampf(-active_age / 0.15, 0.0, 1.0)
			draw_powder(self, center, radius, age, strength, float(mark.at))
		var fall := warning * 0.3
		if active_age < -fall: continue
		var opacity := 1.0 - clampf((active_age - float(r.linger)) / FADE, 0.0, 1.0)
		if opacity <= 0.0: continue
		for j in _arrow_count:
			var seed := float(mark.at) * 19.7 + center.x * 0.019 + center.y * 0.071
			var target := center + scatter(seed, j) * radius * 0.85
			var origin := fall_origin(self, target)
			var progress := clampf((active_age + fall) / fall, 0.0, 1.0)
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

## 同じ着弾を描き直しても位置は動かさず、範囲内へばらけさせる。
static func scatter(seed: float, index: int) -> Vector2:
	var angle := fposmod(sin(index * 127.1 + seed) * 43758.5453, 1.0) * TAU
	var reach := sqrt(fposmod(sin(index * 269.5 + seed + 3.0) * 21563.734, 1.0))
	return Vector2.from_angle(angle) * reach

## 星と区別できる短く細い金色の光の粉。世界時間で進め、戦闘の乱数は消費しない。
static func draw_powder(canvas: CanvasItem, center: Vector2, radius: float, age: float, strength: float, salt := 0.0) -> void:
	var seed := center.x * 0.019 + center.y * 0.071 + salt
	# 縮小表示でも背景の星より見やすい太さを保つ。矢のような長い筋にはしない。
	var pixel := maxf(1.0, 1.0 / maxf(canvas.get_canvas_transform().x.length(), 0.001))
	for j in 7:
		var q := fposmod(sin(j * 127.1 + seed) * 43758.5453, 1.0)
		var u := fposmod(sin(j * 269.5 + seed + 3.0) * 21563.734, 1.0)
		var cycle := fposmod(age * (0.8 + q * 0.5) + u, 1.0)
		var blink := pow(maxf(0.0, sin(cycle * PI)), 1.5) * strength
		var at := center + scatter(seed, j) * radius * 0.85 - Vector2(0, (1.0 - cycle) * 26.0)
		# 矢じりを持たない短い落下線。縮小時も星より太く、実際の矢より短くする。
		var length := (10.0 + q * 5.0) * pixel
		var tip := at - Vector2(0, length)
		canvas.draw_line(tip, at, Color(0.06, 0.03, 0.01, blink * 0.7), 4.5 * pixel)
		canvas.draw_line(tip, at, Color(GOLD, blink * 0.22), 4.0 * pixel)
		canvas.draw_line(tip, at, Color(1.0, 0.72, 0.28, blink * 0.9), 2.0 * pixel)
