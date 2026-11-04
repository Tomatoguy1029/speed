## 技の予告と、号令で飛び出す猟犬の軌跡。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
@export var technique_id: StringName
var visual_kind: StringName
@export var pixel_size := 3.0
const OUTLINE := Color("#1a1928")
const COAT := Color("#7a6f8f")
const SHADE := Color("#4d4660")
const MUZZLE := Color("#a99cc0")
const SIRIUS := Color("#e8f6ff")
const WARNING := Color("#f2b567")
const DANGER := Color("#ff667d")
const OPEN := Color("#9fe8ff")
const LUNGE_TRAIL := 6
func _ready() -> void:
	EFFECT_SETTINGS.apply_to(self)
