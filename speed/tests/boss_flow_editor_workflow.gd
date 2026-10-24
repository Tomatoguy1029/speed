## 区間・条件選択・技を分離し、技の一覧から直接編集・再生へ進める。
extends SceneTree

var failures := 0
var finished := false

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	print("[boss-editor-workflow] ", "PASS " if ok else "FAIL ", message)
	if not ok: failures += 1

func _timeout() -> void:
	if finished: return
	push_error("[boss-editor-workflow] FAIL editor exercise timed out")
	quit(1)

func _texts(node: Node, outside_graph := false) -> PackedStringArray:
	var result := PackedStringArray()
	if node is Control and not node.is_visible_in_tree(): return result
	if outside_graph and node is GraphEdit: return result
	if node is Label: result.append(node.text)
	elif node is BaseButton: result.append(node.text)
	for child in node.get_children(): result.append_array(_texts(child, outside_graph))
	return result

func _has(texts: PackedStringArray, fragment: String) -> bool:
	for value in texts:
		if fragment in value: return true
	return false

func _preview_count(node: Node) -> int:
	var count := 0
	if node is Control and not node.is_visible_in_tree(): return 0
	var script: Script = node.get_script()
	if script != null and "preview" in script.resource_path and node is Control: count += 1
	for child in node.get_children(): count += _preview_count(child)
	return count

func _settle() -> void:
	for frame in 6: await process_frame

