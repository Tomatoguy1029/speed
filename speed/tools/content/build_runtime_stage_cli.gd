extends SceneTree
func _initialize() -> void:
	quit(load("res://tools/content/build_runtime_stage.gd").build_all())
