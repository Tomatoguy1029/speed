@tool
extends EditorExportPlugin
var _development_settings: Dictionary = {}
const BUILD := preload("res://addons/content_build/builder.gd")
func _get_name() -> String:
	return "SpeedContentBuild"
func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var error := BUILD.build_for_editor()
	if error != OK:
		get_export_platform().add_message(EditorExportPlatform.EXPORT_MESSAGE_ERROR, "SPEED", "実行用データの生成に失敗: %s" % error_string(error))
		return
	# パッケージの設定から開発用の入口だけを外し、終了時にエディターの値を戻す。
	for key in ["autoload/DevBootstrap", "editor_plugins/enabled"]:
		if ProjectSettings.has_setting(key):
			_development_settings[key] = ProjectSettings.get_setting(key)
			ProjectSettings.set_setting(key, null)
	# 隠しフォルダの生成物を明示的に含める。開発用の名前の対応表は含めない。
	var index := ResourceLoader.load(BUILD.ROOT.path_join("visual_index.tres"), "", ResourceLoader.CACHE_MODE_IGNORE) as StageResources
	for file in DirAccess.get_files_at(BUILD.ROOT):
		if file == "boss_preview.tres": continue
		if file.begins_with("look_") and not BUILD.ROOT.path_join(file) in index.look_paths.values(): continue
		if file.get_extension() in ["tres", "res"]:
			var path := BUILD.ROOT.path_join(file)
			add_file(path, FileAccess.get_file_as_bytes(path), false)

	# ランの索引・値型定義と資源一覧は生成結果の参照を保ったまま登録する。
	var stamp_path := BUILD.ROOT.path_join("stamp.json")
	var stamp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(stamp_path))
	stamp.outputs = stamp.outputs.filter(func(output):return not String(output).begins_with(BUILD.ROOT.path_join("dev/")))
	add_file(stamp_path, JSON.stringify(stamp).to_utf8_buffer(), false)
	# 内容ハッシュ別の旧世代は開発用キャッシュとして残る。現在の出力一覧だけを配布する。
	for output: String in stamp.outputs:
		if output.begins_with(BUILD.ROOT.path_join("run/")):
			add_file(output, FileAccess.get_file_as_bytes(output), false)
	add_file("res://licenses/run/GODOT.txt", Engine.get_license_text().to_utf8_buffer(), false)
	var notices := PackedStringArray()
	for component in Engine.get_copyright_info():
		notices.append(str(component.name))
		for part in component.parts:
			notices.append("\n".join(part.copyright))
			notices.append(str(part.license))
			notices.append("\n".join(part.files))
	notices.append(JSON.stringify(Engine.get_license_info(), "\t"))
	add_file("res://licenses/run/GODOT-THIRD-PARTY.txt", "\n\n".join(notices).to_utf8_buffer(), false)

func _export_end() -> void:
	for key: String in _development_settings:
		ProjectSettings.set_setting(key, _development_settings[key])
	_development_settings.clear()
