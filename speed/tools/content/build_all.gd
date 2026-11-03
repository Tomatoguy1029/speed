extends SceneTree
func _initialize() -> void:
	var builder = load("res://addons/content_build/builder.gd")
	var error: Error = builder.build_all("--force" in OS.get_cmdline_user_args())
	if "--editor-build-report" in OS.get_cmdline_user_args():
		print(builder.EDITOR_RESULT_PREFIX+JSON.stringify({"error":error,"report":builder.last_build_report}))
	if error != OK: push_error("実行用データの生成に失敗: %s" % error_string(error))
	quit(error)
