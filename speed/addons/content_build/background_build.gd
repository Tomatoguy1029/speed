## 実行用データの生成を別プロセスで動かし、エディターを止めない。
@tool
extends Node
signal progressed(unit: String)
signal finished(success: bool)
const BUILD := preload("res://addons/content_build/builder.gd")
const INCREMENTAL := preload("res://addons/content_build/incremental.gd")
const POLL_SECONDS := 0.2
var running := false
var _pid := 0
var _stdout: FileAccess
var _stderr: FileAccess
var _partial := ""
var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = POLL_SECONDS
	_timer.timeout.connect(_poll)
	add_child(_timer)

func _exit_tree() -> void:
	if running: OS.kill(_pid)

func start() -> bool:
	if running: return true
	var args := BUILD.editor_arguments()
	args.append(INCREMENTAL.PROGRESS_ARGUMENT)
	var process := OS.execute_with_pipe(OS.get_executable_path(),args,false)
	if process.is_empty(): return false
	_pid = process.pid
	_stdout = process.stdio
	_stderr = process.stderr
	_partial = ""
	running = true
	_timer.start()
	return true

func _drain() -> void:
	_stderr.get_buffer(65536)
	_partial += _stdout.get_buffer(65536).get_string_from_utf8()
	var lines := _partial.split("\n")
	_partial = lines[-1]
	for index in lines.size()-1:
		if lines[index].begins_with(INCREMENTAL.PROGRESS_PREFIX):
			progressed.emit(lines[index].trim_prefix(INCREMENTAL.PROGRESS_PREFIX))

func _poll() -> void:
	_drain()
	if OS.is_process_running(_pid): return
	_drain()
	_timer.stop()
	running = false
	finished.emit(OS.get_process_exit_code(_pid) == 0)
