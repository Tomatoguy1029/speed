## 絵担当の差し替え用の最小実装。イベントを受け取り、判定と同じ世界時間で表示する。
extends Node2D
const TUNED_SHADERS := [preload("res://shaders/hydra_burst.gdshader")]
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")

@export var warning_color := Color("#ffd16c")
@export var locked_color := Color("#fff2b0")
@export var attack_color := Color("#ff765c")
@export var recovery_color := Color("#8bf5c0")
@export var hit_color := Color("#ffffff")
@export_range(0.1, 5.0) var body_radius_scale := 1.25
@export_range(4.0, 200.0) var head_radius := 42.0
@export_range(1.0, 12.0) var line_width := 3.0
@export_range(0.05, 2.0) var flash_duration := 0.25
## VisualTimeline の装飾トラックで編集する。予告の有無はイベントが決める。
@export var pulse_scale := 1.0
@export_range(0.5, 3.0, 0.05) var burst_pixel_scale := 1.0
@export var technique_id: StringName
var hydra: Node
	set(value): hydra = value
var retained: bool:
	get: return not slots.is_empty() or not flashes.is_empty()
var slots: Dictionary = {}
var flashes: Array[Dictionary] = []
var sprites: Dictionary={}
var serial:=0
@export var burst_shader: Shader=preload("res://shaders/hydra_burst.gdshader")
@onready var animations: AnimationPlayer = $AnimationPlayer
@onready var body_anchor: Marker2D = $BodyAnchor
@onready var head_anchor: Marker2D = $HeadAnchor

func _ready() -> void:
	EFFECT_SETTINGS.apply_to(self)
