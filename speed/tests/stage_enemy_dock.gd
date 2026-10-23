## ドックの有効化・内容変更でエディター全体の最小高さを押し広げない。
## godot --headless --editor --path speed --script res://tests/stage_enemy_dock.gd
@tool
extends SceneTree

const PANEL := preload("res://addons/stage_enemy_tuning/dock_panel.gd")
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func frames() -> void:
	for i in 8: await process_frame

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func find_panel(node: Node) -> Control:
	if node.get_script() == PANEL: return node as Control
	for child in node.get_children():
		var found := find_panel(child)
		if found != null: return found
	return null

func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	while EditorInterface.get_resource_filesystem().is_scanning(): await process_frame
	root.size = Vector2i(1280, 720)
	var base := EditorInterface.get_base_control()
	if EditorInterface.is_plugin_enabled("stage_enemy_tuning"):
		EditorInterface.set_plugin_enabled("stage_enemy_tuning", false)
	await frames()
	var host := base.find_child("DockHSplitMain", true, false) as Control
	var previous_height := host.get_combined_minimum_size().y
	EditorInterface.set_plugin_enabled("stage_enemy_tuning", true)
	await frames()
	var dock := base.find_child("ステージ敵調整", true, false) as Control
	check(dock != null, "有効化したドックがある")
	if dock != null:
		var tabs := dock.get_parent().get_parent() as TabContainer
		tabs.current_tab = tabs.get_tab_idx_from_control(dock.get_parent())
		await frames()
		var panel := find_panel(dock)
		check(panel != null, "ドック用の敵調整パネルを使う")
		for category in ["耐久・装甲", "範囲・形状"]:
			panel._select_enemy("telescope")
			panel._category = category
			panel._refresh_rows()
			await frames()
			print("[stage_enemy_dock] category=", category, " minimum=", dock.get_combined_minimum_size(), " fields=", panel._scroll.size)
			check(dock.get_combined_minimum_size().y <= 320, "長い説明と多数の項目をドック内に収める")
			check(dock.get_combined_minimum_size().x <= 280, "内容がドックの最小幅を押し広げない")
			check(host.get_combined_minimum_size().y <= maxf(previous_height, 400), "下部バーを押し出す最小高さを親へ伝えない")
			check(panel._scroll.size.y > 0, "数値一覧の表示領域が潰れない")
			for key in panel._row_controls:
				check(panel.FIELDS.belongs(key, category), "選択した分類だけを表示する")
			check(panel._category_picker.get_item_metadata(panel._category_picker.selected) == category, "表示した分類と選択欄を一致させる")
		panel._scroll.scroll_vertical = 100000
		await frames()
		var bar: VScrollBar = panel._scroll.get_v_scroll_bar()
		check(bar.value + bar.page >= bar.max_value - 1, "スクロールで最後の項目へ到達できる")
		check(not panel._scroll.get_h_scroll_bar().visible, "横スクロールを要求しない")
		check(not panel.is_dirty(), "表示と分類の切替ではステージデータを変えない")
		panel._search.text = "__no_matching_field__"
		panel._search.text_changed.emit(panel._search.text)
		await frames()
		check(panel._row_controls.is_empty(), "一致する項目がない検索結果を表示できる")
		panel._search.clear()
		panel._search.text_changed.emit("")
		await frames()
		check(not panel._row_controls.is_empty(), "検索を消すと選択分類の項目へ戻る")
	EditorInterface.set_plugin_enabled("stage_enemy_tuning", false)
	await frames()
	print("[stage_enemy_dock] %d failures" % failed)
	quit(1 if failed else 0)
