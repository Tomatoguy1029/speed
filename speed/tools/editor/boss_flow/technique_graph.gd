@tool
extends GraphEdit
signal picked(kind: String, id: String)
signal play_requested(id: String)
signal layout_changed
signal edit_requested(before: Dictionary, after: Dictionary, title: String)
var rules: Resource
var clipboard: Array = []
var align_enabled := true
var _drag_before := {}
var _updating := false
var _guides := PackedVector2Array()
var _popup := PopupMenu.new()
var _reroute_pending := false
const TITLES := {"bite":"噛みつき","tail_sweep":"尻尾の薙ぎ払い","star_fan":"星弾の扇","tail_slam":"尻尾の叩きつけ","breath":"薙ぎ払いブレス","meteor":"隕石投射","leap":"飛びかかり噛みつき","rifts":"三本爪の亀裂","picaro_wall":"ピカロ隊列と光の矢","clones":"全身複製","inhale":"吸引と吐き出し","spiral":"螺旋収縮","charge": "突進", "return_charge": "往復突進", "sweep": "角の薙ぎ払い", "kick": "後ろ蹴り", "lance": "光の槍", "combo": "突進から薙ぎ払い", "bite_thrust": "噛みつき", "bite_sweep": "薙ぎ払い", "wind_band": "風の帯", "wind_blades": "風刃", "rubble_lump": "瓦礫の塊", "rubble_fan": "瓦礫の散弾", "beam_fixed": "固定ビーム", "beam_bolt": "ビーム弾", "thunder_headbutt": "雷の頭突き", "thunder_drop": "落雷", "tornado": "瓦礫竜巻", "debris_shatter": "瓦礫砕き", "beam_pincer": "挟撃ビーム", "north": "同時噛みつき", "sequence": "順番噛みつき", "curve": "曲線ビーム", "swarm": "連続飛びかかり", "grid": "格子ビーム"}

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
	zoom_min = 0.2
	minimap_enabled = false
	connection_lines_thickness = 1.5
	node_selected.connect(func(node):
		if rules.condition_groups.has(String(node.name)): picked.emit("coverage", String(node.name))
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
		if rules.condition_groups.has(String(from)) and rules.node_ids().has(String(to)): assign_group(String(to), String(from)))
	disconnection_request.connect(func(_from, _port, to, _input): _connect(String(to), false))
	get_menu_hbox().hide()
	resized.connect(func():
		if rules != null and rules.layout.is_empty(): fit_all.call_deferred())
	add_child(_popup)
	for text in ["コピー", "貼り付け", "複製", "選択ノードを削除", "選択ノードを縦に等間隔にする"]: _popup.add_item(text)
	_popup.id_pressed.connect(func(i): command(["copy", "paste", "duplicate", "delete", "align"][i]))
	popup_request.connect(func(at):
		_popup.position = Vector2i(get_screen_position() + at)
		_popup.popup())

func make_toolbar(add_combo: Callable) -> void:
	var overlay := PanelContainer.new()
	overlay.name = "TechniqueTools"
	overlay.position = Vector2(8, 8)
	add_child(overlay)
	var bar := HBoxContainer.new()
	overlay.add_child(bar)
	var label := Label.new()
	label.text = "技・条件"
	bar.add_child(label)
	var add := MenuButton.new()
	add.flat = false
	add.text = "＋ 追加"
	add.get_popup().add_item("条件選択を追加", 0)
	add.get_popup().add_item("コンボ技を作成", 1)
	add.get_popup().id_pressed.connect(func(id):
		if id == 0: add_group()
		else: add_combo.call())
	bar.add_child(add)
	var display := MenuButton.new()
	display.flat = false
	display.text = "表示・整列"
	bar.add_child(display)
	var menu := display.get_popup()
	menu.add_item("全体を表示", 5)
	menu.add_item("条件選択ごとに整列", 6)
	menu.add_item("拡大率 100%", 7)
	menu.add_item("拡大率 50%", 8)
	menu.add_separator()
	menu.add_check_item("グリッドを表示", 0)
	menu.add_check_item("ノードをグリッドに合わせる", 1)
	menu.add_check_item("全体図を表示", 2)
	menu.add_check_item("近くのノードに位置を合わせる", 3)
	menu.add_item("選択ノードを縦に等間隔にする", 4)
	menu.about_to_popup.connect(func():
		for i in 4: menu.set_item_checked(menu.get_item_index(i), [show_grid, snapping_enabled, minimap_enabled, align_enabled][i]))
	menu.id_pressed.connect(_display_action)

