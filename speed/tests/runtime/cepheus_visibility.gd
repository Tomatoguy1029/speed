## ケフェウス座の射撃元が見える時だけ、予告を経て新しい弾を撃つことを確認する。
extends Node

var failed := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error("[cepheus_visibility] " + label)

func _ready() -> void:
	var stage = load("res://tools/content/build_runtime_stage.gd").compile(ContentManager.stage(4))
	var session := RunManager.create_session(self, {"lab": true, "seed": 42, "stage": stage}, false)
	session.auto_step = false
	var m := session.sim.enemies
	var t := m.table
	var state := m.state
	state.ship_pos = Vector2.ZERO
	state.view_center = Vector2.ZERO
	state.view_half = Vector2(300, 200)
	var king := _king(m, Vector2.ZERO)
	var inside := _soldier(m, king, Vector2(100, 0))
	var outside := _soldier(m, king, Vector2(500, 0))
	var b := m.behavior(&"cepheus")
	_step_volley(b, king, 30)
	check(_bolts(m) == 1, "画面内の兵だけが予告後に撃つ")
	check(t.charge[outside] == 0.0, "画面外の兵は予告を蓄積しない")
	state.view_center = Vector2(500, 0)
	_step_volley(b, king, 55)
	check(_bolts(m) == 2, "カメラ移動後に見える兵が撃つ")
	check(t.charge[inside] == 0.0, "画面外になった兵の予告を消す")
	state.view_center = Vector2.ZERO
	state.view_half = Vector2(150, 120)
	t.pos[inside] = Vector2(200, 0)
	t.timer[king] = 0.4
	_step_volley(b, king, 12)
	check(t.charge[inside] == 0.0, "ズームで画面外なら予告しない")
	state.view_half = Vector2(300, 200)
	_step_volley(b, king, 18)
	check(_bolts(m) == 2, "途中で入った兵は短い予告で撃たない")
	_step_volley(b, king, 55)
	check(_bolts(m) == 3, "次の号令では十分に見えた兵が撃つ")
	var second := _king(m, Vector2(0, 100))
	_soldier(m, second, Vector2(0, 100))
	_step_volley(b, second, 30)
	check(_bolts(m) == 4, "複数の王の兵が独立して予告する")
	t.buds[king] = 3
	t.buds[inside] = 0
	t.buds[outside] = 4
	t.pos[outside] = Vector2(-100, 0)
	t.timer[king] = 0.4
	t.bud_t[king] = 0.0
	_step_volley(b, king, 10)
	check(t.charge[inside] > 0.0 and t.charge[outside] == 0.0, "7体隊列は次に撃つ列だけ予告する")
	_step_volley(b, king, 20)
	check(_bolts(m) == 5, "7体隊列の前列だけが撃つ")
	_step_volley(b, king, 10)
	check(t.charge[inside] == 0.0 and t.charge[outside] > 0.0, "号令後は後列へ予告が移る")
	_step_volley(b, king, 20)
	check(_bolts(m) == 6, "7体隊列の後列だけが撃つ")
	check(_bolts(m) > 0, "画面外の兵を止めても発射済みの弾は残る")
	session.free()
	await get_tree().process_frame
	print("[cepheus_visibility] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func _king(m: EnemySystem, pos: Vector2) -> int:
	var i := m.spawn(m.def_of(&"cepheus"), pos)
	m.table.buds[i] = 1
	m.table.mode[i] = EnemyTable.Mode.MOVE
	m.table.timer[i] = 0.4
	m.table.fire_t[i] = 100.0
	return i

func _soldier(m: EnemySystem, king: int, pos: Vector2) -> int:
	var j := m.spawn(m.def_of(&"cepheus_soldier"), pos)
	m.table.target[j] = king
	m.table.target_id[j] = m.table.id[king]
	m.table.mode[j] = EnemyTable.Mode.MOVE
	return j

func _step_volley(b: EnemyBehavior, king: int, count: int) -> void:
	for n in count:
		b.step(king, 0.016)

func _bolts(m: EnemySystem) -> int:
	var total := 0
	for i in m.projectiles.hostile_alive.size():
		if m.projectiles.hostile_alive[i] and m.projectiles.hostile_kind[i] == ProjectileSystem.HostileKind.BOLT:
			total += 1
	return total
