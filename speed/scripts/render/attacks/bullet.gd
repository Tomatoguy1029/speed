## 共通の弾のバッチで描く。
extends AttackVisual

## 弾の二重の円を一度作り、値だけをMultiMeshへ渡す。
static func setup_batch(batch: InstanceBatch) -> void:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var circle := InstanceBatch.circle_points(32)
	for disc in 2:
		var radius := 1.0 if disc==0 else 0.5
		var color := Color("#ff3b3b") if disc==0 else Color("#3a0a0a")
		for i in circle.size():
			vertices.append(Vector2.ZERO)
			vertices.append(circle[i]*radius)
			vertices.append(circle[(i+1)%circle.size()]*radius)
			for j in 3: colors.append(color)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	batch._setup_mesh(mesh)
