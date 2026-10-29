## F6で起動する伝説モジュール演出の調整画面。保存対象は選択したモジュールだけ。
extends Control

const REVEAL := preload("res://scenes/run/legendary_reveal.tscn")
const DIRECTORY := "res://data/legendary_modules"
const AuraBake := preload("res://scripts/ui/legendary_aura_bake.gd")

var _modules := OptionButton.new()
var _layers := OptionButton.new()
var _status := Label.new()
var _mask_path := Label.new()
var _mask_channel := OptionButton.new()
var _light_inputs: Dictionary = {}
var _source_mode := OptionButton.new()
var _bake_status := Label.new()
var _bake_button: Button
var _baking := false
var _bake_folder := "res://data/legendary_aura_bakes"
var _file := FileDialog.new()
var _stage := Control.new()
var _inputs: Dictionary = {}
var _paths: Array[String] = []
var _working: Dictionary = {}
var _hashes: Dictionary = {}
var _dirty: Dictionary = {}
var _selected := ""
var _reveal: Control
var _clock := 0.0
var _paused := false
var preview_host: Control
var controls_host: Control
var _aura_controls := VBoxContainer.new()
var _rays_controls := VBoxContainer.new()
var _bake_controls := VBoxContainer.new()
var _section := "aura"

func _ready() -> void:
	if controls_host == null:
		get_window().title = "SPEED — 伝説モジュール演出プレビュー"
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	margin.visible = controls_host == null
	var split := HSplitContainer.new()
	margin.add_child(split)
	var left := VBoxContainer.new()
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size.x = 320
	(controls_host if controls_host != null else split).add_child(left)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)
	scroll.add_child(panel)
	_label(panel, "伝説モジュール演出プレビュー")
	_modules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modules.item_selected.connect(_select_module)
	panel.add_child(_modules)
	_source_mode.add_item("生成プレビュー（調整用）")
	_source_mode.add_item("ベイク再生（ゲームと同じ）")
	_source_mode.item_selected.connect(func(_index): _select_module(_modules.selected))
	panel.add_child(_source_mode)
	_label(panel, "表示レイヤー")
	for title in ["合成", "オーラのみ", "後光のみ"]:
		_layers.add_item(title)
	_layers.item_selected.connect(func(_i): _show_layers())
	panel.add_child(_layers)
	var pause := CheckButton.new()
	pause.text = "一時停止"
	pause.toggled.connect(func(value): _paused = value)
	panel.add_child(pause)
	panel.add_child(_aura_controls)
	var common := panel
	panel = _aura_controls
	_label(panel, "オーラの位置（デザイン座標のpx）")
	_spin(panel, "X", "offset_x", -640, 640, 1)
	_spin(panel, "Y", "offset_y", -360, 360, 1)
	_label(panel, "オーラの大きさ（倍率）")
	_spin(panel, "横", "scale_x", 0.05, 5, 0.05)
	_spin(panel, "縦", "scale_y", 0.05, 5, 0.05)
	_spin(panel, "角度（度）", "angle", -180, 180, 1)
	_label(panel, "形状マスク")
	_mask_path.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_mask_path)
	_mask_channel.add_item("透過画像：アルファを使う")
	_mask_channel.add_item("白黒画像：白を生成元にする")
	_mask_channel.item_selected.connect(func(index):
		_read(_selected).reveal_aura_mask_channel = index
		_changed())
	panel.add_child(_mask_channel)
	_label(panel, "絵とは別の輪郭画像。アルファ方式：不透明から生成、透明はなし。輝度方式：白から生成、黒・透明はなし。")
	_button(panel, "マスクを選ぶ…", func(): _file.popup_centered_ratio(0.7))
	_button(panel, "マスク解除（旧表示の確認用）", func(): _set_mask(null))
	common.add_child(_rays_controls)
	panel = _rays_controls
	_label(panel, "後光の設定（選択中のモジュールだけ）")
	for key in LegendaryModuleDef.BACKLIGHT_PARAMETERS:
		var field: Array = LegendaryModuleDef.BACKLIGHT_PARAMETERS[key]
		if key == "backlight_color":
			_label(panel, field[0])
			var picker := ColorPickerButton.new()
			picker.edit_alpha = false
			picker.color_changed.connect(func(_color): _change_backlight())
			_light_inputs[key] = picker
			panel.add_child(picker)
		else:
			_spin(panel, field[0], key, field[1], field[2], field[3], true)
	_button(panel, "後光を既定値に戻す", func():
		_read(_selected).reveal_backlight_settings.clear()
		_changed()
		_select_module(_modules.selected))
	left.add_child(_bake_controls)
	_bake_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bake_controls.add_child(_bake_status)
	_bake_button = _button(_bake_controls, "オーラをベイクして保存", _bake)
	_bake_button.tooltip_text = "絵と別の輪郭マスクが必要です。256×186px・32フレームを2枚の圧縮アトラスへ保存します。"
	if controls_host == null:
		_button(left, "設定だけ保存", _save)
		_button(left, "保存状態を再読込", _reload_selected)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_status)
	_status.visible = controls_host == null
	if controls_host == null:
		_label(left, "変更は即反映。未保存値は切替後も保持し、終了時に消えます。")
	var background := ColorRect.new()
	background.color = Color("#0a0f1b")
	background.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(preview_host if preview_host != null else split).add_child(background)
	background.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(_stage)
	_file.access = FileDialog.ACCESS_RESOURCES
	_file.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file.filters = PackedStringArray(["*.png,*.webp,*.svg,*.tres,*.res ; Texture2D"])
	_file.file_selected.connect(_load_mask)
	add_child(_file)
	for filename in DirAccess.get_files_at(DIRECTORY):
		if filename.ends_with(".tres"):
			_paths.append(DIRECTORY.path_join(filename))
	_paths.sort()
	for path in _paths:
		var definition := _read(path)
		_modules.add_item(definition.get_display_name())
		_modules.set_item_tooltip(_modules.item_count - 1, path)
	if not _paths.is_empty():
		_select_module(0)
	set_section(_section)

