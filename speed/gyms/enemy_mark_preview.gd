## 目印とエリートの shader を同じ画面で選び、保存済み設定を編集する。
extends Control

const PATHS := {
	"landmark": "res://data/visuals/landmark_mark.tres",
	"elite": "res://data/visuals/elite_mark.tres",
}
const SHADERS := {
	"landmark": preload("res://shaders/landmark_mark.gdshader"),
	"elite": preload("res://shaders/elite_mark.gdshader"),
}
const SAMPLE := preload("res://assets/pixel/telescope.png")
const LANDMARK := preload("res://scripts/render/landmark_aura.gd")
const LABELS := {
	"pixel_grid": "ドット密度", "inner_radius": "内側の空白", "outer_radius": "外側の広がり",
	"noise_scale": "模様の細かさ", "motion_speed": "変化の速度", "intensity": "明るさ",
	"color": "基調色", "highlight": "光る色",
	"aura_width": "輪郭の幅", "aura_variation": "幅の揺らぎ", "pixel_size": "ドット幅",
}

var preview_host: Control
var controls_host: Control
var _section := "landmark"
var _working: Dictionary = {}
var _hashes: Dictionary = {}
var _dirty: Dictionary = {}
var _message := ""
var _batch: InstanceBatch
var _viewport: SubViewport
var _fields := VBoxContainer.new()
var _clock := 0.0
var _paused := false
var _aura: Sprite2D
var _enemy: Sprite2D

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
	var title := Label.new()
	title.text = "敵のプレビュー（本体の背後へ表示）"
	right.add_child(title)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(480, 480)
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)
	var backdrop := ColorRect.new()
	backdrop.color = Color("#10141e")
	backdrop.z_index = -2
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(backdrop)
	_batch = InstanceBatch.new()
	_batch.setup_shader_quad()
	_batch.z_index = -1
	_viewport.add_child(_batch)
	_batch.begin()
	_batch.add_upright(Vector2(240, 240), 80.0, Color(0.4, 0, 0, 1))
	_batch.end()
	_aura = Sprite2D.new()
	_aura.position = Vector2(240, 240)
	_aura.z_index = -1
	_aura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var aura_material := ShaderMaterial.new()
	aura_material.shader = LANDMARK.SHADER
	aura_material.set_shader_parameter("noise_tex", LANDMARK.NOISE)
	_aura.material = aura_material
	var assets := load(LANDMARK.ASSETS_PATH) as Resource
	LANDMARK.configure(_aura, assets.get_meta("masks")["res://data/visuals/looks/telescope.tres"])
	_viewport.add_child(_aura)
	_enemy = Sprite2D.new()
	_enemy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_enemy.position = Vector2(240, 240)
	_viewport.add_child(_enemy)
	_load(_section)
	_show_section()

func _process(delta: float) -> void:
	if not _paused:
		_clock += delta
	if is_instance_valid(_batch):
		(_batch.material as ShaderMaterial).set_shader_parameter("mark_time", _clock)
	if is_instance_valid(_aura):
		(_aura.material as ShaderMaterial).set_shader_parameter("clock", _clock)

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
	var material := ShaderMaterial.new()
	material.shader = SHADERS[_section]
	(_working[_section] as EnemyMarkSettings).apply_to(material)
	_batch.material = material
	material.set_shader_parameter("mark_time", _clock)
	var landmark := _section == "landmark"
	_batch.visible = not landmark
	_aura.visible = landmark
	if landmark:
		var definition: EnemyDef = ContentManager.enemies[&"telescope"]
		var look := RunPresentation.load_look(&"telescope")
		_enemy.texture = RunPresentation.look_texture(look, {}, definition.armor_colors)
		_enemy.scale = Vector2.ONE * ContentManager.cfg.character_scale * definition.visual_value("scale", 1.0)
		_aura.scale = _enemy.scale
		(_working[_section] as EnemyMarkSettings).apply_aura_to(_aura.material as ShaderMaterial)
	else:
		_enemy.texture = SAMPLE
		_enemy.scale = Vector2.ONE * 1.5
	_rebuild_fields()

func _rebuild_fields() -> void:
	for child in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()
	var description := Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.text = "星座の手掛かり。船体の輪郭に沿って揺れる濃い金色のオーラ。本編と同じマスク・設定を使います。" if _section == "landmark" else "強化された個体。装甲の外側に断続する発光片。"
	_fields.add_child(description)
	var pause := CheckButton.new()
	pause.text = "一時停止"
	pause.button_pressed = _paused
	pause.toggled.connect(func(value): _paused = value)
	_fields.add_child(pause)
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
			if LABELS.has(property.name) and property.name not in ["aura_width", "aura_variation", "pixel_size"]:
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
	settings.set(key, int(value) if key == "pixel_grid" else value)
	_changed()

func _set_color(value: Color, key: String) -> void:
	(_working[_section] as EnemyMarkSettings).set(key, value)
	_changed()

func _changed() -> void:
	_dirty[_section] = true
	if _section == "landmark":
		(_working[_section] as EnemyMarkSettings).apply_aura_to(_aura.material as ShaderMaterial)
	else:
		(_working[_section] as EnemyMarkSettings).apply_to(_batch.material as ShaderMaterial)
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
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if is_instance_valid(_viewport):
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
