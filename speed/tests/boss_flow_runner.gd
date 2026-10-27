extends SceneTree
class Adapter:
	extends RefCounted
	var requests: Array = []
	var busy := false
	var options := [{"id": "a", "cost": 1.0, "parts": [1], "category": "single"}]
	var started: Array = []
	func candidates(query: Dictionary) -> Dictionary:
		requests.append(query)
		return {"candidates": options}
	func start(actions: Array) -> bool:
		started.append(actions)
		busy = true
		return true
	func running() -> bool: return busy
	func blocked() -> bool: return false
func _initialize() -> void:
	var script = load("res://scripts/bosses/flow/runner.gd")
	if script == null:
		quit(1)
		return
	var flow = load("res://scripts/data_types/boss_flow_def.gd").new()
	flow.sections = [{"request": "normal", "next": 1}, {"request": "major", "next": 0}]
	var runner = script.new()
	runner.configure(flow)
	var adapter := Adapter.new()
	runner.tick(0.1, {"player": Vector2.ZERO}, adapter)
	assert(adapter.busy and runner.index == 0)
	assert(not adapter.requests[0].has("index") and adapter.requests[0].request == "normal")
	adapter.busy = false
	runner.tick(0.1, {}, adapter)
	assert(runner.index == 1)
	flow.maximum_stamina = 10.0
	flow.sections = [{"request": "any", "cap": 1.0, "allowed_techniques": ["a"], "next": 1}, {"request": "any", "cap": 1.0, "allowed_techniques": ["b"], "next": 0}]
	runner.configure(flow)
	adapter = Adapter.new()
	runner.index = 1
	runner.tick(0.2, {}, adapter)
	assert(adapter.started.is_empty(), "a section cannot start a technique outside its allow list")
	runner.configure(flow)
	adapter = Adapter.new()
	adapter.options.append({"id": "b", "cost": 1.0, "parts": [2], "category": "single"})
	for expected in ["a", "b", "a"]:
		runner.tick(0.2, {}, adapter)
		assert(adapter.started.back()[0].id == expected, "each section filters the shared candidates and its loop executes")
		adapter.busy = false
		runner.tick(0.2, {}, adapter)
	flow.maximum_stamina = 4.0
	flow.sections = [{"request": "normal", "cap": 2.0, "section_budget": 2.0, "action_count": 2, "action_interval": 0.3, "no_candidate_timeout": 0.5, "weights": {"single": 100.0}, "next": 1},
		{"request": "major", "cap": 2.0, "no_candidate_timeout": 0.5, "weights": {"major": 100.0}, "next": 0}]
	runner.configure(flow)
	adapter = Adapter.new()
	adapter.options = [{"id": "a", "cost": 1.0, "parts": [1], "category": "single"}, {"id": "m", "cost": 2.0, "parts": [1], "category": "major"}]
	runner.tick(0.1, {}, adapter)
	assert(adapter.started.size() == 1 and adapter.started[0][0].id == "a", "the section policy filters category after eligibility")
	adapter.busy = false
	runner.tick(0.1, {}, adapter)
	assert(runner.index == 0 and runner.completed_actions == 1 and is_equal_approx(runner.section_spent, 1.0), "a section keeps its count and cumulative budget")
	runner.tick(0.2, {}, adapter)
	assert(adapter.started.size() == 1, "the attack interval delays the next selection")
	runner.tick(0.1, {}, adapter)
	assert(adapter.started.size() == 2 and adapter.started[1][0].id == "a", "the second action starts after the interval")
	adapter.busy = false
	runner.tick(0.1, {}, adapter)
	assert(runner.index == 1 and runner.completed_actions == 0 and is_zero_approx(runner.section_spent), "the count advances and resets the section")
	runner.tick(0.2, {}, adapter)
	assert(adapter.started.size() == 3 and adapter.started[2][0].id == "m", "the next section can choose a major from the same eligible pool")
	adapter.busy = false
	runner.tick(0.2, {}, adapter)
	flow.sections[0].section_budget = 1.0
	runner.configure(flow)
	adapter = Adapter.new()
	runner.tick(0.2, {}, adapter)
	adapter.busy = false
	runner.tick(0.2, {}, adapter)
	for _step in 8:
		runner.tick(0.2, {}, adapter)
		if runner.index == 1: break
	assert(runner.index == 1 and adapter.started.size() == 1, "an exhausted section budget ends the section")
	flow.sections[0].section_budget = 2.0
	runner.configure(flow)
	adapter = Adapter.new()
	adapter.options.clear()
	for _step in 6:
		runner.tick(0.2, {}, adapter)
		if runner.index == 1: break
	assert(runner.index == 1 and adapter.started.is_empty(), "a section with no eligible attack advances after its timeout")
	flow.sections[0].erase("section_budget")
	flow.sections[0].erase("no_candidate_timeout")
	flow.sections[0].erase("action_count")
	flow.sections[0].erase("action_interval")
	flow.sections[0].fallback = 1
	runner.configure(flow)
	adapter = Adapter.new()
	adapter.options.clear()
	runner.tick(0.2, {}, adapter)
	assert(runner.index == 1, "legacy fallback remains immediate when the timeout is absent")
	print("[boss-runner] PASS legacy, category policy, count, interval, budget and bounded fallback")
	quit()