func _display_action(id: int) -> void:
	match id:
		0: show_grid = not show_grid
		1: snapping_enabled = not snapping_enabled
		2: minimap_enabled = not minimap_enabled
		3: align_enabled = not align_enabled
		4: command("align")
		5: fit_all()
		6: arrange_categories()
		7: zoom = 1.0
		8: zoom = 0.5

func focus_technique(id: String) -> void:
	var node := get_node_or_null(NodePath(id)) as GraphNode
	if node != null: scroll_offset = (node.position_offset - Vector2(180, 70)) * zoom

func snapshot() -> Dictionary:
	return {"conditions": rules.conditions.duplicate(true), "layout": rules.layout.duplicate(true), "graph_nodes": rules.graph_nodes.duplicate(true), "combos": rules.combos.duplicate(true), "costs": rules.costs.duplicate(true), "condition_groups": rules.condition_groups.duplicate(true)}

func category_for(id: String) -> String:
	var group := hub_for(id)
	if not group.is_empty(): return rules.category_for_group(group)
	var source: String = rules.source_for(id)
	if rules.combos.has(source): return "combo"
	for move in rules.techniques:
		if String(move.technique) == source: return "normal" if move.category == &"single" else String(move.category)
	return "normal"

func hub_for(id: String) -> String:
	for group in rules.condition_groups:
		if id in rules.condition_groups[group].get("nodes", []): return group
	return ""

func _default_groups() -> Dictionary:
	var result := {}
	for category in ["normal", "combo", "major"]:
		var buckets := {}
		for id in rules.node_ids():
			if category_for(id) != category: continue
			var kind := ""
			for move in rules.techniques:
				if String(move.technique) == rules.source_for(id): kind = String(move.get("head_kind") if move.get("head_kind") != null else "")
			if not buckets.has(kind): buckets[kind] = []
			buckets[kind].append(id)
		if buckets.is_empty(): buckets[""] = []
		var number := 0
		for kind in buckets:
			var ids: Array = buckets[kind]
			var count := maxi(1, ceili(ids.size() / 4.0))
			var chunk := maxi(1, ceili(ids.size() / float(count)))
			for i in count:
				number += 1
				var group: String = "choose_" + category + ("_" + str(number) if number > 1 else "")
				var title_text: String = {"normal": "通常技", "combo": "コンボ", "major": "大技"}[category]
				title_text += " · " + {"bite": "噛みつき", "vortex": "渦", "debris": "瓦礫", "beam": "ビーム", "thunder": "雷"}.get(kind, kind) if not kind.is_empty() else (" " + str(number) if number > 1 else "")
				result[group] = {"title": title_text, "category": category, "nodes": ids.slice(i * chunk, (i + 1) * chunk)}
	return result

func assign_group(id: String, group: String) -> void:
	if not rules.condition_groups.has(group) or not rules.node_ids().has(id): return
	var before := snapshot()
	var after := snapshot()
	for value in after.condition_groups.values(): value.nodes.erase(id)
	after.condition_groups[group].nodes.append(id)
	if not after.graph_nodes.has(id): after.graph_nodes[id] = {"source": rules.source_for(id)}
	after.graph_nodes[id].connected = true
	edit_requested.emit(before, after, "技の条件選択を変更")

func add_group() -> void:
	var before := snapshot()
	var after := snapshot()
	var n := 1
	while after.condition_groups.has("choose_custom_" + str(n)): n += 1
	var id := "choose_custom_" + str(n)
	after.condition_groups[id] = {"title": "条件選択 " + str(n), "category": "normal", "nodes": []}
	after.layout[id] = (scroll_offset + size * 0.5) / zoom
	edit_requested.emit(before, after, "条件選択を追加")
	picked.emit("coverage", id)

