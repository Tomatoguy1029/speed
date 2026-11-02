## 表示なしのランを閉じると、Systemと行動・装備・行の管理も解放される。
extends Node

func _ready() -> void:
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	var failed := 0
	if session.sim.combat.grid.table == null:
		failed += 1
		push_error("最初の更新前から空の当たり判定を問い合わせられる")
	session.auto_step = false
	session.sim.enemies.spawn(session.sim.enemies.def_of(&"telescope"), Vector2.ZERO)
	session.sim.loadout.grant(&"weapon", &"W25")
	var references: Array[WeakRef] = []
	for object in [session.sim, session.sim.ctx, session.sim.enemies, session.sim.enemies.slots,
			session.sim.enemies.behavior(&"sniper"), session.sim.loadout,
			session.sim.loadout.weapon_behaviors[&"W25"], session.sim.projectiles, session.sim.projectiles.friend_slots]:
		references.append(weakref(object))
	session.free()
	await get_tree().process_frame
	for ref in references:
		if ref.get_ref() != null:
			failed += 1
			push_error("ラン終了後も実体が残る: %s" % ref.get_ref())
	print("[run_lifetime] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
