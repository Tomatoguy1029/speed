## 本番と背景エディターで、同じ星の配置・色・大きさ・視差を使う。
extends RefCounted

static func create() -> InstanceBatch:
	var batch := InstanceBatch.new()
	batch.setup_polygon(InstanceBatch.circle_points(16))
	var mm := batch.multimesh
	mm.use_custom_data = true
	mm.instance_count = 400
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in mm.instance_count:
		var star := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(0.2, 1.0))
		mm.set_instance_transform_2d(i, Transform2D.IDENTITY)
		mm.set_instance_custom_data(i, Color(star.x, star.y, star.z, 0.0))
		mm.set_instance_color(i, Color(0.7, 0.8, 1.0, 0.25 + 0.5 * star.z))
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/background_stars.gdshader")
	batch.material = material
	return batch

static func update_view(batch: InstanceBatch, center: Vector2, half: Vector2, zoom: float) -> void:
	batch.material.set_shader_parameter("view_center", center)
	batch.material.set_shader_parameter("view_half", half)
	batch.material.set_shader_parameter("camera_zoom", zoom)
