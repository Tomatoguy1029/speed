extends SceneTree
func _initialize() -> void:
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
	print("[boss-single] PASS same flow handles a single actor without neck state")
	quit()
