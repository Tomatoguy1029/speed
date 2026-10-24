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
	print("[boss-runner] PASS start, end, next section and boundary")
	quit()
