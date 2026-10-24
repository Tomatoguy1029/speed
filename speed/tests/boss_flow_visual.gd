## ボス編集Controlの描画確認。編集元へ保存しない。
extends SceneTree
func _initialize() -> void: call_deferred("exercise")
func exercise() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1100, 800)
	var panel = load("res://addons/boss_flow/editor.gd").new()
	panel.theme = ThemeDB.get_default_theme()
	var host := VBoxContainer.new()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	panel._picked("technique", "bite_thrust")
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.content/tests")
	root.get_texture().get_image().save_png("res://.content/tests/boss_editor.png")
	panel._edit_section(0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.content/tests/boss_section.png")
	panel._edit_coverage()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.content/tests/boss_coverage.png")
	panel.queue_free()
	await process_frame
	quit()
