@tool
extends VBoxContainer

var current: Resource
var source_path := ""
var history := UndoRedo.new()
var _fields := GridContainer.new()
var _status := Label.new()
var _path := LineEdit.new()

func _ready() -> void:
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	_path.placeholder_text = "技Resourceのパス（res://…）"
	_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_path)
	for entry in [["開く", _open_path], ["保存", save_current], ["戻す", history.undo], ["やり直す", history.redo]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		toolbar.add_child(button)
	add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_fields.columns = 2
	_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_fields)
	_status.text = "技を開いて編集します。保存では実行データを生成しません。"

func _open_path() -> void:
	open_technique(_path.text)

func open_technique(path: String) -> Error:
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or not loaded.get("parameters") is Dictionary:
		_status.text = "技の設定を開けません: " + path
		return ERR_INVALID_DATA
	current = loaded.duplicate(true)
	source_path = path
	_path.text = path
	history.clear_history()
	_refresh()
	return OK

func set_value(key: String, value: float) -> void:
	if current == null or not current.parameters.has(key): return
	var old: Variant = current.parameters[key]
	var next: Variant = int(value) if old is int else value
	if old == next: return
	history.create_action("技の " + key + " を変更")
	history.add_do_method(_assign.bind(key, next))
	history.add_undo_method(_assign.bind(key, old))
	history.commit_action()

func _assign(key: String, value: Variant) -> void:
	current.parameters[key] = value
	current.emit_changed()
	_status.text = "未保存: " + source_path
	for node in _fields.get_children():
		if node is SpinBox and node.get_meta("key", "") == key:
			node.set_value_no_signal(float(value))

func save_current() -> Error:
	if current == null or source_path.is_empty(): return ERR_UNCONFIGURED
	var error := ResourceSaver.save(current, source_path)
	_status.text = "保存済み（実行データは試遊前に生成）" if error == OK else error_string(error)
	return error

func _refresh() -> void:
	for child in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()
	for key in current.parameters:
		var label := Label.new()
		label.text = String(key)
		_fields.add_child(label)
		var field := SpinBox.new()
		field.min_value = 0
		field.max_value = 100000
		field.step = 1 if current.parameters[key] is int else 0.01
		field.value = float(current.parameters[key])
		field.set_meta("key", key)
		field.value_changed.connect(func(value): set_value(key, value))
		_fields.add_child(field)
	_status.text = "編集中: " + source_path
