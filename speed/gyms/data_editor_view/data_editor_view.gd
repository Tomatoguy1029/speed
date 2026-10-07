## 確認用：データ編集ツールの画面を、ゲームの中で表示して撮る。
extends Control

func _ready() -> void:
	var panel = load("res://addons/speed_data_editor/data_editor_panel.gd").new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	panel.reload()
	var out := OS.get_cmdline_user_args()[0]
	for i in panel._cats.size():
		var label: String = panel._cats[i].label
		if label in ["config", "weapons", "enemies", "phases"]:
			panel._categories.select(i)
			panel._show(i)
			var first = panel._tree.get_root().get_first_child()
			if label != "config" and first != null:
				first.select(0)
			await get_tree().create_timer(0.3).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("editor_%s.png" % label))
	get_tree().quit()
