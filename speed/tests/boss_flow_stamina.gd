extends SceneTree
class Adapter:
	extends RefCounted
	var busy := false
	var cost := 3.0
	var enabled := true
	func candidates(_query: Dictionary) -> Dictionary:
		return {"candidates": [{"id": "a", "category": "single", "cost": cost, "parts": [1]}] if enabled else [], "reason": "parts"}
	func start(_actions: Array) -> bool:
		busy = true
		return true
	func running() -> bool: return busy
	func blocked() -> bool: return false
func _initialize() -> void:
	var runner = load("res://scripts/bosses/flow/runner.gd").new()
	if runner.get("rest_remaining") == null:
		print("[boss-stamina] FAIL rest state missing")
		quit(1)
		return
	var flow = load("res://scripts/data_types/boss_flow_def.gd").new()
	flow.maximum_stamina = 4.0
	flow.sections = [{"cap": 3.0, "weights": {"single": 100.0}, "next": 0}]
	flow.partial_rest = 1.0
	flow.empty_rest = 3.0
	runner.configure(flow)
	var adapter := Adapter.new()
	runner.tick(0.2, {}, adapter)
	assert(runner.stamina == 1.0)
	adapter.busy = false
	runner.tick(0.2, {}, adapter)
	runner.tick(0.2, {}, adapter)
	assert(runner.rest_remaining == 1.0)
	runner.tick(1.0, {}, adapter)
	assert(runner.stamina == 4.0)
	runner.stamina = 3.0
	runner.tick(0.2, {}, adapter)
	adapter.busy = false
	runner.tick(0.2, {}, adapter)
	assert(runner.rest_remaining == 3.0)
	runner.tick(3.0, {}, adapter)
	adapter.enabled = false
	runner.tick(0.2, {}, adapter)
	assert(runner.rest_remaining == 0.0)
	print("[boss-stamina] PASS spend, two rests, refill and parts failure")
	quit()
