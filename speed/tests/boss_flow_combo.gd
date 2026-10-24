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
	print("[boss-combo] PASS ordered actions, delay and cancel")
	quit()
