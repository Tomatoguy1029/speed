## 実行前の判定。ビルドは始めず、古いライブラリは利用者に選んでもらう。
@tool
extends RefCounted
const STATE := preload("res://addons/runtime_library/runtime_state.gd")
const IDENTITY := preload("res://addons/runtime_library/runtime_id.gd")
const NON_INTERACTIVE_ARGUMENTS := ["--export-release","--export-debug","--export-pack","--headless"]
## 古いまま起動すると選んだソースの識別子。同じソースでは聞き直さない。
static var accepted_id := ""
## 道具から起動する場面。空ならメインシーンを起動する。
static var requested_scene := ""
## 判定結果を受け取る plugin.gd の関数。
static var on_blocked := Callable()

## 道具から場面を起動するときは、古いライブラリの確認後に同じ場面へ戻せるよう記録する。
static func play_scene(path: String) -> void:
	requested_scene = path
	EditorInterface.play_custom_scene(path)

static func _interactive() -> bool:
	for argument in OS.get_cmdline_args():
		if argument in NON_INTERACTIVE_ARGUMENTS: return false
	return on_blocked.is_valid()

## false を返すと起動を止める。
static func allow_run() -> bool:
	if not _interactive(): return true
	var current := IDENTITY.compute(STATE.cpp_directory())
	var state := STATE.state_of(current)
	if state in [STATE.State.CURRENT,STATE.State.NO_SOURCE] or (state == STATE.State.STALE and accepted_id == current):
		requested_scene = ""
		return true
	on_blocked.call_deferred(state,current,requested_scene)
	requested_scene = ""
	return false
