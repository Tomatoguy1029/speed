## 同じ形の多数の物を、1つの MultiMeshInstance2D でまとめて描く（設計書 6・10）。
##
## 毎フレーム begin() → add() を繰り返す → end()。インスタンスの値は配列（buffer）へ直接書く。
## 形は +X を前とする単位の大きさ（半径 1）の多角形で作る。
class_name InstanceBatch
extends MultiMeshInstance2D

const STRIDE := 12  # 2D の変換 8 ＋ 色 4

var _buf := PackedFloat32Array()
var _count := 0

## points：単位の大きさの多角形（中心を含む三角形の扇に分ける）
func setup_polygon(points: PackedVector2Array) -> void:
	var verts := PackedVector2Array()
	for i in points.size():
		verts.append(Vector2.ZERO)
		verts.append(points[i])
		verts.append(points[(i + 1) % points.size()])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = mesh
	# buffer へ直接書くと、Compatibility では描画の範囲（カリングの枠）が更新されず、原点から離れた物が
	# 描かれない。フィールド全体を覆う枠を指定しておく
	mm.custom_aabb = AABB(Vector3(-20000, -20000, -1), Vector3(40000, 40000, 2))
	multimesh = mm

static func circle_points(segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		pts.append(Vector2.from_angle(i * TAU / segments))
	return pts

func begin() -> void:
	_count = 0

func add(pos: Vector2, angle: float, scale_r: float, color: Color) -> void:
	var need := (_count + 1) * STRIDE
	if _buf.size() < need:
		_buf.resize(maxi(need, _buf.size() * 2))
	var c := cos(angle) * scale_r
	var s := sin(angle) * scale_r
	var i := _count * STRIDE
	_buf[i] = c
	_buf[i + 1] = -s
	_buf[i + 2] = 0.0
	_buf[i + 3] = pos.x
	_buf[i + 4] = s
	_buf[i + 5] = c
	_buf[i + 6] = 0.0
	_buf[i + 7] = pos.y
	_buf[i + 8] = color.r
	_buf[i + 9] = color.g
	_buf[i + 10] = color.b
	_buf[i + 11] = color.a
	_count += 1

func end() -> void:
	var mm := multimesh
	if mm.instance_count < _count:
		mm.instance_count = maxi(_count, mm.instance_count * 2 + 64)
		_buf.resize(mm.instance_count * STRIDE)
	if _buf.size() != mm.instance_count * STRIDE:
		_buf.resize(mm.instance_count * STRIDE)
	mm.buffer = _buf
	mm.visible_instance_count = _count
