## 実雑魚の凝縮塊と、短い緑白の尾。描画ノードは同時表示数の範囲で再利用する。
extends AttackVisual
const SHADER := preload("res://shaders/pump_shell.gdshader")
const CONTENTS := [preload("res://assets/pixel/drifter.png"), preload("res://assets/pixel/swarm.png"), preload("res://assets/pixel/splitling.png")]
var _mesh: QuadMesh
var _nodes: Array[MeshInstance2D] = []
var _count := 0
func setup(render: RunPresentation) -> void:
	super.setup(render)
	_mesh = QuadMesh.new()
	_mesh.size = Vector2(190, 80)
func begin_batch() -> void:
	_count = 0
func end_batch() -> void:
	for n in range(_count, _nodes.size()): _nodes[n].hide()
func draw_shot(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> bool:
	if _count == _nodes.size():
		var created := MeshInstance2D.new()
		created.mesh = _mesh
		var material := ShaderMaterial.new()
		material.shader = SHADER
		for k in 3: material.set_shader_parameter("enemy%d" % k, CONTENTS[k])
		created.material = material
		c.add_child(created)
		_nodes.append(created)
	var node := _nodes[_count]
	_count += 1
	var scale_px := pr.hostile_r[i] / 38.0
	var dir := pr.hostile_vel[i].normalized()
	node.position = pos - dir * 55.0 * scale_px
	node.rotation = dir.angle()
	node.scale = Vector2.ONE * scale_px
	node.show()
	(node.material as ShaderMaterial).set_shader_parameter("clock", state.world_time)
	return true
