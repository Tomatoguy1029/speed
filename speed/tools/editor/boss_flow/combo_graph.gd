@tool
extends VBoxContainer
signal changed(program: Dictionary)
signal inspected(step_path: Array)
var program: Dictionary = {}
var graph := GraphEdit.new()
var _selected := -1
var _type := OptionButton.new()
var _technique := OptionButton.new()
var _seconds := SpinBox.new()
var path: Array = []
var _moves: Array = []
var _clipboard: Array = []
var _drag_layout := {}
var _menu := PopupMenu.new()

func _at(value: Dictionary) -> Dictionary:
	var node := value
	for index in path:
		if index >= node.get("children", []).size():
			path.clear()
			return value
		node = node.children[index]
	return node

func _ready() -> void:
	var tools := HFlowContainer.new()
	add_child(tools)
	for title_text in ["技", "待機", "順次グループ", "並列グループ", "条件分岐"]: _type.add_item(title_text)
	tools.add_child(_type)
	tools.add_child(_technique)
	_seconds.step = 0.1
	_seconds.max_value = 100
	_seconds.tooltip_text = "待機時間（秒）"
	tools.add_child(_seconds)
	var seconds_unit := Label.new()
	seconds_unit.text = "秒"
	tools.add_child(seconds_unit)
	seconds_unit.hide()
	_type.item_selected.connect(func(index):
		_technique.visible = index == 0
		_seconds.visible = index == 1
		seconds_unit.visible = index == 1)
	_seconds.hide()
	var close_editor := Button.new()
	close_editor.text = "内部編集を閉じる"
	close_editor.pressed.connect(hide)
	tools.add_child(close_editor)
	var add := Button.new()
	add.text = "選んだ要素を追加"
	add.pressed.connect(_append)
	tools.add_child(add)
	var remove := Button.new()
	remove.text = "選択した要素を削除"
	remove.pressed.connect(func():
		if _selected >= 0 and _selected < _at(program).get("children", []).size():
			var copy := program.duplicate(true)
			_at(copy).children.remove_at(_selected)
			changed.emit(copy))
	tools.add_child(remove)
	var back := Button.new()
	back.text = "親のグループへ戻る"
	back.pressed.connect(func():
		if not path.is_empty(): path.pop_back()
		open(program, _moves))
	tools.add_child(back)
	for direction in [-1, 1]:
		var shift := Button.new()
		shift.text = "前に移動" if direction < 0 else "後ろに移動"
		shift.pressed.connect(func():
			var copy := program.duplicate(true)
			var nodes: Array = _at(copy).get("children", [])
			var other: int = _selected + direction
			if _selected >= 0 and other >= 0 and other < nodes.size():
				var temp = nodes[_selected]
				nodes[_selected] = nodes[other]
				nodes[other] = temp
				_selected = other
				changed.emit(copy))
		tools.add_child(shift)
	graph.custom_minimum_size = Vector2(280, 150)
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.node_selected.connect(func(id):
		_selected = String(id.name).trim_prefix("step_").to_int()
		inspected.emit(path + [_selected]))
	add_child(graph)
	graph.focus_mode = Control.FOCUS_ALL
	graph.get_menu_hbox().hide()
	var view_tools := HFlowContainer.new()
	add_child(view_tools)
	move_child(view_tools, graph.get_index())
	var display := MenuButton.new()
	display.text = "図の表示設定"
	view_tools.add_child(display)
	var display_menu := display.get_popup()
	for title_text in ["グリッドを表示", "ノードをグリッドに合わせる", "全体図を表示"]: display_menu.add_check_item(title_text)
	display_menu.add_item("このグループの要素を順番に整列")
	display_menu.about_to_popup.connect(func():
		for i in 3: display_menu.set_item_checked(i, [graph.show_grid, graph.snapping_enabled, graph.minimap_enabled][i]))
	display_menu.id_pressed.connect(_display_action)
	var zoom_label := Label.new()
	zoom_label.text = "拡大率"
	view_tools.add_child(zoom_label)
	var zoom := HSlider.new()
	zoom.min_value = 0.35
	zoom.max_value = 1.5
	zoom.step = 0.05
	zoom.value = 1.0
	zoom.custom_minimum_size.x = 80 * maxf(1.0, get_theme_default_font_size() / 14.0)
	zoom.value_changed.connect(func(value): graph.zoom = value)
	view_tools.add_child(zoom)
	var spacing_label := Label.new()
	spacing_label.text = "グリッド間隔"
	view_tools.add_child(spacing_label)
	var spacing := SpinBox.new()
	spacing.min_value = 1
	spacing.max_value = 256
	spacing.value = graph.snapping_distance
	spacing.value_changed.connect(func(value): graph.snapping_distance = int(value))
	view_tools.add_child(spacing)
	var help := Label.new()
	help.text = "複数選択・コピーに対応。グループをダブルクリックして中を編集"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)
	graph.begin_node_move.connect(func():
		_drag_layout.clear()
		for node in graph.get_children():
			if node is GraphNode: _drag_layout[String(node.name)] = node.position_offset)
	graph.end_node_move.connect(_move_end)
	graph.copy_nodes_request.connect(func(): command("copy"))
	graph.cut_nodes_request.connect(func(): command("cut"))
	graph.paste_nodes_request.connect(func(): command("paste"))
	graph.duplicate_nodes_request.connect(func(): command("duplicate"))
	graph.delete_nodes_request.connect(func(_ids): command("delete"))
	add_child(_menu)
	for text in ["コピー", "貼り付け", "複製", "選択した要素を削除"]: _menu.add_item(text)
	_menu.id_pressed.connect(func(i): command(["copy", "paste", "duplicate", "delete"][i]))
	graph.popup_request.connect(func(at):
		_menu.position = Vector2i(graph.get_screen_position() + at)
		_menu.popup())

