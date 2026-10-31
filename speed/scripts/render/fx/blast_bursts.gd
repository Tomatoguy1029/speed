## ドット単位の爆発（自爆する雑魚・機雷）。1つの爆発を1枚の四角に blast_burst.gdshader で描き、寿命が来たら消す。
## 位置は世界座標、半径はドット数。四角の大きさと寿命は、置いたときの調整値で粒と輪の届く範囲から決める。
class_name BlastBursts
extends Node2D

const SHADER := preload("res://shaders/blast_burst.gdshader")
const VALUE_NOISE := preload("res://assets/effects/build/value_noise.png")
var px := 2.366
## 戦闘エフェクトツールの装備・攻撃キー（ShaderTuning）
var key := ""
var _items: Array[Dictionary] = []

func setup(cell: float) -> void:
	px = cell
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## delay 秒たってから爆発する。
func add(pos: Vector2, radius: float, delay := 0.0) -> void:
	var node := MeshInstance2D.new()
	node.mesh = FireBursts._mesh()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	ShaderTuning.apply(mat, key)
	var center := (pos / px).round()
	var half := ceilf(radius * _reach(mat, radius)) + 3.0
	node.position = center * px
	node.scale = Vector2.ONE * half * px
	mat.set_shader_parameter("value_noise", VALUE_NOISE)
	mat.set_shader_parameter("half_cells", half)
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("origin", center)
	mat.set_shader_parameter("seed", randf() * 9.0)
	node.material = mat
	add_child(node)
	node.visible = delay <= 0.0
	_items.append({"node": node, "age": -delay, "life": _life(mat)})
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
		mat.set_shader_parameter("age", maxf(0.0, item.age))
		ShaderTuning.apply(mat, key)
	_items = _items.filter(func(item): return item.age < item.life)

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
