## 弾シーンの固定の図形を、実行時にまとめて描けるMeshへ変換する。
@tool
extends RefCounted

static func _resource_paths(directory: String, paths: Dictionary) -> void:
	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".tres") or file.ends_with(".tscn"):
			preload("res://tools/content/build_stage_resources.gd")._add(paths, directory.path_join(file))
	for child in DirAccess.get_directories_at(directory):
		if not child.begins_with("."): _resource_paths(directory.path_join(child), paths)

static func _root_script(scene: PackedScene) -> Script:
	while scene != null:
		var state := scene.get_state()
		if state.get_node_count() == 0: return null
		for property in state.get_node_property_count(0):
			if state.get_node_property_name(0, property) == &"script":
				return state.get_node_property_value(0, property) as Script
		scene = state.get_node_instance(0)
	return null

## 既定の弾と、技・敵から参照する専用の弾を保存先に関係なく拾う。
static func scene_paths() -> PackedStringArray:
	var references := {}
	for directory in ["res://scenes/attacks", "res://data/bosses", "res://data/enemies"]:
		_resource_paths(directory, references)
	var scenes := PackedStringArray()
	for path: String in references:
		if not path.ends_with(".tscn"): continue
		var scene := load(path) as PackedScene
		if scene == null: continue
		var script := _root_script(scene)
		while script != null:
			if script == preload("res://scripts/render/attacks/attack_visual.gd") or script == preload("res://scripts/render/attacks/hydra_shape.gd"):
				scenes.append(path)
				break
			script = script.get_base_script()
	scenes.sort()
	return scenes

static func input_paths() -> PackedStringArray:
	var paths := {}
	for scene in scene_paths(): preload("res://tools/content/build_stage_resources.gd")._add(paths, scene)
	var inputs := PackedStringArray(paths.keys())
	for path in paths:
		if FileAccess.file_exists(path + ".import"): inputs.append(path + ".import")
	return inputs

static func _polygons(node: Node, transform: Transform2D, vertices: PackedVector2Array, colors: PackedColorArray, tint := Color.WHITE) -> void:
	if node is CanvasItem and not node.visible: return
	if node is CanvasItem: tint *= node.modulate
	var local: Transform2D = transform * node.transform if node is Node2D else transform
	if node is Polygon2D and node.polygon.size() >= 3:
		var indices := Geometry2D.triangulate_polygon(node.polygon)
		for index in indices:
			vertices.append(local * node.polygon[index])
			colors.append(node.color * tint * node.self_modulate)
	for child in node.get_children(): _polygons(child, local, vertices, colors, tint)

static func _mesh(node: Node) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	_polygons(node, Transform2D.IDENTITY, vertices, colors)
	if vertices.is_empty(): return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func build(output: String) -> Error:
	var library := Resource.new()
	var looks := {}
	for path in scene_paths():
		var scene := load(path) as PackedScene
		if scene == null: return ERR_INVALID_DATA
		var source := scene.instantiate()
		var layers := {}
		for phase in ["Flight", "Hit", "Fade"]:
			var node := source.get_node_or_null(phase)
			if node != null:
				layers[phase] = _mesh(node)
				var sprites: Array[Dictionary] = []
				_sprites(node, Transform2D.IDENTITY, Color.WHITE, sprites)
				layers[phase + "_sprites"] = sprites
		looks[path] = layers
		source.free()
	library.set_meta("looks", looks)
	return ResourceSaver.save(library, output.path_join("attack_visuals.res"))

static func _sprites(node: Node, transform: Transform2D, tint: Color, pieces: Array[Dictionary]) -> void:
	var local: Transform2D = transform * node.transform if node is Node2D else transform
	if node is CanvasItem and not node.visible: return
	if node is CanvasItem: tint *= node.modulate
	if node is Sprite2D and node.texture != null:
		var texture: Texture2D = node.texture
		var rect: Rect2 = node.get_rect()
		var size: Vector2 = texture.get_size()
		var frame_size := size / Vector2(node.hframes, node.vframes)
		var region: Rect2 = node.region_rect if node.region_enabled else Rect2(Vector2(node.frame_coords) * frame_size, frame_size)
		var u0 := region.position / size
		var u1 := region.end / size
		if node.flip_h:
			var swap := u0.x
			u0.x = u1.x
			u1.x = swap
		if node.flip_v:
			var swap := u0.y
			u0.y = u1.y
			u1.y = swap
		if texture is AtlasTexture:
			var atlas := texture as AtlasTexture
			u0 = (atlas.region.position + u0 * atlas.region.size) / atlas.atlas.get_size()
			u1 = (atlas.region.position + u1 * atlas.region.size) / atlas.atlas.get_size()
			texture = atlas.atlas
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([local * rect.position, local * Vector2(rect.end.x, rect.position.y), local * rect.end, local * Vector2(rect.position.x, rect.end.y)])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([u0, Vector2(u1.x, u0.y), u1, Vector2(u0.x, u1.y)])
		var color: Color = tint * node.self_modulate
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray([color, color, color, color])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		pieces.append({"mesh": mesh, "texture": texture})
	for child in node.get_children(): _sprites(child, local, tint, pieces)
