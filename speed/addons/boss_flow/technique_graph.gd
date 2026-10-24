@tool
extends GraphEdit
signal picked(kind: String, id: String)
var rules: Resource

func _ready() -> void:
	custom_minimum_size = Vector2(350, 240)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	node_selected.connect(func(node): picked.emit("technique", String(node)))
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
		_add_node(id, id, rules.layout.get(id, Vector2(380, i * 105)), true)
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
		if rules != null: rules.layout[id] = node.position_offset)
	add_child(node)

func _input_graph(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var connection := get_closest_connection_at_point(event.position, 14.0)
		if not connection.is_empty(): picked.emit("condition", String(connection.to_node))
