## メニューを開いても、戦闘用の定義を読み込まずに表示できる。
extends Node
var failed := 0
func _ready() -> void:
	var paths := []
	for category in [&"stages", &"weapons", &"traits", &"legendary_modules", &"meta_upgrades"]:
		for entry in ContentManager.catalog.table(category).values(): paths.append(entry.path)
	for name in ["title", "stage_select", "encyclopedia", "upgrade"]:
		var screen: Node = load("res://scenes/app/%s.tscn" % name).instantiate()
		add_child(screen)
		await get_tree().process_frame
		await get_tree().process_frame
		for path in paths:
			if ResourceLoader.has_cached(path):
				failed += 1
				push_error("%sが定義を読んだ: %s" % [name, path])
		screen.queue_free()
		await get_tree().process_frame
	print("[menu_catalog] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
