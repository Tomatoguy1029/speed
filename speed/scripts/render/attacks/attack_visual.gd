## 攻撃の種類ごとの表示。状態を読み、描画だけを受け持つ。
class_name AttackVisual
extends Node2D

const PIXEL_LIGHTNING := preload("res://scripts/render/pixel_lightning.gd")
var rm: RunPresentation
var state: RunState:
	get: return rm.state

func setup(render: RunPresentation) -> void:
	rm = render
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

func draw_friend(_c: CanvasItem, _projectiles: ProjectileSystem, _row: int, _pos: Vector2) -> void:
	pass

## シーンのFlightに図形を置くと、生成したMeshで飛行中の絵を差し替える。
@export_range(0.01, 100.0, 0.01) var flight_scale := 1.0
@export var turn_with_velocity := false
var _flight_batch: InstanceBatch
var _flight_mesh: Mesh
func _prepare_flight() -> void:
	if scene_file_path.is_empty(): return
	var library: Resource = rm.run.ctx.resources.resources.get("res://.content/attack_visuals.res")
	if library == null and state.lab_mode: library = load("res://.content/attack_visuals.res")
	if library == null: return
	_flight_mesh = library.get_meta("looks", {}).get(scene_file_path, {}).get("Flight")
	if _flight_mesh == null: return
	_flight_batch = InstanceBatch.new()
	_flight_batch._setup_mesh(_flight_mesh)
	rm._layers.projectiles.add_child(_flight_batch)
func begin_batch() -> void:
	if _flight_batch != null: _flight_batch.begin()
func end_batch() -> void:
	if _flight_batch != null: _flight_batch.end()
func render_shot(canvas: CanvasItem, projectiles: ProjectileSystem, row: int, at: Vector2) -> bool:
	if _flight_batch == null: return draw_shot(canvas, projectiles, row, at)
	_flight_batch.add(at, projectiles.hostile_vel[row].angle() if turn_with_velocity else 0.0, flight_scale, Color.WHITE)
	return true
func render_hazard(canvas: CanvasItem, projectiles: ProjectileSystem, row: int, view: Rect2) -> void:
	if _flight_mesh == null:
		draw_hazard(canvas, projectiles, row, view)
		return
	canvas.draw_mesh(_flight_mesh, null, Transform2D(projectiles.hazard_angle[row], projectiles.hazard_pos[row]).scaled_local(Vector2.ONE * flight_scale))

## 着弾と消えるときの表示時間。図形はシーンのHitとFadeに置く。
@export_range(0.01, 10.0, 0.01) var hit_duration := 0.25
@export_range(0.01, 10.0, 0.01) var fade_duration := 0.2
var _end_effects: Array[Dictionary] = []
func end_effect(phase: String, at: Vector2) -> void:
	var library: Resource = rm.run.ctx.resources.resources.get("res://.content/attack_visuals.res")
	if library == null and state.lab_mode: library = load("res://.content/attack_visuals.res")
	if library == null: return
	var mesh: Mesh = library.get_meta("looks", {}).get(scene_file_path, {}).get(phase)
	if mesh == null: return
	var duration := hit_duration if phase == "Hit" else fade_duration
	_end_effects.append({"mesh": mesh, "pos": at, "age": 0.0, "duration": duration})
func advance_end_effects(dt: float) -> void:
	for effect in _end_effects: effect.age += dt
	_end_effects = _end_effects.filter(func(effect): return effect.age < effect.duration)
func draw_end_effects(canvas: CanvasItem) -> void:
	for effect in _end_effects:
		canvas.draw_mesh(effect.mesh, null, Transform2D(0.0, effect.pos), Color(1, 1, 1, 1.0 - effect.age / effect.duration))

var _shape_mesh: Mesh
var _shape: Dictionary
func configure(actor: Node, _kind: StringName, _points: PackedVector2Array, _white: Texture2D) -> void:
	var library: Resource = actor.ctx.resources.resources.get("res://.content/attack_visuals.res")
	if library == null and actor.run_state.lab_mode: library = load("res://.content/attack_visuals.res")
	if library != null: _shape_mesh = library.get_meta("looks", {}).get(scene_file_path, {}).get("Flight")
	for phase in ["Flight", "Hit", "Fade"]:
		var node := get_node_or_null(phase) as CanvasItem
		if node != null: node.hide()
func update_effect(effect: Dictionary, _clock: float) -> void:
	_shape = effect
	queue_redraw()
func _draw() -> void:
	if _shape_mesh != null and not _shape.is_empty():
		draw_mesh(_shape_mesh, null, Transform2D((_shape.points[-1] - _shape.points[0]).angle(), _shape.points[0]))
