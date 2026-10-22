## 衝撃波の命中記録と寿命は装備管理から独立する。
extends Node
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	session.auto_step = false
	var sim := session.sim
	var pr := sim.projectiles
	check(pr.has_method("attached_attack"), "移動に沿う攻撃を共通の攻撃として取得できる")
	if pr.has_method("attached_attack"):
		var wave = pr.attached_attack(&"sonic")
		var row := sim.enemies.spawn(sim.enemies.def_of(&"telescope"), Vector2(100, 0))
		sim.enemies.table.hp[row] = 1000.0
		sim.combat.rebuild_grid()
		wave.fire(&"sonic", 30.0, 10.0, 0.0, 0.5)
		var hp := sim.enemies.table.hp[row]
		pr.trail_attached(Vector2.ZERO, Vector2(200, 0))
		var hit_hp := sim.enemies.table.hp[row]
		check(hit_hp < hp, "通過した敵に衝撃波が当たる")
		pr.trail_attached(Vector2(200, 0), Vector2.ZERO)
		check(sim.enemies.table.hp[row] == hit_hp, "同じ波は同じ敵へ再び当たらない")
		pr.tick_attached(0.6)
		check(wave.waves.is_empty(), "実時間の寿命で波が終わる")
	session.free()
	await get_tree().process_frame
	print("[attached_attacks] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
