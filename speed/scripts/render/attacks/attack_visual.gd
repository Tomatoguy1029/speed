## 攻撃の種類ごとの表示。状態を読み、描画だけを受け持つ。
class_name AttackVisual
extends Node2D

const PIXEL_LIGHTNING := preload("res://scripts/render/pixel_lightning.gd")
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
var rm: RunPresentation
var effect_tint := Color.WHITE
## 専用の使用元を持つ弾シーンだけが指定する。旧sceneキーは互換値として引き継ぐ。
@export var visual_profile_key := ""
@export var visual_profile_fallback := ""
var state: RunState:
	get: return rm.state

func setup(render: RunPresentation) -> void:
	rm = render
	_apply_effect_settings()
	if get_parent() == null: rm.add_child(self)
	for phase in ["Flight", "Hit", "Fade"]:
		var node := get_node_or_null(phase) as CanvasItem
		if node != null: node.hide()
	_prepare_flight()

## 専用の形を描いた場合はtrue。falseなら共通の弾のバッチで描く。
func draw_shot(_c: CanvasItem, _pr: ProjectileSystem, _i: int, _pos: Vector2) -> bool:
	return false

func draw_hazard(_c: CanvasItem, _pr: ProjectileSystem, _i: int, _view: Rect2) -> void:
	pass

func update(_dt: float) -> void:
	pass

func _px(px: float) -> float:
	return rm._px(px)

func _apply_effect_settings() -> void:
	var values: Dictionary
	if visual_profile_key.is_empty():
		EFFECT_SETTINGS.apply_to(self)
		values = EFFECT_SETTINGS.values_for(scene_file_path)
	else:
		values = EFFECT_SETTINGS.component_values(visual_profile_key, "projectile", visual_profile_fallback)
		EFFECT_SETTINGS.apply_values(self, values)
	effect_tint = values.get("effect_tint", Color.WHITE)

func draw_friend(_c: CanvasItem, _projectiles: ProjectileSystem, _row: int, _pos: Vector2) -> void:
	pass

## シーンのFlightに図形を置くと、生成したMeshで飛行中の絵を差し替える。
@export_range(0.01, 100.0, 0.01) var flight_scale := 1.0
@export var turn_with_velocity := false
var _sprite_batches: Array[InstanceBatch] = []
var _sprite_pieces: Array = []
var _flight_batch: InstanceBatch
var _flight_mesh: Mesh
func _prepare_flight() -> void:
	if scene_file_path.is_empty() or rm.run == null or rm.run.ctx == null: return
	var library: Resource = rm.run.ctx.resources.resources.get("res://.content/attack_visuals.res")
	if library == null and state.lab_mode: library = load("res://.content/attack_visuals.res")
	if library == null: return
	_flight_mesh = library.get_meta("looks", {}).get(scene_file_path, {}).get("Flight")
	_sprite_pieces = library.get_meta("looks", {}).get(scene_file_path, {}).get("Flight_sprites", [])
	if _flight_mesh != null:
		_flight_batch = InstanceBatch.new()
		_flight_batch._setup_mesh(_flight_mesh)
		rm._layers.projectiles.add_child(_flight_batch)
	for piece: Dictionary in _sprite_pieces:
		var batch := InstanceBatch.new()
		batch._setup_mesh(piece.mesh)
		batch.texture = piece.texture
		rm._layers.projectiles.add_child(batch)
		_sprite_batches.append(batch)
func begin_batch() -> void:
	if _flight_batch != null: _flight_batch.begin()
	for batch in _sprite_batches: batch.begin()
func end_batch() -> void:
	if _flight_batch != null: _flight_batch.end()
	for batch in _sprite_batches: batch.end()
func render_shot(canvas: CanvasItem, projectiles: ProjectileSystem, row: int, at: Vector2) -> bool:
	if _flight_batch == null and _sprite_batches.is_empty(): return draw_shot(canvas, projectiles, row, at)
	var angle := projectiles.hostile_vel[row].angle() if turn_with_velocity else 0.0
	if _flight_batch != null: _flight_batch.add(at, angle, flight_scale, effect_tint)
	for batch in _sprite_batches: batch.add(at, angle, flight_scale, effect_tint)
	return true
func render_hazard(canvas: CanvasItem, projectiles: ProjectileSystem, row: int, view: Rect2) -> void:
	if _flight_mesh == null and _sprite_pieces.is_empty():
		draw_hazard(canvas, projectiles, row, view)
		return
	var transform := Transform2D(projectiles.hazard_angle[row], projectiles.hazard_pos[row]).scaled_local(Vector2.ONE * flight_scale)
	if _flight_mesh != null: canvas.draw_mesh(_flight_mesh, null, transform, effect_tint)
	for piece: Dictionary in _sprite_pieces: canvas.draw_mesh(piece.mesh, piece.texture, transform, effect_tint)

## 着弾と消えるときの表示時間。図形はシーンのHitとFadeに置く。
@export_range(0.01, 10.0, 0.01) var hit_duration := 0.25
@export_range(0.01, 10.0, 0.01) var fade_duration := 0.2
var _end_effects: Array[Dictionary] = []
func end_effect(phase: String, at: Vector2) -> void:
	var library: Resource = rm.run.ctx.resources.resources.get("res://.content/attack_visuals.res")
	if library == null and state.lab_mode: library = load("res://.content/attack_visuals.res")
	if library == null: return
	var mesh: Mesh = library.get_meta("looks", {}).get(scene_file_path, {}).get(phase)
	var duration := hit_duration if phase == "Hit" else fade_duration
	if mesh != null: _end_effects.append({"mesh": mesh, "texture": null, "pos": at, "age": 0.0, "duration": duration})
	for piece: Dictionary in library.get_meta("looks", {}).get(scene_file_path, {}).get(phase + "_sprites", []):
		_end_effects.append({"mesh": piece.mesh, "texture": piece.texture, "pos": at, "age": 0.0, "duration": duration})
func advance_end_effects(dt: float) -> void:
	for effect in _end_effects: effect.age += dt
	_end_effects = _end_effects.filter(func(effect): return effect.age < effect.duration)
func draw_end_effects(canvas: CanvasItem) -> void:
	for effect in _end_effects:
		canvas.draw_mesh(effect.mesh, effect.texture, Transform2D(0.0, effect.pos), Color(1, 1, 1, 1.0 - effect.age / effect.duration) * effect_tint)

var _shape_sprite_pieces: Array = []
var _shape_mesh: Mesh
var _shape: Dictionary
func configure(actor: Node, _kind: StringName, _points: PackedVector2Array, _white: Texture2D) -> void:
	_apply_effect_settings()
	var library: Resource = actor.ctx.resources.resources.get("res://.content/attack_visuals.res")
	if library == null and actor.run_state.lab_mode: library = load("res://.content/attack_visuals.res")
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
