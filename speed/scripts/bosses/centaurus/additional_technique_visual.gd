## 追加技の仮表示。円と扇は戦闘処理と同じ中心・半径・角度・世界時刻から描く。
extends Node2D
@export_range(0.5, 12.0, 0.25) var line_width := 3.0
@export_range(0.0, 0.5, 0.01) var warning_opacity := 0.12
@export_range(0.0, 1.0, 0.01) var attack_opacity := 0.28
@export var technique_id: StringName
var visual_kind: StringName
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
		var variation := fposmod(sin(j * 91.7 + seed + 8.0) * 19463.17, 1.0)
		var blink := pow(maxf(0.0, sin(cycle * PI)), 2.0 + variation * 2.0) * strength
		var at := center + scatter(seed, j) * radius * 0.85 - Vector2(0, (1.0 - cycle) * 26.0)
		# 粒ごとに長さ・太さ・輝きを変え、尾へ向けて細く薄くする。
		var length := (5.0 + q * 10.0) * pixel
		var width := (0.65 + u * 0.8) * pixel
		var opacity := blink * (0.25 + variation * 0.35)
		var tail := at - Vector2((u - 0.5) * 2.0 * pixel, length)
		for segment in 4:
			var f := float(segment + 1) / 4.0
			var a := tail.lerp(at, float(segment) / 4.0)
			var b := tail.lerp(at, f)
			canvas.draw_line(a, b, Color(GOLD, opacity * f * f), width * (0.3 + f * 0.7), true)
