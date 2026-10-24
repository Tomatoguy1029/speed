@tool
extends GraphEdit
signal picked(kind: String, id: String)
signal layout_changed
signal edit_requested(before: Dictionary, after: Dictionary, title: String)
var rules: Resource
var clipboard: Array = []
var align_enabled := true
var _drag_before := {}
var _updating := false
var _guides := PackedVector2Array()
var _popup := PopupMenu.new()
const TITLES := {"bite_thrust": "噛みつき", "bite_sweep": "薙ぎ払い", "wind_band": "風の帯", "wind_blades": "風刃", "rubble_lump": "瓦礫の塊", "rubble_fan": "瓦礫の散弾", "beam_fixed": "固定ビーム", "beam_bolt": "ビーム弾", "thunder_headbutt": "雷の頭突き", "thunder_drop": "落雷", "tornado": "瓦礫竜巻", "debris_shatter": "瓦礫砕き", "beam_pincer": "挟撃ビーム", "north": "同時噛みつき", "sequence": "順番噛みつき", "curve": "曲線ビーム", "swarm": "連続飛びかかり", "grid": "格子ビーム"}

static func title_for(id: String) -> String:
	if id.begins_with("combo_"):
		var parts := id.split("_copy_")
		return "コンボ" + parts[0].trim_prefix("combo_") + ("（複製" + parts[-1] + "）" if parts.size() > 1 else "")
	return TITLES.get(id, id)

static func node_title(value: Resource, id: String) -> String:
	var source: String = value.source_for(id)
	return title_for(source) + ("（別条件" + id.trim_prefix(source + "_copy_") + "）" if source != id else "")

func _ready() -> void:
	custom_minimum_size = Vector2(280, 160)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	right_disconnects = true
	connection_lines_thickness = 1.5
	node_selected.connect(func(node):
		if node.name == &"choose": picked.emit("coverage", "")
		else: picked.emit("technique", String(node.name)))
	gui_input.connect(_input_graph)
	begin_node_move.connect(_move_begin)
	end_node_move.connect(_move_end)
	copy_nodes_request.connect(func(): command("copy"))
	cut_nodes_request.connect(func(): command("cut"))
	paste_nodes_request.connect(func(): command("paste"))
	duplicate_nodes_request.connect(func(): command("duplicate"))
	delete_nodes_request.connect(func(ids): _delete(ids))
	connection_request.connect(func(from, _port, to, _input):
		if String(from) == "choose": _connect(String(to), true))
	disconnection_request.connect(func(_from, _port, to, _input): _connect(String(to), false))
	get_menu_hbox().hide()
	add_child(_popup)
	for text in ["コピー", "貼り付け", "複製", "選択ノードを削除", "選択ノードを縦に等間隔にする"]: _popup.add_item(text)
	_popup.id_pressed.connect(func(i): command(["copy", "paste", "duplicate", "delete", "align"][i]))
	popup_request.connect(func(at):
		_popup.position = Vector2i(get_screen_position() + at)
		_popup.popup())

func make_display_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	var display := MenuButton.new()
	display.text = "配置と表示"
	bar.add_child(display)
	var spacing_label := Label.new()
	spacing_label.text = "グリッド間隔"
	bar.add_child(spacing_label)
	var spacing := SpinBox.new()
	spacing.min_value = 1
	spacing.max_value = 256
	spacing.value = snapping_distance
	spacing.value_changed.connect(func(value): snapping_distance = int(value))
	bar.add_child(spacing)
	var menu := display.get_popup()
	menu.add_check_item("グリッドを表示", 0)
	menu.add_check_item("ノードをグリッドに合わせる", 1)
	menu.add_check_item("全体図を表示", 2)
	menu.add_check_item("近くのノードに位置を合わせる", 3)
	menu.add_item("選択ノードを縦に等間隔にする", 4)
	menu.add_item("全ノードを縦に整列する", 5)
	menu.about_to_popup.connect(func():
		for i in 4: menu.set_item_checked(i, [show_grid, snapping_enabled, minimap_enabled, align_enabled][i]))
	menu.id_pressed.connect(_display_action)
	return bar

func _display_action(id: int) -> void:
	match id:
		0: show_grid = not show_grid
		1: snapping_enabled = not snapping_enabled
		2: minimap_enabled = not minimap_enabled
		3: align_enabled = not align_enabled
		4: command("align")
		5: command("align_all")

func focus_technique(id: String) -> void:
	var node := get_node_or_null(NodePath(id)) as GraphNode
	if node != null: scroll_offset = (node.position_offset - Vector2(180, 70)) * zoom

