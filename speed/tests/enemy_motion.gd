## 移動・旋回・発射時刻の共通処理は、種類の追加と独立した補助へ置く。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	session.auto_step = false
	var enemies := session.sim.enemies
	var motion = enemies.get("motion")
	check(motion != null, "共通の移動補助を取得できる")
	if motion != null:
		var def := enemies.def_of(&"drifter").duplicate(true) as EnemyDef
		def.params = {"telegraph": 1.0, "fire_interval": 3.0}
		var row := enemies.spawn(def, Vector2.ZERO)
		motion._steer_to(row, Vector2(100, 0), 100.0, 10.0, 0.1)
		check(enemies.table.vel[row].is_equal_approx(Vector2(100, 0)), "指定の速さと加速で目標へ向かう")
		enemies.table.facing[row] = 0.0
		motion._turn_toward(row, PI, 1.0, 0.1)
		check(is_equal_approx(absf(enemies.table.facing[row]), 0.1), "旋回速度の上限を保つ")
		enemies.table.fire_t[row] = 0.5
		check(not motion._gun_timer(row, 0.1) and enemies.table.charge[row] > 0.0, "発射前に予告が進む")
		check(motion._gun_timer(row, 0.5) and enemies.table.fire_t[row] == 3.0, "発射時に次の間隔へ戻す")
		var state := session.sim.state
		state.enemy_aim = Vector2.ZERO
		state.ship_pos = Vector2(1200, 0)
		state.tracing = true
		motion._update_aim(0.1)
		check(state.enemy_aim == Vector2.ZERO, "なぞり中は敵の照準位置を固定する")
		state.tracing = false
		motion._update_aim(0.1)
		check(state.enemy_aim.x > 0.0 and state.enemy_aim.x <= session.sim.cfg.enemy_aim_speed * 0.1 + 0.01, "なぞり終了後も照準が瞬間移動しない")
		state.glide = true
		var before: float = state.enemy_aim.x
		motion._update_aim(0.1)
		check(state.enemy_aim.x > before and state.enemy_aim.x - before <= session.sim.cfg.enemy_aim_speed * 0.1 + 0.01, "勢い中は世界時間と速度上限で追従を再開する")
		state.glide = false
	session.free()
	await get_tree().process_frame
	print("[enemy_motion] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
