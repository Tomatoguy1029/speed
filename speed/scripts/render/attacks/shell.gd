## pixelfxのLaser boltに沿った、白い芯・緑の色帯・流れる光点。ノードは同時表示数の範囲で再利用する。
extends AttackVisual
const SHADER := preload("res://shaders/pump_shell.gdshader")
const TUNED_SHADERS := [SHADER]
const KEY := "res://scenes/attacks/shell.tscn"
const CONTENTS := [preload("res://assets/pixel/drifter.png"), preload("res://assets/pixel/swarm.png"), preload("res://assets/pixel/splitling.png")]
var _mesh: QuadMesh
var _nodes: Array[MeshInstance2D] = []
var _count := 0
var preview_paused := false
var _preview_age := 0.0

func setup(render: RunPresentation) -> void:
	super.setup(render)
	_prepare_mesh()

func _prepare_mesh() -> void:
	if _mesh != null: return
	_mesh = QuadMesh.new()
	# vertex shaderが128x32の描画域を作る。上限倍率まで収めるculling用の寸法。
	_mesh.size = Vector2(800, 256)

func _ready() -> void:
	if rm == null:
		_prepare_mesh()
		preview_restart()

func begin_batch() -> void:
	_count = 0
func end_batch() -> void:
	for n in range(_count, _nodes.size()): _nodes[n].hide()
func draw_shot(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> bool:
	_present(c, pos, pr.hostile_vel[i].angle(), pr.hostile_r[i], state.world_time)
	return true

func _present(c: CanvasItem, pos: Vector2, angle: float, radius: float, clock: float) -> void:
	if _count == _nodes.size():
		var created := MeshInstance2D.new()
		created.mesh = _mesh
		var created_material := ShaderMaterial.new()
		created_material.shader = SHADER
		for k in 3: created_material.set_shader_parameter("enemy%d" % k, CONTENTS[k])
		created.material = created_material
		created.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
		c.add_child(created)
		_nodes.append(created)
	var node := _nodes[_count]
	_count += 1
	var scale_px := radius / 38.0 * flight_scale
	var dir := Vector2.from_angle(angle)
	node.position = pos - dir * 55.0 * scale_px
	node.rotation = angle
	node.scale = Vector2.ONE * scale_px
	node.modulate = RenderPipeline.plain_color(rm._layers.projectiles, effect_tint) if rm != null else Color.WHITE
	node.show()
	var material := node.material as ShaderMaterial
	material.set_shader_parameter("clock", clock)
	ShaderTuning.apply(material, KEY)

## 単独プレビューも同じ光弾・描画パラメータを使う。飛行を画面内へ縮尺表示する。
func _process(dt: float) -> void:
	if rm == null: preview_step(0.0 if preview_paused else dt)

func preview_restart(age := 0.0) -> void:
	_preview_age = age
	preview_step(0.0)

func preview_step(dt: float) -> void:
	_preview_age = fmod(_preview_age + dt, 640.0 / 900.0 + 0.35)
	begin_batch()
	if _preview_age < 640.0 / 900.0:
		var at := Vector2((-320.0 + 900.0 * _preview_age) * 0.6, 0.0)
		_present(self, at, 0.0, 26.0 * 0.6, _preview_age)
	end_batch()
