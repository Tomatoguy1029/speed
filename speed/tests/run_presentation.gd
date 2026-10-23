## 本番と実験場は、同じRunPresentationを表示の入口に使う。
extends Node
func _ready() -> void:
	var path := "res://scripts/render/run_presentation.gd"
	if not ResourceLoader.exists(path):
		push_error("RunPresentationの入口が必要")
		get_tree().quit(1)
		return
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, true)
	session.auto_step = false
	var presentation := session.view.get_node_or_null("RunPresentation")
	var ok: bool = presentation != null and presentation.get_script().resource_path == path
	session.free()
	await get_tree().process_frame
	print("[run_presentation] ", "OK" if ok else "FAILED")
	get_tree().quit(0 if ok else 1)
