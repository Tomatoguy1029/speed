extends SceneTree
func _initialize() -> void:
	var error: Error = load("res://addons/content_build/builder.gd").build_all("--force" in OS.get_cmdline_user_args())
	if error != OK: push_error("実行用データの生成に失敗: %s" % error_string(error))
	quit(error)
