## 収納内容と位置の値だけを、制作済みの圧縮弾shaderへ渡す。
extends Node2D
const ROLE = preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.VisualRole
var _scope: ContentResourceScope
var _visuals: Dictionary
var _textures: Dictionary = {}
var _contents := PackedInt32Array()
var _full := -1.0
var _reach := -1.0
var _mesh: MeshInstance2D
var _stone: DrawLayer
var _row: Dictionary = {}
func setup(scope: ContentResourceScope, visuals: Dictionary) -> void:
	_scope = scope
	_visuals = visuals
	_mesh = MeshInstance2D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(800,256)
	_mesh.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = scope.resources.get("res://shaders/pump_shell_runtime.gdshader")
	mat.set_shader_parameter("linear_colors",RenderingServer.get_current_rendering_method()!="gl_compatibility")
	_mesh.material = mat
	_mesh.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
	add_child(_mesh)
	_stone = DrawLayer.new()
	_stone.draw_fn = func(c: CanvasItem):
		if not _row.is_empty() and _row.petrified_radius>0.0: c.draw_circle(_row.points[0],_row.petrified_radius,Color(0.62,0.6,0.58,0.9))
	add_child(_stone)
func _texture(id: int) -> Texture2D:
	if not _textures.has(id):
		var entry: Dictionary = _visuals.get(id,{})
		var texture: Texture2D
		if entry.get("role")==ROLE.EnemyLook:
			var look: EnemyLook = _scope.resources.get(entry.path)
			if look!=null: texture = look.previews.get(entry.get("hull_preview",""))
		elif entry.get("role")!=ROLE.EnemyPolygon: texture = _scope.resources.get(entry.get("path","")) as Texture2D
		_textures[id] = texture
	return _textures[id]
func apply_frame(row: Dictionary) -> void:
	_row = row
	var p: Vector2 = row.points[0]
	var scale_px: float = row.widths[0]/38.0*row.flight_scale
	var direction := Vector2.from_angle(row.angle)
	_mesh.position = p-direction*55.0*scale_px
	_mesh.rotation = row.angle
	_mesh.scale = Vector2.ONE*scale_px
	_mesh.modulate = row.colors[0]
	var mat := _mesh.material as ShaderMaterial
	if _contents!=row.contents or _full!=row.full:
		var samples := PackedInt32Array()
		var distinct := {}
		for id: int in row.contents:
			if samples.size()==7: break
			if not distinct.has(id) and _texture(id)!=null:
				distinct[id] = true
				samples.append(id)
		var skipped := {}
		for id: int in row.contents:
			if samples.size()==7: break
			if not distinct.has(id): continue
			if not skipped.has(id): skipped[id] = true; continue
			samples.append(id)
		for k in samples.size(): mat.set_shader_parameter("enemy%d" % k,_texture(samples[k]))
		mat.set_shader_parameter("contents_count",float(samples.size()))
		mat.set_shader_parameter("contents_fill",row.full)
		_contents = row.contents
		_full = row.full
	var local_reach: float = minf(432.0,maxf(0.0,(p-row.mouth).dot(direction))/maxf(scale_px,0.001))
	if _reach!=local_reach: mat.set_shader_parameter("trail_reach",local_reach); _reach = local_reach
	mat.set_shader_parameter("clock",row.clock)
	_stone.queue_redraw()
