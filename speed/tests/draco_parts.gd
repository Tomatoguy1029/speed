## Tail assets retain their order, endpoint and articulation on curved spines.
extends Node2D
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	var parts := preload("res://scripts/bosses/draco_parts.gd").new()
	add_child(parts)
	var points := PackedVector2Array()
	for i in 129:
		var t := i / 128.0
		points.append(Vector2(-t * 1500.0, sin(t * TAU) * 180.0))
	parts.pose(points, 154.0, 1.35)
	var tip: Sprite2D = parts._segments[-1]
	var joint: Sprite2D = parts._segments[-2]
	check(tip.get_meta(&"part") == &"tail_tip" and joint.get_meta(&"part") == &"tail_joint", "尾の最後の2節に専用パーツを使う")
	check(tip.position.distance_to(points[-1]) < 0.01, "山形の尾先を背骨の終端へ置く")
	check(tip.texture.get_width() == 40 and joint.texture.get_width() == 48, "菱形を付け根、右端の山形を尾先として使う")
	var tangent := (points[-1] - points[-2]).normalized()
	check(Vector2.UP.rotated(tip.rotation).dot(tangent) > 0.98, "尾先の尖った側を終端の接線へ向ける")
	check(tip.offset.y == tip.texture.get_height() * 0.5, "尾先の尖端を配置支点へ合わせる")
	for pair in parts.TEXTURES.values():
		var diffuse: Image = pair[0].get_image()
		var normal: Image = pair[1].get_image()
		check(diffuse.get_size() == normal.get_size(), "色と法線の寸法を合わせる")
		for y in diffuse.get_height():
			for x in diffuse.get_width():
				check(diffuse.get_pixel(x, y).a == normal.get_pixel(x, y).a, "色と法線の透明度を保持する")
	check(parts._arms.size() == 4 and parts._claws.size() == 4, "前後左右に計4本の四肢と手足先を配置する")
	check(parts._arms[0].scale.x * parts._arms[1].scale.x < 0.0, "左右の腕を鏡像で組み立てる")
	check(parts._arms[0].position.distance_to(parts._arms[2].position) > 500.0, "前腕と後脚を胴の前後に分ける")
	check(parts.TEXTURES[&"arm"][0].get_size() == Vector2(33, 37), "更新された大きい腕を使う")
	for i in 4:
		check(parts._arms[i].z_index == parts._segments[0].z_index and parts._claws[i].z_index == parts._segments[0].z_index, "戦闘背景の上で四肢を胴と同じ層に描く")
		var wrist: Vector2 = parts.to_local(parts._arms[i].to_global(parts.ARM_WRIST - parts.ARM_ROOT))
		check(parts._claws[i].position.distance_to(wrist) < 0.01, "手先を腕の末端へ接続する")
	var straight := PackedVector2Array([Vector2.ZERO, Vector2(-1500, 0)])
	parts.pose(straight, 154.0, 1.35)
	for i in 4:
		check(parts._claws[i].position.x > parts._arms[i].position.x, "腕と手足先を頭側へ向ける")
	parts.pose(points, 154.0, 1.35)
	var before: float = parts._segments[-1].rotation
	points[-1] += Vector2(0, 100)
	parts.pose(points, 154.0, 1.35)
	check(not is_equal_approx(parts._segments[-1].rotation, before), "先端の曲がりで尾先の向きも変わる")
	parts.pose(points, 154.0, 1.35, 0.0)
	check(not parts.visible, "消滅時に全パーツを隠す")
	parts.pose(points, 154.0, 1.35)
	parts.position = Vector2(1040, 290)
	parts.scale = Vector2.ONE * 0.58
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("DRACO_CAPTURE"))
	parts.free()
	print("[draco_parts] %d failures" % failed)
	get_tree().quit(1 if failed else 0)

func _draw() -> void:
	var form = preload("res://scripts/bosses/draco_form.gd")
	for at in [Vector2(10000, 10000), Vector2(100000, 100000)]:
		for size in [0.011, 0.02, 0.05, 0.1, 10.0]:
			form.star(self, at, size, Color.WHITE)
