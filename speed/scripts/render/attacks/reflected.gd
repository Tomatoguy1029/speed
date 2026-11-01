## REFLECTEDの弾の表示。
extends AttackVisual
const TAIL = Color("#ff84df")
const BODY = Color("#f45ec5")
const CORE = Color("#fff0fc")

func draw_shot(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> bool:
	var u := pr.hostile_vel[i].normalized()
	c.draw_line(pos - u * pr.hostile_r[i] * 3.0, pos, TAIL, pr.hostile_r[i] * 0.9)
	c.draw_circle(pos, pr.hostile_r[i], BODY)
	c.draw_circle(pos, pr.hostile_r[i] * 0.5, CORE)
	return true

## 尾・本体・芯を一度作り、半径と向きを値で受け取る。
static func setup_batch(batch: InstanceBatch) -> void:
	var vertices := PackedVector2Array([Vector2(-3,-0.45),Vector2(0,-0.45),Vector2(0,0.45),
		Vector2(-3,-0.45),Vector2(0,0.45),Vector2(-3,0.45)])
	var colors := PackedColorArray([TAIL,TAIL,TAIL,TAIL,TAIL,TAIL])
	var circle := InstanceBatch.circle_points(32)
	for disc in 2:
		var radius := 1.0 if disc==0 else 0.5
		var color := BODY if disc==0 else CORE
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
