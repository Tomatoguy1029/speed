## ドット単位のプラズマの球（pixelfx の plasma-explosion）。1つの球を1枚の四角に shader で描き、消えきったら外す。
## 位置は世界座標、半径はドット数。四角は半径とふちの揺らぎが収まる大きさにする。
class_name PlasmaBursts
extends Node2D

const SHADER := preload("res://shaders/plasma_burst.gdshader")
const NOISE := preload("res://assets/effects/build/burst_noise.tres")
var px := 2.366
## 戦闘エフェクトツールの装備キー（ShaderTuning）
var key := ""
var _items: Array[Dictionary] = []

func setup(cell: float) -> void:
	px = cell
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## ball 秒で膨らみ、中空になり、裂けて消える。
func add(pos: Vector2, radius: float, ball: float) -> void:
	var node := MeshInstance2D.new()
	node.mesh = FireBursts._mesh()
	var half := ceilf(radius * 1.12) + 3.0
	node.position = (pos / px).round() * px
	node.scale = Vector2.ONE * half * px
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("value_noise", NOISE.get_meta("texture"))
	mat.set_shader_parameter("half_cells", half)
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("ball", ball)
	mat.set_shader_parameter("seed", randf() * 9.0)
	ShaderTuning.apply(mat, key)
	node.material = mat
	add_child(node)
	_items.append({"node": node, "age": 0.0, "life": ball,
		"tuning_revision": ShaderTuning.SETTINGS.preview_revision, "tuning_key": key})
	if _items.size() > 48: _items.pop_front().node.queue_free()

## dt は世界の秒。
func step(dt: float) -> void:
	var revision: int = ShaderTuning.SETTINGS.preview_revision
	for item in _items:
		item.age += dt
		if item.age >= item.life:
			item.node.queue_free()
			continue
		var mat := item.node.material as ShaderMaterial
		mat.set_shader_parameter("age", item.age)
		if item.tuning_revision != revision or item.tuning_key != key:
			ShaderTuning.apply(mat, key)
			item.tuning_revision = revision
			item.tuning_key = key
	_items = _items.filter(func(item): return item.age < item.life)
