@tool
extends EditorPlugin
const BUILD := preload("res://addons/content_build/builder.gd")
const EXPORT := preload("res://addons/content_build/export.gd")
const GATE := preload("res://addons/runtime_library/run_gate.gd")
var _export: EditorExportPlugin
func _enter_tree() -> void:
	_export = EXPORT.new()
	add_export_plugin(_export)
func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null
func _build() -> bool:
	if not GATE.allow_run(): return false
	var started := Time.get_ticks_usec()
	var error := BUILD.build_for_editor()
	var rebuilt := BUILD.last_build_report.filter(func(row): return row.rebuilt).size()
	print("起動前の生成: %.2f秒（作り直し%d件）" % [(Time.get_ticks_usec()-started)/1000000.0,rebuilt])
	if error != OK: push_error("実行用データの生成に失敗: %s" % error_string(error))
	return error == OK
