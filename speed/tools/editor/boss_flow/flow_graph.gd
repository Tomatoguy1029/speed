@tool
extends GraphEdit
signal picked(index: int)
signal shared_settings_requested
signal edit_requested(before: Dictionary, after: Dictionary, title: String)
var flow: Resource
var _before := {}
var _reroute_pending := false
var clipboard: Array = []

func _request_reroute() -> void:
	if _reroute_pending: return
	_reroute_pending = true
	_reroute.call_deferred()

func _reroute() -> void:
	_reroute_pending = false
	preload("res://tools/editor/boss_flow/wire_router.gd").refresh(self)

func _get_connection_line(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	return preload("res://tools/editor/boss_flow/wire_router.gd").for_graph(self, from_position, to_position)

func _draw() -> void:
	preload("res://tools/editor/boss_flow/wire_router.gd").draw_directions(self, Color.SKY_BLUE)

func _ready() -> void:
	custom_minimum_size = Vector2(280, 150) * maxf(1.0, get_theme_default_font_size() / 14.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	get_menu_hbox().hide()
	copy_nodes_request.connect(func(): command("copy"))
	cut_nodes_request.connect(func(): command("cut"))
	paste_nodes_request.connect(func(): command("paste"))
	duplicate_nodes_request.connect(func(): command("duplicate"))
	delete_nodes_request.connect(func(_ids): command("delete"))
	minimap_enabled = false
	resized.connect(func():
		if flow != null: fit_all.call_deferred())
	node_selected.connect(func(node):
		if node.name == &"shared_rest": shared_settings_requested.emit()
		else: picked.emit(String(node.name).trim_prefix("section_").to_int()))
	connection_request.connect(func(from, _port, to, _input):
		if not String(from).begins_with("section_") or not String(to).begins_with("section_"): return
		var after := snapshot()
		after.sections[String(from).trim_prefix("section_").to_int()].next = String(to).trim_prefix("section_").to_int()
		edit_requested.emit(snapshot(), after, "次の区間を接続"))
	begin_node_move.connect(func(): _before = snapshot())
	end_node_move.connect(func():
		if _before.is_empty(): return
		var after := snapshot()
		for node in get_children():
			if node is GraphNode: after.layout[String(node.name)] = node.position_offset
		if after != _before: edit_requested.emit(_before, after, "区間ノードを移動")
		_before = {})

func snapshot() -> Dictionary:
	return {"sections": flow.sections.duplicate(true), "layout": flow.layout.duplicate(true)}

func show_flow(value: Resource) -> void:
	flow = value
	clear_connections()
	for node in get_children():
		if node is GraphNode:
			remove_child(node)
			node.queue_free()
	var factor := maxf(1.0, get_theme_default_font_size() / 14.0)
	var x := 20.0 * factor
	for i in flow.sections.size():
		var section: Dictionary = flow.sections[i]
		var node := GraphNode.new()
		node.name = "section_" + str(i)
		node.title = ("開始 · " if i == 0 else "") + String(section.get("name", "区間"))
		node.self_modulate = Color(0.65, 0.85, 1.0)
		var summary := Label.new()
		summary.text = "休息" if section.get("request") == "rest" else "消費上限 %s" % section.get("cap", 2)
		node.add_child(summary)
		node.set_slot(0, true, 0, Color.SKY_BLUE, true, 0, Color.SKY_BLUE)
		add_child(node)
		node.position_offset_changed.connect(_request_reroute)
		node.resized.connect(_request_reroute)
		node.position_offset = flow.layout.get(String(node.name), Vector2(x, 14 * factor))
		x += node.get_combined_minimum_size().x + 48 * factor
	for i in flow.sections.size():
		var next := int(flow.sections[i].get("next", 0))
		if next >= 0 and next < flow.sections.size(): connect_node("section_" + str(i), 0, "section_" + str(next), 0)
	var rest := GraphNode.new()
	rest.name = "shared_rest"
	rest.title = "スタミナ・休息"
	rest.self_modulate = Color(1.0, 0.8, 0.55)
	var note := Label.new()
	note.text = "全区間で共有"
	rest.add_child(note)
	add_child(rest)
	rest.position_offset = flow.layout.get("shared_rest", Vector2(x + 20 * factor, 14 * factor))
	fit_all.call_deferred()

func fit_all() -> void:
	if size.x <= 0: return
	var bounds := Rect2()
	for node in get_children():
		if node is GraphNode: bounds = bounds.merge(Rect2(node.position_offset, node.get_combined_minimum_size()))
	bounds = bounds.grow(24)
	zoom = clampf(minf((size.x - 20) / maxf(1, bounds.size.x), (size.y - 14) / maxf(1, bounds.size.y)), zoom_min, 1.0)
	scroll_offset = bounds.position * zoom - Vector2(10, 6)

func command(action: String) -> void:
	var selected: Array[int] = []
	for node in get_children():
		if node is GraphNode and node.selected and String(node.name).begins_with("section_"): selected.append(String(node.name).trim_prefix("section_").to_int())
	selected.sort()
	if action in ["copy", "cut", "duplicate"]:
		clipboard.clear()
		for index in selected: clipboard.append({"index": index, "section": flow.sections[index].duplicate(true), "position": get_node("section_" + str(index)).position_offset})
		if action == "copy": return
	var before := snapshot()
	var after := snapshot()
	if action in ["paste", "duplicate"]:
		if clipboard.is_empty(): return
		var mapping := {}
		var right := 0.0
		for node in get_children():
			if node is GraphNode: right = maxf(right, node.position_offset.x + node.size.x)
		var shift: Vector2 = Vector2(right + 50, clipboard[0].position.y) - clipboard[0].position
		for entry in clipboard:
			mapping[entry.index] = after.sections.size()
			after.sections.append(entry.section.duplicate(true))
		for entry in clipboard:
			var index: int = mapping[entry.index]
			for field in ["next", "fallback"]:
				if entry.section.has(field): after.sections[index][field] = mapping.get(int(entry.section[field]), int(entry.section[field]))
			after.layout["section_" + str(index)] = entry.position + shift
	elif action in ["delete", "cut"]:
		if selected.is_empty() or selected.size() == flow.sections.size(): return
		var mapping := {}
		after.sections = []
		after.layout = {}
		if flow.layout.has("shared_rest"): after.layout.shared_rest = flow.layout.shared_rest
		for i in flow.sections.size():
			if i in selected: continue
			mapping[i] = after.sections.size()
			after.sections.append(flow.sections[i].duplicate(true))
			if flow.layout.has("section_" + str(i)): after.layout["section_" + str(mapping[i])] = flow.layout["section_" + str(i)]
		for section in after.sections:
			for field in ["next", "fallback"]:
				if not section.has(field): continue
				var next := int(section[field])
				for attempt in flow.sections.size():
					if mapping.has(next): break
					next = int(flow.sections[next].get("next", 0))
				section[field] = mapping.get(next, 0)
	elif action == "align":
		if selected.is_empty(): selected.assign(range(flow.sections.size()))
		var first: GraphNode = get_node("section_" + str(selected[0]))
		var x := first.position_offset.x
		for index in selected:
			var node: GraphNode = get_node("section_" + str(index))
			after.layout[String(node.name)] = Vector2(x, first.position_offset.y)
			x += node.size.x + 48 * maxf(1.0, get_theme_default_font_size() / 14.0)
	else: return
	edit_requested.emit(before, after, "区間ノードを編集")
