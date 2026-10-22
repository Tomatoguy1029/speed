@tool
extends EditorExportPlugin
const BUILD := preload("res://addons/content_build/builder.gd")
func _get_name() -> String:
	return "SpeedContentBuild"
func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var error := BUILD.build_all()
	if error != OK:
		get_export_platform().add_message(EditorExportPlatform.EXPORT_MESSAGE_ERROR, "SPEED", "実行用データの生成に失敗: %s" % error_string(error))
		return
	# 隠しフォルダの生成物を明示的に含める。開発用の名前の対応表は含めない。
	for file in DirAccess.get_files_at(BUILD.ROOT):
		if file.ends_with(".tres"):
			var path := BUILD.ROOT.path_join(file)
			add_file(path, FileAccess.get_file_as_bytes(path), false)
