## 尾の予告。形は技が決め、塗りと輪郭はこのシーンで編集する。
extends Polygon2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
@export var base_color := Color(1.0, 0.61, 0.25, 0.12)
@export var progress_color := Color(1.0, 0.66, 0.3, 0.3)
@export var outline_color := Color(1.0, 0.69, 0.36, 0.42)
@export var outline_width := 3.0
var center := Vector2.ZERO

func _ready() -> void:
	EFFECT_SETTINGS.apply_to(self)
