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
	check(actor.get_node_or_null("LimboHSM") == null and actor.get("flow_runner") != null, "production Hydra uses the new flow without a Limbo state machine")
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
	# 実際の通常技を内部から開始し、終了・待機までつながる。
	actor.action_rules = actor.action_rules.duplicate(true)
	for n in actor.necks: n.cd = 0.0
	var normals: Array = adapter.candidates({"request": "normal"}).candidates.filter(func(c): return c.category == "single")
	if not normals.is_empty():
		var id: String = normals[0].id
		actor.action_rules.combos["test_native"] = {"type": "sequence", "children": [{"type": "action", "id": id}, {"type": "wait", "seconds": 0.05}]}
		var authored: Array = adapter.candidates({"request": "normal"}).candidates.filter(func(c): return c.id == "test_native")
		check(not authored.is_empty() and adapter.start(authored), "native action starts through authored combo")
		adapter.tick(0.01)
		check(actor.necks.any(func(n): return n.mode == StringName(id)), "authored leaf starts an actual Hydra attack")
		for i in 2500:
			actor.sim_tick(0.01, 0.01)
			adapter.tick(0.01)
			if not adapter.running(): break
		check(not adapter.running(), "native combo finishes after attack recovery and wait")
		actor.action_rules.combos.erase("test_native")
		actor.action_rules.combos["test_parallel"] = {"type": "parallel", "children": [{"type": "action", "id": "bite_thrust"}, {"type": "action", "id": "bite_thrust"}]}
		var saved_gate: Dictionary = actor.action_rules.conditions.bite_thrust
		actor.action_rules.conditions.bite_thrust = {"min": 0.0, "max": 2000.0, "half_angle": 180.0}
		for n in actor.necks: n.cd = 0.0
		check(adapter.candidates({"request": "normal", "children_only": true}).candidates.filter(func(c): return c.id == "bite_thrust").size() == 2, "both native leaves are spatially eligible before the parallel start")
		var parallel: Array = adapter.candidates({"request": "normal"}).candidates.filter(func(c): return c.id == "test_parallel")
		check(not parallel.is_empty() and adapter.start(parallel), "parallel native combo reserves enough distinct heads")
		adapter.tick(0.01)
		check(actor.necks.filter(func(n): return n.mode == &"bite_thrust").size() == 2, "parallel leaves start on different heads")
		adapter.cancel_all()
		check(not adapter.running() and actor.necks.all(func(n): return n.mode == &"idle"), "cancelling a custom combo releases every native leaf")
		actor.action_rules.combos.erase("test_parallel")
		actor.action_rules.conditions.bite_thrust = saved_gate
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
	# 保存したコンボ定義を実際のヒュドラへ接続する。
	actor.action_rules = actor.action_rules.duplicate(true)
	actor.action_rules.combos["test_wait"] = {"type": "sequence", "children": [{"type": "wait", "seconds": 0.2}]}
	actor.action_rules.costs["test_wait"] = 1.0
	result = adapter.candidates({"request": "normal"})
	var custom: Array = result.candidates.filter(func(c): return c.id == "test_wait")
	check(custom.size() == 1, "editor-authored combo becomes an executable candidate")
	if not custom.is_empty():
		check(adapter.start(custom) and adapter.running(), "custom combo starts once")
		adapter.tick(0.3)
		check(not adapter.running(), "custom combo reaches its completion")
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
