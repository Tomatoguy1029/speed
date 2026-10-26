## 炎・オーラ・後光・マップの制作入口。描画と保存は既存プレビューが所有する。
extends Control

const TOOLS := [
	["fire", "炎", "res://gyms/pixel_fire_preview.gd"],
	["aura", "オーラ", "res://gyms/legendary_reveal_preview.gd"],
	["rays", "後光", "res://gyms/legendary_reveal_preview.gd"],
	["map", "マップ", "res://gyms/map_reveal_preview.gd"],
]

var _sessions: Dictionary = {}
var _buttons: Array[Button] = []
var _selected := 0
var _previews := VBoxContainer.new()
var _controls := VBoxContainer.new()
var _path := LineEdit.new()
var _dirty := Label.new()
var _status := Label.new()
var _save := Button.new()
var _reload := Button.new()
var _close := Button.new()
var _confirm := ConfirmationDialog.new()
var _pending_action: Callable
var _previous_auto_quit := true

func _ready() -> void:
	get_window().title = "SPEED — ビジュアル編集"
	theme = Theme.new()
	theme.default_font_size = 18
	var background := ColorRect.new()
	background.color = Color("171b24")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_previous_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := Label.new()
	title.text = "ビジュアル編集"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_dirty.tooltip_text = "各ツールの調整値は切替後も保持します。保存は表示中の保存先だけへ行います。"
	heading.add_child(_dirty)
	_save.text = "保存"
	_save.pressed.connect(func():
		_current().save_current()
		_refresh())
	heading.add_child(_save)
	_reload.text = "再読込"
	_reload.pressed.connect(func(): request_reload(_current().reload_current))
	heading.add_child(_reload)
	_close.text = "閉じる"
	_close.pressed.connect(request_close)
	heading.add_child(_close)
	var path_row := HBoxContainer.new()
	layout.add_child(path_row)
	var path_label := Label.new()
	path_label.text = "保存先"
	path_row.add_child(path_label)
	_path.editable = false
	_path.add_theme_color_override("font_uneditable_color", Color("bdcbd8"))
	_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_row.add_child(_path)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(columns)
	var types := VBoxContainer.new()
	types.custom_minimum_size.x = 72
	columns.add_child(types)
	var group := ButtonGroup.new()
	for index in TOOLS.size():
		var button := Button.new()
		button.text = TOOLS[index][1]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size.y = 44
		button.pressed.connect(select_tool.bind(index))
		types.add_child(button)
		_buttons.append(button)
	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(split)
	_previews.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_previews.custom_minimum_size.x = 220
	split.add_child(_previews)
	_controls.custom_minimum_size.x = 260
	_controls.size_flags_horizontal = Control.SIZE_FILL
	split.add_child(_controls)
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	layout.add_child(_status)
	_confirm.title = "未保存の調整値"
	_confirm.ok_button_text = "破棄して続ける"
	_confirm.cancel_button_text = "編集に戻る"
	_confirm.confirmed.connect(func():
		var action := _pending_action
		_pending_action = Callable()
		if action.is_valid(): action.call())
	_confirm.canceled.connect(func(): _pending_action = Callable())
	add_child(_confirm)
	select_tool(0)

func _key(index: int) -> String:
	return "legendary" if index in [1, 2] else TOOLS[index][0]

func _current() -> Variant:
	return _sessions[_key(_selected)].editor

func select_tool(index: int) -> void:
	if index < 0 or index >= TOOLS.size() or is_busy():
		return
	var key := _key(index)
	if not _sessions.has(key):
		var preview := VBoxContainer.new()
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_previews.add_child(preview)
		var controls := VBoxContainer.new()
		controls.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_controls.add_child(controls)
		# 未選択のツールは、依存する絵・シーン・生成用資源も読み込まない。
		var editor = load(TOOLS[index][2]).new()
		editor.preview_host = preview
		editor.controls_host = controls
		editor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if key == "fire":
			editor.request_reload = request_reload
		_sessions[key] = {"editor": editor, "preview": preview, "controls": controls}
		add_child(editor)
	_selected = index
	for session_key in _sessions:
		var session: Dictionary = _sessions[session_key]
		var active: bool = session_key == key
		session.preview.visible = active
		session.controls.visible = active
		session.preview.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
		session.editor.visible = active
		session.editor.set_active(active)
	if key == "legendary":
		_current().set_section(TOOLS[index][0])
	_buttons[index].set_pressed_no_signal(true)
	_refresh()

func is_busy() -> bool:
	for session in _sessions.values():
		if session.editor.editing_state().busy:
			return true
	return false

func dirty_paths() -> Array[String]:
	var paths: Array[String] = []
	for session in _sessions.values():
		for path in session.editor.editing_state().dirty_paths:
			if path not in paths:
				paths.append(path)
	return paths

func _process(_delta: float) -> void:
	var controls_width := 340.0 if get_viewport_rect().size.x >= 800.0 else 260.0
	if _controls.custom_minimum_size.x != controls_width:
		_controls.custom_minimum_size.x = controls_width
	_refresh()

func _refresh() -> void:
	if _sessions.is_empty(): return
	var state: Dictionary = _current().editing_state()
	var busy := is_busy()
	var short_path: String = state.path.get_file()
	if _path.text != short_path:
		_path.text = short_path
	_path.tooltip_text = state.path
	var current_dirty: bool = state.path in state.dirty_paths
	_dirty.text = "● 未保存" if current_dirty else "保存済"
	_dirty.tooltip_text = "全体の未保存 %d件。切替後も調整値を保持します" % dirty_paths().size()
	_status.text = state.message
	_status.tooltip_text = state.message
	_save.disabled = busy or state.path.is_empty()
	_reload.disabled = busy or state.path.is_empty()
	_close.disabled = busy
	for index in _buttons.size():
		var key := _key(index)
		var changed: bool = _sessions.has(key) and not _sessions[key].editor.editing_state().dirty_paths.is_empty()
		_buttons[index].text = TOOLS[index][1] + (" ●" if changed else "")
		_buttons[index].disabled = busy

func request_reload(action: Callable) -> void:
	if is_busy(): return
	var state: Dictionary = _current().editing_state()
	if state.path not in state.dirty_paths:
		action.call()
		return
	_pending_action = action
	_confirm.dialog_text = "この素材の未保存値を破棄して読み込みます。\n" + state.path
	_confirm.popup_centered(Vector2i(560, 180))

func request_close() -> void:
	if is_busy(): return
	var paths := dirty_paths()
	if paths.is_empty():
		get_tree().quit()
		return
	_pending_action = func(): get_tree().quit()
	_confirm.dialog_text = "未保存の調整値を破棄して閉じます。\n" + "\n".join(paths)
	_confirm.popup_centered(Vector2i(600, 220))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_close()

func _exit_tree() -> void:
	get_tree().auto_accept_quit = _previous_auto_quit