func snapshot() -> Dictionary:
	return {"conditions": rules.conditions.duplicate(true), "layout": rules.layout.duplicate(true), "graph_nodes": rules.graph_nodes.duplicate(true), "combos": rules.combos.duplicate(true), "costs": rules.costs.duplicate(true)}

func show_rules(value: Resource) -> void:
	rules = value
	_updating = true
	clear_connections()
	for child in get_children():
		if child is GraphNode:
			remove_child(child)
			child.queue_free()
	var scale_factor := maxf(1.0, get_theme_default_font_size() / 14.0)
	var source := _add_node("choose", "行動選択", rules.layout.get("choose", Vector2(30, 100) * scale_factor), false)
	var x := source.position_offset.x + source.get_combined_minimum_size().x + 100 * scale_factor
	var y := 20.0 * scale_factor
	for id in rules.node_ids():
		var settings: Dictionary = rules.graph_nodes.get(id, {})
		var node := _add_node(id, node_title(rules, id), rules.layout.get(id, Vector2(x, y)), true)
		y += node.get_combined_minimum_size().y + 28 * scale_factor
		if settings.get("connected", true): connect_node("choose", 0, id, 0)
	_updating = false

func _add_node(id: String, title_text: String, at: Vector2, input: bool) -> GraphNode:
	var node := GraphNode.new()
	node.name = id
	node.title = title_text
	var label := Label.new()
	label.text = "技の性能" if input else "条件 → 技"
	node.add_child(label)
	node.set_slot(0, input, 0, Color(0.6, 0.7, 0.8), not input, 0, Color(0.6, 0.7, 0.8))
	add_child(node)
	node.position_offset = at
	node.position_offset_changed.connect(func():
		if not _updating and not _drag_before.is_empty(): _assist(node))
	return node

func selected_ids() -> Array[String]:
	var ids: Array[String] = []
	for node in get_children():
		if node is GraphNode and node.selected and node.name != &"choose": ids.append(String(node.name))
	return ids

func positions() -> Dictionary:
	var result := {}
	for node in get_children():
		if node is GraphNode: result[String(node.name)] = node.position_offset
	return result

func _move_begin() -> void:
	_drag_before = positions()

func _move_end() -> void:
	if _drag_before.is_empty(): return
	var before := snapshot()
	before.layout = _drag_before.duplicate(true)
	var selected := selected_ids()
	if selected.size() == 1 and align_enabled and not Input.is_key_pressed(KEY_ALT): _settle(get_node(NodePath(selected[0])))
	var after := snapshot()
	after.layout = positions()
	_drag_before.clear()
	_guides.clear()
	queue_redraw()
	if before.layout != after.layout: edit_requested.emit(before, after, "ノードを移動")

func _assist(node: GraphNode) -> void:
	if not align_enabled or Input.is_key_pressed(KEY_ALT) or selected_ids().size() > 1: return
	var next := node.position_offset
	_guides.clear()
	var scale_factor := maxf(1.0, get_theme_default_font_size() / 14.0)
	var threshold := 12.0 * scale_factor / zoom
	var gap := 28.0 * scale_factor
	for other in get_children():
		if not other is GraphNode or other == node or other.selected: continue
		if absf(next.x - other.position_offset.x) < threshold:
			next.x = other.position_offset.x
			_guides.append_array(PackedVector2Array([Vector2(next.x, -10000), Vector2(next.x, 10000)]))
		for y in [other.position_offset.y, other.position_offset.y + other.size.y + gap, other.position_offset.y - node.size.y - gap]:
			if absf(next.y - y) < threshold:
				next.y = y
				_guides.append_array(PackedVector2Array([Vector2(-10000, y), Vector2(10000, y)]))
	_updating = true
	node.position_offset = next
	_updating = false
	queue_redraw()

func _settle(node: GraphNode) -> void:
	var gap := 28.0 * maxf(1.0, get_theme_default_font_size() / 14.0)
	var rect := Rect2(node.position_offset, node.size).grow(10.0)
	var collision := false
	var ys := [node.position_offset.y]
	for other in get_children():
		if not other is GraphNode or other == node or other.selected: continue
		if rect.intersects(Rect2(other.position_offset, other.size)): collision = true
		ys.append(other.position_offset.y + other.size.y + gap)
		ys.append(other.position_offset.y - node.size.y - gap)
	if not collision: return
	ys.sort_custom(func(a, b): return absf(a - node.position_offset.y) < absf(b - node.position_offset.y))
	for y in ys:
		var candidate := Rect2(Vector2(node.position_offset.x, y), node.size).grow(10.0)
		var free := true
		for other in get_children():
			if other is GraphNode and other != node and not other.selected and candidate.intersects(Rect2(other.position_offset, other.size)): free = false
		if free:
			node.position_offset.y = y
			return

