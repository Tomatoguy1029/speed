## F6で共通炎を単体調整する。ゲームの攻撃仕様と独立し、外観は本人確認待ち。
extends Control

const SETTINGS_PATH := "res://data/visuals/pixel_flame.tres"
var _settings: PixelFlameSettings = preload(SETTINGS_PATH).duplicate()
var _source_hash := FileAccess.get_md5(SETTINGS_PATH)
var _flame: PixelFlame
var _stage: SubViewport
var _clock := 1.2
var _paused := false
var _burst := false
var _capturing := false
var _seek := HSlider.new()
var _status := Label.new()
var _inputs: Dictionary = {}
var _views: Array[TextureRect] = []

func _ready() -> void:
	get_window().title = "SPEED — 共通ピクセル炎 / 本人確認待ち"
	var background := ColorRect.new()
	background.color = Color("10141e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var split := HSplitContainer.new()
	margin.add_child(split)
	var controls := VBoxContainer.new()
	controls.custom_minimum_size.x = 330
	split.add_child(controls)
	_label(controls, "共通ピクセル炎", 24)
	_label(controls, "外観は本人確認待ち / 変更は即反映", 14)
	var mode := OptionButton.new()
	mode.add_item("連続燃焼")
	mode.add_item("短い噴出 → 残った炎が消える")
	mode.item_selected.connect(func(index):
		_burst = index == 1
		_flame.emission_duration = 0.3 if _burst else 0.0
		_clock = 0.0
	)
	controls.add_child(mode)
	var playback := HBoxContainer.new()
	controls.add_child(playback)
	var pause := CheckButton.new()
	pause.text = "停止"
	pause.toggled.connect(func(value): _paused = value)
	playback.add_child(pause)
	_button(playback, "1コマ進む", func():
		pause.button_pressed = true
		_clock += 1.0 / (maxf(1.0, _settings.animation_fps if _settings.animation_fps > 0.0 else 60.0) * _settings.speed)
		_refresh()
	)
	_button(playback, "先頭へ", func(): _clock = 0.0; _refresh())
	_seek.min_value = 0.0
	_seek.max_value = 4.0
	_seek.step = 1.0 / 120.0
	_seek.value_changed.connect(func(value): _clock = value; _refresh())
	controls.add_child(_seek)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.add_child(tabs)
	for section: Array in [
		["形", [
			["発生数 / 秒", "birth_rate", 20, 140, 1],
			["発生源の幅", "source_width", 16, 100, 1],
			["粒の半径", "particle_radius", 6, 26, 0.5],
			["外炎の寿命", "outer_lifetime", 0.4, 1.8, 0.02],
			["内炎の寿命", "inner_lifetime", 0.2, 1.3, 0.02],
			["芯の寿命", "core_lifetime", 0.1, 0.8, 0.02],
			["上昇速度", "rise_speed", 30, 160, 1],
			["横風", "wind", -40, 40, 1],
			["揺らぎ", "sway", 0, 20, 0.5],
		]],
		["輪郭", [
			["密度の境界", "density_threshold", 0.1, 0.9, 0.01],
			["縁の柔らかさ", "edge_softness", 0.01, 0.2, 0.01],
			["局所変形", "distortion", 0, 6, 0.1],
			["ドットの大きさ", "pixel_size", 1, 6, 1],
			["時間のコマ数 / 0=連続", "animation_fps", 0, 30, 1],
			["再生速度", "speed", 0.2, 2, 0.05],
		]],
		["色・光", [
			["発光の強さ", "glow_strength", 0, 0.6, 0.01],
			["不透明度", "opacity", 0, 1, 0.01],
		]],
	]:
		var scroll := ScrollContainer.new()
		scroll.name = section[0]
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(scroll)
		var fields := VBoxContainer.new()
		fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fields.add_theme_constant_override("separation", 10)
		scroll.add_child(fields)
		for field: Array in section[1]:
			_field(fields, field)
		if section[0] == "色・光":
			for color: Array in [["輪郭", "outline_color"], ["外炎", "outer_color"], ["内炎", "inner_color"], ["芯", "core_color"]]:
				var row := HBoxContainer.new()
				fields.add_child(row)
				_label(row, color[0])
				var picker := ColorPickerButton.new()
				picker.color = _settings.get(color[1])
				picker.custom_minimum_size = Vector2(120, 32)
				picker.color_changed.connect(func(value): _settings.set(color[1], value); _refresh())
				row.add_child(picker)
				_inputs[color[1]] = picker
	var files := HBoxContainer.new()
	controls.add_child(files)
	_button(files, "調整値を保存", _save)
	_button(files, "保存値へ戻す", _reload)
	_status.text = "保存前の変更は終了時に破棄します。"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(_status)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	_label(right, "合成 / 根元の結合・先端の分離・消失", 20)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(container)
	_stage = SubViewport.new()
	_stage.size = Vector2i(860, 420)
	_stage.disable_3d = true
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_stage)
	var stage_background := DrawLayer.new()
	stage_background.draw_fn = func(c: CanvasItem):
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(_stage.size)), Color("080d17"))
		var base := float(_stage.size.y) * 0.9
		c.draw_line(Vector2(20, base), Vector2(_stage.size.x - 20, base), Color("283448"))
	_stage.add_child(stage_background)
	_stage.size_changed.connect(func(): stage_background.queue_redraw())
	_flame = PixelFlame.new()
	_flame.settings = _settings
	_flame.autoplay = false
	_stage.add_child(_flame)
	var layers := HBoxContainer.new()
	layers.custom_minimum_size.y = 180
	right.add_child(layers)
	for index in 4:
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		layers.add_child(card)
		_label(card, ["外炎 / 長い寿命", "内炎 / 中間の寿命", "芯 / 短い寿命", "RGBの密度 / 輪郭補正前"][index], 13)
		var image := TextureRect.new()
		image.texture = _flame.density_viewport.get_texture()
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var material := ShaderMaterial.new()
		material.shader = PixelFlame.COMPOSITE_SHADER
		material.set_shader_parameter("view_mode", index + 1)
		image.material = material
		card.add_child(image)
		_views.append(image)
	_refresh()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			_capturing = true
			_capture.call_deferred(argument.trim_prefix("--capture="))

