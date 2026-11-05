@tool
extends EditorPlugin
const BUILD := preload("res://addons/content_build/builder.gd")
const EXPORT := preload("res://addons/content_build/export.gd")
const GATE := preload("res://addons/runtime_library/run_gate.gd")
const STATE := preload("res://addons/runtime_library/runtime_state.gd")
const BACKGROUND := preload("res://addons/content_build/background_build.gd")
const WATCH_SECONDS := 2.0
var _export: EditorExportPlugin
var _background: Node
var _status: Label
var _watch: Timer
var _play_after := false
var _play_scene := ""
func _enter_tree() -> void:
	_export = EXPORT.new()
	add_export_plugin(_export)
	if DisplayServer.get_name() == "headless" or FileAccess.file_exists(BUILD.ROOT.path_join("stamp.json")): return
	# クローン直後は、F5を待たずに裏でデータを用意する。
	_background = BACKGROUND.new()
	_background.progressed.connect(_on_progressed)
	_background.finished.connect(_on_generated)
	add_child(_background)
	_status = Label.new()
	add_control_to_container(CONTAINER_TOOLBAR,_status)
	_watch = Timer.new()
	_watch.wait_time = WATCH_SECONDS
	_watch.timeout.connect(_start_when_ready)
	add_child(_watch)
	_watch.start()
func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null
	if is_instance_valid(_status):
		remove_control_from_container(CONTAINER_TOOLBAR,_status)
		_status.queue_free()
## 生成にはimport済みの素材とC++ライブラリが要る。どちらも揃ってから始める。
func _start_when_ready() -> void:
	if EditorInterface.get_resource_filesystem().is_scanning() or not FileAccess.file_exists(STATE.library_path()): return
	_watch.stop()
	if _background.start(): _status.text = "データ: 生成中"
	else: _status.text = "データ: F5で生成"
func _on_progressed(unit: String) -> void:
	_status.text = "データ: 生成中 (%s)" % unit
func _on_generated(success: bool) -> void:
	_status.text = "" if success else "データ: 失敗（F5で再試行）"
	if not success: push_error("実行用データの生成に失敗しました。F5で再試行してください。")
	if not _play_after or not success: return
	_play_after = false
	if _play_scene.is_empty(): EditorInterface.play_main_scene()
	else: GATE.play_scene(_play_scene)
func _build() -> bool:
	var scene := GATE.requested_scene
	if not GATE.allow_run(): return false
	if is_instance_valid(_background) and _background.running:
		_play_after = true
		_play_scene = scene
		EditorInterface.get_editor_toaster().push_toast("データを生成中です。終わったら起動します。")
		return false
	var started := Time.get_ticks_usec()
	if BUILD.is_unchanged():
		print("起動前の確認: %.2f秒（変更なし）" % ((Time.get_ticks_usec()-started)/1000000.0))
		return true
	var error := BUILD.build_for_editor()
	var rebuilt := BUILD.last_build_report.filter(func(row): return row.rebuilt).size()
	print("起動前の生成: %.2f秒（作り直し%d件）" % [(Time.get_ticks_usec()-started)/1000000.0,rebuilt])
	if error != OK: push_error("実行用データの生成に失敗: %s" % error_string(error))
	return error == OK
