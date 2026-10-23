## Nodeを選択しても、タイムラインのResource配列を不正に検索しない。
## godot --headless --editor --path speed --script res://tests/spawn_timeline_selection.gd
@tool
extends SceneTree

const TimelinePlugin := preload("res://addons/spawn_timeline/plugin.gd")
const Timeline := preload("res://addons/spawn_timeline/timeline.gd")

class TestPanel extends Timeline:
	var saves := 0
	func _save() -> void:
		saves += 1
	func refresh() -> void:
		pass

class ArrayErrors extends Logger:
	var messages: Array[String] = []
	var mutex := Mutex.new()
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if code.contains("typed.validate") or rationale.begins_with("Attempted to use 'has'"):
			mutex.lock()
			messages.append(code + " " + rationale)
			mutex.unlock()

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var subject := TimelinePlugin.new()
	var panel := TestPanel.new()
	var main := TestPanel.new()
	var stage := StageDef.new()
	var phase := PhaseDef.new()
	var clip := SpawnClip.new()
	stage.phases = [phase]
	stage.clips = [clip]
	panel.stage = stage
	subject._panel = panel
	subject._main = main
	var marker := Node2D.new()
	marker.name = "EnemyMarker"
	root.add_child(marker)
	var errors := ArrayErrors.new()
	OS.add_logger(errors)
	for object in [marker, Resource.new(), null, phase, clip]:
		EditorInterface.inspect_object(object)
		subject._on_inspected()
		subject._queue_phase_save()
		var related: bool = object == phase or object == clip
		_check(subject._save_queued == related, "Only stage resources queue a save")
		# 保存を予約した直後にNodeへ選択が移った場合も検証する。
		EditorInterface.inspect_object(marker)
		subject._save_phase_changes()
		_check(not subject._save_queued, "Deferred save clears its pending state")
	_check(panel.saves == 5, "Queued saves preserve the opened stage after selection changes")
	_check(errors.messages.is_empty(), "Selection must not emit TypedArray errors: %s" % [errors.messages])
	EditorInterface.inspect_object(null)
	marker.free()
	panel.free()
	main.free()
	subject.free()
	print("[spawn_timeline_selection] %d checks, %d failures, %d array errors" % [checks, failures, errors.messages.size()])
	quit(1 if failures else 0)
