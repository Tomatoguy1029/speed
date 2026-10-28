## 弾シーンの固定の図形を、実行時にまとめて描けるMeshへ変換する。
@tool
extends RefCounted

static func _polygons(node: Node, transform: Transform2D, vertices: PackedVector2Array, colors: PackedColorArray) -> void:
	var local: Transform2D = transform * node.transform if node is Node2D else transform
	if node is Polygon2D and node.polygon.size() >= 3:
		var indices := Geometry2D.triangulate_polygon(node.polygon)
		for index in indices:
			vertices.append(local * node.polygon[index])
			colors.append(node.color * node.modulate)
	for child in node.get_children(): _polygons(child, local, vertices, colors)

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
	for file in DirAccess.get_files_at("res://scenes/attacks"):
		if not file.ends_with(".tscn"): continue
		var path := "res://scenes/attacks/" + file
		var scene := load(path) as PackedScene
		if scene == null: return ERR_INVALID_DATA
		var source := scene.instantiate()
		var layers := {}
		for phase in ["Flight", "Hit", "Fade"]:
			var node := source.get_node_or_null(phase)
			if node != null: layers[phase] = _mesh(node)
		looks[path] = layers
		source.free()
	library.set_meta("looks", looks)
	return ResourceSaver.save(library, output.path_join("attack_visuals.res"))
