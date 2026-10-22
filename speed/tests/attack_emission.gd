## 新しい複合攻撃は、共通の管理を変更せずに既存の形を組み合わせられる。
extends Node
class Pair:
	extends AttackKind
	func spawn(ps: ProjectileSystem, pos: Vector2) -> PackedInt32Array:
		var rows := PackedInt32Array()
		for angle in [-0.2, 0.2]:
			rows.append(ps.fire_beam(pos, angle, 400.0, 10.0, 0.5, 1.0, 7.0))
		return rows

var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	session.auto_step = false
	var pr := session.sim.projectiles
	check(pr.has_method("register_attack"), "外から攻撃の種類を登録できる")
	if pr.has_method("register_attack"):
		pr.register_attack(&"test_pair", Pair.new())
		var rows: PackedInt32Array = pr.emit_attack(&"test_pair", [Vector2(10, 20)])
		check(rows.size() == 2 and pr.hazard_count() == 2, "新しい種類から2本のビームを出せる")
		check(pr.hazard_pos[rows[0]] == Vector2(10, 20), "出現位置を保つ")
		check(pr.hazard_dmg[rows[1]] == 7.0, "形の共通管理でダメージを保つ")
	session.free()
	await get_tree().process_frame
	print("[attack_emission] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
