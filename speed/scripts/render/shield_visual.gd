## たて座の盾と、奪って機体に装備した盾。前面の板・移動・残り時間を同じ意匠で描く。
extends RefCounted

const STEEL := Color("#8db9cf")
const EDGE := Color("#bcefff")
const GUARD := Color("#65e8ff")
const EQUIPPED_SHADER := preload("res://shaders/scutum_guard.gdshader")
const ARMOR_SHADER := preload("res://shaders/scutum_guard_armor.gdshader")
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

static func equipped(c: CanvasItem, render: RunPresentation, ship_radius: float, scale: float, visual_pos := Vector2.INF) -> void:
	var state := render.state
	# 実行中にスクリプトを更新した場合も、旧一枚描画を重ねて残さない。
	var old := c.get_node_or_null("ScutumGuard") as MeshInstance2D
	if old != null:
		old.hide()
		if not old.is_queued_for_deletion(): old.queue_free()
	var canvas := c.get_node_or_null("ScutumGuardLighting") as CanvasLayer
	if state.ship_shield_t <= 0.0:
		if canvas != null: canvas.hide()
		return
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "ScutumGuardLighting"
		canvas.layer = (render._lit_enemy_marks.get_parent() as CanvasLayer).layer + 1
		canvas.follow_viewport_enabled = true
		c.add_child(canvas)
		var root := Node2D.new()
		root.name = "ScutumGuard"
		canvas.add_child(root)
		var membrane := MeshInstance2D.new()
		membrane.name = "Membrane"
		var mesh := QuadMesh.new()
		mesh.size = Vector2(112, 112)
		membrane.mesh = mesh
		var material := ShaderMaterial.new()
		material.shader = EQUIPPED_SHADER
		material.set_shader_parameter("guard_base", GUARD_BASE)
		material.set_shader_parameter("guard_armor", GUARD_ARMOR)
		material.set_shader_parameter("linear_output", c.get_viewport().use_hdr_2d)
		membrane.material = material
		root.add_child(membrane)
		var base := Sprite2D.new()
		base.name = "Base"
		base.texture = GUARD_BASE
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		base.material = unshaded
		root.add_child(base)
		var armor := Sprite2D.new()
		armor.name = "Armor"
		var texture := CanvasTexture.new()
		texture.diffuse_texture = GUARD_ARMOR
		texture.normal_texture = GUARD_NORMAL
		armor.texture = texture
		var armor_material := ShaderMaterial.new()
		armor_material.shader = ARMOR_SHADER
		armor.material = armor_material
		# 敵と同じくCOLOR.r/gは被弾フラッシュ用。通常時は両方0。
		armor.self_modulate = Color(0, 0, 0, 1)
		root.add_child(armor)
		for sprite: Sprite2D in [base, armor]:
			sprite.position = Vector2(31, -0.5)
			sprite.rotation = PI * 0.5
			sprite.scale = Vector2(61.0 / 47.0, 36.0 / 28.0)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		for light_name in ["UpperLeftLight", "LowerRightLight"]:
			var light := DirectionalLight2D.new()
			light.name = light_name
			light.range_layer_min = canvas.layer
			light.range_layer_max = canvas.layer
			canvas.add_child(light)
	var node := canvas.get_node("ScutumGuard") as Node2D
	var heading := state.ship_heading.angle()
	# airship.pngの可視範囲(0,10)-(30,50)と、実際の描画原点(-15.5,-30)。
	var center: Vector2 = state.ship_pos if visual_pos == Vector2.INF else visual_pos
	node.position = center + Vector2(-0.5 * scale, 0).rotated(heading + PI * 0.5)
	node.rotation = heading
	node.scale = Vector2.ONE * maxf(ship_radius * 2.5, 36.0 * scale) / 65.0
	canvas.show()
	var membrane_material := (node.get_node("Membrane") as MeshInstance2D).material as ShaderMaterial
	membrane_material.set_shader_parameter("clock", state.world_time)
	(node.get_node("Base") as Sprite2D).self_modulate = c.self_modulate
	var source := render.shield_source_type
	render._ensure_enemy_batch(source)
	var def := render.run.enemies.def_of(source)
	var painted := render._armor_batches[source].texture as CanvasTexture
	var source_material := render._armor_batches[source].material as ShaderMaterial
	var guard_material := (node.get_node("Armor") as Sprite2D).material as ShaderMaterial
	# 元画像と同じ座標のcropなので、元の領域キーで準備した塗装をそのまま参照する。
	guard_material.set_shader_parameter("painted_armor", painted.diffuse_texture)
	for key in ["brightness", "ambient", "normal_strength"]:
		guard_material.set_shader_parameter(key, source_material.get_shader_parameter(key))
	for i in 2:
		var prefix := "key_" if i == 0 else "fill_"
		var light := canvas.get_node("UpperLeftLight" if i == 0 else "LowerRightLight") as DirectionalLight2D
		light.energy = def.visual_value(prefix + "energy", render.lighting_settings.get(prefix + "energy"))
		light.rotation_degrees = def.visual_value(prefix + "angle", render.lighting_settings.get(prefix + "angle"))
		light.height = def.visual_value("height", render.lighting_settings.height)

static func hide_equipped(c: CanvasItem) -> void:
	var canvas := c.get_node_or_null("ScutumGuardLighting") as CanvasLayer
	if canvas != null: canvas.hide()

static func transfer(c: CanvasItem, effect: Dictionary, target: Vector2) -> void:
	var k := clampf(1.0 - float(effect.life) / float(effect.max), 0.0, 1.0)
	var p: Vector2 = effect.pos.lerp(target, k * (2.0 - k))
	var facing := lerp_angle(float(effect.facing), (target - effect.pos).angle(), k)
	plate(c, p, facing, float(effect.r) * (1.0 - k * 0.25), float(effect.arc), 1.0 - k)
