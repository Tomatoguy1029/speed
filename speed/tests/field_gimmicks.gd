## 仕掛けの更新と、フィールドから使う共通の入口を確認する。
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
	var field := sim.field
	check(field.has_method("gimmick"), "仕掛けの種類ごとの処理を取得できる")
	if field.has_method("gimmick"):
		for id in [&"moons", &"dust", &"meteors", &"comets", &"warp", &"gravity"]:
			check(field.gimmick(id) != null, "%sの仕掛けを登録する" % id)
	sim.state.ship_pos = Vector2(3000, 0)
	sim.state.ship_vel = Vector2.ZERO
	field.add_well(Vector2(3100, 0), 10.0, 500.0, 1000.0)
	sim.state.world_time += 0.1
	field.tick(0.1, 0.1)
	check(sim.state.ship_vel.x > 0.0, "低速の機体を重力の中心へ引く")
	sim.state.glide = true
	sim.state.ship_vel = Vector2.ZERO
	field.tick(0.1, 0.1)
	check(sim.state.ship_vel == Vector2.ZERO, "高速の機体を重力で引かない")
	field.warp_pos = sim.state.ship_pos
	field.warp_gone = sim.state.world_time + 1.0
	check(field.take_warp() and not field.take_warp(), "接触したワープを一度だけ取得する")
	field.dust = [Vector3(3000, 0, 100)]
	check(field.dust_drag_at(sim.state.ship_pos) == sim.cfg.dust_drag, "宇宙塵の内側で減速する")
	check(field.dust_drag_at(Vector2(5000, 0)) == 0.0, "宇宙塵の外側では減速しない")
	session.free()
	await get_tree().process_frame
	print("[field_gimmicks] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
