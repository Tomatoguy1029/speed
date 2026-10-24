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

func _at(value: Dictionary) -> Dictionary:
	var node := value
	for index in path:
		if index >= node.get("children", []).size():
			path.clear()
			return value
		node = node.children[index]
	return node

func _ready() -> void:
	var tools := HBoxContainer.new()
	add_child(tools)
	for title_text in ["技", "待機", "順次グループ", "並列グループ", "条件分岐"]: _type.add_item(title_text)
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
		if _selected >= 0 and _selected < _at(program).get("children", []).size():
			var copy := program.duplicate(true)
			_at(copy).children.remove_at(_selected)
			changed.emit(copy))
	tools.add_child(remove)
	var back := Button.new()
	back.text = "上の階層"
	back.pressed.connect(func():
		if not path.is_empty(): path.pop_back()
		open(program, _moves))
	tools.add_child(back)
	for direction in [-1, 1]:
		var shift := Button.new()
		shift.text = "←" if direction < 0 else "→"
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
	graph.custom_minimum_size = Vector2(400, 220)
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.node_selected.connect(func(id):
		_selected = String(id).trim_prefix("step_").to_int()
		inspected.emit(path + [_selected]))
	add_child(graph)

func open(value: Dictionary, moves: Array) -> void:
	program = value
	_moves = moves
	_technique.clear()
	for move in moves: _technique.add_item(String(move.technique))
	graph.clear_connections()
	for node in graph.get_children():
		if node is GraphNode:
			graph.remove_child(node)
			node.queue_free()
	var nodes: Array = _at(program).get("children", [])
	for i in nodes.size():
		var step: Dictionary = nodes[i]
		var node := GraphNode.new()
		node.name = "step_" + str(i)
		node.title = String(step.get("id", step.get("type", "技")))
		node.position_offset = Vector2(i * 210, 50)
		var label := Label.new()
		label.text = "%s秒" % step.get("seconds", 0.0) if step.get("type", "") == "wait" else "実行後、技後待ちまで待つ"
		node.add_child(label)
		node.set_slot(0, true, 0, Color.GRAY, true, 0, Color.GRAY)
		graph.add_child(node)
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
		0: node = {"type": "action", "id": _technique.get_item_text(_technique.selected)}
		1: node = {"type": "wait", "seconds": _seconds.value}
		2: node = {"type": "sequence", "children": []}
		3: node = {"type": "parallel", "children": []}
		_: node = {"type": "branch", "condition": {"min": 0.0, "max": 600.0, "angle": 0.0, "half_angle": 180.0}, "children": [{"type": "sequence", "children": []}, {"type": "sequence", "children": []}]}
	target.children.append(node)
	changed.emit(copy)
