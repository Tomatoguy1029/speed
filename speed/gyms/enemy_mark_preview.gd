## 目印とエリートの shader を同じ画面で選び、保存済み設定を編集する。
extends Control

const PATHS := {
	"landmark": "res://data/visuals/landmark_mark.tres",
	"elite": "res://data/visuals/elite_mark.tres",
}
const LABELS := {
 "interval_min": "最短の発生間隔（秒）", "interval_random": "発生間隔のばらつき（秒）",
 "interval_max": "最長の発生間隔（秒）", "arc_count": "同時放電の中心本数",
 "spark_count": "火花の上限", "intensity": "濃さ", "color": "赤い光", "highlight": "放電の芯", "shadow": "黒い縁",
}

var preview_host: Control
var controls_host: Control
var _section := "landmark"
var _working: Dictionary = {}
var _hashes: Dictionary = {}
var _dirty: Dictionary = {}
var _message := ""
var _fields := VBoxContainer.new()
var _game_context
var _context_active := false

func _ready() -> void:
	var controls := ScrollContainer.new()
	controls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(controls_host if controls_host != null else self).add_child(controls)
	_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(_fields)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(preview_host if preview_host != null else self).add_child(right)
	_game_context = load("res://gyms/game_context_preview.gd").new()
	right.add_child(_game_context)
	_load(_section)
	_show_section()

func _load(section: String) -> void:
	var path: String = PATHS[section]
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EnemyMarkSettings
	if loaded == null:
		_message = "設定を読み込めません: " + path
		return
	_working[section] = loaded.duplicate()
	_hashes[section] = FileAccess.get_md5(path)
	_dirty[section] = false
	_message = "保存値を読み込みました: " + path

func set_section(section: String) -> void:
	if not PATHS.has(section): return
	_section = section
	if is_node_ready():
		if not _working.has(section): _load(section)
		_show_section()

func _show_section() -> void:
	if not _working.has(_section): return
	if _section == "landmark":
		_game_context.set_landmark_settings(_working[_section] as EnemyMarkSettings)
	else:
		_game_context.set_elite_settings(_working[_section] as EnemyMarkSettings)
	_game_context.set_active(_context_active)
	_rebuild_fields()

func _rebuild_fields() -> void:
	for child in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()
	var description := Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.text = "星座の手掛かり。船体の輪郭に沿って揺れる濃い金色のオーラ。本編と同じマスク・設定を使います。" if _section == "landmark" else "輪郭の異なる場所に、赤黒い短い放電が不規則に走る強化個体。本編と同じ接点・描画を使います。"
	_fields.add_child(description)
	var settings := _working[_section] as EnemyMarkSettings
	if _section == "landmark":
		for group in EnemyMarkSettings.AURA_GROUPS:
			_fields.add_child(HSeparator.new())
			var heading := Label.new()
			heading.text = group
			_fields.add_child(heading)
			for property in settings.get_property_list():
				var details: Array = EnemyMarkSettings.AURA_FIELDS.get(property.name, [])
				if details.is_empty() or details[0] != group: continue
				_add_setting(property, settings, details[1], details[2])
	else:
		for property in settings.get_property_list():
			if LABELS.has(property.name):
				_add_setting(property, settings, LABELS[property.name], "")

func _add_setting(property: Dictionary, settings: EnemyMarkSettings, caption: String, help: String) -> void:
	if not (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_EDITOR): return
	var key: String = property.name
	var label := Label.new()
	label.text = caption
	label.tooltip_text = help
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fields.add_child(label)
	if property.type == TYPE_COLOR:
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(72, 32)
		picker.tooltip_text = help
		picker.color = settings.get(key)
		picker.color_changed.connect(_set_color.bind(key))
		_fields.add_child(picker)
	elif property.type == TYPE_INT or property.type == TYPE_FLOAT:
		var spin := SpinBox.new()
		spin.tooltip_text = help
		var range_parts: PackedStringArray = String(property.hint_string).split(",")
		if range_parts.size() >= 2:
			spin.min_value = float(range_parts[0])
			spin.max_value = float(range_parts[1])
		if range_parts.size() >= 3: spin.step = float(range_parts[2])
		spin.value = settings.get(key)
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(_set_number.bind(key))
		_fields.add_child(spin)

func _set_number(value: float, key: String) -> void:
	var settings := _working[_section] as EnemyMarkSettings
	settings.set(key, int(value) if key in ["arc_count", "spark_count"] else value)
	_changed()

func _set_color(value: Color, key: String) -> void:
	(_working[_section] as EnemyMarkSettings).set(key, value)
	_changed()

func _changed() -> void:
	_dirty[_section] = true
	if _section == "landmark":
		_game_context.set_landmark_settings(_working[_section] as EnemyMarkSettings)
	else:
		_game_context.set_elite_settings(_working[_section] as EnemyMarkSettings)
	_message = "未保存の調整値: " + PATHS[_section]

func editing_state() -> Dictionary:
	var paths: Array[String] = []
	for section in _dirty:
		if _dirty[section]: paths.append(PATHS[section])
	return {"path": PATHS[_section], "dirty_paths": paths, "busy": false, "message": _message}

func is_section_dirty(section: String) -> bool:
	return _dirty.get(section, false)

func save_current() -> void:
	var path: String = PATHS[_section]
	if not _working.has(_section): return
	if FileAccess.get_md5(path) != _hashes[_section]:
		_message = "保存先が外部で変わりました。再読込してください: " + path
		return
	var error := ResourceSaver.save((_working[_section] as EnemyMarkSettings).duplicate(), path)
	if error != OK:
		_message = "保存に失敗しました: " + error_string(error)
		return
	_hashes[_section] = FileAccess.get_md5(path)
	_dirty[_section] = false
	_message = "保存しました: " + path

func reload_current() -> void:
	_load(_section)
	_show_section()

func set_active(active: bool) -> void:
	_context_active = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if is_instance_valid(_game_context): _game_context.set_active(active)
