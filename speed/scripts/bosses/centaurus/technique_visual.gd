## 矢の予告と降下。ボス中心と正面+Xに合わせ、雨だけをワールド座標で描く。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
@export var technique_id: StringName
var visual_kind: StringName
@export var pixel_size := 3.0
const WARNING := Color("#f2b567")
const DANGER := Color("#ff667d")
const LIGHT_ARROW := preload("res://scripts/render/attacks/light_arrow.gd")
const RAIN_VISUAL := preload("res://scripts/bosses/centaurus/additional_technique_visual.gd")
func _ready() -> void:
	EFFECT_SETTINGS.apply_to(self)
