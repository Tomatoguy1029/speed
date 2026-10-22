extends SceneTree
func _initialize() -> void:
	quit(load("res://tools/content/build_catalog.gd").build())
