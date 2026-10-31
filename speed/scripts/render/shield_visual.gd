## たて座の盾と、奪って機体に装備した盾。前面の板・移動・残り時間を同じ意匠で描く。
extends RefCounted

const STEEL := Color("#8db9cf")
const EDGE := Color("#bcefff")
const GUARD := Color("#65e8ff")
const EQUIPPED_SHADER := preload("res://shaders/scutum_guard.gdshader")
const GUARD_BASE := preload("res://assets/pixel/shield/scutum_guard_base.png")
const GUARD_ARMOR := preload("res://assets/pixel/shield/scutum_guard_armor.png")
const GUARD_NORMAL := preload("res://assets/pixel/shield/scutum_guard_normal.png")

static func plate(c: CanvasItem, p: Vector2, facing: float, r: float, arc: float, flash := 0.0) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for k in 17:
		var u := Vector2.from_angle(facing + lerpf(-arc, arc, k / 16.0))
		outer.append(p + u * r * 1.12)
		inner.append(p + u * r * 0.8)
	var shape := outer.duplicate()
	for k in range(inner.size() - 1, -1, -1):
		shape.append(inner[k])
	c.draw_colored_polygon(shape, STEEL.lerp(Color.WHITE, flash))
	c.draw_polyline(outer, EDGE, maxf(1.5, r * 0.07), true)
	c.draw_polyline(inner, Color("#34546d"), maxf(1.0, r * 0.04), true)
	for k in [0, 4, 8, 12, 16]:
		c.draw_line(inner[k], outer[k], Color("#d9f6ff"), maxf(1.0, r * 0.04), true)
	var u := Vector2.from_angle(facing)
	c.draw_circle(p + u * r * 0.95, r * 0.12, Color.WHITE if flash > 0.0 else GUARD)

static func enemy(c: CanvasItem, t: EnemyTable, i: int) -> void:
	plate(c, t.pos[i], t.facing[i], t.r[i], float(t.def[i].params.front_arc), minf(1.0, t.flash[i] * 10.0))

static func equipped(c: CanvasItem, state: RunState, ship_radius: float, scale: float, visual_pos := Vector2.INF) -> void:
	var node := c.get_node_or_null("ScutumGuard") as MeshInstance2D
	if state.ship_shield_t <= 0.0:
		if node != null: node.hide()
		return
	if node == null:
		node = MeshInstance2D.new()
		node.name = "ScutumGuard"
		var mesh := QuadMesh.new()
		mesh.size = Vector2(112, 112)
		node.mesh = mesh
		var material := ShaderMaterial.new()
		material.shader = EQUIPPED_SHADER
		material.set_shader_parameter("guard_base", GUARD_BASE)
		material.set_shader_parameter("guard_armor", GUARD_ARMOR)
		material.set_shader_parameter("guard_normal", GUARD_NORMAL)
		material.set_shader_parameter("armor_paint", Color("#ccdce0"))
		material.set_shader_parameter("linear_output", c.get_viewport().use_hdr_2d)
		node.material = material
		c.add_child(node)
	var heading := state.ship_heading.angle()
	# airship.pngの可視範囲(0,10)-(30,50)と、実際の描画原点(-15.5,-30)。
	var center: Vector2 = state.ship_pos if visual_pos == Vector2.INF else visual_pos
	node.position = center + Vector2(-0.5 * scale, 0).rotated(heading + PI * 0.5)
	node.rotation = heading
	node.scale = Vector2.ONE * maxf(ship_radius * 2.5, 36.0 * scale) / 65.0
	node.show()
	(node.material as ShaderMaterial).set_shader_parameter("clock", state.world_time)

static func hide_equipped(c: CanvasItem) -> void:
	var node := c.get_node_or_null("ScutumGuard") as MeshInstance2D
	if node != null: node.hide()

static func transfer(c: CanvasItem, effect: Dictionary, target: Vector2) -> void:
	var k := clampf(1.0 - float(effect.life) / float(effect.max), 0.0, 1.0)
	var p: Vector2 = effect.pos.lerp(target, k * (2.0 - k))
	var facing := lerp_angle(float(effect.facing), (target - effect.pos).angle(), k)
	plate(c, p, facing, float(effect.r) * (1.0 - k * 0.25), float(effect.arc), 1.0 - k)
