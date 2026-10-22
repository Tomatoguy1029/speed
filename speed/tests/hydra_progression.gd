## 中央のHPによる段階進行。通常のダメージ経路を通す。
extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	print("[hydra-progress] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func _ready() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty": true, "stage": 4, "ship_pos": [400, 0]})
	lab.run.bosses.spawn_lab(&"hydra", Vector2.ZERO)
	var boss = lab.run.bosses.lab_instances.back().actor
	boss.hsm.set_active(false)
	var maximum: float = boss.table.max_hp[boss.body]
	lab.run.combat.damage_enemy(boss.necks[0].row,100000.0,{"cause":&"weapon"})
	lab.run.combat.damage_enemy(boss.body, maximum * 0.4, {"cause": &"weapon"})
	check(is_equal_approx(boss.table.hp[boss.body], maximum * 0.6), "central rubble takes ordinary weapon damage and carries excess")
	boss.sim_tick(0.01, 0.01)
	check(boss.count == 5, "HP threshold grows five heads")
	check(boss.necks.all(func(n):return boss._alive(n)),"growth restores heads killed earlier in the same world step")
	check(boss.necks.any(func(n): return n.kind == &"thunder"), "five heads contain all five kinds")
	var after: float = boss.table.hp[boss.body]
	lab.run.combat.damage_enemy(boss.body, 100.0, {"cause": &"weapon"})
	check(boss.table.hp[boss.body] == after, "growth animation protects the boss")
	boss.sim_tick(2.0, 2.0)
	lab.run.combat.damage_enemy(boss.body, maximum * 0.4, {"cause": &"weapon"})
	boss.sim_tick(0.01, 0.01)
	check(boss.count == 8, "second HP threshold grows eight heads")
	check(boss.necks.all(func(n): return boss._alive(n) and is_equal_approx(boss.table.hp[n.row], boss.table.max_hp[n.row])), "growth restores every head")
	boss.sim_tick(2.0, 2.0)
	lab.run.combat.damage_enemy(boss.body, maximum * 2.0, {"cause": &"weapon"})
	check(not lab.run.state.boss_dead and boss.manager.has_boss(), "central destruction keeps the encounter alive")
	lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
