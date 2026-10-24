@tool
extends GraphEdit
signal picked(kind: String, id: String)
signal layout_changed
var rules: Resource
const TITLES := {"bite_thrust": "噛みつき", "bite_sweep": "薙ぎ払い", "wind_band": "風の帯", "wind_blades": "風刃", "rubble_lump": "瓦礫の塊", "rubble_fan": "瓦礫の散弾", "beam_fixed": "固定ビーム", "beam_bolt": "ビーム弾", "thunder_headbutt": "雷の頭突き", "thunder_drop": "落雷", "tornado": "瓦礫竜巻", "debris_shatter": "瓦礫砕き", "beam_pincer": "挟撃ビーム", "north": "同時噛みつき", "sequence": "順番噛みつき", "curve": "曲線ビーム", "swarm": "連続飛びかかり", "grid": "格子ビーム"}

static func title_for(id: String) -> String: return TITLES.get(id, id)

func _ready() -> void:
	custom_minimum_size = Vector2(350, 240)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	node_selected.connect(func(node):
		if node.name == &"choose": picked.emit("coverage", "")
		else: picked.emit("technique", String(node.name)))
	gui_input.connect(_input_graph)

func show_rules(value: Resource) -> void:
	rules = value
	clear_connections()
	for child in get_children():
		if child is GraphNode:
			remove_child(child)
			child.queue_free()
	_add_node("choose", "行動候補", Vector2(30, 120), false)
	for i in rules.techniques.size():
		var move: Resource = rules.techniques[i]
		var id := String(move.technique)
		_add_node(id, title_for(id), rules.layout.get(id, Vector2(380, i * 105)), true)
		connect_node("choose", 0, id, 0)
	for id in rules.combos:
		if get_node_or_null(NodePath(id)) != null: continue
		_add_node(id, "コンボ: " + id, rules.layout.get(id, Vector2(680, rules.combos.keys().find(id) * 110)), true)
		connect_node("choose", 0, id, 0)

func _add_node(id: String, title_text: String, at: Vector2, input: bool) -> void:
	var node := GraphNode.new()
	node.name = id
	node.title = title_text
	node.position_offset = at
	var label := Label.new()
	label.text = "技" if input else "線を選んで発動条件を編集"
	node.add_child(label)
	node.set_slot(0, input, 0, Color(0.6, 0.7, 0.8), not input, 0, Color(0.6, 0.7, 0.8))
	node.position_offset_changed.connect(func():
		if rules != null:
			rules.layout[id] = node.position_offset
			layout_changed.emit())
	add_child(node)

func _input_graph(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var connection := get_closest_connection_at_point(event.position, 14.0)
		if not connection.is_empty(): picked.emit("condition", String(connection.to_node))
