## 既存の本体・塗装・法線を使い、後部だけを膨らませる。
extends EnemyVisual
const BODY_SHADER := preload("res://shaders/pump_reservoir.gdshader")
const WIND_SHADER := preload("res://shaders/pump_wind.gdshader")
const ENEMIES := [preload("res://assets/pixel/drifter.png"), preload("res://assets/pixel/swarm.png"), preload("res://assets/pixel/splitling.png")]
var swallows: Array[Dictionary] = []
var _bodies: Array[MeshInstance2D] = []
var _winds: Array[MeshInstance2D] = []
var _count := 0
var _body_mesh: QuadMesh
var _wind_mesh: QuadMesh

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super.setup(render, behavior_name)
	events = [&"swallow"]
	_body_mesh = QuadMesh.new()
	_body_mesh.size = Vector2(44, 54)
	_wind_mesh = QuadMesh.new()
	_wind_mesh.size = Vector2(150, 150)

func on_event(ev: Dictionary) -> void:
	if swallows.size() < 120:
		swallows.append({"type": ev.enemy_type, "pos": ev.pos, "r": ev.r, "facing": ev.facing,
			"row": ev.row, "id": ev.id, "spin": ev.spin, "life": 0.48})

func update(dt: float) -> void:
	for f in swallows: f.life -= dt
	swallows = swallows.filter(func(f): return f.life > 0.0)

func _base_radius(t: EnemyTable, i: int) -> float:
	var def: EnemyDef = t.def[i]
	return def.radius * (1.25 if t.elite[i] != 0 else 1.0) * rm.cfg.character_scale * def.visual_value("scale", 1.0) * def.visual_value("collision_scale", 1.0)

func _source_scale(t: EnemyTable, i: int) -> float:
	return rm.enemy_sprite_radius(t.type[i], _base_radius(t, i)) / 18.5

func sprite_radius(t: EnemyTable, i: int) -> float:
	return _source_scale(t, i) * 27.0

func draw_body(_c: CanvasItem, t: EnemyTable, i: int, p: Vector2) -> bool:
	var look := rm.look_of(t.type[i])
	if look == null: return false
	rm._ensure_enemy_batch(t.type[i])
	if _count == _bodies.size():
		var body_node := MeshInstance2D.new()
		body_node.mesh = _body_mesh
		var material := ShaderMaterial.new()
		material.shader = BODY_SHADER
		for k in 3: material.set_shader_parameter("enemy%d" % k, ENEMIES[k])
		body_node.material = material
		rm._batches[t.type[i]].get_parent().add_child(body_node)
		_bodies.append(body_node)
		var wind_node := MeshInstance2D.new()
		wind_node.mesh = _wind_mesh
		var wind_material := ShaderMaterial.new()
		wind_material.shader = WIND_SHADER
		wind_node.material = wind_material
		rm._lit_enemy_marks.add_child(wind_node)
		_winds.append(wind_node)
	var body := _bodies[_count]
	var wind := _winds[_count]
	_count += 1
	var lighting: Node = rm._batches[t.type[i]].get_parent()
	if body.get_parent() != lighting: body.reparent(lighting)
	var scale_px := _source_scale(t, i)
	var angle := rm._enemy_sprite_angle(t.type[i], t.facing[i])
	body.position = p + Vector2(0, 8.5 * scale_px).rotated(angle)
	body.rotation = angle
	body.scale = Vector2.ONE * scale_px
	body.visible = not state.cinematic_hide_enemies
	var mat := body.material as ShaderMaterial
	mat.set_shader_parameter("base_tex", look.base)
	mat.set_shader_parameter("armor_tex", (rm._armor_batches[t.type[i]].texture as CanvasTexture).diffuse_texture)
	mat.set_shader_parameter("normal_tex", look.normal)
	var swelling := clampf((t.r[i] / maxf(_base_radius(t, i), 0.001) - 1.0) / maxf(float(t.def[i].params.grow), 0.001), 0.0, 1.0)
	mat.set_shader_parameter("full", 1.0 if t.mode[i] == EnemyTable.Mode.WINDUP else swelling)
	mat.set_shader_parameter("clock", state.world_time)
	mat.set_shader_parameter("flash", minf(1.0, t.flash[i] * 10.0))
	mat.set_shader_parameter("normal_strength", t.def[i].visual_value("normal_strength", rm.lighting_settings.normal_strength))
	mat.set_shader_parameter("ambient", t.def[i].visual_value("ambient", rm.lighting_settings.ambient))
	mat.set_shader_parameter("brightness", (rm._armor_batches[t.type[i]].material as ShaderMaterial).get_shader_parameter("brightness"))
	wind.position = p + Vector2.from_angle(t.facing[i]) * (15.725 + 75.0) * scale_px
	wind.rotation = t.facing[i]
	wind.scale = Vector2.ONE * scale_px
	wind.visible = body.visible and t.mode[i] == EnemyTable.Mode.MOVE and t.buds[i] < int(t.def[i].params.store_max)
	(wind.material as ShaderMaterial).set_shader_parameter("clock", state.world_time)
	return true

func draw_marks(_c: CanvasItem, _t: EnemyTable, _i: int) -> void:
	pass

func draw_layer(c: CanvasItem, _view: Rect2) -> void:
	for n in range(_count, _bodies.size()):
		_bodies[n].hide()
		_winds[n].hide()
	_count = 0
	if state.cinematic_hide_enemies: return
	var t := run.enemies.table
	for sw in swallows:
		if not run.enemies.is_same(sw.row, sw.id): continue
		var k := clampf(1.0 - float(sw.life) / 0.48, 0.0, 1.0)
		var scale_px := _source_scale(t, sw.row)
		var u := Vector2.from_angle(t.facing[sw.row])
		var mouth := t.pos[sw.row] + u * 15.725 * scale_px
		var rear := t.pos[sw.row] - u * 8.5 * scale_px
		var at: Vector2 = (sw.pos as Vector2).lerp(mouth, pow(minf(k / 0.625, 1.0), 2.0)) if k < 0.625 else mouth.lerp(rear, (k - 0.625) / 0.375)
		var tex := rm._enemy_texture(sw.type)
		if tex == null: continue
		var r := rm.enemy_sprite_radius(sw.type, sw.r) * lerpf(1.0, 0.12, minf(k / 0.625, 1.0))
		var size := tex.get_size() / maxf(tex.get_width(), tex.get_height()) * r * 2.0
		c.draw_set_transform(at, rm._enemy_sprite_angle(sw.type, sw.facing + float(sw.spin) * k * 0.48))
		c.draw_texture_rect(tex, Rect2(-size / 2, size), false, Color(1, 1, 1, minf(1.0, (1.0 - k) * 5.0)))
		c.draw_set_transform(Vector2.ZERO)
