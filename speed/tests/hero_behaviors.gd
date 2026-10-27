## 英雄の力は同じ入口を使い、それぞれのランにだけ作用する。
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
	check(sim.heroes.has_method("behavior"), "英雄の種類別の力を取得できる")
	if sim.heroes.has_method("behavior"):
		for id in [&"perseus", &"hercules", &"gemini", &"leo"]:
			check(sim.heroes.behavior(id) != null, "%sの力が共通の入口を持つ" % id)
		sim.state.hero_power = &"leo"
		sim.heroes.activate()
		check(is_equal_approx(sim.state.hero_active_t, 14.0), "しし座の発動は14秒")
		sim.heroes.tick(13.0, 0.0)
		check(sim.heroes.active_power() == &"leo" and is_equal_approx(sim.state.hero_active_t, 1.0), "13秒後も継続")
		check(sim.heroes.trace_width() > 1.0, "しし座の力が当たりの太さへ反映される")
		sim.heroes.tick(1.0, 0.0)
		check(sim.heroes.active_power() == &"" and sim.state.hero_active_t == 0.0, "14秒で終了")
		check(sim.heroes.trace_width() == 1.0, "力の終了後は通常の太さへ戻る")
		sim.state.hero_power = &"gemini"
		sim.state.hero_active_t = 1.0
		sim.state.draw_points = PackedVector2Array([Vector2.ZERO, Vector2(100, 0)])
		sim.state.draw_limit = 1000.0
		sim.state.draw_start_charge = 1.0
		sim.state.draw_length = 100.0
		check(sim.heroes.capture_first_trace(), "ふたご座は最初の線を保存する")
		check(sim.state.twin_first.size() == 2 and sim.state.draw_points.is_empty(), "次の線を描く状態へ進む")
	session.free()
	await get_tree().process_frame
	print("[hero_behaviors] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
