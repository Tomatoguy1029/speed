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
	var panel = load("res://tools/editor/boss_flow/editor.gd").new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	assert(panel.open_boss(rules_path, flow_path) == OK)
	await process_frame
	panel._edit_section(0)
	_number_field(panel, "区間の攻撃回数").value = 3.0
	_number_field(panel, "区間内の攻撃間隔（秒）").value = 0.4
	var budget_toggle := _toggle(panel, "区間の累計消費上限を使う")
	budget_toggle.button_pressed = true
	budget_toggle.toggled.emit(true)
	_number_field(panel, "区間の累計消費上限").value = 5.0
	var timeout_toggle := _toggle(panel, "候補なしの待機上限（秒）を使う")
	timeout_toggle.button_pressed = true
	timeout_toggle.toggled.emit(true)
	_number_field(panel, "候補なしの待機上限（秒）").value = 0.7
	assert(panel.flow.sections[0].action_count == 3 and is_equal_approx(panel.flow.sections[0].action_interval, 0.4))
	assert(is_equal_approx(panel.flow.sections[0].section_budget, 5.0) and is_equal_approx(panel.flow.sections[0].no_candidate_timeout, 0.7))
	timeout_toggle.button_pressed = false
	timeout_toggle.toggled.emit(false)
	assert(not panel.flow.sections[0].has("no_candidate_timeout"), "disabling an optional field removes it from the flow")
	panel.undo_edit()
	assert(is_equal_approx(panel.flow.sections[0].no_candidate_timeout, 0.7), "the optional field can be restored by undo")
	panel._edit_section(0)
	assert(not panel.flow.sections[1].has("section_budget") and not panel.flow.sections[1].has("no_candidate_timeout"), "untouched legacy sections keep omitted optional fields")
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
	assert(saved.sections[0].action_count == 3 and is_equal_approx(saved.sections[0].action_interval, 0.4))
	assert(is_equal_approx(saved.sections[0].section_budget, 5.0) and is_equal_approx(saved.sections[0].no_candidate_timeout, 0.7))
	assert(not saved.sections[1].has("section_budget") and not saved.sections[1].has("no_candidate_timeout"))
	var compiler = load("res://tools/content/build_boss_program.gd")
	var compiled = compiler.compile({"rules": rules, "flow": saved}, "res://.content/tests/sections_program.tres")
	assert(compiled.error == OK and compiled.program.data.flow.sections[0].action_count == 3)
	assert(is_equal_approx(compiled.program.data.flow.sections[0].section_budget, 5.0) and is_equal_approx(compiled.program.data.flow.sections[0].no_candidate_timeout, 0.7), "saved section fields reach the runtime program")
	saved.sections[0].allowed_techniques = ["missing"]
	assert(not compiler.validate({"rules": rules, "flow": saved}).is_empty())
	assert(panel.open_boss("res://data/bosses/ai/monoceros_action_rules.tres", "res://data/bosses/ai/monoceros_flow.tres") == OK)
	panel._edit_section(1)
	assert(_number_field(panel, "区間の攻撃回数").value == 2.0 and is_equal_approx(_number_field(panel, "区間の累計消費上限").value, 4.0))
	assert(_toggle(panel, "区間の累計消費上限を使う").button_pressed and _toggle(panel, "候補なしの待機上限（秒）を使う").button_pressed)
	assert(panel.open_boss("res://data/bosses/ai/draco_action_rules.tres", "res://data/bosses/ai/draco_flow.tres") == OK)
	panel._edit_section(0)
	assert(_number_field(panel, "区間の攻撃回数").value == 2.0 and is_equal_approx(_number_field(panel, "候補なしの待機上限（秒）").value, 0.3))
	panel.queue_free()
	await process_frame
	print("[boss-sections] PASS loop connections, section scope, copy/undo and save/reload")
	quit()

func _number_field(panel: Control, title: String) -> SpinBox:
	var fields: Array = panel._fields.get_children()
	for i in fields.size() - 1:
		if fields[i] is Label and fields[i].text == title and fields[i + 1] is SpinBox: return fields[i + 1]
	return null

func _toggle(panel: Control, title: String) -> CheckButton:
	for child in panel._fields.get_children():
		if child is CheckButton and child.text == title: return child
	return null