func _get_connection_line(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	return preload("res://tools/editor/boss_flow/wire_router.gd").for_graph(self, from_position, to_position)

func show_rules(value: Resource) -> void:
	rules = value
	if rules.condition_groups.is_empty():
		rules.condition_groups = _default_groups()
		# 旧エディターの単一ハブが生成した縦一列配置を移行する。
		if rules.layout.has("choose"): rules.layout = {}
	# 新しく作成した技は既存グループへ加える。
	for id in rules.node_ids():
		if not hub_for(id).is_empty(): continue
		var group := "choose_" + category_for(id)
		if not rules.condition_groups.has(group): rules.condition_groups[group] = {"title": "条件選択", "nodes": []}
		rules.condition_groups[group].nodes.append(id)
	_updating = true
	clear_connections()
	for child in get_children():
		if child is GraphNode:
			remove_child(child)
			child.queue_free()
	var factor := maxf(1.0, get_theme_default_font_size() / 14.0)
	var blocks: Array = []
	var block_size := Vector2.ZERO
	for group in rules.condition_groups:
		var ids: Array[String] = []
		for id in rules.condition_groups[group].get("nodes", []):
			if rules.node_ids().has(id) and hub_for(id) == group: ids.append(id)
		var label: String = {"normal": "通常技", "combo": "コンボ技", "major": "大技"}.get(rules.category_for_group(group), "通常技")
		var hub := _add_node(group, rules.condition_groups[group].title + " · " + label, Vector2.ZERO, false)
		var nodes: Array[GraphNode] = []
		var node_size := Vector2.ZERO
		for id in ids:
			var node := _add_node(id, node_title(rules, id), Vector2.ZERO, true)
			nodes.append(node)
			node_size.x = maxf(node_size.x, node.get_combined_minimum_size().x)
			node_size.y = maxf(node_size.y, node.get_combined_minimum_size().y)
		var row_height := node_size.y + 26 * factor
		var height := maxf(hub.get_combined_minimum_size().y, ids.size() * row_height - (26 * factor if not ids.is_empty() else 0.0)) + 56 * factor
		block_size.x = maxf(block_size.x, hub.get_combined_minimum_size().x + 80 * factor + node_size.x + 56 * factor)
		blocks.append({"hub": hub, "ids": ids, "nodes": nodes, "row_height": row_height, "node_x": hub.get_combined_minimum_size().x + 80 * factor, "total_height": height})
	var lanes := mini(4, blocks.size())
	var heights := []
	heights.resize(lanes)
	heights.fill(0.0)
	for b in blocks.size():
		var block: Dictionary = blocks[b]
		var lane := 0
		for i in lanes:
			if heights[i] < heights[lane]: lane = i
		var at := Vector2(20, 58) * factor + Vector2(lane * block_size.x, heights[lane])
		heights[lane] += block.total_height
		block.hub.position_offset = rules.layout.get(String(block.hub.name), at)
		for i in block.nodes.size():
			var id: String = block.ids[i]
			block.nodes[i].position_offset = rules.layout.get(id, at + Vector2(block.node_x, i * block.row_height))
			if rules.graph_nodes.get(id, {}).get("connected", true): connect_node(String(block.hub.name), 0, id, 0)
	_updating = false
	if rules.layout.is_empty(): fit_all.call_deferred()

## 条件選択ノードは黄、技ノードは紫。
const SELECT_COLOR := Color(1.0, 0.88, 0.45)
const TECHNIQUE_COLOR := Color(0.85, 0.7, 1.0)

func _add_node(id: String, title_text: String, at: Vector2, input: bool) -> GraphNode:
	var node := GraphNode.new()
	node.name = id
	node.title = title_text
	node.self_modulate = TECHNIQUE_COLOR if input else SELECT_COLOR
	if input:
		var diagram := preload("res://tools/editor/boss_flow/range_preview.gd").new()
		diagram.custom_minimum_size = Vector2(120, 58) * maxf(1.0, get_theme_default_font_size() / 14.0)
		diagram.gate = rules.conditions.get(id, {})
		diagram.tooltip_text = "青：発動条件　橙：基準の攻撃範囲"
		for move in rules.techniques:
			if String(move.technique) == rules.source_for(id): diagram.set_attack(move, String(rules.adapter))
		node.add_child(diagram)
		var play := Button.new()
		play.text = "保存して再生"
		play.pressed.connect(func(): play_requested.emit(id))
		node.add_child(play)
	else:
		var label := Label.new()
		label.text = "条件のカバーを確認"
		label.custom_minimum_size.y = 58.0 * maxf(1.0, get_theme_default_font_size() / 14.0)
		node.add_child(label)
	node.set_slot(0, input, 0, Color(0.6, 0.8, 0.7), not input, 0, Color(0.6, 0.8, 0.7))
	add_child(node)
	node.resized.connect(_request_reroute)
	node.position_offset = rules.layout.get(id, at)
	node.position_offset_changed.connect(func():
		_request_reroute()
		if not _updating and not _drag_before.is_empty(): _assist(node))
	return node

func _request_reroute() -> void:
	if _reroute_pending: return
	_reroute_pending = true
	_reroute.call_deferred()

func _reroute() -> void:
	_reroute_pending = false
	preload("res://tools/editor/boss_flow/wire_router.gd").refresh(self)

func fit_all() -> void:
	if size.x <= 0 or size.y <= 0: return
	var bounds := Rect2()
	var first := true
	for node in get_children():
		if node is GraphNode:
			var rect := Rect2(node.position_offset, node.get_combined_minimum_size())
			bounds = rect if first else bounds.merge(rect)
			first = false
	var top := 48.0 * maxf(1.0, get_theme_default_font_size() / 14.0)
	zoom = clampf(minf((size.x - 25) / maxf(1, bounds.size.x), (size.y - top - 12) / maxf(1, bounds.size.y)), zoom_min, 1.0)
	scroll_offset = bounds.position * zoom - Vector2(12, top)

func arrange_categories() -> void:
	var before := snapshot()
	var after := snapshot()
	rules.layout = {}
	show_rules(rules)
	after.layout = positions()
	rules.layout = before.layout
	edit_requested.emit(before, after, "技を分類して整列")
	fit_all.call_deferred()

func selected_ids() -> Array[String]:
	var ids: Array[String] = []
	for node in get_children():
		if node is GraphNode and node.selected: ids.append(String(node.name))
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
	var closest_x := INF
	var closest_y := INF
	for other in get_children():
		if not other is GraphNode or other == node or other.selected: continue
		var horizontal_gap := maxf(0.0, maxf(other.position_offset.x - (node.position_offset.x + node.size.x), node.position_offset.x - (other.position_offset.x + other.size.x)))
		var vertical_gap := maxf(0.0, maxf(other.position_offset.y - (node.position_offset.y + node.size.y), node.position_offset.y - (other.position_offset.y + other.size.y)))
		if vertical_gap <= 160.0 * scale_factor and absf(node.position_offset.x - other.position_offset.x) < threshold:
			var score_x := vertical_gap + absf(node.position_offset.x - other.position_offset.x)
			if score_x < closest_x:
				closest_x = score_x
				next.x = other.position_offset.x
		if horizontal_gap > 120.0 * scale_factor: continue
		for y in [other.position_offset.y, other.position_offset.y + other.size.y + gap, other.position_offset.y - node.size.y - gap]:
			if absf(node.position_offset.y - y) < threshold:
				var score_y := horizontal_gap + absf(node.position_offset.y - y)
				if score_y >= closest_y: continue
				closest_y = score_y
				next.y = y
	if closest_x < INF: _guides.append_array(PackedVector2Array([Vector2(next.x, -10000), Vector2(next.x, 10000)]))
	if closest_y < INF: _guides.append_array(PackedVector2Array([Vector2(-10000, next.y), Vector2(10000, next.y)]))
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
	preload("res://tools/editor/boss_flow/wire_router.gd").draw_directions(self, Color(0.65, 0.9, 0.75))
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
	var targets: Array = ids.duplicate()
	for raw in ids:
		if after.condition_groups.has(String(raw)):
			for member in after.condition_groups[String(raw)].nodes:
				if not targets.has(member): targets.append(member)
			after.condition_groups.erase(String(raw))
			after.layout.erase(String(raw))
	for raw in targets:
		var id := String(raw)
		if id.begins_with("choose_"): continue
		for group in after.condition_groups.values(): group.nodes.erase(id)
		if not after.graph_nodes.has(id): after.graph_nodes[id] = {"source": rules.source_for(id)}
		after.graph_nodes[id].hidden = true
		after.graph_nodes[id].connected = false
	edit_requested.emit(before, after, "選択ノードを削除")

func command(action: String) -> void:
	var ids := selected_ids()
	if action in ["copy", "cut", "duplicate"]:
		clipboard.clear()
		var expanded: Array[String] = ids.duplicate()
		for id in ids:
			if not rules.condition_groups.has(id): continue
			clipboard.append({"id": id, "group": rules.condition_groups[id].duplicate(true), "position": get_node(NodePath(id)).position_offset, "size": get_node(NodePath(id)).size})
			for member in rules.condition_groups[id].nodes:
				if rules.node_ids().has(member) and not expanded.has(member): expanded.append(member)
		for id in expanded:
			if rules.condition_groups.has(id): continue
			clipboard.append({"id": id, "source": rules.source_for(id), "owner": hub_for(id), "gate": rules.conditions.get(id, {}).duplicate(true), "position": get_node(NodePath(id)).position_offset, "size": get_node(NodePath(id)).size, "connected": rules.graph_nodes.get(id, {}).get("connected", true)})
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
		var groups := {}
		for entry in clipboard:
			if not entry.has("group"): continue
			var n := 1
			while after.condition_groups.has(entry.id + "_copy_" + str(n)): n += 1
			var id: String = entry.id + "_copy_" + str(n)
			groups[entry.id] = id
			after.condition_groups[id] = {"title": entry.group.title + "（複製）", "category": entry.group.get("category", rules.category_for_group(entry.id)), "nodes": []}
			after.layout[id] = entry.position + offset
			pasted.append(id)
		for entry in clipboard:
			if entry.has("group"): continue
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
			var owner: String = groups.get(entry.owner, entry.owner)
			if after.condition_groups.has(owner): after.condition_groups[owner].nodes.append(id)
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
