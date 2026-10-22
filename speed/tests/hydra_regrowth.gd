extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	print("[hydra-regrow] ", "PASS " if ok else "FAIL ", label)
	if not ok: failed += 1
func _ready() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty": true, "stage": 4})
	lab.run.bosses.spawn_lab(&"hydra", Vector2.ZERO)
	var boss = lab.run.bosses.lab_instances.back().actor
	boss.hsm.set_active(false)
	for neck in boss.necks: neck.cd = 1e6
	var first = boss.necks[0]
	lab.run.state.world_time = 10.0
	lab.run.combat.damage_enemy(first.row, 1e6, {"cause": &"fire"})
	lab.run.enemies.cleanup()
	check(first.regrow > float(boss.def.params.regrow), "fire extends down time")
	for neck in boss.necks:
		if boss._alive(neck): lab.run.combat.damage_enemy(neck.row, 1e6, {"cause": &"weapon"})
	lab.run.enemies.cleanup()
	for neck in boss.necks: neck.regrow = 0.0
	boss.sim_tick(0.01, 0.01)
	check(boss.get("chance_t") != null, "all-head down has a dedicated chance window")
	if boss.get("chance_t") != null:
		check(boss.chance_t > 0.0 and boss.necks.all(func(n): return n.row < 0), "chance wins over expired regrowth")
		var before: float = boss.table.hp[boss.body]
		lab.run.combat.damage_enemy(boss.body, 1.0, {"cause": &"weapon"})
		check(boss.table.hp[boss.body] < before, "central rubble is vulnerable during chance")
		boss.sim_tick(boss.chance_t + 0.1, boss.chance_t + 0.1)
		check(boss.necks.all(func(n): return boss._alive(n)), "all heads return after guaranteed chance, including burnt heads")
	check(boss.immortal_row < 0, "no exposure mechanic during combined combat")
	lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
