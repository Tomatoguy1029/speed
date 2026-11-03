## 技の予告・攻撃線・着弾。各技のシーンが表示の値と追加描画を持つ。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
@export var technique_id: StringName
var visual_kind: StringName
@export var keep_visible := false
@export_range(0.5, 12.0, 0.25) var telegraph_line_width := 3.0
@export_range(0.5, 12.0, 0.25) var active_line_width := 4.0
@export_range(0.0, 0.5, 0.01) var telegraph_fill_opacity := 0.12
@export_range(0.0, 0.8, 0.01) var telegraph_progress_opacity := 0.3
@export_range(0.0, 0.6, 0.01) var telegraph_edge_opacity := 0.42
@export_range(0.0, 1.0, 0.01) var motion_trail_opacity := 0.24
@export_range(0.1, 2.0, 0.05) var impact_lifetime := 0.65
@export_range(0.1, 3.0, 0.05) var collapse_lifetime := 1.1
var effects: Array = []
var retained: bool:
	get: return keep_visible or not effects.is_empty()
const FORM = preload("res://scripts/bosses/draco_form.gd")

func _ready() -> void:
	EFFECT_SETTINGS.apply_to(self)
