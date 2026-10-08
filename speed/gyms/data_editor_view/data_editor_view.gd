## 確認用：データ編集ツールの画面を、ゲームの中で表示して撮る。
## 引数：保存先のフォルダ。
extends Control

func _ready() -> void:
	var panel = load("res://addons/speed_data_editor/data_editor_panel.gd").new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	panel.reload()
	var out := OS.get_cmdline_user_args()[0]
	var shots := [
		["config_all", func(m): return m.kind == "all"],
		["config_ship", func(m): return m.kind == "group" and m.group.name == "機体"],
		["weapons_table", func(m): return m.kind == "table" and m.cat.folder == "weapons"],
		["weapon_item", func(m): return m.kind == "item" and m.cat.folder == "weapons"],
		["enemy_item", func(m): return m.kind == "item" and str(m.res.get("id")) == "darter"],
		["phase_item", func(m): return m.kind == "item" and m.cat.folder == "phases"],
		["stage_item", func(m): return m.kind == "item" and m.cat.folder == "stages"],
		["trait_item", func(m): return m.kind == "item" and str(m.res.get("id")) == "T07"],
	]
	for s in shots:
		panel._select_in_nav(s[1])
		await _shot(out, s[0])
	panel._search.text = "ボス"
	panel._on_search()
	await _shot(out, "search")
	get_tree().quit()

func _shot(out: String, name_: String) -> void:
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("editor_%s.png" % name_))
