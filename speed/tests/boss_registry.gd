## 1つのBossSystemが複数の役者を管理し、1体の削除を他へ波及させない。
extends Node
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	session.auto_step = false
	var bosses := session.sim.bosses
	var one := bosses.spawn_lab(&"provisional", Vector2(3000, 0))
	var two := bosses.spawn_lab(&"provisional", Vector2(-3000, 0))
	check(bosses.get("actors") != null, "ボス管理は役者の一覧を持つ")
	if bosses.get("actors") != null:
		check(bosses.actors.size() == 2, "同じSystemに2体を登録する")
		var a := bosses.actor_for_row(one)
		var b := bosses.actor_for_row(two)
		check(a.ctx == session.sim.ctx and b.ctx == session.sim.ctx, "両方の役者が同じランのContextを使う")
		bosses.remove_actor(a)
		check(not a.has_body() and b.has_body(), "1体を取り除いても他の本体を保持する")
		check(bosses.actor_for_row(one) == null and bosses.actor_for_row(two) == b, "行とIDで正しい役者を返す")
	session.free()
	await get_tree().process_frame
	print("[boss_registry] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
