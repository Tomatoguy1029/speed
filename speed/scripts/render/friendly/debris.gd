extends AttackVisual
## 飛ぶ破片。星砕きの破片は星屑（またたく小さな四角と、後ろへ引く紫の尾）をドット単位で描く。

var _painter: PixelPainter
const PUMP_SHADER := preload("res://shaders/pump_debris.gdshader")
const PUMP_ENEMIES := [preload("res://assets/pixel/drifter.png"), preload("res://assets/pixel/swarm.png"), preload("res://assets/pixel/splitling.png")]
var _pump_mesh: QuadMesh
var _pump_nodes: Array[MeshInstance2D] = []
var _pump_count := 0

func begin_batch() -> void:
	_pump_count = 0
	if _painter == null:
		_painter = PixelPainter.new()
		_painter.setup_painter(1.82 * rm.cfg.character_scale)
		_painter.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
		_painter.modulate = RenderPipeline.plain_color(rm._layers.projectiles)
		rm._layers.projectiles.add_child(_painter)
	_painter.begin()
	super()

func end_batch() -> void:
	for n in range(_pump_count, _pump_nodes.size()): _pump_nodes[n].hide()
	if _painter != null: _painter.end()
	super()

func draw_friend(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> void:
	if pr.friend_visual[i] == &"enemy/pump_burst":
		_pump_debris(c, pr, i, pos)
		return
	if pr.friend_visual[i] == &"weapon/knockback":
		_stardust(pr, i, pos)
		return
	var r := pr.friend_r[i]
	var trail := pr.friend_trail[i]
	var key := String(pr.friend_visual[i])
	var tint := EFFECT_SETTINGS.tinted(key, Color.WHITE)
	if trail.size() > 1:
		c.draw_polyline(trail, Color(1.0, 0.6, 0.25, 0.7) * tint,
			_px(3.0) * EFFECT_SETTINGS.number(key, "debris_trail_width", 1.0))
	var u := Vector2.from_angle(pr.friend_angle[i]) * r
	var v := Vector2(-u.y, u.x) * 0.6
	c.draw_colored_polygon(PackedVector2Array([pos + u, pos + v, pos - u * 0.7, pos - v]), Color("#aeb6c4") * tint)
	c.draw_polyline(PackedVector2Array([pos + u, pos + v, pos - u * 0.7, pos - v, pos + u]),
		Color("#ff9a3c") * tint, _px(1.5))

func _pump_debris(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> void:
	if _pump_count == _pump_nodes.size():
		if _pump_mesh == null:
			_pump_mesh = QuadMesh.new()
			_pump_mesh.size = Vector2(288, 32)
		var created := MeshInstance2D.new()
		created.mesh = _pump_mesh
		var created_material := ShaderMaterial.new()
		created_material.shader = PUMP_SHADER
		created_material.set_shader_parameter("linear_output", c.get_viewport().use_hdr_2d)
		for k in 3: created_material.set_shader_parameter("enemy%d" % k, PUMP_ENEMIES[k])
		created.material = created_material
		c.add_child(created)
		_pump_nodes.append(created)
	var node := _pump_nodes[_pump_count]
	_pump_count += 1
	var dir := pr.friend_vel[i].normalized()
	node.position = pos - dir * 128.0
	node.rotation = dir.angle()
	node.show()
	var material := node.material as ShaderMaterial
	material.set_shader_parameter("age", pr.friend_age[i])
	material.set_shader_parameter("life", pr.friend_life[i])
	material.set_shader_parameter("speed", pr.friend_vel[i].length())
	material.set_shader_parameter("clock", state.world_time)
	material.set_shader_parameter("seed", float(i))
	material.set_shader_parameter("pixel", 1.82 * rm.cfg.character_scale)
	material.set_shader_parameter("spin", pr.friend_angle[i] - dir.angle())
	material.set_shader_parameter("kind", -1 if pr.friend_type[i] == &"pump" else PUMP_ENEMIES_TYPE.find(pr.friend_type[i]))
	material.set_shader_parameter("pump_art", rm._enemy_texture(&"pump"))

const PUMP_ENEMIES_TYPE := [&"drifter", &"swarm", &"splitling"]

## 星屑：0.07秒前の位置から今の位置まで、1ドットおきに紫の尾（1.2秒まで）。本体は 2〜4 ドット角で、またたく。
## 1.3秒を過ぎると点滅して消える。
func _stardust(pr: ProjectileSystem, i: int, pos: Vector2) -> void:
	if _painter == null: return
	var age := pr.friend_age[i]
	var tail := pos - pr.friend_vel[i] * 0.07
	var n := ceili(tail.distance_to(pos) / _painter.px) if age < 1.2 else 0
	for j in range(0, n, 2):
		var k := float(j) / maxi(n, 1)
		_painter.dot(tail.lerp(pos, k), Color("#7a4fd0") if k < 0.5 else Color("#b48cff"))
	if age >= 1.3 and int(age * 20.0) % 2 != 0: return
	var twinkle := sin(state.world_time * 30.0 + i * 1.7) > -0.3
	var size := 2 + (i * 7) % 3
	var cell := _painter.cell(pos)
	_painter.fill(cell.x - size / 2.0, cell.y - size / 2.0, Color("#fff3c4") if twinkle else Color("#e0d0ff"), size, size)
