extends SceneTree
func _initialize() -> void: call_deferred("exercise")
func exercise() -> void:
	var script = load("res://gyms/boss_flow_single_adapter.gd")
	if script == null:
		quit(1)
		return
	var adapter = script.new()
	var flow = load("res://scripts/data_types/boss_flow_def.gd").new()
	flow.maximum_stamina = 2.0
	flow.sections = [{"request": "normal", "cap": 1.0, "weights": {"single": 100.0}, "next": 0}]
	var runner = load("res://scripts/bosses/flow/runner.gd").new()
	runner.configure(flow)
	runner.tick(0.1, {"player": Vector2(120, 0)}, adapter)
	assert(adapter.started.size() == 1 and runner.stamina == 1.0)
	adapter.advance(2.0)
	runner.tick(0.1, {"player": Vector2(120, 0)}, adapter)
	runner.tick(0.2, {"player": Vector2(120, 0)}, adapter)
	assert(adapter.started.size() == 2)
	var move = load("res://scripts/data_types/boss_technique.gd").new()
	move.technique = &"strike"
	move.parameters = {"damage": 12.0}
	var rules = load("res://scripts/data_types/boss_action_rules.gd").new()
	rules.techniques.append(move)
	DirAccess.make_dir_recursive_absolute("res://.content/tests")
	ResourceSaver.save(rules, "res://.content/tests/single_action_rules.tres")
	ResourceSaver.save(flow, "res://.content/tests/single_flow.tres")
	var editor = load("res://addons/boss_flow/editor.gd").new()
	root.add_child(editor)
	assert(editor.open_boss("res://.content/tests/single_action_rules.tres", "res://.content/tests/single_flow.tres") == OK)
	assert(not editor._is_hydra())
	assert(editor.preview_scene().is_empty(), "unconfigured single actors must not launch the Hydra trial")
	editor._picked("technique", "strike")
	editor.set_value("damage", 15.0)
	assert(editor.open_boss("res://data/bosses/ai/hydra_action_rules.tres", "res://data/bosses/ai/hydra_flow.tres") == ERR_BUSY, "switching bosses cannot discard unsaved edits")
	assert(editor.save_current() == OK)
	var saved = ResourceLoader.load("res://.content/tests/single_action_rules.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	assert(saved.techniques[0].parameters.damage == 15.0)
	editor._edit_coverage()
	editor.preview_stamina = -1.0
	editor._analyze_coverage()
	assert(editor.preview.coverage_mode and editor.preview.layers.is_empty() and editor.preview.gaps.size() == 1024, "zero feasible attacks show an entirely uncovered area")
	editor.queue_free()
	await process_frame
	print("[boss-single] PASS same flow handles a single actor without neck state")
	quit()