func _process(dt: float) -> void:
	if _capturing:
		return
	if not _paused:
		_clock += dt
		if _burst and _clock > 2.5:
			_clock = 0.0
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(_flame):
		return
	_flame.position = Vector2(_stage.size.x * 0.5, _stage.size.y * 0.85).round()
	var zoom := maxf(1.0, floorf(minf(float(_stage.size.y) / 150.0, float(_stage.size.x) / 220.0)))
	_flame.scale = Vector2.ONE * zoom
	_flame.seek(_clock)
	_seek.set_value_no_signal(fmod(_clock, 4.0))
	for view in _views:
		var material := view.material as ShaderMaterial
		_settings.apply(material)
		material.set_shader_parameter("clock", _flame.composite.get_shader_parameter("clock"))

func _field(parent: Control, field: Array) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _label(row, field[0], 14)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spin := SpinBox.new()
	spin.min_value = field[2]
	spin.max_value = field[3]
	spin.step = field[4]
	spin.value = _settings.get(field[1])
	spin.custom_minimum_size.x = 94
	spin.value_changed.connect(func(value): _settings.set(field[1], value); _refresh())
	row.add_child(spin)
	_inputs[field[1]] = spin

func _label(parent: Node, value: String, font_size := 16) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.pressed.connect(action)
	parent.add_child(button)

func _save() -> void:
	if FileAccess.get_md5(SETTINGS_PATH) != _source_hash:
		_status.text = "保存先が外部で変更されています。保存値へ戻してから調整してください。"
		return
	var error := ResourceSaver.save(_settings, SETTINGS_PATH)
	if error != OK:
		_status.text = "保存に失敗しました: %s" % error_string(error)
		return
	_source_hash = FileAccess.get_md5(SETTINGS_PATH)
	_status.text = "data/visuals/pixel_flame.tres に保存しました。本人確認待ち。"

func _reload() -> void:
	_settings = ResourceLoader.load(SETTINGS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE).duplicate()
	_source_hash = FileAccess.get_md5(SETTINGS_PATH)
	_flame.settings = _settings
	for key in _inputs:
		if _inputs[key] is ColorPickerButton:
			_inputs[key].color = _settings.get(key)
		else:
			_inputs[key].set_value_no_signal(_settings.get(key))
	_status.text = "保存値を読み込みました。"
	_refresh()

## 短い描画確認用。粒子を同じ時計へseekし、透明背景の連番とUIを保存する。
func _capture(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var export_view := SubViewport.new()
	export_view.size = PixelFlame.FIELD_SIZE * 2
	export_view.transparent_bg = true
	export_view.disable_3d = true
	export_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(export_view)
	var flame := PixelFlame.new()
	flame.autoplay = false
	flame.settings = _settings
	flame.position = PixelFlame.SOURCE * 2
	flame.scale = Vector2.ONE * 2
	export_view.add_child(flame)
	for mode in ["continuous", "burst"]:
		flame.emission_duration = 0.3 if mode == "burst" else 0.0
		_flame.emission_duration = flame.emission_duration
		for frame in 30:
			_clock = frame / 12.0
			_refresh()
			flame.seek(_clock)
			export_view.size = flame.density_viewport.size * 2
			flame.position = flame.source_position * 2
			for settle in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			export_view.get_texture().get_image().save_png(folder.path_join("%s_%03d.png" % [mode, frame]))
			if frame == 14:
				get_viewport().get_texture().get_image().save_png(folder.path_join(mode + "_ui.png"))
				flame.density_viewport.get_texture().get_image().save_png(folder.path_join(mode + "_density.png"))
		print("[pixel flame] rendered ", mode, " 30 frames / 12fps; output=", folder)
	get_tree().quit()
