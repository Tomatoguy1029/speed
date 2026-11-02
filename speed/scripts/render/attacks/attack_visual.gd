## 攻撃の種類ごとの表示。状態を読み、描画だけを受け持つ。
class_name AttackVisual
extends Node2D

const PIXEL_LIGHTNING := preload("res://scripts/render/pixel_lightning.gd")
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
var effect_tint := Color.WHITE
## 専用の使用元を持つ弾シーンだけが指定する。旧sceneキーは互換値として引き継ぐ。
@export var visual_profile_key := ""
@export var visual_profile_fallback := ""
@export var visual_component := "projectile"

func _apply_effect_settings() -> void:
	effect_tint = apply_effect_settings_to(self)

## 制作工程は非toolの弾のインスタンスにも、実行時と同じ値の変換を適用する。
static func apply_effect_settings_to(target: CanvasItem) -> Color:
	var values: Dictionary
	if String(target.get("visual_profile_key")).is_empty():
		EFFECT_SETTINGS.apply_to(target)
		values = EFFECT_SETTINGS.values_for(target.scene_file_path)
	else:
		values = EFFECT_SETTINGS.component_values(target.get("visual_profile_key"), target.get("visual_component"), target.get("visual_profile_fallback"))
		EFFECT_SETTINGS.apply_values(target, values)
	return values.get("effect_tint", Color.WHITE)

@export_range(0.01, 100.0, 0.01) var flight_scale := 1.0
@export var turn_with_velocity := false
var _sprite_batches: Array[InstanceBatch] = []
var _sprite_pieces: Array = []
var _flight_batch: InstanceBatch
var _flight_mesh: Mesh
@export_range(0.01, 10.0, 0.01) var hit_duration := 0.25
@export_range(0.01, 10.0, 0.01) var fade_duration := 0.2
var _end_effects: Array[Dictionary] = []
var _shape_sprite_pieces: Array = []
var _shape_mesh: Mesh
var _shape: Dictionary
func configure(owner: Node, _kind: StringName, _points: PackedVector2Array, _white: Texture2D) -> void:
	_apply_effect_settings()
	var scope: ContentResourceScope = owner.get("frame_scope")
	var library: Resource = scope.resources.get("res://.content/attack_visuals.res")
	if library != null:
		_shape_mesh = library.get_meta("looks", {}).get(scene_file_path, {}).get("Flight")
		_shape_sprite_pieces = library.get_meta("looks", {}).get(scene_file_path, {}).get("Flight_sprites", [])
	for phase in ["Flight", "Hit", "Fade"]:
		var node := get_node_or_null(phase) as CanvasItem
		if node != null: node.hide()
func update_effect(effect: Dictionary, _clock: float) -> void:
	_shape = effect
	queue_redraw()
func _draw() -> void:
	if _shape.is_empty(): return
	var transform := Transform2D((_shape.points[-1] - _shape.points[0]).angle(), _shape.points[0])
	if _shape_mesh != null: draw_mesh(_shape_mesh, null, transform)
	for piece: Dictionary in _shape_sprite_pieces: draw_mesh(piece.mesh, piece.texture, transform)
