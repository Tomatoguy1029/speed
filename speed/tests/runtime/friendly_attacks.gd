## 弾は直進し、破片だけが航跡を残す。解放した行の命中処理を次の弾へ持ち越さない。
extends Node

var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)

func _ready() -> void:
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	session.auto_step = false
	var pr := session.sim.projectiles
	pr.fire_shot(Vector2.ZERO, 0.0, 2.0)
	var shot := 0
	var debris := pr._add_friend(ProjectileSystem.FriendKind.DEBRIS, &"corpse", Vector2.ZERO,
		Vector2(100, 0), 2.0, 2.0, 1.0, true, 0, Color.WHITE, true, 0.0, 0.0, 1.0, -1)
	check(pr.has_method("_friend_shape"), "味方の弾の動きを種類ごとに取得できる")
	if pr.has_method("_friend_shape"):
		pr._friend_shape(pr.friend_kind[shot]).advance(pr, shot, Vector2(10, 0), 0.1)
		pr._friend_shape(pr.friend_kind[debris]).advance(pr, debris, Vector2(10, 0), 0.1)
		check(pr.friend_trail[shot].is_empty(), "通常弾は破片の航跡を作らない")
		check(pr.friend_trail[debris] == PackedVector2Array([Vector2(10, 0)]), "破片は移動先を航跡に記録する")
		check(is_equal_approx(pr.friend_angle[debris], 0.1), "破片の回転を維持する")
	pr.friend_on_hit[shot] = func(_row, _damage, _pos): pass
	pr.release_friend(shot)
	check(not pr.friend_on_hit[shot].is_valid(), "解放時に命中処理を解放する")
	pr.fire_shot(Vector2.ZERO, 0.0, 2.0)
	check(not pr.friend_on_hit[shot].is_valid(), "再利用した行に以前の命中処理が残らない")
	session.free()
	await get_tree().process_frame
	print("[friendly_attacks] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
