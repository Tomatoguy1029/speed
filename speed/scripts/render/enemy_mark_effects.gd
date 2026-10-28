## 目印とエリートを敵本体の背後へまとめて描く。判定や敵の定義は変更しない。
class_name EnemyMarkEffects
extends Node2D

const LANDMARK := preload("res://data/visuals/landmark_mark.tres")
const ELITE := preload("res://data/visuals/elite_mark.tres")
const LANDMARK_SHADER := preload("res://shaders/landmark_mark.gdshader")
const ELITE_SHADER := preload("res://shaders/elite_mark.gdshader")

var _landmark_batch: InstanceBatch
var _elite_batch: InstanceBatch

func _ready() -> void:
	z_index = -2
	_landmark_batch = _make_batch(LANDMARK, LANDMARK_SHADER)
	_elite_batch = _make_batch(ELITE, ELITE_SHADER)

func _make_batch(settings: EnemyMarkSettings, shader: Shader) -> InstanceBatch:
	var batch := InstanceBatch.new()
	batch.setup_shader_quad()
	var material := ShaderMaterial.new()
	material.shader = shader
	settings.apply_to(material)
	batch.material = material
	add_child(batch)
	return batch

func begin(time: float) -> void:
	_landmark_batch.begin()
	_elite_batch.begin()
	(_landmark_batch.material as ShaderMaterial).set_shader_parameter("mark_time", time)
	(_elite_batch.material as ShaderMaterial).set_shader_parameter("mark_time", time)

func add(pos: Vector2, sprite_radius: float, enemy_id: int, landmark: bool, elite: bool) -> void:
	var extent := sprite_radius * 3.2
	var seed := float(posmod(enemy_id, 997)) / 997.0
	var data := Color(seed, 0.0, 0.0, 1.0)
	if landmark:
		_landmark_batch.add_upright(pos, extent, data)
	if elite:
		_elite_batch.add_upright(pos, extent, data)

func finish() -> void:
	_landmark_batch.end()
	_elite_batch.end()
