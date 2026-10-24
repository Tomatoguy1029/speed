## 区間の接続・候補・禁止ペアを、保存と履歴を通して確認する。
extends SceneTree
func _initialize() -> void: call_deferred("exercise")
func exercise() -> void:
	root.size = Vector2i(1280, 900)
	var rules = load("res://scripts/data_types/boss_action_rules.gd").new()
	rules.techniques.append(load("res://data/bosses/hydra_moves/bite_thrust.tres"))
	var flow = load("res://scripts/data_types/boss_flow_def.gd").new()
	flow.sections = [{"name": "A", "next": 1}, {"name": "B", "next": 2}, {"name": "C", "next": 1}]
	DirAccess.make_dir_recursive_absolute("res://.content/tests")
	var rules_path := "res://.content/tests/sections_action_rules.tres"
	var flow_path := "res://.content/tests/sections_flow.tres"
	ResourceSaver.save(rules, rules_path)
	ResourceSaver.save(flow, flow_path)
	var panel = load("res://addons/boss_flow/editor.gd").new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	assert(panel.open_boss(rules_path, flow_path) == OK)
	await process_frame
	panel.flow_graph.connection_request.emit(&"section_2", 0, &"section_0", 0)
	assert(panel.flow.sections[2].next == 0)
	panel.undo_edit()
	assert(panel.flow.sections[2].next == 1)
	panel.redo_edit()
	assert(panel.flow.sections[2].next == 0)
	panel._set_section_techniques(0, false, ["bite_thrust"])
	panel._set_section_forbidden(0, [["bite_thrust", "bite_thrust"]])
	assert(not panel.flow.sections[1].has("forbidden"))
	panel.flow_graph.get_node("section_0").selected = true
	panel.flow_graph.get_node("section_1").selected = true
	panel.flow_graph.command("copy")
	panel.flow_graph.command("paste")
	assert(panel.flow.sections.size() == 5 and panel.flow.sections[3].next == 4)
	panel.undo_edit()
	assert(panel.flow.sections.size() == 3)
	panel.redo_edit()
	assert(panel.flow.sections.size() == 5)
	panel.flow_graph.begin_node_move.emit()
	panel.flow_graph.get_node("section_1").position_offset.y += 70
	panel.flow_graph.end_node_move.emit()
	var moved_y: float = panel.flow_graph.get_node("section_1").position_offset.y
	panel.flow_graph.command("align")
	assert(is_equal_approx(panel.flow_graph.get_node("section_0").position_offset.y, panel.flow_graph.get_node("section_1").position_offset.y), "section alignment keeps the flow horizontal")
	panel.undo_edit()
	assert(panel.flow_graph.get_node("section_1").position_offset.y == moved_y)
	assert(panel.save_current() == OK)
	var saved = ResourceLoader.load(flow_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	assert(saved.sections[2].next == 0 and saved.sections[3].next == 4)
	assert(saved.sections[0].allowed_techniques == ["bite_thrust"] and saved.sections[0].forbidden.size() == 1)
	var compiler = load("res://tools/content/build_boss_program.gd")
	assert(compiler.compile({"rules": rules, "flow": saved}, "res://.content/tests/sections_program.tres").error == OK)
	saved.sections[0].allowed_techniques = ["missing"]
	assert(not compiler.validate({"rules": rules, "flow": saved}).is_empty())
	panel.queue_free()
	await process_frame
	print("[boss-sections] PASS loop connections, section scope, copy/undo and save/reload")
	quit()