func _label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _spin(parent: Control, title: String, key: String, low: float, high: float, step: float, backlight := false) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.allow_greater = true
	spin.allow_lesser = low < 0.0
	spin.custom_minimum_size.x = 140
	if backlight:
		spin.value_changed.connect(func(_value): _change_backlight())
		_light_inputs[key] = spin
	else:
		spin.value_changed.connect(func(_value): _change_values())
		_inputs[key] = spin
	row.add_child(spin)

func _read(path: String) -> LegendaryModuleDef:
	if not _working.has(path):
		# 個別のResourceを読み、ゲーム側や別モジュールのインスタンスを編集しない。
		_working[path] = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		_hashes[path] = FileAccess.get_md5(path)
	return _working[path]

func _select_module(index: int) -> void:
	_modules.select(index)
	_selected = _paths[index]
	var definition := _read(_selected)
	_inputs.offset_x.set_value_no_signal(definition.reveal_aura_offset.x)
	_inputs.offset_y.set_value_no_signal(definition.reveal_aura_offset.y)
	_inputs.scale_x.set_value_no_signal(definition.reveal_aura_scale.x)
	_inputs.scale_y.set_value_no_signal(definition.reveal_aura_scale.y)
	_inputs.angle.set_value_no_signal(definition.reveal_aura_rotation_degrees)
	_mask_channel.select(definition.reveal_aura_mask_channel)
	_mask_path.text = definition.reveal_aura_mask.resource_path if definition.reveal_aura_mask != null else "未指定（生成プレビューのみ・ベイク不可）"
	if is_instance_valid(_reveal):
		_reveal.free()
	_reveal = REVEAL.instantiate()
	_reveal.setup(definition, _source_mode.selected == 0)
	_stage.add_child(_reveal)
	_reveal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reveal.set_timing(1.0, 20.0, 1.0)
	for key in _light_inputs:
		var control = _light_inputs[key]
		if control is ColorPickerButton:
			control.set_block_signals(true)
			control.color = _reveal.get(key)
			control.set_block_signals(false)
		else:
			control.set_value_no_signal(_reveal.get(key))
	_show_layers()
	_status.text = ("未保存：" if _dirty.get(_selected, false) else "保存先：") + _selected.get_file()
	_status.tooltip_text = _selected
	_refresh_bake_status()