func open(value: Dictionary, moves: Array) -> void:
	program = value
	_moves = moves
	_technique.clear()
	for move in moves:
		_technique.add_item(preload("res://tools/editor/boss_flow/technique_graph.gd").title_for(String(move.technique)))
		_technique.set_item_metadata(_technique.item_count - 1, String(move.technique))
	graph.clear_connections()
	for node in graph.get_children():
		if node is GraphNode:
			graph.remove_child(node)
			node.queue_free()
	var nodes: Array = _at(program).get("children", [])
	var next_x := 30.0
	for i in nodes.size():
		var step: Dictionary = nodes[i]
		var node := GraphNode.new()
		node.name = "step_" + str(i)
		node.title = preload("res://tools/editor/boss_flow/technique_graph.gd").title_for(String(step.id)) if step.get("type") == "action" else {"wait": "待機", "sequence": "順番に実行", "parallel": "同時に実行", "branch": "条件で分岐"}.get(step.get("type", ""), "技")
		node.position_offset = _at(program).get("layout", {}).get("step_" + str(i), Vector2(next_x, 50))
		var label := Label.new()
		label.text = "%s秒" % step.get("seconds", 0.0) if step.get("type", "") == "wait" else "技後の待ちまで実行" if step.get("type") == "action" else "ダブルクリックして内部を編集"
		node.add_child(label)
		node.set_slot(0, true, 0, Color.GRAY, true, 0, Color.GRAY)
		if step.get("type") == "action": node.self_modulate = preload("res://tools/editor/boss_flow/technique_graph.gd").TECHNIQUE_COLOR
		graph.add_child(node)
		next_x += node.get_combined_minimum_size().x + 40.0
		if step.get("type", "") in ["sequence", "parallel", "branch"]:
			node.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.double_click:
					path.append(i)
					open(program, _moves))
		if i > 0 and _at(program).get("type", "") != "parallel": graph.connect_node("step_" + str(i - 1), 0, node.name, 0)

func _append() -> void:
	var copy := program.duplicate(true)
	var target := _at(copy)
	if not target.has("children"): target.children = []
	var node: Dictionary
	match _type.selected:
		0: node = {"type": "action", "id": _technique.get_item_metadata(_technique.selected)}
		1: node = {"type": "wait", "seconds": _seconds.value}
		2: node = {"type": "sequence", "children": []}
		3: node = {"type": "parallel", "children": []}
		_: node = {"type": "branch", "condition": {"min": 0.0, "max": 600.0, "angle": 0.0, "half_angle": 180.0}, "children": [{"type": "sequence", "children": []}, {"type": "sequence", "children": []}]}
	target.children.append(node)
	changed.emit(copy)

func _selection() -> Array[int]:
	var result: Array[int] = []
	for node in graph.get_children():
		if node is GraphNode and node.selected: result.append(String(node.name).trim_prefix("step_").to_int())
	result.sort()
	return result

func _move_end() -> void:
	var copy := program.duplicate(true)
	var target := _at(copy)
	target.layout = {}
	for node in graph.get_children():
		if node is GraphNode: target.layout[String(node.name)] = node.position_offset
	if target.layout != _drag_layout: changed.emit(copy)
	_drag_layout.clear()

func command(action: String) -> void:
	var ids := _selection()
	if action in ["copy", "cut", "duplicate"]:
		_clipboard.clear()
		for id in ids: _clipboard.append(_at(program).children[id].duplicate(true))
		if action == "copy": return
	var copy := program.duplicate(true)
	var target := _at(copy)
	if action in ["delete", "cut"]:
		if ids.is_empty(): return
		ids.reverse()
		for id in ids: target.children.remove_at(id)
		target.erase("layout")
	elif action in ["paste", "duplicate"]:
		if _clipboard.is_empty(): return
		for item in _clipboard: target.children.append(item.duplicate(true))
	else: return
	var pasted_from: int = _at(program).get("children", []).size()
	changed.emit(copy)
	if action in ["paste", "duplicate"]: _select_range.call_deferred(pasted_from, target.children.size())

func _select_range(first: int, last: int) -> void:
	for node in graph.get_children():
		if node is GraphNode:
			var index := String(node.name).trim_prefix("step_").to_int()
			node.selected = index >= first and index < last

func _display_action(id: int) -> void:
	match id:
		0: graph.show_grid = not graph.show_grid
		1: graph.snapping_enabled = not graph.snapping_enabled
		2: graph.minimap_enabled = not graph.minimap_enabled
		3:
			var copy := program.duplicate(true)
			_at(copy).erase("layout")
			changed.emit(copy)
