@tool
extends EditorExportPlugin
var _development_settings: Dictionary = {}
const BUILD := preload("res://addons/content_build/builder.gd")
func _get_name() -> String:
	return "SpeedContentBuild"
func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var error := BUILD.build_all()
	if error != OK:
		get_export_platform().add_message(EditorExportPlatform.EXPORT_MESSAGE_ERROR, "SPEED", "実行用データの生成に失敗: %s" % error_string(error))
		return
	# パッケージの設定から開発用の入口だけを外し、終了時にエディターの値を戻す。
	for key in ["autoload/DevBootstrap", "editor_plugins/enabled"]:
		if ProjectSettings.has_setting(key):
			_development_settings[key] = ProjectSettings.get_setting(key)
			ProjectSettings.set_setting(key, null)
	# 隠しフォルダの生成物を明示的に含める。開発用の名前の対応表は含めない。
	for file in DirAccess.get_files_at(BUILD.ROOT):
		if file.get_extension() in ["tres", "res"]:
			var path := BUILD.ROOT.path_join(file)
			add_file(path, FileAccess.get_file_as_bytes(path), false)

func _export_end() -> void:
	for key: String in _development_settings:
		ProjectSettings.set_setting(key, _development_settings[key])
	_development_settings.clear()
