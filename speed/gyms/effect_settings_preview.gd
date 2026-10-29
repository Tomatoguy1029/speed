## 戦闘表示シーンの視覚値を、種類ごとのタブを作らず同じ画面で調整する。
extends Control

const SETTINGS_PATH := "res://data/visuals/effect_settings.tres"
const ROOT := "res://scenes/bosses"
const DIRECT_EFFECTS := [
	"weapon/barrier", "weapon/contactWave", "weapon/mines", "weapon/rear", "weapon/bipolar",
	"weapon/dashRangeDrone", "weapon/afterimage", "weapon/interceptor", "weapon/massTow",
	"weapon/sonic", "trait/vortex", "trait/critBeam", "trait/endBlast",
	"trait/reactive", "trait/killSonic",
	"boss/final_strike",
]
const ATTACK_SCENES := [
	"res://scenes/attacks/star_bolt.tscn", "res://scenes/attacks/hydra_shape.tscn",
	"res://scenes/attacks/beam_draco.tscn", "res://scenes/attacks/bolt.tscn",
	"res://scenes/attacks/light_arrow.tscn", "res://scenes/attacks/cosmic_arrow.tscn",
	"res://scenes/attacks/beam.tscn", "res://scenes/attacks/zone.tscn",
]
const VISUAL_FIELDS := [
	"pixel_size", "warning_color", "locked_color", "attack_color", "recovery_color",
	"hit_color", "line_width", "flash_duration", "base_color", "progress_color",
	"outline_color", "outline_width", "flight_scale",
]
const NUMBER_LIMITS := {
	"pixel_size": [1.0, 8.0, 0.25], "line_width": [0.5, 12.0, 0.25],
	"outline_width": [0.5, 12.0, 0.25], "flash_duration": [0.05, 2.0, 0.05],
}
const DIRECT_FIELDS := {
	"weapon/mines": [
		["機雷の点", "dot_radius", 2.0, 20.0, 0.5, 7.0],
		["周囲の輪", "ring_radius", 4.0, 28.0, 0.5, 11.0],
		["輪の太さ", "ring_width", 0.5, 6.0, 0.25, 1.5],
	],
	"trait/vortex": [
		["回転速度", "spin_speed", 0.0, 12.0, 0.1, 4.0],
		["弧の透明度", "arc_opacity", 0.0, 1.0, 0.01, 0.6],
		["弧の太さ", "arc_width", 0.5, 8.0, 0.25, 3.0],
	],
	"weapon/afterimage": [
		["残像の間隔", "echo_spacing", 0.0, 12.0, 0.25, 4.0],
		["残光の透明度", "trail_opacity", 0.0, 0.4, 0.01, 0.12],
		["本体の透明度", "body_opacity", 0.0, 1.0, 0.01, 0.85],
	],
	"res://scenes/attacks/hydra_shape.tscn": [
		["ドット倍率", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
	],
	"res://scenes/attacks/beam_draco.tscn": [
		["ドット倍率", "pixel_scale", 0.5, 3.0, 0.05, 1.0],
	],
}

var preview_host: Control
var controls_host: Control
var _working: Resource
var _source_hash := ""
var _dirty := false
var _message := ""
var _paths: Array[String] = []
var _selected := ""
var _picker := OptionButton.new()
var _fields := VBoxContainer.new()
var _sample: Node2D
var _viewport: SubViewport
var _swatch := ColorRect.new()

func _ready() -> void:
	_collect(ROOT)
	_paths.append_array(DIRECT_EFFECTS)
	_paths.append_array(ATTACK_SCENES)
	_paths.sort()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(controls_host if controls_host != null else self).add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	body.add_child(_picker)
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for path in _paths:
		_picker.add_item(path.trim_prefix(ROOT + "/").trim_suffix("_visual.tscn"))
	_picker.item_selected.connect(func(index: int): _select(_paths[index]))
	body.add_child(_fields)
	var preview := VBoxContainer.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(preview_host if preview_host != null else self).add_child(preview)
	var note := Label.new()
	note.text = "戦闘イベントを必要とする表現は、シーンの静的な部分だけを表示します。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.add_child(note)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(480, 480)
	_viewport.disable_3d = true
	container.add_child(_viewport)
	var background := ColorRect.new()
	background.color = Color("#10141e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(background)
	_swatch.position = Vector2(168, 168)
	_swatch.size = Vector2(144, 144)
	_viewport.add_child(_swatch)
	reload_current()
	if _working == null: return
	if not _paths.is_empty(): _select(_paths[0])

func _collect(folder: String) -> void:
	for filename in DirAccess.get_files_at(folder):
		if filename.ends_with("_visual.tscn"):
			_paths.append(folder.path_join(filename))
	for directory in DirAccess.get_directories_at(folder):
		_collect(folder.path_join(directory))

func _select(path: String) -> void:
	_selected = path
	_picker.select(_paths.find(path))
	if is_instance_valid(_sample): _sample.queue_free()
	_sample = null
	if path.begins_with("res://"):
		var scene := load(path) as PackedScene
		_sample = scene.instantiate() as Node2D
		var base_modulate := _sample.modulate
		_sample.position = Vector2(240, 240)
		_viewport.add_child(_sample)
		_sample.set_meta("visual_base_modulate", base_modulate)
	_swatch.visible = _sample == null
	_build_fields()
	_apply_preview()

func _build_fields() -> void:
	for child in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()
	_add_color("色・明るさ倍率", "effect_tint", Color.WHITE)
	for field in DIRECT_FIELDS.get(_selected, []):
		_add_number(field[0], field[1], field[5], "%s,%s,%s" % [field[2], field[3], field[4]])
	if not is_instance_valid(_sample): return
	for info in _sample.get_property_list():
		var name: String = info.name
		if name not in VISUAL_FIELDS: continue
		if name == "flight_scale" and _selected != "res://scenes/attacks/star_bolt.tscn": continue
		if not (info.usage & PROPERTY_USAGE_EDITOR): continue
		if info.type == TYPE_COLOR:
			_add_color(name, name, _sample.get(name))
		elif info.type == TYPE_FLOAT:
			_add_number(name, name, _sample.get(name), info.hint_string)

func _value(name: String, fallback: Variant) -> Variant:
	return (_working.profiles.get(_selected, {}) as Dictionary).get(name, fallback)

func _set_value(name: String, value: Variant) -> void:
	var values: Dictionary = _working.profiles.get(_selected, {}).duplicate()
	values[name] = value
	_working.profiles[_selected] = values
	_dirty = true
	_message = "未保存: " + _selected
	_apply_preview()

func _add_color(label: String, name: String, original: Color) -> void:
	var row := HBoxContainer.new()
	_fields.add_child(row)
	var caption := Label.new()
	caption.text = label
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var picker := ColorPickerButton.new()
	picker.color = _value(name, original)
	picker.color_changed.connect(func(color: Color): _set_value(name, color))
	row.add_child(picker)

func _add_number(label: String, name: String, original: float, hint: String) -> void:
	var row := HBoxContainer.new()
	_fields.add_child(row)
	var caption := Label.new()
	caption.text = label
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var spin := SpinBox.new()
	var parts := hint.split(",")
	var limits: Array = NUMBER_LIMITS.get(name, [0.0, maxf(100.0, original * 4.0), 0.05])
	spin.min_value = float(parts[0]) if parts.size() > 0 and parts[0].is_valid_float() else limits[0]
	spin.max_value = float(parts[1]) if parts.size() > 1 and parts[1].is_valid_float() else limits[1]
	spin.step = float(parts[2]) if parts.size() > 2 and parts[2].is_valid_float() else limits[2]
	spin.value = _value(name, original)
	spin.value_changed.connect(func(value: float): _set_value(name, value))
	row.add_child(spin)

func _apply_preview() -> void:
	_swatch.color = _value("effect_tint", Color.WHITE)
	if not is_instance_valid(_sample): return
	_sample.modulate = Color.WHITE
	_working.apply_to(_sample)
	_sample.queue_redraw()

func editing_state() -> Dictionary:
	var paths: Array[String] = []
	if _dirty: paths.append(SETTINGS_PATH)
	return {"path": SETTINGS_PATH, "dirty_paths": paths, "busy": false, "message": _message}

func save_current() -> void:
	if FileAccess.get_md5(SETTINGS_PATH) != _source_hash:
		_message = "保存先が外部で変更されました。再読込してください。"
		return
	var error := ResourceSaver.save(_working.duplicate(true), SETTINGS_PATH)
	if error != OK:
		_message = "保存失敗: " + error_string(error)
		return
	_source_hash = FileAccess.get_md5(SETTINGS_PATH)
	_dirty = false
	_message = "保存しました: " + SETTINGS_PATH

func reload_current() -> void:
	var loaded := ResourceLoader.load(SETTINGS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null:
		_message = "設定を読み込めません: " + SETTINGS_PATH
		return
	_working = loaded.duplicate(true)
	_source_hash = FileAccess.get_md5(SETTINGS_PATH)
	_dirty = false
	_message = "保存値を読み込みました"
	if not _selected.is_empty(): _select(_selected)

func set_active(active: bool) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if is_instance_valid(_viewport):
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
