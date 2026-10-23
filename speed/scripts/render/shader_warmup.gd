## 利用するmaterialを専用の小さなViewportで描き、戦闘の前に描画パイプラインを準備する。
extends SubViewport
var _scope: ContentResourceScope
var _frames := 0
func prepare(scope: ContentResourceScope) -> void:
	_scope = scope
	scope.warming = true
	if DisplayServer.get_name() == "headless":
		_finish()
		return
	size = Vector2i(16, 16)
	world_2d = World2D.new()
	transparent_bg = true
	use_hdr_2d = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	image.fill(Color(0.5, 0.5, 1.0, 1.0))
	var normal := ImageTexture.create_from_image(image)
	var lit_texture := CanvasTexture.new()
	lit_texture.diffuse_texture = texture
	lit_texture.normal_texture = normal
	var materials: Array[Material] = [null]
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	materials.append(additive)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	materials.append(unshaded)
	for resource in scope.resources.values():
		if resource is Shader and resource.get_mode() == Shader.MODE_CANVAS_ITEM:
			var material := ShaderMaterial.new()
			material.shader = resource
			materials.append(material)
		elif resource is ShaderMaterial: materials.append(resource)
	scope.warm_materials = materials
	for lit in [false, true]:
		var layer := CanvasLayer.new()
		layer.layer = 1 if lit else 0
		add_child(layer)
		if lit:
			for index in 2:
				var light := DirectionalLight2D.new()
				light.range_layer_min = 1
				light.range_layer_max = 1
				light.rotation = index * PI
				layer.add_child(light)
		for material in materials:
			_geometry(layer, material, lit_texture if lit else texture)
func _geometry(parent: Node, material: Material, texture: Texture2D) -> void:
	# ボスの首と地形は、個体のバッチを使わず頂点色付きのmeshを描く。
	var meshes: Array[ArrayMesh] = []
	for textured in [false, true]:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2.ZERO, Vector2(16, 0), Vector2(0, 16)])
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
		if textured: arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		meshes.append(mesh)
	var raw_mesh := DrawLayer.new()
	raw_mesh.material = material
	raw_mesh.draw_fn = func(canvas: CanvasItem):
		canvas.draw_mesh(meshes[0], null)
		canvas.draw_mesh(meshes[1], texture)
	parent.add_child(raw_mesh)
	for region in [false, true]:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(8, 8)
		sprite.material = material
		sprite.region_enabled = region
		sprite.region_rect = Rect2(Vector2.ZERO, texture.get_size() / 2.0)
		parent.add_child(sprite)
	var drawing := DrawLayer.new()
	drawing.material = material
	drawing.draw_fn = func(canvas: CanvasItem):
		var points := PackedVector2Array([Vector2(1, 1), Vector2(15, 1), Vector2(15, 15), Vector2(1, 15)])
		canvas.draw_colored_polygon(points, Color.WHITE)
		canvas.draw_polygon(points, PackedColorArray([Color.WHITE]), PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]), texture)
		for antialias in [false, true]:
			canvas.draw_line(Vector2(1, 1), Vector2(15, 15), Color.WHITE, 2.0, antialias)
			canvas.draw_polyline(points, Color.WHITE, 2.0, antialias)
			canvas.draw_arc(Vector2(8, 8), 4.0, 0.0, TAU, 8, Color.WHITE, 2.0, antialias)
		canvas.draw_circle(Vector2(8, 8), 4.0, Color.WHITE)
	parent.add_child(drawing)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.size = Vector2(16, 16)
	rect.material = material
	parent.add_child(rect)
	for textured in [false, true]:
		var batch := InstanceBatch.new()
		if textured: batch.setup_texture(texture)
		else: batch.setup_polygon(InstanceBatch.circle_points(8))
		batch.material = material
		batch.begin()
		batch.add(Vector2(8, 8), 0.0, 4.0, Color.WHITE)
		batch.end()
		parent.add_child(batch)
func _process(_dt: float) -> void:
	if _scope == null: return
	if _scope.cancelled:
		_scope.warming = false
		_scope = null
		queue_free()
		return
	_frames += 1
	if _frames >= 3: _finish()
func _finish() -> void:
	_scope.warmup_complete = true
	_scope.warming = false
	_scope = null
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	queue_free()
