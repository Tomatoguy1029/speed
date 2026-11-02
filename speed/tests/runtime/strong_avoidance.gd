## 雑魚だけの局所回避。密集、動くボス、吸引、内部出現、固定行動を検査する。
extends Node

var failed := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	var session := RunManager.create_session(self, {"lab": true, "seed": 932}, false)
	session.auto_step = false
	session.sim.field.bodies.clear()
	session.sim.field.battle_arenas.clear()
	var enemies := session.sim.enemies
	var t := enemies.table
	var normal := enemies.spawn(enemies.def_of(&"biter"), Vector2(-47, 0))
	var strong := enemies.spawn(enemies.def_of(&"crab"), Vector2.ZERO)
	var dt := 0.1
	var step := t.speed[normal] * dt
	var radius := t.r[normal] + t.r[strong] + 2.0
	var start := Vector2(-radius - 2.0, 0)
	t.pos[normal] = start
	enemies._capture_avoidance_starts()
	t.pos[normal] += Vector2(step, 0)
	enemies.avoid_strong(dt)
	check(t.pos[normal].distance_to(start) <= step + 0.001, "接近回避は通常速度以下")
	check(t.pos[normal].distance_to(t.pos[strong]) >= radius - 0.001, "接近時に強敵の身体へ入らない")
	check(t.pos[strong] == Vector2.ZERO, "強敵の位置は変えない")

	# 既に内部へ出た雑魚も瞬間移動させず、通常の速さで外へ出る。
	t.pos[normal] = Vector2.ZERO
	var previous := t.pos[normal]
	for k in 7:
		enemies._capture_avoidance_starts()
		enemies.avoid_strong(dt)
		check(t.pos[normal].distance_to(previous) <= step + 0.001, "内部出現の離脱速度を抑える")
		if previous.distance_to(t.pos[strong]) < radius - 0.001:
			check(t.pos[normal].distance_to(t.pos[strong]) > previous.distance_to(t.pos[strong]), "内部出現は外へ進む")
		previous = t.pos[normal]
	check(t.pos[normal].distance_to(t.pos[strong]) >= radius, "内部出現は身体の外へ出る")

	# ボスの移動で雑魚が内部に入っても、ボスと部位を動かさない。
	var boss := enemies.spawn_boss(&"draco", Vector2(100, 0), 35.0, 100.0, 0.0, 0.0, 0.0, 0.0, 0.0, Color.WHITE)
	t.pos[normal] = Vector2.ZERO
	enemies._capture_avoidance_starts()
	t.pos[boss] = Vector2(10, 0)
	enemies.avoid_strong(dt)
	check(t.pos[boss] == Vector2(10, 0), "移動したボス側は変えない")
	check(t.pos[normal].distance_to(Vector2.ZERO) <= step + 0.001 and t.pos[normal].x < 0.0,
		"動くボスから雑魚だけ通常速度で離れる")
	t.pos[boss] = Vector2(1000, 0)

	# Dracoの胴体を別の判定円として扱い、頭から遠い部位も避ける。
	var segment := enemies.spawn_boss(&"draco", Vector2(300, 0), 32.0, 100.0, 0.0, 0.0, 0.0, 0.0, 0.0, Color.WHITE)
	t.parent[segment] = boss
	t.parent_id[segment] = t.id[boss]
	t.pos[normal] = Vector2(250, 0)
	enemies._capture_avoidance_starts()
	t.pos[normal].x += step
	enemies.avoid_strong(dt)
	check(t.pos[normal].distance_to(t.pos[segment]) >= t.r[normal] + t.r[segment] + 2.0 - 0.001,
		"Dracoの個別胴体行を避ける")

	# 追跡を続けても円の前で振動・停止せず、片側から回り込める。
	t.pos[normal] = Vector2(-radius - 10.0, 0)
	for frame in 45:
		var before := t.pos[normal]
		enemies._capture_avoidance_starts()
		t.pos[normal] += (Vector2(250, 0) - before).normalized() * step
		enemies.avoid_strong(dt)
		check(t.pos[normal].distance_to(before) <= step + 0.001, "追跡中の回避速度")
		check(t.pos[normal].distance_to(t.pos[strong]) >= radius - 0.001, "追跡中も強敵へ侵入しない")
	check(t.pos[normal].x > 0.0, "強敵の片側を回って先へ進む")

	var pump := enemies.spawn(enemies.def_of(&"pump"), Vector2(500, 0))
	t.pos[normal] = Vector2(500, 0)
	t.pump_owner[normal] = pump
	t.pump_owner_id[normal] = t.id[pump]
	enemies._capture_avoidance_starts()
	enemies.avoid_strong(dt)
	check(t.pos[normal] == Vector2(500, 0), "Pumpが吸引中の雑魚はそのまま")
	t.pump_owner[normal] = -1
	t.pump_owner_id[normal] = -1
	enemies._capture_avoidance_starts()
	enemies.avoid_strong(dt)
	check(t.pos[normal] == Vector2(500, 0), "吸引可能なPumpへ近づく雑魚も妨げない")
	t.mode[normal] = EnemyTable.Mode.WINDUP
	t.pos[normal] = Vector2(300, 0)
	enemies._capture_avoidance_starts()
	enemies.avoid_strong(dt)
	check(t.pos[normal] == Vector2(300, 0), "予告中の固定行動は動かさない")
	t.mode[normal] = EnemyTable.Mode.MOVE

	# 実際の固定更新順（敵→ボス→回避→戦闘格子）でも回避が働く。
	var runner := enemies.spawn(enemies.def_of(&"biter"), Vector2(2000, 2000))
	var stationary := enemies.spawn(enemies.def_of(&"crab"), Vector2(2070, 2000))
	t.stone[stationary] = 10.0
	session.sim.state.ship_pos = Vector2(2200, 2000)
	session.sim.input_source = func(): return Intent.new()
	var before_runtime := t.pos[runner].distance_to(t.pos[stationary])
	session.sim.physics_step(1.0 / 60.0)
	session.sim.physics_step(1.0 / 60.0)
	check(t.pos[runner].distance_to(t.pos[stationary]) >= before_runtime,
		"固定更新の実経路でも雑魚が強敵へ食い込まない")
	check(t.pos[stationary] == Vector2(2070, 2000), "固定更新でも強敵は動かさない")

	# 多数の雑魚とDraco相当の部位を同じ更新で扱い、速度と実行時間を確認する。
	var crowd := PackedInt32Array()
	for k in 480:
		var a := float(k) * TAU / 480.0
		crowd.append(enemies.spawn(enemies.def_of(&"splitling"), Vector2(300, 0) + Vector2.from_angle(a) * (40.0 + float(k % 12))))
	for k in 31:
		var part := enemies.spawn_boss(&"draco", Vector2(300 + k * 35, 0), 32.0, 100.0, 0.0, 0.0, 0.0, 0.0, 0.0, Color.WHITE)
		t.parent[part] = boss
		t.parent_id[part] = t.id[boss]
	var begin := Time.get_ticks_usec()
	var avoidance_usec := 0
	for frame in 30:
		enemies._capture_avoidance_starts()
		for i in crowd:
			var dir := (Vector2(900, 0) - t.pos[i]).normalized()
			t.pos[i] += dir * t.speed[i] * dt
		var before_avoidance := Time.get_ticks_usec()
		enemies.avoid_strong(dt)
		avoidance_usec += Time.get_ticks_usec() - before_avoidance
	var elapsed_ms := float(Time.get_ticks_usec() - begin) / 1000.0
	var remaining_overlap := 0
	for i in crowd:
		check(t.pos[i].is_finite(), "密集時に有効な位置を保つ")
		for j in enemies._avoid_obstacles:
			if t.pos[i].distance_to(t.pos[j]) < t.r[i] + t.r[j] - 0.001:
				remaining_overlap += 1
	check(remaining_overlap == 0, "密集した雑魚も強敵とボス部位の外へ抜ける")
	print("[strong_avoidance] checks=%d failed=%d crowded_avg_ms=%.3f avoidance_avg_ms=%.3f remaining_overlap=%d" %
		[checks, failed, elapsed_ms / 30.0, float(avoidance_usec) / 30000.0, remaining_overlap])
	session.free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
