extends SceneTree
class Ticket:
	extends RefCounted
	var busy := true
	func running() -> bool: return busy
	func cancel() -> void: busy = false
class Adapter:
	extends RefCounted
	var started: Array = []
	var tickets: Array = []
	func start_step(id: String) -> Object:
		started.append(id)
		var ticket := Ticket.new()
		tickets.append(ticket)
		return ticket
	func step_condition(gate: Dictionary) -> bool: return gate.get("test", false)
func _initialize() -> void:
	var script = load("res://scripts/bosses/flow/combo_runner.gd")
	if script == null:
		quit(1)
		return
	var adapter := Adapter.new()
	var combo = script.new({"type": "sequence", "children": [{"type": "action", "id": "a"}, {"type": "wait", "seconds": 0.5}, {"type": "action", "id": "b"}]}, adapter)
	combo.tick(0.1)
	assert(adapter.started == ["a"])
	adapter.tickets[0].busy = false
	combo.tick(0.1)
	combo.tick(0.4)
	assert(adapter.started == ["a"])
	combo.tick(0.2)
	combo.tick(0.1)
	assert(adapter.started == ["a", "b"])
	combo.cancel()
	assert(not adapter.tickets[1].busy)
	var parallel_adapter := Adapter.new()
	var parallel = script.new({"type": "parallel", "children": [{"type": "action", "id": "a"}, {"type": "sequence", "children": [{"type": "wait", "seconds": 0.5}, {"type": "action", "id": "b"}]}]}, parallel_adapter)
	parallel.tick(0.1)
	if parallel_adapter.started != ["a"]:
		print("[boss-combo] FAIL parallel execution missing")
		quit(1)
		return
	parallel.tick(0.5)
	parallel.tick(0.1)
	assert(parallel_adapter.started == ["a", "b"])
	parallel_adapter.tickets[0].busy = false
	assert(parallel.tick(0.1) == &"running")
	parallel_adapter.tickets[1].busy = false
	assert(parallel.tick(0.1) == &"finished")
	var branch_adapter := Adapter.new()
	var branch = script.new({"type": "branch", "condition": {"test": false}, "children": [{"type": "action", "id": "near"}, {"type": "action", "id": "far"}]}, branch_adapter)
	branch.tick(0.1)
	if branch_adapter.started != ["far"]:
		print("[boss-combo] FAIL branch decision missing")
		quit(1)
		return
	print("[boss-combo] PASS ordered actions, delay and cancel")
	quit()
