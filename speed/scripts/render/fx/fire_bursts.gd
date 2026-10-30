## ドット単位の炎の爆発（試作の pfire）。1つの爆発を1枚の四角に shader で描き、寿命が来たら消す。
## 位置は世界座標、半径はドット数。四角は半径の 1.2 倍とノイズの崩れが収まる大きさにする。
class_name FireBursts
extends Node2D

const SHADER := preload("res://shaders/fire_burst.gdshader")
const VALUE_NOISE := preload("res://assets/effects/build/value_noise.png")
## 爆発の色（白・薄い黄・橙・赤）
const EMBER := [Color.WHITE, Color("#fff2a8"), Color("#ffb030"), Color("#d2461c")]
var px := 2.366
## 戦闘エフェクトツールの装備キー（ShaderTuning）
var key := ""
var _items: Array[Dictionary] = []
static var _quad: ArrayMesh

func setup(cell: float) -> void:
	px = cell
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## delay 秒たってから燃え始める。
func add(pos: Vector2, radius: float, life: float, colors: Array = EMBER, delay := 0.0) -> void:
	var node := MeshInstance2D.new()
	node.mesh = _mesh()
	var center := (pos / px).round()
	var half := ceilf(radius * 1.25) + 3.0
	node.position = center * px
	node.scale = Vector2.ONE * half * px
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("value_noise", VALUE_NOISE)
	mat.set_shader_parameter("half_cells", half)
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("origin", center)
	mat.set_shader_parameter("seed", randf() * 9.0)
	for i in 4: mat.set_shader_parameter("c%d" % i, colors[i])
	ShaderTuning.apply(mat, key)
	node.material = mat
	add_child(node)
	node.visible = delay <= 0.0
	_items.append({"node": node, "age": -delay, "life": life})
	if _items.size() > 96: _items.pop_front().node.queue_free()

## dt は世界の秒。
func step(dt: float) -> void:
	for item in _items:
		item.age += dt
		if item.age >= item.life:
			item.node.queue_free()
			continue
		item.node.visible = item.age >= 0.0
		var mat := item.node.material as ShaderMaterial
		mat.set_shader_parameter("life", maxf(0.0, item.age) / item.life)
		ShaderTuning.apply(mat, key)
	_items = _items.filter(func(item): return item.age < item.life)

static func _mesh() -> ArrayMesh:
	if _quad != null: return _quad
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2(1, 0), Vector2.ONE, Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	_quad = ArrayMesh.new()
	_quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _quad
