## ドット単位の輪・針・太い輪・六角形を GPU でまとめて描く（shaders/pixel_shapes.gdshaderinc）。1つの図形を1枚の四角にし、
## 四角の中心をドットの格子の角へそろえる。光を足し合わせる描き方と、重ねる描き方を選べる。
## 毎フレーム begin → add_〜 → end。1つの束は1種類の図形だけを描く。
class_name PixelShapes
extends MultiMeshInstance2D

const ADD := preload("res://shaders/pixel_shapes.gdshader")
const MIX := preload("res://shaders/pixel_shapes_mix.gdshader")
const STRIDE := 16  # 2D の変換 8 ＋ 色 4 ＋ 図形の値 4
enum Shape { RING, SPINDLE, THICK_RING, HEX }
var px := 2.366
var _buf := PackedFloat32Array()
var _count := 0

func setup(cell: float, kind: Shape, additive := true) -> void:
	px = cell
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.custom_aabb = AABB(Vector3(-20000, -20000, -1), Vector3(40000, 40000, 2))
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = ADD if additive else MIX
	mat.set_shader_parameter("shape", kind)
	material = mat

func begin() -> void:
	_count = 0

## 隙間のない輪（半径 radius ドット）。inner は1ドット内側の輪の濃さの割合（0 なら描かない）。
func add_ring(pos: Vector2, radius: float, color: Color, inner := 0.0) -> void:
	_add(pos, ceilf(radius) + 2.0, color, Color(0.0, radius, inner, 0.0))

## 両端の尖った針（PixelPainter.spindle と同じ形）。
func add_spindle(pos: Vector2, angle: float, length: float, w: float, alpha: float) -> void:
	if alpha <= 0.0 or length <= 0.0: return
	_add(pos, ceilf(length * 0.5 + w) + 2.0, Color(1, 1, 1, alpha), Color(0.0, length, w, angle))

## 太さ w ドットの輪（半径から内側へ）。nz は輪の形の揺らぎ（5山の正弦）。
func add_thick_ring(pos: Vector2, radius: float, w: int, color: Color, nz := 0.0) -> void:
	if radius <= 0.0: return
	_add(pos, ceilf(radius * (1.0 + absf(nz))) + 2.0, color, Color(0.0, radius, w, nz))

## 六角形の輪郭（頂点までの半径 radius ドット）。
func add_hex(pos: Vector2, radius: float, color: Color) -> void:
	_add(pos, ceilf(radius) + 2.0, color, Color(0.0, radius, 0.0, 0.0))

func _add(pos: Vector2, half: float, color: Color, custom: Color) -> void:
	var need := (_count + 1) * STRIDE
	if _buf.size() < need: _buf.resize(maxi(need, _buf.size() * 2))
	var center := (pos / px).round() * px
	var i := _count * STRIDE
	var size := half * px
	_buf[i] = size; _buf[i + 1] = 0.0; _buf[i + 2] = 0.0; _buf[i + 3] = center.x
	_buf[i + 4] = 0.0; _buf[i + 5] = size; _buf[i + 6] = 0.0; _buf[i + 7] = center.y
	_buf[i + 8] = color.r; _buf[i + 9] = color.g; _buf[i + 10] = color.b; _buf[i + 11] = color.a
	_buf[i + 12] = half; _buf[i + 13] = custom.g; _buf[i + 14] = custom.b; _buf[i + 15] = custom.a
	_count += 1

func end() -> void:
	var mm := multimesh
	if _count == 0:
		if mm.visible_instance_count != 0: mm.visible_instance_count = 0
		return
	if mm.instance_count < _count:
		mm.instance_count = maxi(_count, mm.instance_count * 2 + 64)
	if _buf.size() != mm.instance_count * STRIDE: _buf.resize(mm.instance_count * STRIDE)
	mm.buffer = _buf
	mm.visible_instance_count = _count