func _draw() -> void:
	for i in range(0, _guides.size(), 2): draw_line(_guides[i] * zoom - scroll_offset, _guides[i + 1] * zoom - scroll_offset, Color(1.0, 0.75, 0.2, 0.8), 1.0)

func _connect(id: String, connected: bool) -> void:
	if not rules.node_ids().has(id): return
	var before := snapshot()
	var after := snapshot()
	if not after.graph_nodes.has(id): after.graph_nodes[id] = {"source": rules.source_for(id)}
	after.graph_nodes[id].connected = connected
	edit_requested.emit(before, after, "条件線を接続" if connected else "条件線を外す")

func _delete(ids: Array) -> void:
	if ids.is_empty(): return
	var before := snapshot()
	var after := snapshot()
	for raw in ids:
		var id := String(raw)
		if id == "choose": continue
		if not after.graph_nodes.has(id): after.graph_nodes[id] = {"source": rules.source_for(id)}
		after.graph_nodes[id].hidden = true
		after.graph_nodes[id].connected = false
	edit_requested.emit(before, after, "選択ノードを削除")

func command(action: String) -> void:
	var ids := selected_ids()
	if action in ["copy", "cut", "duplicate"]:
		clipboard.clear()
		for id in ids:
			clipboard.append({"id": id, "source": rules.source_for(id), "gate": rules.conditions.get(id, {}).duplicate(true), "position": get_node(NodePath(id)).position_offset, "size": get_node(NodePath(id)).size, "connected": rules.graph_nodes.get(id, {}).get("connected", true)})
			if rules.combos.has(rules.source_for(id)):
				clipboard[-1].program = rules.combos[rules.source_for(id)].duplicate(true)
				clipboard[-1].cost = rules.costs.get(rules.source_for(id), 2.0)
		if action == "cut": _delete(ids)
		if action != "duplicate": return
	if action in ["paste", "duplicate"]:
		if clipboard.is_empty(): return
		var before := snapshot()
		var after := snapshot()
		var pasted: Array[String] = []
		var offset := _paste_offset()
		for entry in clipboard:
			var n := 1
			var id: String = entry.source + "_copy_" + str(n)
			while after.graph_nodes.has(id) or rules.node_ids().has(id) or after.combos.has(id):
				n += 1
				id = entry.source + "_copy_" + str(n)
			var source: String = entry.source
			if entry.has("program"):
				after.combos[id] = entry.program.duplicate(true)
				after.costs[id] = entry.cost
				source = id
			after.graph_nodes[id] = {"source": source, "connected": entry.connected}
			after.conditions[id] = entry.gate.duplicate(true)
			after.layout[id] = entry.position + offset
			pasted.append(id)
		edit_requested.emit(before, after, "ノードを貼り付け")
		_select_nodes.call_deferred(pasted)
		focus_technique.call_deferred(pasted[0])
	elif action == "delete": _delete(ids)
	elif action in ["align", "align_all"]:
		if action == "align_all": ids = rules.node_ids()
		if ids.is_empty(): return
		ids.sort_custom(func(a, b): return get_node(NodePath(a)).position_offset.y < get_node(NodePath(b)).position_offset.y)
		var before := snapshot()
		var after := snapshot()
		var first: GraphNode = get_node(NodePath(ids[0]))
		var y := first.position_offset.y
		for id in ids:
			var node: GraphNode = get_node(NodePath(id))
			after.layout[id] = Vector2(first.position_offset.x, y)
			y += node.size.y + 28.0 * maxf(1.0, get_theme_default_font_size() / 14.0)
		edit_requested.emit(before, after, "ノードを等間隔に整列")

func _select_nodes(ids: Array) -> void:
	for node in get_children():
		if node is GraphNode: node.selected = String(node.name) in ids

func _input_graph(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		var connection := get_closest_connection_at_point(event.position, 10.0)
		if not connection.is_empty(): picked.emit("condition", String(connection.to_node))

func _paste_offset() -> Vector2:
	var offset := Vector2(70, 70)
	for attempt in 128:
		var overlaps := false
		for entry in clipboard:
			var pasted := Rect2(entry.position + offset, entry.get("size", Vector2(180, 100))).grow(12.0)
			for node in get_children():
				if node is GraphNode and pasted.intersects(Rect2(node.position_offset, node.size)): overlaps = true
		if not overlaps: return offset
		offset += Vector2(64, 24)
	return offset
