extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	print("[hydra-normal] ", "PASS " if ok else "FAIL ", label)
	if not ok: failed += 1
func _ready() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty": true, "stage": 4, "ship_pos": [400, 0]})
	lab.run.bosses.spawn_lab(&"hydra", Vector2.ZERO)
	var boss = lab.run.bosses.lab_instances.back().actor
	boss.hsm.set_active(false)
	check(boss.has_method("normal_ready"), "normal attacks have an editable BT selection path")
	if boss.has_method("normal_ready"):
		var n = boss.necks[0]
		n.cd = 0.0
		check(boss.normal_ready(0, &"bite_thrust"), "front player can be bitten")
		boss.table.attack_value[n.row]=4.0
		check(not boss.normal_ready(0,&"bite_thrust"),"per-head attack value contributes to Hydra normal budget")
		boss.table.attack_value[n.row]=1.0
		var director=lab.run.projectiles.director
		director.formation_mode=true
		director.configure({"enabled":true,"budget":0.1,"jitter":0.0})
		check(boss.start_normal(0,&"bite_thrust"),"normal run uses the Hydra budget independently of the small-fry budget")
		director.configure({"enabled":false})
		director.formation_mode=false
		var waiting: int = lab.run.projectiles.director.waiting.size()
		boss.normal_ready(0, &"bite_thrust")
		check(lab.run.projectiles.director.waiting.size() == waiting, "eligibility has no reservation side effect")
		boss.sim_tick(0.01, 0.01)
		check(n.mode == &"bite_thrust", "head tree selects the eligible attack")
		for i in 70: boss.sim_tick(0.01, 0.01)
		var locked: Vector2 = n.target
		lab.run.state.ship_pos += Vector2(0, 200)
		for i in 15: boss.sim_tick(0.01, 0.01)
		check(n.target == locked, "normal bite does not follow player after lock")
		check(boss._head_pos(n).distance_to(locked) < 2.0, "bite reaches its locked target")
		check(n.mode != &"idle", "head remains exposed for counterattack")
		lab.run.state.view_center = Vector2(-9000, -9000)
		n.mode = &"idle"
		n.cd = 0.0
		check(not boss.normal_ready(0, &"bite_thrust"), "offscreen head cannot start an attack")
	lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
