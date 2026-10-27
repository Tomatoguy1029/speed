## 二体のポンプの取り合いと、所有者・対象の寿命を確認する。
extends Node
var failed := 0
var sim: RunSimulation
var t: EnemyTable
var pump: EnemyBehavior
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	session.auto_step = false
	sim = session.sim
	t = sim.enemies.table
	sim.enemies.clear_all()
	var a := sim.enemies.spawn(sim.enemies.def_of(&"pump"), Vector2(-180, 0))
	var b := sim.enemies.spawn(sim.enemies.def_of(&"pump"), Vector2(180, 0))
	pump = sim.enemies.behavior(&"pump")
	var target := sim.enemies.spawn(sim.enemies.def_of(&"drifter"), Vector2.ZERO)
	t.facing[a] = 0.0
	t.facing[b] = PI
	pull(a)
	var velocity := t.vel[target]
	pull(b)
	check(t.vel[target] == velocity and velocity.x < 0.0, "最初のポンプの吸引速度を後のポンプが上書きしない")
	# 口へ届いても、他のポンプの在庫には入らない。
	t.pos[target] = t.pos[b]
	# 所有範囲を広げ、両方の範囲内を維持する。
	pull(b)
	check(t.dead[target] == 0 and t.buds[b] == 0, "吸引途中の対象を別ポンプが飲み込まない")
	t.pos[target] = Vector2.ZERO
	sim.enemies.mark_dead(a)
	pull(b)
	check(t.vel[target].x > 0.0, "所有ポンプの死亡で次のポンプが吸引できる")
	sim.enemies.cleanup()
	a = sim.enemies.spawn(sim.enemies.def_of(&"pump"), Vector2(-180, 0))
	t.facing[a] = 0.0
	velocity = t.vel[target]
	pull(a)
	check(t.vel[target] == velocity, "再利用した所有者の行へ所有権を移さない")
	# 範囲外、満杯、構え、石化、牽引、吹き飛ばしで所有者が吸えない。
	for reason in ["range", "full", "windup", "stone", "held", "knock", "shove"]:
		t.pos[b] = Vector2(180, 0)
		t.mode[b] = EnemyTable.Mode.MOVE
		t.buds[b] = 0
		t.stone[b] = 0.0
		t.held[b] = 0
		t.knock_t[b] = 0.0
		t.shove_time[b] = 0.0
		pull(b)
		match reason:
			"range": t.pos[b] = Vector2(3000, 0)
			"full": t.buds[b] = int(t.def[b].params.store_max)
			"windup": t.mode[b] = EnemyTable.Mode.WINDUP
			"stone": t.stone[b] = 1.0
			"held": t.held[b] = 1
			"knock": t.knock_t[b] = 1.0
			"shove": t.shove_time[b] = 1.0
		pump.after_tick(0.1)
		pull(a)
		check(t.vel[target].x < 0.0, "%sで所有を解放する" % reason)
		# 次の条件を同じ所有者Bで始める。
		t.mode[a] = EnemyTable.Mode.WINDUP
		pump.after_tick(0.1)
		t.mode[a] = EnemyTable.Mode.MOVE
	sim.enemies.mark_dead(target)
	sim.enemies.cleanup()
	target = sim.enemies.spawn(sim.enemies.def_of(&"drifter"), Vector2.ZERO)
	pull(a)
	check(t.vel[target].x < 0.0, "消えた対象の行を再利用しても吸引できる")
	t.pos[target] = t.pos[a]
	t.bud_t[a] = 0.0
	pull(a)
	check(t.dead[target] != 0 and t.buds[a] == 1 and t.buds[b] == 0, "所有者が飲み込んだ在庫は個体ごとに保持する")
	sim.enemies.clear_all()
	a = sim.enemies.spawn(sim.enemies.def_of(&"pump"), Vector2(-180, 0))
	target = sim.enemies.spawn(sim.enemies.def_of(&"drifter"), Vector2.ZERO)
	pull(a)
	check(t.vel[target].x < 0.0, "全消去後も所有を持ち越さない")
	check(t.pump_owner[target] == a and t.pump_owner_id[target] == t.id[a], "対象が所有者の行と個体IDを保持する")
	sim.enemies.mark_dead(a)
	check(t.pump_owner[target] == -1, "所有者の死亡通知で即座に所有を解放する")
	sim.enemies.tick(0.3, 0.3)
	check(t.knock_t[target] <= 0.0, "吸引の停止後に自走停止時間が尽きる")
	session.free()
	print("[pump_ownership] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
func pull(row: int) -> void:
	sim.combat.rebuild_grid()
	pump._pump_suck(row, t.def[row].params, 0.1)
