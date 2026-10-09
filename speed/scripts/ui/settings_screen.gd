## 設定（仕様書 3）。音量・画面モード・キー設定。変えるとすぐ反映し、設定のファイルに保存する。
extends UiScreen

const VOLUMES := [["master_volume", "全体の音量"], ["sfx_volume", "効果音"], ["engine_volume", "エンジン音"]]
const WINDOW_MODES := [["windowed", "ウィンドウ"], ["fullscreen", "フルスクリーン"], ["exclusive", "排他フルスクリーン"]]

## キーの割り当てを待っているアクション（なければ空）
var _waiting: StringName = &""
var _bind_buttons: Dictionary = {}

func _ready() -> void:
	_section("音量")
	for v in VOLUMES:
		_slider_row(v[0], v[1])
	var mute := CheckBox.new()
	mute.text = "消音（M キーでも切り替え）"
	mute.button_pressed = bool(SaveManager.settings.muted)
	mute.toggled.connect(func(on): SaveManager.set_setting("muted", on))
	%Content.add_child(mute)
	_section("画面モード")
	var mode := OptionButton.new()
	mode.custom_minimum_size = Vector2(320, 44)
	mode.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for i in WINDOW_MODES.size():
		mode.add_item(WINDOW_MODES[i][1], i)
		if WINDOW_MODES[i][0] == SaveManager.settings.window_mode:
			mode.select(i)
	mode.item_selected.connect(func(i): SaveManager.set_setting("window_mode", WINDOW_MODES[i][0]))
	%Content.add_child(mode)
	_section("キー設定（ボタンを押してから、割り当てるキーを押す）")
	for action in InputActions.REBINDABLE:
		_binding_row(action, InputActions.REBINDABLE[action])
	var reset := Button.new()
	reset.text = "キー設定を初期値に戻す"
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(_reset_bindings)
	%Content.add_child(reset)
	super()

func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	%Content.add_child(l)

func _slider_row(key: String, label_text: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.custom_minimum_size = Vector2(220, 0)
	label.text = label_text
	row.add_child(label)
	var s := HSlider.new()
	s.custom_minimum_size = Vector2(360, 32)
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(SaveManager.settings[key])
	s.value_changed.connect(func(v): SaveManager.set_setting(key, v))
	row.add_child(s)
	%Content.add_child(row)

func _binding_row(action: StringName, label_text: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.custom_minimum_size = Vector2(300, 0)
	label.text = label_text
	row.add_child(label)
	var b := Button.new()
	b.custom_minimum_size = Vector2(220, 44)
	b.pressed.connect(func(): _wait_for_key(action))
	row.add_child(b)
	_bind_buttons[action] = b
	_refresh_binding(action)
	%Content.add_child(row)

func _refresh_binding(action: StringName) -> void:
	var code := InputActions.key_of(action)
	_bind_buttons[action].text = OS.get_keycode_string(code) if code != 0 else "（なし）"

func _wait_for_key(action: StringName) -> void:
	_waiting = action
	_bind_buttons[action].text = "キーを押す…"

func _input(event: InputEvent) -> void:
	if _waiting == &"" or not (event is InputEventKey) or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	var action := _waiting
	_waiting = &""
	SaveManager.set_binding(action, event.physical_keycode)
	_refresh_binding(action)

func _reset_bindings() -> void:
	SaveManager.settings.bindings = {}
	SaveManager.set_setting("bindings", {})
	for action in _bind_buttons:
		_refresh_binding(action)
