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
	var shape = load("res://scripts/attacks/beam.gd").new()
	check(shape.has_method("spawn"), "ビームの種類が生成処理を持つ")
	if shape.has_method("spawn"):
		var beam: int = pr.emit_attack(&"beam", [Vector2.ZERO, 0.0, 100.0, 10.0, 0.2, 0.3, 4.0])
		check(pr.hazard_len[beam] == 100.0 and pr.hazard_dmg[beam] == 4.0, "公開入口と同じビームを生成する")

	var wave_shape = load("res://scripts/attacks/wave.gd").new()
	check(wave_shape.has_method("spawn"), "波の種類が生成処理を持つ")
	if wave_shape.has_method("spawn"):
		var wave: int = pr.emit_attack(&"wave", [Vector2.ZERO, 0.0, PI, 300.0, 100.0, 20.0, 0.5, 4.0])
		check(pr.hazard_active[wave] == 3.0 and pr.hazard_speed[wave] == 100.0, "波の到達時間と速度を維持する")

	var shell_shape = load("res://scripts/attacks/shell.gd").new()
	check(shell_shape.has_method("spawn"), "圧縮弾の種類が生成処理を持つ")
	if shell_shape.has_method("spawn"):
		var row := session.sim.enemies.spawn(session.sim.enemies.def_of(&"drifter"), Vector2.ZERO)
		pr.emit_attack(&"shell", [row, 0.0, 100.0, 20.0, 300.0, 90.0, 8.0])
		check(pr.hostile_count() == 1 and pr.hostile_burst[0] == 90.0, "圧縮弾の破裂半径を維持する")

	var friend_shape = load("res://scripts/attacks/friend_shot.gd").new()
	check(friend_shape.has_method("spawn"), "味方弾の種類が生成処理を持つ")
	if friend_shape.has_method("spawn"):
		pr.emit_attack(&"friend_shot", [Vector2.ZERO, 0.0, 5.0, {"speed": 900.0}])
		check(pr.friend_count() == 1 and pr.friend_vel[0] == Vector2(900, 0), "味方弾の指定速度を維持する")

	session.free()
	await get_tree().process_frame
	print("[attack_emission] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
