extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	print("[boss-hydra] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("exercise")
func exercise() -> void:
	var script = load("res://scripts/bosses/hydra_flow_adapter.gd")
	if script == null:
		quit(1)
		return
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	root.add_child(lab)
	await lab.reset({"empty": true, "stage": 4, "ship_pos": [400, 0], "invincible": true})
	lab.run.bosses.spawn_lab(&"hydra", Vector2.ZERO)
	var actor = lab.run.bosses.actors.back()
	actor.hsm.set_active(false)
	actor.use_action_rules(load("res://data/bosses/hydra_action_rules.tres"))
	var adapter = script.new(actor)
	var result: Dictionary = adapter.candidates({"request": "normal"})
	check(not result.candidates.is_empty(), "returns concrete normal candidates")
	if not result.candidates.is_empty():
		var action: Dictionary = result.candidates[0]
		var stale: Dictionary = action.duplicate(true)
		stale.parts = [-999]
		check(not adapter.start([stale]), "stale participants reject without starting")
		check(adapter.start([action]), "concrete participants start")
		check(adapter.running(), "running includes technique recovery")
	actor.interrupt_tech()
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