func _change_values() -> void:
	if _selected.is_empty():
		return
	var definition := _read(_selected)
	definition.reveal_aura_offset = Vector2(_inputs.offset_x.value, _inputs.offset_y.value)
	definition.reveal_aura_scale = Vector2(_inputs.scale_x.value, _inputs.scale_y.value)
	definition.reveal_aura_rotation_degrees = _inputs.angle.value
	_changed(false)

func _change_backlight() -> void:
	if _selected.is_empty():
		return
	var definition := _read(_selected)
	for key in _light_inputs:
		var control = _light_inputs[key]
		var value = control.color if control is ColorPickerButton else control.value
		if key.ends_with("_count"):
			value = int(value)
		definition.reveal_backlight_settings[key] = value
		_reveal.set(key, value)
	_changed(false)

func _load_mask(path: String) -> void:
	var texture := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Texture2D
	if texture == null:
		_status.text = "Texture2Dを選んでください。設定は変更していません。"
		return
	_set_mask(texture)

func _set_mask(texture: Texture2D) -> void:
	if _selected.is_empty():
		return
	_read(_selected).reveal_aura_mask = texture
	_mask_path.text = texture.resource_path if texture != null else "未指定（生成プレビューのみ・ベイク不可）"
	_changed()

func _changed(refresh_bake := true) -> void:
	_dirty[_selected] = true
	_status.text = "未保存：" + _selected.get_file()
	if refresh_bake:
		_refresh_bake_status()

func _refresh_bake_status() -> void:
	var definition := _read(_selected)
	var valid := AuraBake.valid(definition, _reveal.aura_recipe())
	_bake_status.text = "ベイク済み（32フレーム・4秒ループ）" if valid else "未作成／要再ベイク。ゲームではオーラを非表示。"
	if definition.reveal_aura_mask == null:
		_bake_status.text += " 輪郭マスクを選んでください。"
	_bake_button.disabled = _baking or definition.reveal_aura_mask == null or DisplayServer.get_name() == "headless"
	if DisplayServer.get_name() == "headless":
		_bake_status.text += " ベイクには描画付きで起動してください。"
	if not _reveal._procedural_preview:
		_reveal._baked_valid = valid
	_show_layers()

func _show_layers() -> void:
	if not is_instance_valid(_reveal):
		return
	_reveal._light.visible = _layers.selected != 1
	var aura_available: bool = _reveal._procedural_preview or _reveal._baked_valid
	_reveal._aura.visible = _layers.selected != 2 and aura_available
	_reveal._mantle.visible = _layers.selected != 2 and aura_available

func _process(delta: float) -> void:
	if not _paused:
		_clock += delta
	if is_instance_valid(_reveal):
		_reveal.set_endpoints(_stage.size / 2.0, _stage.size / 2.0)
		_reveal.set_progress((2.4 + fmod(_clock, 18.0)) / 22.0)

func _save() -> bool:
	if _selected.is_empty():
		return false
	if FileAccess.get_md5(_selected) != _hashes[_selected]:
		_status.text = "別の場所でファイルが更新されました。保存を止めました。再読込して確認してください。"
		return false
	var error := ResourceSaver.save(_read(_selected), _selected)
	if error != OK:
		_status.text = "保存できませんでした（%d）" % error
		return false
	_hashes[_selected] = FileAccess.get_md5(_selected)
	_dirty[_selected] = false
	_status.text = "保存済み：" + _selected.get_file()
	_refresh_bake_status()
	return true

