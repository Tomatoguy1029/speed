extends SceneTree
class Adapter:
	extends RefCounted
	var requests: Array = []
	var busy := false
	func candidates(query: Dictionary) -> Dictionary:
		requests.append(query)
		return {"candidates": [{"id": "a", "cost": 1.0, "parts": [1], "category": "single"}]}
	func start(_actions: Array) -> bool:
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
	print("[boss-runner] PASS start, end, next section and boundary")
	quit()
