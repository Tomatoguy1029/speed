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
	actor.use_action_rules(load("res://data/bosses/ai/hydra_action_rules.tres"))
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
	actor._set_count(8)
	actor.recovery_t = 0.0
	actor._tech_until.clear()
	actor._tech_cd = 0.0
	actor.combo_wait = 0.0
	result = adapter.candidates({"request": "normal"})
	var tornadoes: Array = result.candidates.filter(func(c): return c.id == "tornado")
	check(tornadoes.size() == 2, "all distinct vortex and debris combinations are offered")
	result = adapter.candidates({"request": "major"})
	check(result.candidates.any(func(c): return c.id == "curve"), "combined major is offered")
	actor.begin_separation()
	actor.separation_t = 0.0
	actor.recovery_t = 0.0
	actor._tech_cd = 0.0
	result = adapter.candidates({"request": "major"})
	check(result.candidates.any(func(c): return c.id == "swarm"), "separated swarm is offered")
	var guard = actor.necks[0]
	guard.free_pos = actor.table.pos[actor.immortal_row] + Vector2(500, 100)
	actor._sim_dt = 0.1
	actor._guard_patrol(guard, 0)
	check(guard.motion.has("guard_angle"), "guard uses a changing orbit from current position")
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