func _reload_selected() -> void:
	if _selected.is_empty():
		return
	_working.erase(_selected)
	_dirty.erase(_selected)
	_select_module(_modules.selected)

func _set_busy(value: bool) -> void:
	_baking = value
	var stack: Array[Node] = [self]
	if controls_host != null:
		stack.append(controls_host)
	while not stack.is_empty():
		var node := stack.pop_back() as Node
		if node is BaseButton:
			node.disabled = value
		elif node is SpinBox:
			node.editable = not value
		stack.append_array(node.get_children())
	if not value:
		_refresh_bake_status()

func _bake() -> void:
	if _baking or _selected.is_empty() or DisplayServer.get_name() == "headless":
		return
	var path := _selected
	var definition := _read(path)
	if definition.reveal_aura_mask == null:
		_status.text = "絵とは別の輪郭マスクを選んでください。"
		return
	if FileAccess.get_md5(path) != _hashes[path]:
		_status.text = "別の場所で更新されています。再読込してからベイクしてください。"
		return
	_set_busy(true)
	# 配置の調整は再生時に適用する。形状そのものと生成結果だけをベイクする。
	var local_definition: LegendaryModuleDef = definition.duplicate()
	local_definition.reveal_aura_offset = Vector2.ZERO
	local_definition.reveal_aura_scale = Vector2.ONE
	local_definition.reveal_aura_rotation_degrees = 0.0
	var generator = REVEAL.instantiate()
	generator.setup(local_definition, true)
	_stage.add_child(generator)
	generator.hide()
	var result := await AuraBake.bake(self, generator, func(progress): _bake_status.text = "ベイク中 %d%%" % roundi(progress * 100.0))
	if result.has("error"):
		_set_busy(false)
		_status.text = result.error
		return
	if FileAccess.get_md5(path) != _hashes[path]:
		_set_busy(false)
		_status.text = "ベイク中にファイルが更新されたため保存を止めました。"
		return
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_bake_folder))
	var textures: Array[Texture2D] = []
	for layer in ["back", "front"]:
		if error != OK:
			break
		var destination := _bake_folder.path_join(path.get_file().get_basename() + "_" + layer + ".res")
		error = ResourceSaver.save(ImageTexture.create_from_image(result[layer]), destination, ResourceSaver.FLAG_COMPRESS)
		if error == OK:
			textures.append(ResourceLoader.load(destination, "", ResourceLoader.CACHE_MODE_IGNORE))
	if error != OK or textures.size() != 2:
		_set_busy(false)
		_status.text = "ベイク素材を保存できませんでした（%d）" % error
		return
	definition.reveal_aura_baked_back = textures[0]
	definition.reveal_aura_baked_front = textures[1]
	definition.reveal_aura_bake_signature = result.signature
	definition.reveal_aura_bake_frames = result.frames
	definition.reveal_aura_bake_columns = result.columns
	definition.reveal_aura_bake_fps = result.fps
	if not _save():
		_set_busy(false)
		return
	_set_busy(false)
	_source_mode.select(1)
	_select_module(_modules.selected)

# オーラと後光は同じモジュールの複製を共有し、切替で保存値を失わない。
func set_section(section: String) -> void:
	_section = section
	if not is_node_ready():
		return
	_aura_controls.visible = controls_host == null or section == "aura"
	_rays_controls.visible = controls_host == null or section == "rays"
	_bake_controls.visible = controls_host == null or section == "aura"

func editing_state() -> Dictionary:
	var paths: Array[String] = []
	for path in _dirty:
		if _dirty[path]:
			paths.append(path)
	return {"path": _selected, "dirty_paths": paths, "busy": _baking, "message": _status.text}

func save_current() -> void:
	_save()

func reload_current() -> void:
	_reload_selected()

func set_active(active: bool) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if is_instance_valid(_reveal):
		_reveal._viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
