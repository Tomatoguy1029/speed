## 区間の接続・候補・禁止ペアを、保存と履歴を通して確認する。
extends SceneTree
func _initialize() -> void: call_deferred("exercise")
func exercise() -> void:
	root.size = Vector2i(1280, 900)
	DirAccess.make_dir_recursive_absolute("res://.content/tests")
	var move_path := "res://.content/tests/sections_move.tres"
	var move: Resource = load("res://data/bosses/hydra_moves/bite_thrust.tres").duplicate(true)
	assert(ResourceSaver.save(move, move_path) == OK)
	var rules = load("res://scripts/data_types/boss_action_rules.gd").new()
	rules.adapter = &"hydra"
	rules.allow_parallel_attacks = true
	rules.techniques.append(ResourceLoader.load(move_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP))
	var flow = load("res://scripts/data_types/boss_flow_def.gd").new()
	flow.sections = [{"name": "A", "next": 1}, {"name": "B", "next": 2}, {"name": "C", "next": 1}]
	var rules_path := "res://.content/tests/sections_action_rules.tres"
	var flow_path := "res://.content/tests/sections_flow.tres"
	ResourceSaver.save(rules, rules_path)
	ResourceSaver.save(flow, flow_path)
	var panel = load("res://tools/editor/boss_flow/editor.gd").new()
	root.add_child(panel)
	assert(panel._ordered_boss_ids == ["monoceros", "centaurus", "canis_major", "hydra", "draco"], "boss switcher follows stages 1 through 5")
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	assert(panel.open_boss(rules_path, flow_path) == OK)
	await process_frame
	assert(panel._parallel_toggle.button_pressed, "Hydra's simultaneous attacks remain registered")
	assert(not panel.flow_graph.has_node("condition_choose_major"), "condition selection stays in the section inspector")
	panel._parallel_toggle.set_pressed_no_signal(false)
	panel._parallel_toggle.toggled.emit(false)
	assert(not panel.rules.allow_parallel_attacks, "unchecked simultaneous attacks are inactive")
	panel._edit_section(0)
	var before_collapse: Array = panel.flow.sections.duplicate(true)
	var history_before_collapse: int = panel.history.get_version()
	for list_kind in ["targets", "exclusions"]:
		var category: VBoxContainer = panel._fields.find_child(list_kind + "_normal", true, false)
		assert(category != null, "each list groups its normal entries independently")
		var header: Button = category.get_node("Header")
		var rows: VBoxContainer = category.get_node("Rows")
		header.set_pressed_no_signal(false)
		header.toggled.emit(false)
		assert(not rows.visible, "category entries collapse")
	panel._edit_section(0)
	assert(not panel._fields.find_child("targets_normal", true, false).get_node("Rows").visible)
	assert(not panel._fields.find_child("exclusions_normal", true, false).get_node("Rows").visible)
	assert(panel.flow.sections == before_collapse and panel.history.get_version() == history_before_collapse, "folding both lists is view-only")
	panel._split.split_offset = 1000
	await process_frame
	assert(panel._detail_scroll.size.x <= 500 and panel._fields.columns == 1 and not panel._detail_scroll.get_h_scroll_bar().visible, "narrow inspector stacks fields with one vertical scroll")
	panel._split.split_offset = -1000
	await process_frame
	assert(panel._fields.columns == 2, "wide inspector uses available width for paired fields")
	assert(not panel._fields.get_children().any(func(child): return child is Label and child.text == "禁止する組合せ"), "unchecked simultaneous attacks have no section controls")
	panel.undo_edit()
	assert(panel.rules.allow_parallel_attacks, "undo restores simultaneous attacks")
	var group: String = panel.graph.hub_for("bite_thrust")
	assert(panel.rules.category_for_group(group) == "normal", "legacy normal attack becomes a normal condition node")
	panel._set_group_category(group, "major")
	assert(panel.rules.category_for_group(group) == "major", "condition node owns one category")
	panel.undo_edit()
	assert(panel.rules.category_for_group(group) == "normal", "category change is undoable")
	panel.redo_edit()
	assert(panel.rules.category_for_group(group) == "major", "redo restores condition category")
	panel._edit_section(0)
	assert(not _has_label(panel, "要求する攻撃") and not _has_label(panel, "次の区間"), "wires alone select the next section")
	_number_field(panel, "攻撃回数").value = 3.0
	_number_field(panel, "攻撃間隔（秒）").value = 0.4
	var budget_toggle := _toggle(panel, "この区間で使える力")
	budget_toggle.button_pressed = true
	budget_toggle.toggled.emit(true)
	_number_field(panel, "この区間で使える力").value = 5.0
	var timeout_toggle := _toggle(panel, "候補なしで次へ（秒）")
	timeout_toggle.button_pressed = true
	timeout_toggle.toggled.emit(true)
	_number_field(panel, "候補なしで次へ（秒）").value = 0.7
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
	panel._set_section_target(0, group, false, true)
	assert(group in panel.flow.sections[0].allowed_groups and panel.flow.sections[0].request == "any", "explicit condition nodes replace the request dropdown")
	panel._set_section_exclusion(0, "bite_thrust", true)
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
	panel._picked("technique", "bite_thrust")
	_number_field(panel, "技後の隙（秒）").value = 0.75
	assert(is_equal_approx(panel.current.post_gap, 0.75), "ordinary technique post-attack gap is editable")
	assert(panel.save_current() == OK)
	var saved_move: Resource = ResourceLoader.load(move_path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	assert(is_equal_approx(saved_move.post_gap, 0.75), "the individual gap survives save and reload")
	var saved_rules: Resource = ResourceLoader.load(rules_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	assert(saved_rules.allow_parallel_attacks and saved_rules.category_for_group(group) == "major", "simultaneous and condition labels survive reload")
	var saved = ResourceLoader.load(flow_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	assert(saved.sections[2].next == 0 and saved.sections[3].next == 4)
	assert(group in saved.sections[0].allowed_groups and "bite_thrust" in saved.sections[0].excluded_techniques and saved.sections[0].forbidden.size() == 1)
	assert(saved.sections[0].action_count == 3 and is_equal_approx(saved.sections[0].action_interval, 0.4))
	assert(is_equal_approx(saved.sections[0].section_budget, 5.0) and is_equal_approx(saved.sections[0].no_candidate_timeout, 0.7))
	assert(not saved.sections[1].has("section_budget") and not saved.sections[1].has("no_candidate_timeout"))
	var compiler = load("res://tools/content/build_boss_program.gd")
	var compiled = compiler.compile({"rules": saved_rules, "flow": saved}, "res://.content/tests/sections_program.tres")
	assert(compiled.error == OK and compiled.program.data.flow.sections[0].action_count == 3)
	assert(compiled.program.data.rules.allow_parallel_attacks and compiled.program.data.rules.category_for_group(group) == "major", "generated runtime data retains condition labels")
	assert(is_equal_approx(compiled.program.data.flow.sections[0].section_budget, 5.0) and is_equal_approx(compiled.program.data.flow.sections[0].no_candidate_timeout, 0.7), "saved section fields reach the runtime program")
	saved.sections[0].excluded_techniques = ["missing"]
	assert(not compiler.validate({"rules": saved_rules, "flow": saved}).is_empty())
	assert(panel.open_boss("res://data/bosses/ai/monoceros_action_rules.tres", "res://data/bosses/ai/monoceros_flow.tres") == OK)
	assert(panel._boss_selector.selected == 0, "opening a boss externally updates the stage-order switcher")
	assert(not panel._parallel_toggle.button_pressed, "Monoceros has no simultaneous attack registration")
	panel._edit_section(1)
	for kind in ["normal", "combo", "major"]:
		assert(panel._fields.find_child("targets_" + kind, true, false) != null and panel._fields.find_child("exclusions_" + kind, true, false) != null, "both lists group every existing technique category")
	var normal_header: Button = panel._fields.find_child("targets_normal", true, false).get_node("Header")
	normal_header.set_pressed_no_signal(false)
	normal_header.toggled.emit(false)
	assert(panel._fields.find_child("targets_combo", true, false).get_node("Rows").visible and panel._fields.find_child("exclusions_normal", true, false).get_node("Rows").visible, "folding one category does not fold another category or list")
	assert(_number_field(panel, "攻撃回数").value == 2.0 and is_equal_approx(_number_field(panel, "この区間で使える力").value, 4.0))
	assert(_toggle(panel, "この区間で使える力").button_pressed and _toggle(panel, "候補なしで次へ（秒）").button_pressed)
	assert(panel.open_boss("res://data/bosses/ai/draco_action_rules.tres", "res://data/bosses/ai/draco_flow.tres") == OK)
	assert(panel._boss_selector.selected == 4, "the stage-order switcher follows external boss changes")
	assert(not panel._parallel_toggle.button_pressed, "Draco has no simultaneous attack registration")
	panel._edit_section(0)
	assert(_number_field(panel, "攻撃回数").value == 2.0 and is_equal_approx(_number_field(panel, "候補なしで次へ（秒）").value, 0.3))
	panel.queue_free()
	await process_frame
	print("[boss-sections] PASS loop connections, section scope, copy/undo and save/reload")
	quit()

func _number_field(panel: Control, title: String) -> SpinBox:
	var fields: Array = panel._fields.get_children()
	for i in fields.size() - 1:
		if (fields[i] is Label or fields[i] is CheckButton) and fields[i].text == title and fields[i + 1] is SpinBox: return fields[i + 1]
	return null

func _has_label(panel: Control, title: String) -> bool:
	return panel._fields.get_children().any(func(child): return child is Label and child.text == title)

func _toggle(panel: Control, title: String) -> CheckButton:
	for child in panel._fields.get_children():
		if child is CheckButton and child.text == title: return child
	return null
