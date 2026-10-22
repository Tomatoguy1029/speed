@tool
extends EditorPlugin
const BUILD := preload("res://addons/content_build/builder.gd")
const EXPORT := preload("res://addons/content_build/export.gd")
var _export: EditorExportPlugin
func _enter_tree() -> void:
	_export = EXPORT.new()
	add_export_plugin(_export)
func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null
func _build() -> bool:
	var error := BUILD.build_all()
	if error != OK: push_error("実行用データの生成に失敗: %s" % error_string(error))
	return error == OK
