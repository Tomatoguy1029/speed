## 尾の予告。形は技が決め、塗りと輪郭はこのシーンで編集する。
extends Polygon2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
@export var base_color := Color(1.0, 0.61, 0.25, 0.12)
@export var progress_color := Color(1.0, 0.66, 0.3, 0.3)
@export var outline_color := Color(1.0, 0.69, 0.36, 0.42)
@export var outline_width := 3.0
var actor: BossActor
var center := Vector2.ZERO

func _ready() -> void:
	EFFECT_SETTINGS.apply_to(self)

func update_technique() -> void:
	var tell := get_node("Telegraph") as Polygon2D
	tell.polygon = PackedVector2Array()
	if actor == null or actor.telegraph_areas.is_empty(): return
	var area: Dictionary = actor.telegraph_areas[0]
	var shape := PackedVector2Array()
	for point in area.polygon: shape.append(actor.to_local(point))
	tell.polygon = shape
	center = actor.to_local(area.center)

func _draw() -> void:
	var shape: PackedVector2Array = get_node("Telegraph").polygon
	if shape.size() < 3 or actor == null: return
	var progress := clampf(actor.elapsed / maxf(0.01, float(actor.rule().warn)), 0.0, 1.0) if actor.mode == &"windup" else 1.0
	draw_colored_polygon(shape, base_color)
	var far := 0.0
	for point in shape: far = maxf(far, point.distance_to(center))
	var circle := PackedVector2Array()
	for j in 64: circle.append(center + Vector2.from_angle(TAU * j / 64.0) * far * progress)
	if progress > 0.0:
		for part in Geometry2D.intersect_polygons(shape, circle): draw_colored_polygon(part, progress_color)
	var outline := outline_color
	outline.a += progress * 0.4
	draw_polyline(shape + PackedVector2Array([shape[0]]), outline, outline_width, false)
