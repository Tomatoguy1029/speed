## 影で着地点を示し、炎と火の粉を専用shaderで描く。外観は本人レビューで調整する。
extends EnemyVisual

var flame_settings: Resource = preload("res://data/visuals/phoenix_flames.tres")
var _flame_layer: DrawLayer

func update(_dt: float) -> void:
	if is_instance_valid(_flame_layer):
		_flame_layer.queue_redraw()

func draw_marks(_c: CanvasItem, _t: EnemyTable, _i: int) -> void:
	pass

## 本体が画面外でも、画面内にある着地点を描く。
func draw_layer(c: CanvasItem, view: Rect2) -> void:
	_ensure_flames(c)
	var t := run.enemies.table
	for i in behavior.rows():
		if t.dead[i] != 0 or t.mode[i] not in [EnemyTable.Mode.WINDUP, EnemyTable.Mode.DASH]:
			continue
		var center := t.anchor[i]
		var radius: float = behavior.impact_radius(i)
		if not view.grow(radius).has_point(center):
			continue
		var k := t.charge[i] if t.mode[i] == EnemyTable.Mode.WINDUP else 1.0
		var col: Color = flame_settings.flame_color
		c.draw_circle(center, radius, Color(col, 0.025 + 0.035 * k))
		c.draw_arc(center, radius, 0.0, TAU, 64, Color(col, 0.3 + 0.5 * k), _px(2.0))
		var shadow_size := t.r[i] * (0.5 + 0.5 * k)
		var shadow := PackedVector2Array()
		for point: Vector2 in [Vector2(0, -1), Vector2(0.28, -0.15), Vector2(1.2, 0.4),
				Vector2(0.3, 0.22), Vector2(0, 0.9), Vector2(-0.3, 0.22),
				Vector2(-1.2, 0.4), Vector2(-0.28, -0.15)]:
			shadow.append(center + (point * shadow_size).rotated(t.facing[i] + PI / 2.0))
		c.draw_colored_polygon(shadow, Color(0.09, 0.035, 0.015, 0.5 + 0.35 * k))
		shadow.append(shadow[0])
		c.draw_polyline(shadow, Color(col, 0.3 + 0.6 * k), _px(1.5))

func _ensure_flames(c: CanvasItem) -> void:
	if is_instance_valid(_flame_layer):
		return
	_flame_layer = DrawLayer.new()
	_flame_layer.name = "PhoenixFlames"
	_flame_layer.z_index = rm._layers.projectiles.z_index + 1
	_flame_layer.draw_fn = _draw_flames
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/phoenix_flames.gdshader")
	material.set_shader_parameter("noise_tex", preload("res://assets/fx/water_noise.png"))
	_flame_layer.material = material
	# 親のHDR用modulateで、頂点色に詰めた進行度などの値を変えない。
	c.get_parent().add_child(_flame_layer)
	if not rm.pipeline.rich:
		_flame_layer.visibility_layer = 1 | RenderPipeline.GLOW_LAYER

func _draw_flames(c: CanvasItem) -> void:
	var material := _flame_layer.material as ShaderMaterial
	flame_settings.apply(material)
	material.set_shader_parameter("linear_colors", _flame_layer.get_viewport().use_hdr_2d)
	material.set_shader_parameter("clock", state.world_time)
	var view := rm.view_rect()
	var t := run.enemies.table
	for i in behavior.rows():
		if t.dead[i] == 0 and t.mode[i] in [EnemyTable.Mode.WINDUP, EnemyTable.Mode.DASH]:
			var radius: float = behavior.impact_radius(i)
			if view.grow(radius * 1.2).has_point(t.anchor[i]):
				_flame_quad(c, t.anchor[i], radius, t.charge[i] if t.mode[i] == EnemyTable.Mode.WINDUP else 1.0,
					float(t.id[i] % 31) / 31.0, false)
	var pr := run.projectiles
	for i in pr.hazard_alive.size():
		if pr.hazard_alive[i] == 0 or pr.hazard_style[i] != ProjectileSystem.HazardStyle.PHOENIX:
			continue
		var radius := pr.hazard_len[i]
		if view.grow(radius * 1.2).has_point(pr.hazard_pos[i]):
			var age := clampf((pr.hazard_t[i] - pr.hazard_delay[i]) / maxf(0.001, pr.hazard_active[i]), 0.0, 1.0)
			_flame_quad(c, pr.hazard_pos[i], radius, age, float(i % 31) / 31.0, true)

func _flame_quad(c: CanvasItem, center: Vector2, radius: float, age: float, seed: float, attack: bool) -> void:
	var uv := PackedVector2Array([Vector2(-1.2, -1.2), Vector2(1.2, -1.2), Vector2(1.2, 1.2), Vector2(-1.2, 1.2)])
	var points := PackedVector2Array()
	for p in uv:
		points.append(center + p * radius)
	var payload := Color(age, seed, radius / 1000.0, 1.0 if attack else 0.25)
	c.draw_polygon(points, PackedColorArray([payload, payload, payload, payload]), uv)
