## 下部パネルのビルドログ。ビルドは別プロセスで動かし、完了を通知する。
@tool
extends VBoxContainer
signal finished(success: bool)
const STATE := preload("res://addons/runtime_library/runtime_state.gd")
const POLL_SECONDS := 0.2
var running := false
var _log: TextEdit
var _pid := 0
var _stdout: FileAccess
var _stderr: FileAccess
var _timer: Timer
var _cancel_path := ""

func _ready() -> void:
	name = "C++ビルド"
	_log = TextEdit.new()
	_log.editable = false
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size = Vector2(0,160)
	add_child(_log)
	_timer = Timer.new()
	_timer.wait_time = POLL_SECONDS
	_timer.timeout.connect(_poll)
	add_child(_timer)

static func _python() -> PackedStringArray:
	for candidate: String in (["py","python","python3"] if OS.get_name() == "Windows" else ["python3","python"]):
		var output := []
		if OS.execute(candidate,PackedStringArray(["--version"]),output,true) == 0: return PackedStringArray([candidate])
	return PackedStringArray()

func _append(text: String) -> void:
	if text.is_empty(): return
	_log.text += text
	_log.scroll_vertical = _log.get_line_count()

func start() -> void:
	if running: return
	_log.text = ""
	var python := _python()
	if python.is_empty():
		_append("Pythonが見つかりません。Python 3を入れてください。\n")
		finished.emit(false)
		return
	var root := STATE.project_root()
	_cancel_path = STATE.bin_directory().path_join(".cancel-build")
	DirAccess.make_dir_recursive_absolute(STATE.bin_directory())
	DirAccess.remove_absolute(_cancel_path)
	var process := OS.execute_with_pipe(python[0],PackedStringArray(["-u",root.path_join("tools/build/dev_build.py"),"build","--cancel-file",_cancel_path]),false)
	if process.is_empty():
		_append("ビルドを開始できません。\n")
		finished.emit(false)
		return
	_pid = process.pid
	_stdout = process.stdio
	_stderr = process.stderr
	running = true
	_timer.start()

func cancel() -> void:
	if not running: return
	var file := FileAccess.open(_cancel_path,FileAccess.WRITE)
	if file != null: file.close()

func _drain() -> void:
	for pipe: FileAccess in [_stdout,_stderr]:
		var bytes := pipe.get_buffer(65536)
		if not bytes.is_empty(): _append(bytes.get_string_from_utf8())

func _poll() -> void:
	_drain()
	if OS.is_process_running(_pid): return
	_drain()
	_timer.stop()
	running = false
	var code := OS.get_process_exit_code(_pid)
	DirAccess.remove_absolute(_cancel_path)
	finished.emit(code == 0)
