@tool
extends VBoxContainer
signal changed(program: Dictionary)
var program: Dictionary = {}
var graph := GraphEdit.new()
var _selected := -1
var _type := OptionButton.new()
var _technique := OptionButton.new()
var _seconds := SpinBox.new()

func _ready() -> void:
	var tools := HBoxContainer.new()
	add_child(tools)
	for title_text in ["技", "待機"]: _type.add_item(title_text)
	tools.add_child(_type)
	tools.add_child(_technique)
	_seconds.step = 0.1
	_seconds.max_value = 100
	_seconds.tooltip_text = "待機時間（秒）"
	tools.add_child(_seconds)
	var add := Button.new()
	add.text = "追加"
	add.pressed.connect(_append)
	tools.add_child(add)
	var remove := Button.new()
	remove.text = "選択を削除"
	remove.pressed.connect(func():
		if _selected >= 0 and _selected < program.get("children", []).size():
			var copy := program.duplicate(true)
			copy.children.remove_at(_selected)
			changed.emit(copy))
	tools.add_child(remove)
	graph.custom_minimum_size = Vector2(400, 220)
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.node_selected.connect(func(id): _selected = String(id).trim_prefix("step_").to_int())
	add_child(graph)

func open(value: Dictionary, moves: Array) -> void:
	program = value
	_technique.clear()
	for move in moves: _technique.add_item(String(move.technique))
	graph.clear_connections()
	for node in graph.get_children():
		if node is GraphNode:
			graph.remove_child(node)
			node.queue_free()
	for i in program.get("children", []).size():
		var step: Dictionary = program.children[i]
		var node := GraphNode.new()
		node.name = "step_" + str(i)
		node.title = String(step.get("id", step.get("type", "技")))
		node.position_offset = Vector2(i * 210, 50)
		var label := Label.new()
		label.text = "%s秒" % step.get("seconds", 0.0) if step.get("type", "") == "wait" else "実行後、技後待ちまで待つ"
		node.add_child(label)
		node.set_slot(0, true, 0, Color.GRAY, true, 0, Color.GRAY)
		graph.add_child(node)
		if i > 0: graph.connect_node("step_" + str(i - 1), 0, node.name, 0)

func _append() -> void:
	var copy := program.duplicate(true)
	if not copy.has("children"): copy.children = []
	copy.type = "sequence"
	copy.children.append({"type": "action", "id": _technique.get_item_text(_technique.selected)} if _type.selected == 0 else {"type": "wait", "seconds": _seconds.value})
	changed.emit(copy)