func exercise() -> void:
	create_timer(20.0).timeout.connect(_timeout)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 900)
	var host := VBoxContainer.new()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel = load("res://tools/editor/boss_flow/editor.gd").new()
	panel.theme = ThemeDB.get_default_theme()
	host.add_child(panel)
	await _settle()

	var flow_graph = panel.get("flow_graph")
	check(flow_graph is GraphEdit and flow_graph.is_visible_in_tree(), "the upper battle flow is a visible node editor")
	if flow_graph is GraphEdit:
		var section_nodes: Array = flow_graph.get_children().filter(func(node): return node is GraphNode)
		check(section_nodes.size() >= panel.flow.sections.size(), "every battle section has a selectable node")
		check(flow_graph.get_global_rect().end.y <= panel.graph.get_global_rect().position.y + 1.0, "the section graph stays above the separate technique graph")

	var forbidden_options := PackedStringArray(["技の性能", "発動条件", "区間の選択割合", "同時攻撃の禁止"])
	var universal_selector := false
	for node in panel.find_children("*", "OptionButton", true, false):
		if not node.is_visible_in_tree(): continue
		var options := PackedStringArray()
		for index in node.item_count: options.append(node.get_item_text(index))
		if options.has(forbidden_options[0]) and options.has(forbidden_options[2]): universal_selector = true
	check(not universal_selector, "there is no universal selector mixing technique and section settings")

	var graph: GraphEdit = panel.graph
	check(graph.get_global_rect().position.y - flow_graph.get_global_rect().end.y <= 24.0, "only the resize divider separates the section and technique canvases")
	var add_menu: MenuButton
	for node in graph.find_children("*", "MenuButton", true, false):
		if "追加" in node.text: add_menu = node
	check(add_menu != null and not add_menu.flat, "technique creation is an explicit menu inside its own canvas")
	if add_menu != null:
		var groups: int = panel.rules.condition_groups.size()
		add_menu.get_popup().id_pressed.emit(0)
		await _settle()
		check(panel.rules.condition_groups.size() == groups + 1 and panel._inspector_mode == 5, "the canvas add menu creates and selects a condition-selection hub")
		panel.undo_edit()
		await _settle()
		check(panel.rules.condition_groups.size() == groups, "the canvas creation menu participates in undo")
	check(not _has(_texts(panel), "グリッド間隔"), "the workspace does not expose an unnecessary grid interval field")
	var splitter := graph.get_parent() as VSplitContainer
	check(splitter != null, "the technique canvas directly shares the resize divider with the section area")
	if splitter != null:
		var before_height: float = flow_graph.size.y
		var before_bottom: float = graph.size.y
		var before_offset := splitter.split_offset
		splitter.split_offset += 60
		await _settle()
		check(flow_graph.size.y > before_height and graph.size.y < before_bottom, "moving the divider grows the section canvas and shrinks the technique canvas")
		splitter.split_offset = before_offset
		await _settle()
	var hubs := ["choose_normal", "choose_combo", "choose_major"]
	for id in hubs: check(graph.get_node_or_null(NodePath(id)) is GraphNode, "the technique overview has a separate " + id + " hub")
	var columns := {}
	var technique_nodes: Array[GraphNode] = []
	for id in panel.rules.node_ids():
		var node := graph.get_node_or_null(NodePath(id)) as GraphNode
		if node == null: continue
		technique_nodes.append(node)
		columns[roundi(node.position_offset.x)] = true
	check(columns.size() >= 3, "techniques are arranged in multiple category columns")
	check(technique_nodes.size() == panel.rules.node_ids().size(), "the overview retains every technique")
	var graph_area := Rect2(Vector2.ZERO, graph.size).grow(4.0)
	var all_visible := true
	for node in technique_nodes:
		var visible_rect := Rect2(node.position_offset * graph.zoom - graph.scroll_offset, node.size * graph.zoom)
		if not graph_area.encloses(visible_rect): all_visible = false
	check(all_visible, "the default overview fits all techniques in one screen")
	var wires_complete := true
	for editor in [flow_graph, graph]:
		for connection in editor.get_connection_list():
			var source: GraphNode = editor.get_node(NodePath(connection.from_node))
			var target: GraphNode = editor.get_node(NodePath(connection.to_node))
			var from: Vector2 = (source.position_offset + source.get_output_port_position(0)) * editor.zoom
			var to: Vector2 = (target.position_offset + target.get_input_port_position(0)) * editor.zoom
			var line: PackedVector2Array = editor.get_connection_line(from, to)
			if line.size() < 2 or not line[-1].is_equal_approx(to):
				wires_complete = false
				print("[boss-editor-workflow] missing route ", connection.from_node, " -> ", connection.to_node)
	check(wires_complete, "every visible connection has a complete route between its ports")

	var bite := graph.get_node_or_null("bite_thrust") as GraphNode
	check(bite != null and _preview_count(bite) > 0, "a technique node contains its own range preview")
	check(bite != null and _has(_texts(bite), "再生"), "a technique can be played from its node")
	panel._picked("technique", "bite_thrust")
	await _settle()
	var text := _texts(panel, true)
	check(_has(text, "最大距離") and _has(text, "噛みつきのダメージ"), "selecting a technique directly exposes its trigger condition and performance")
	check(_preview_count(panel) > _preview_count(graph), "the selected technique has a detailed range preview")
	check(not _has(text, "単独攻撃の割合") and not _has(text, "今回の消費上限") and not _has(text, "禁止ペアを追加"), "technique editing does not expose section probability, cap or forbidden pairs")

	panel._edit_section(0)
	await _settle()
	text = _texts(panel, true)
	check(_has(text, "単独攻撃の割合") and _has(text, "今回の消費上限"), "selecting a section exposes its probability and consumption cap")
	check(_has(text, "禁止ペア") or _has(text, "同時攻撃の禁止"), "forbidden simultaneous attacks belong to the selected section")
	check(not _has(text, "噛みつきのダメージ") and not _has(text, "最大距離"), "section editing does not expose technique performance or trigger distances")

	var normal_hub := graph.get_node_or_null("choose_normal") as GraphNode
	if normal_hub != null:
		graph.node_selected.emit(normal_hub)
		await _settle()
		text = _texts(panel, true)
		check(_has(text, "範囲") or _has(text, "カバー"), "a condition-selection hub exposes its coverage")
		check(not _has(text, "噛みつきのダメージ") and not _has(text, "単独攻撃の割合"), "the condition-selection hub keeps technique and section settings separate")
		check(_has(text, "ノード名") and _has(text, "技の接続先を変更"), "the selected condition hub exposes its own name and technique membership")
		check(panel._coverage_gates("wind_band").is_empty(), "the bite hub coverage does not include unrelated wind techniques")
		var name_field: LineEdit
		for field in panel._fields.get_children():
			if field is LineEdit: name_field = field
		if name_field != null:
			var old_name: String = panel.rules.condition_groups.choose_normal.title
			name_field.grab_focus()
			name_field.text = "近距離の選択"
			name_field.text_submitted.emit(name_field.text)
			panel.undo_edit()
			check(panel.rules.condition_groups.choose_normal.title == old_name, "undoing a hub name while editing its field does not reapply the changed name")

	panel.queue_free()
	await process_frame
	finished = true
	print("[boss-editor-workflow] failures=", failures)
	quit(1 if failures else 0)
