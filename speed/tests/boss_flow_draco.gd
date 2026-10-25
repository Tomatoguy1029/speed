extends SceneTree
func _initialize() -> void: call_deferred("exercise")
func exercise() -> void:
	var editor = load("res://tools/editor/boss_flow/editor.gd").new()
	root.add_child(editor)
	var listed := false
	for picker in editor.find_children("*", "OptionButton", true, false):
		for index in picker.item_count:
			if picker.get_item_text(index) == "りゅう座": listed = true
	if not listed:
		push_error("ボス選択に竜を表示する")
		quit(1)
		return
	assert(editor.open_boss("res://data/bosses/ai/draco_action_rules.tres", "res://data/bosses/ai/draco_flow.tres") == OK)
	assert(editor.preview_scene() == "res://gyms/boss_flow_trial.tscn")
	editor.queue_free()
	await process_frame
	print("[boss-draco-editor] PASS")
	quit()
