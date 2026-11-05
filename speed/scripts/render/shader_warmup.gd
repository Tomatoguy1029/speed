## 利用するmaterialを専用の小さなViewportで描き、戦闘の前に描画パイプラインを準備する。
extends SubViewport
const COLLECT_BUDGET_US := 4000
## 1回に並べるmaterialの上限。並べた回の最も長いフレームが GROW_SECONDS 未満なら倍にし、SHRINK_SECONDS を超えたら半分にする。
const MAX_BATCH := 64
const GROW_SECONDS := 1.0 / 30.0
const SHRINK_SECONDS := 0.1
var _scope: ContentResourceScope
var _frames := 0
var _material_index := 0
var _batch := 1
var _batch_count := 0
var _batch_longest := 0.0
var _layers: Array[CanvasLayer] = []
var _texture: Texture2D
var _lit_texture: CanvasTexture
var _sources: Array = []
var _source_index := 0
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
	_texture = texture
	_lit_texture = lit_texture
	var materials: Array[Material] = [null]
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	materials.append(additive)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	materials.append(unshaded)
	scope.warm_materials = materials
	_sources = scope.resources.values()
	for lit in [false, true]:
		var layer := CanvasLayer.new()
		layer.layer = 1 if lit else 0
		add_child(layer)
		_layers.append(layer)
		if lit:
			for index in 2:
				var light := DirectionalLight2D.new()
				light.range_layer_min = 1
				light.range_layer_max = 1
				light.rotation = index * PI
				layer.add_child(light)
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
## materialの作成も主スレッドを止めるので、1フレーム分ずつ進める。
func _collect_materials() -> void:
	var began := Time.get_ticks_usec()
	while _source_index < _sources.size() and Time.get_ticks_usec()-began < COLLECT_BUDGET_US:
		var resource: Variant = _sources[_source_index]
		_source_index += 1
		if resource is Shader and resource.get_mode() == Shader.MODE_CANVAS_ITEM:
			var material := ShaderMaterial.new()
			material.shader = resource
			_scope.warm_materials.append(material)
		elif resource is ShaderMaterial: _scope.warm_materials.append(resource)

func _process(delta: float) -> void:
	if _scope == null: return
	if _scope.cancelled:
		_scope.warming = false
		_scope = null
		queue_free()
		return
	if _source_index < _sources.size():
		_collect_materials()
		return
	# 一度に全materialを投入すると、最初の描画だけでロード表示まで止まる。
	# 同じ幾何と照明の組を数個のmaterialずつ描き、各組の描画を終えてから次へ進む。
	# 並べる数はフレームの長さを見て増減し、ロード表示を止めない範囲でまとめる。
	if _frames > 0:
		_frames += 1
		_batch_longest = maxf(_batch_longest, delta)
		if _frames < 3: return
		for layer in _layers:
			for child in layer.get_children():
				if child is DirectionalLight2D: continue
				layer.remove_child(child)
				child.queue_free()
		_material_index += _batch_count
		if _batch_longest < GROW_SECONDS: _batch = mini(_batch * 2, MAX_BATCH)
		elif _batch_longest > SHRINK_SECONDS: _batch = maxi(_batch >> 1, 1)
		_frames = 0
		_scope.warmup_progress = float(_material_index) / _scope.warm_materials.size()
	if _material_index >= _scope.warm_materials.size():
		_finish()
		return
	_batch_count = mini(_batch, _scope.warm_materials.size() - _material_index)
	for offset in _batch_count:
		for index in _layers.size():
			_geometry(_layers[index], _scope.warm_materials[_material_index + offset], _lit_texture if index == 1 else _texture)
	_batch_longest = 0.0
	_frames = 1
func _finish() -> void:
	_scope.warmup_complete = true
	_scope.warmup_progress = 1.0
	_scope.warming = false
	_scope = null
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	queue_free()
