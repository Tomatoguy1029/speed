## 確認用：InstanceBatch（MultiMesh）がレンダラごとに描けるか。
extends Node2D

func _ready() -> void:
	var cam := Camera2D.new()
	add_child(cam)
	cam.make_current()
	for k in 3:
		var b := InstanceBatch.new()
		b.setup_polygon(InstanceBatch.circle_points(12))
		if k == 1:
			var m := ShaderMaterial.new()
			m.shader = load("res://shaders/enemy.gdshader")
			b.material = m
		add_child(b)
		b.begin()
		for i in 5:
			b.add(Vector2(-300 + i * 120, -150 + k * 150), 0.0, 30.0, Color(0.5, 0.8, 1.0))
		if k == 2:
			# 2つ目のフレームで数を変える
			pass
		b.end()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
