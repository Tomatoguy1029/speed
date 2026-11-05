## 石になった敵が砕ける破片（shaders/hero_shatter.gdshader）。破片・細かい粒・土ぼこりを1つの MultiMesh にまとめる。
## 砕けた瞬間に位置・向き・速さ・回転・寿命を1回だけ書き込み、動きは頂点で求める。数と大きさは敵の大きさに合わせる。
class_name StoneShards
extends MultiMeshInstance2D

const SHADER := preload("res://shaders/hero_shatter.gdshader")
const CAPACITY := 2048
const CHUNK := 0.0
const GRIT := 0.5
const DUST := 1.0
var px := 1.82
var _time := 0.0
var _next := 0
var _material: ShaderMaterial

func setup(cell: float) -> void:
	px = cell
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = FireBursts._mesh()
	mm.custom_aabb = AABB(Vector3(-20000, -20000, -1), Vector3(40000, 40000, 2))
	mm.instance_count = CAPACITY
	mm.visible_instance_count = 0
	multimesh = mm
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material = _material

## pos は世界座標、radius は敵の半径（世界の長さ）。
func burst(pos: Vector2, radius: float) -> void:
	var r := maxf(radius / px, 3.0)
	for i in clampi(int(5.0 + r / 2.5), 5, 18):
		_put(pos, r * 0.4, randf_range(r * 3.0, r * 7.0), maxf(2.5, r * randf_range(0.28, 0.5)), randf_range(-12.0, 12.0), randf_range(0.7, 1.0), CHUNK)
	for i in clampi(int(8.0 + r), 8, 40):
		_put(pos, r * 0.5, randf_range(r * 6.0, r * 12.0), 0.6, 0.0, randf_range(0.3, 0.7), GRIT)
	for i in clampi(int(3.0 + r / 8.0), 3, 8):
		_put(pos, r * 0.3, randf_range(r * 1.0, r * 2.5), r * randf_range(0.4, 0.6), 0.0, randf_range(0.7, 1.0), DUST)
	multimesh.visible_instance_count = maxi(multimesh.visible_instance_count, mini(_next, CAPACITY))

## dt は演出の秒。
func step(dt: float) -> void:
	_time += dt
	_material.set_shader_parameter("time", _time)

func _put(pos: Vector2, spread: float, speed: float, size: float, spin: float, life: float, kind: float) -> void:
	var at := pos + Vector2.from_angle(randf() * TAU) * randf() * spread * px
	var slot := _next % CAPACITY
	_next += 1
	multimesh.set_instance_transform_2d(slot, Transform2D(0.0, Vector2.ONE * size * px, 0.0, at))
	multimesh.set_instance_custom_data(slot, Color(randf() * TAU, speed, spin, _time))
	multimesh.set_instance_color(slot, Color(randf(), life / 4.0, size / 32.0, kind))
