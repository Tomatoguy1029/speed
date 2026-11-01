## 作業コピーの履歴。復元中の通知を記録せず、ドラッグとキーの連続入力をまとめる。
extends RefCounted

var restoring := false
var _history := UndoRedo.new()
var _serial := 0
var _last_key := ""
var _last_msec := 0
var _held := false

func begin_gesture() -> void:
	end_gesture()
	_held = true

func end_gesture() -> void:
	_held = false
	_last_key = ""

func record(key: String, before: Dictionary, after: Dictionary, restore: Callable) -> void:
	if restoring or before == after: return
	var now := Time.get_ticks_msec()
	if key != _last_key or (not _held and now - _last_msec > 500): _serial += 1
	_last_key = key
	_last_msec = now
	_history.create_action("%s/%d" % [key, _serial], UndoRedo.MERGE_ENDS)
	_history.add_do_method(_restore.bind(after.duplicate(true), restore))
	_history.add_undo_method(_restore.bind(before.duplicate(true), restore))
	_history.commit_action(false)

func _restore(snapshot: Dictionary, restore: Callable) -> void:
	restoring = true
	restore.call(snapshot.duplicate(true))
	restoring = false

func undo(redo := false) -> bool:
	end_gesture()
	if redo:
		if not _history.has_redo(): return false
		return _history.redo()
	if not _history.has_undo(): return false
	return _history.undo()

func clear() -> void:
	_history.clear_history()
	end_gesture()

func dispose() -> void:
	clear()
	_history.free()
