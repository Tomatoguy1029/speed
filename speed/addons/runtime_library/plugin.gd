## C++ライブラリの状態表示、自動取得、Godot内ビルド、実行前の確認。
@tool
extends EditorPlugin
const STATE := preload("res://addons/runtime_library/runtime_state.gd")
const IDENTITY := preload("res://addons/runtime_library/runtime_id.gd")
const GATE := preload("res://addons/runtime_library/run_gate.gd")
const Fetcher := preload("res://addons/runtime_library/fetcher.gd")
const BuildPanel := preload("res://addons/runtime_library/build_panel.gd")
const RETRY_MSEC := 60000
const STATE_STALE_TEXT := "C++ライブラリがソースより古いままです。"
const STATE_MISSING_TEXT := "C++ライブラリがありません。「ビルド」を押すか、取得が終わるのを待ってください。"
var _bar: HBoxContainer
var _label: Label
var _build_button: Button
var _fetcher: Fetcher
var _panel: BuildPanel
var _dialog: ConfirmationDialog
var _current := ""
var _unpublished_id := ""
var _failed_id := ""
var _loaded_at_start := false
var _pending_scene := ""
var _pending_id := ""
var _checked_at := 0

func _enter_tree() -> void:
	if DisplayServer.get_name() == "headless": return
	_loaded_at_start = ClassDB.class_exists(&"SpeedRunCore")
	STATE.remove_retired()
	_bar = HBoxContainer.new()
	_label = Label.new()
	_bar.add_child(_label)
	_build_button = Button.new()
	_build_button.text = "ビルド"
	_build_button.pressed.connect(_on_build_pressed)
	_bar.add_child(_build_button)
	add_control_to_container(CONTAINER_TOOLBAR,_bar)
	_fetcher = Fetcher.new()
	_fetcher.finished.connect(_on_fetched)
	add_child(_fetcher)
	_panel = BuildPanel.new()
	_panel.finished.connect(_on_built)
	add_control_to_bottom_panel(_panel,"C++ビルド")
	_dialog = ConfirmationDialog.new()
	_dialog.ok_button_text = "このまま起動"
	_dialog.add_button("ビルド",true,"build")
	_dialog.confirmed.connect(_on_run_anyway)
	_dialog.custom_action.connect(_on_dialog_action)
	EditorInterface.get_base_control().add_child(_dialog)
	GATE.on_blocked = _on_blocked
	refresh()

func _exit_tree() -> void:
	if not is_instance_valid(_bar): return
	GATE.on_blocked = Callable()
	remove_control_from_container(CONTAINER_TOOLBAR,_bar)
	_bar.queue_free()
	remove_control_from_bottom_panel(_panel)
	_panel.queue_free()
	_dialog.queue_free()

func _notification(what: int) -> void:
	# pull などでソースが変わるので、エディターへ戻るたびに確認する。
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_instance_valid(_bar): refresh()

func refresh() -> void:
	_current = IDENTITY.compute(STATE.cpp_directory())
	# CIの完了待ちを拾うため、一定時間ごとに取得をやり直す。
	if Time.get_ticks_msec()-_checked_at > RETRY_MSEC:
		_checked_at = Time.get_ticks_msec()
		_unpublished_id = ""
		_failed_id = ""
	var state := STATE.state_of(_current)
	if state in [STATE.State.STALE,STATE.State.MISSING] and not _panel.running and _current != _unpublished_id and _current != _failed_id:
		_fetcher.fetch(_current)
	_show_state(state)

func _show_state(state: STATE.State) -> void:
	_build_button.text = "中止" if _panel.running else "ビルド"
	if _panel.running:
		_label.text = "C++: ビルド中"
	elif _fetcher.busy:
		_label.text = "C++: 取得中"
	elif state == STATE.State.CURRENT:
		_label.text = "C++: 最新" if _loaded_at_start else "C++: 再起動で反映"
	elif state == STATE.State.MISSING:
		_label.text = "C++: なし"
	elif state == STATE.State.STALE:
		_label.text = "C++: 古い"
	else:
		_label.text = "C++: ソースなし"

func _on_fetched(result: Fetcher.Result,detail: String) -> void:
	if result == Fetcher.Result.NOT_PUBLISHED:
		_unpublished_id = _current
	elif result == Fetcher.Result.FAILED:
		_failed_id = _current
		print("[Runtime Library] ",detail)
	elif ClassDB.class_exists(&"SpeedRunCore"):
		_loaded_at_start = true
	refresh()

func _on_build_pressed() -> void:
	if _panel.running:
		_panel.cancel()
		return
	_panel.start()
	make_bottom_panel_item_visible(_panel)
	_show_state(STATE.state_of(_current))

func _on_built(_success: bool) -> void:
	_unpublished_id = ""
	_failed_id = ""
	refresh()

func _on_blocked(state: STATE.State,current: String,scene: String) -> void:
	_pending_id = current
	_pending_scene = scene
	_dialog.title = "C++ライブラリの確認"
	_dialog.dialog_text = STATE_MISSING_TEXT if state == STATE.State.MISSING else STATE_STALE_TEXT
	_dialog.get_ok_button().visible = state == STATE.State.STALE
	_dialog.popup_centered()

func _on_run_anyway() -> void:
	GATE.accepted_id = _pending_id
	if _pending_scene.is_empty(): EditorInterface.play_main_scene()
	else: EditorInterface.play_custom_scene(_pending_scene)

func _on_dialog_action(action: StringName) -> void:
	if action != &"build": return
	_dialog.hide()
	if not _panel.running: _on_build_pressed()
