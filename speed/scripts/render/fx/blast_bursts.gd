## ドット単位の爆発（自爆する雑魚・機雷）。煙・火球と輪・燃えかす・火の粉を順に描き、寿命が来たら消す。
## 位置は世界座標、半径はドット数。四角の大きさと寿命は、置いたときの調整値で粒と輪の届く範囲から決める。
class_name BlastBursts
extends Node2D

const SHADER := preload("res://shaders/blast_burst.gdshader")
const NOISE := preload("res://assets/effects/build/burst_noise.tres")
var px := 2.366
## 戦闘エフェクトツールの装備・攻撃キー（ShaderTuning）
var key := ""
var _items: Array[Dictionary] = []
## shader の上限と同じ粒数。各粒の四角は共有し、頂点で現在の軌道へ置く。
const PARTICLE_COUNTS := {1: 24, 2: 96, 3: 64}
static var _particle_meshes: Dictionary = {}

func setup(cell: float) -> void:
	px = cell
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## delay 秒たってから爆発する。
func add(pos: Vector2, radius: float, delay := 0.0) -> void:
	var node := Node2D.new()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	ShaderTuning.apply(mat, key)
	var center := (pos / px).round()
	var half := ceilf(radius * _reach(mat, radius)) + 3.0
	node.position = center * px
	node.scale = Vector2.ONE * half * px
	mat.set_shader_parameter("value_noise", NOISE.get_meta("texture"))
	mat.set_shader_parameter("half_cells", half)
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("origin", center)
	mat.set_shader_parameter("seed", randf() * 9.0)
	var materials: Array[ShaderMaterial] = []
	# 子の順番とmesh内の粒番号順で、元のshaderの重なり順を保つ。
	for mode: int in [1, 0, 2, 3]:
		var surface := MeshInstance2D.new()
		surface.mesh = FireBursts._mesh() if mode == 0 else _particle_mesh(mode)
		var part: ShaderMaterial = mat if mode == 0 else mat.duplicate() as ShaderMaterial
		part.set_shader_parameter("pass_mode", mode)
		surface.material = part
		node.add_child(surface)
		materials.append(part)
	add_child(node)
	node.visible = delay <= 0.0
	_items.append({"node": node, "materials": materials, "age": -delay, "life": _life(mat),
		"tuning_revision": ShaderTuning.SETTINGS.preview_revision, "tuning_key": key})
	if _items.size() > 96: _items.pop_front().node.queue_free()

## dt は世界の秒。
func step(dt: float) -> void:
	var revision: int = ShaderTuning.SETTINGS.preview_revision
	for item in _items:
		item.age += dt
		if item.age >= item.life:
			item.node.queue_free()
			continue
		item.node.visible = item.age >= 0.0
		var retune: bool = item.tuning_revision != revision or item.tuning_key != key
		for mat: ShaderMaterial in item.materials:
			mat.set_shader_parameter("age", maxf(0.0, item.age))
			if retune: ShaderTuning.apply(mat, key)
		item.tuning_revision = revision
		item.tuning_key = key
	_items = _items.filter(func(item): return item.age < item.life)

## 上限分の四角を1枚のmeshにまとめる。UV.xへ粒番号を埋め、順序と頂点数を固定する。
static func _particle_mesh(mode: int) -> ArrayMesh:
	if _particle_meshes.has(mode): return _particle_meshes[mode]
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in int(PARTICLE_COUNTS[mode]):
		vertices.append_array(PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]))
		var u := float(i * 2)
		uvs.append_array(PackedVector2Array([Vector2(u, 0), Vector2(u + 1, 0), Vector2(u + 1, 1), Vector2(u, 1)]))
		var v := i * 4
		indices.append_array(PackedInt32Array([v, v + 1, v + 2, v, v + 2, v + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_particle_meshes[mode] = mesh
	return mesh

## 半径に対する、火の粉・衝撃波の輪・煙の届く範囲（shader の reach と同じ）。
static func _reach(mat: ShaderMaterial, radius: float) -> float:
	var spark_seconds: float = _value(mat, "spark_seconds")
	var sparks := 0.16 + 6.6 * _value(mat, "spark_speed") * (1.0 - exp(-0.6 * (spark_seconds + 0.06))) / 0.6 + 17.0 / maxf(radius, 1.0)
	var ring: float = 0.21 + _value(mat, "ring_size") + 3.0 / maxf(radius, 1.0)
	return maxf(1.7, maxf(sparks, ring))

## 最後の煙・燃えかす・火の粉が消えるまでの秒。
static func _life(mat: ShaderMaterial) -> float:
	var fire: float = _value(mat, "fire_seconds")
	return maxf(maxf(fire, _value(mat, "ring_seconds")), maxf(0.3 + _value(mat, "smoke_seconds"),
		maxf(0.67 * fire + _value(mat, "cinder_seconds"), 0.06 + _value(mat, "spark_seconds"))))

static func _value(mat: ShaderMaterial, uniform: String) -> float:
	var value: Variant = mat.get_shader_parameter(uniform)
	return float(value) if value != null else float(ShaderTuning.default_value(SHADER, uniform))
