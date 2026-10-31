## 1枚の輪と84本の光筋。GPU資源と表示ノードは表示の寿命で再利用する。
extends MultiMeshInstance2D

const SHADER: Shader = preload("res://shaders/pulser_laser.gdshader")
var _shader: ShaderMaterial
var _radius := -1.0
var _pixel := -1.0
var _seed := -1.0
var _progress := -2.0

func setup(canvas: CanvasItem) -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	var instances: MultiMesh = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_2D
	instances.mesh = quad
	instances.instance_count = 85
	# 頂点シェーダーの移動分も含む。既存のInstanceBatchと同じカリング範囲。
	instances.custom_aabb = AABB(Vector3(-20000, -20000, -1), Vector3(40000, 40000, 2))
	for i in 85:
		instances.set_instance_transform_2d(i, Transform2D.IDENTITY)
	multimesh = instances
	_shader = ShaderMaterial.new()
	_shader.shader = SHADER
	material = _shader
	canvas.add_child(self)
	_shader.set_shader_parameter("linear_output", canvas.get_viewport().use_hdr_2d)

func show_ring(at: Vector2, radius: float, width: float, progress: float, seed: int = 0) -> void:
	position = at
	visible = true
	var pixel: float = maxf(width / 5.0, 0.01)
	if radius != _radius:
		_radius = radius
		_shader.set_shader_parameter("radius", radius)
	if pixel != _pixel:
		_pixel = pixel
		_shader.set_shader_parameter("pixel", pixel)
	if float(seed) != _seed:
		_seed = float(seed)
		_shader.set_shader_parameter("seed", _seed)
	if progress != _progress:
		_progress = progress
		_shader.set_shader_parameter("progress", progress)
	var count: int = 1 if progress < 0.0 else 85
	if multimesh.visible_instance_count != count:
		multimesh.visible_instance_count = count
