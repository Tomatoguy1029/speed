## かに座の横歩き、向き直し、攻撃と防御撤去を確認する。
extends Node

var failed := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	var stage := load("res://tools/content/build_runtime_stage.gd").compile(ContentManager.stage(2)) as RuntimeStage
	if "--capture" in OS.get_cmdline_user_args():
		await _capture(stage)
		return
	var session := RunManager.create_session(self, {"lab": true, "stage": stage, "stage_index": 2, "seed": 42}, false)
	session.auto_step = false
	var sim := session.sim
	sim.field.bodies.clear()
	var enemies := sim.enemies
	var t := enemies.table
	var def := enemies.def_of(&"crab")
	check(def.gate == &"", "かに座は旧正面防御を持たない")
	check(def.params.has("turn_delay"), "横歩きと向き直しの調整値を持つ")
	if not def.params.has("turn_delay"):
		session.free()
		get_tree().quit(1)
		return
	var p := def.params
	sim.state.ship_pos = Vector2(350, 200)
	sim.state.enemy_aim = sim.state.ship_pos
	var row := enemies.spawn(def, Vector2.ZERO, {"facing": 0.0})
	var b := enemies.behavior(&"crab")
	var render := RunPresentation.new()
	render.run = sim
	render.state = sim.state
	render.cfg = sim.cfg
	check(render._visual_for_type(&"crab").get_script().resource_path.ends_with("/crab.gd"), "専用表示を読み込める")
	check(render.look_of(&"crab").normal != null, "既存の本体・装甲・法線の外観を維持する")
	render.free()
	b.step(row, 0.01)
	check(absf(t.vel[row].x) < 0.001 and t.vel[row].y > 0.0, "正面へ追跡せず、体の左右だけに動く")
	check(is_zero_approx(t.facing[row]), "横歩き中は自機へ向き直らない")
	# 歩いている途中に自機が反対側へ抜けたら、次の判断で進行方向を変える。
	t.timer[row] = 0.0
	t.bud_t[row] = 10.0
	sim.state.ship_pos.y = -200.0
	b.step(row, 0.01)
	check(t.vel[row].y < 0.0, "途中の再判断で反対側へ引き返す")
	t.bud_t[row] = 0.0
	b.step(row, 0.01)
	check(t.vel[row] == Vector2.ZERO and t.buds[row] == 0, "小走りのあとに立ち止まる")
	check(absf(b.body_tilt(row)) > 0.0, "停止中は自機の方へ体を傾ける")
	var pause := t.bud_t[row]
	b.step(row, pause + 0.01)
	check(t.buds[row] != 0, "停止時間が終わるとまた横歩きを始める")

	# 正面の届く範囲では横から位置を合わせ、予告後に1回だけ薙ぐ。
	enemies.clear_all()
	sim.state.ship_pos = Vector2(110, 0)
	row = enemies.spawn(def, Vector2.ZERO, {"facing": 0.0})
	t.fire_t[row] = 0.0
	b.step(row, 0.01)
	check(t.mode[row] == EnemyTable.Mode.WINDUP, "ハサミが届くと薙ぎの予告へ進む")
	check(_hazards(sim.projectiles) == 0, "予告中はダメージ判定を出さない")
	b.step(row, float(p.telegraph) + 0.01)
	check(t.mode[row] == EnemyTable.Mode.RECOVER and _hazards(sim.projectiles) == 1, "予告後に前方を一度薙ぐ")
	for h in sim.projectiles.hazard_alive.size():
		if sim.projectiles.hazard_alive[h]:
			var shape = sim.projectiles._hazard_shape(sim.projectiles.hazard_kind[h])
			check(shape.touches(sim.projectiles, h, Vector2(110, 0), 0.0), "薙ぎは前方に当たる")
			check(not shape.touches(sim.projectiles, h, Vector2(0, 100), 0.0), "薙ぎは縦の側面まで覆わない")

	# 一度で合わせる場合と、数回に分ける場合の両方で合計90度を超えない。
	for steps in [1, 3]:
		sim.projectiles.clear_hostile()
		enemies.clear_all()
		sim.state.ship_pos = Vector2(300, 300)
		row = enemies.spawn(def, Vector2.ZERO, {"facing": 0.0})
		t.fire_t[row] = 0.0
		t.carry[row] = float(p.turn_delay)
		b.step(row, 0.01)
		t.target_id[row] = steps
		check(t.mode[row] == EnemyTable.Mode.WINDUP and t.vel[row] == Vector2.ZERO, "届かない時間が続くと止まって向き直す")
		var previous := t.facing[row]
		var turned := 0.0
		for frame in 120:
			b.step(row, float(p.turn_time) / 100.0)
			turned += absf(Geom.angle_diff(t.facing[row], previous))
			previous = t.facing[row]
			if t.mode[row] == EnemyTable.Mode.DASH: break
		check(turned <= PI / 2.0 + 0.001, "向き直しの合計を90度以内に保つ")
		check(t.mode[row] == EnemyTable.Mode.DASH and t.vel[row].length() > t.speed[row], "向きが合うと自機へ直線突進する")
		var direction := t.vel[row].normalized()
		check(direction.dot(sim.state.ship_pos.normalized()) > 0.99, "突進は向きを合わせた自機の位置へ向かう")
		sim.state.ship_pos = Vector2(-300, -300)
		b.step(row, 0.01)
		check(t.vel[row].normalized().dot(direction) > 0.999, "突進中は追尾しない")
		var h := t.links[row][0]
		check(sim.projectiles.hazard_block[h] == 0, "突進は移動を止める壁にならない")
		t.pos[row] += t.vel[row] * 0.01
		b.after_tick(0.01)
		check(sim.projectiles.hazard_len[h] > 0.0, "突進の判定は実際に進んだ短い区間を覆う")
		b.step(row, float(p.dash_time))
		check(t.mode[row] == EnemyTable.Mode.RECOVER and t.vel[row] == Vector2.ZERO, "突進後に停止する")
		check(_hazards(sim.projectiles) == 0, "突進後は接触線を残さない")

	# 背後には90度で止まり、向きが合っていない方向へ突進しない。
	enemies.clear_all()
	sim.state.ship_pos = Vector2(-300, 0)
	row = enemies.spawn(def, Vector2.ZERO, {"facing": 0.0})
	t.fire_t[row] = 0.0
	t.carry[row] = float(p.turn_delay)
	b.step(row, 0.01)
	b.step(row, float(p.turn_time) + 0.01)
	check(absf(t.facing[row]) <= PI / 2.0 + 0.001 and t.mode[row] != EnemyTable.Mode.DASH, "背後に対して90度以上回らず、未整列で突進しない")
	# 真横は前方の薙ぎ範囲へ横移動だけでは届かない。
	enemies.clear_all()
	sim.state.ship_pos = Vector2(0, 300)
	row = enemies.spawn(def, Vector2.ZERO, {"facing": 0.0})
	b.step(row, 0.1)
	check(t.carry[row] > 0.0, "真横でも届かない時間を進める")

	# 予算待ちでも共通追跡に戻らず、撃破と行の再利用で攻撃を残さない。
	enemies.clear_all()
	sim.state.ship_pos = Vector2(350, 200)
	row = enemies.spawn(def, Vector2.ZERO, {"facing": 0.0})
	t.fire_t[row] = 0.0
	t.carry[row] = float(p.turn_delay)
	sim.projectiles.director.configure({"enabled": true, "budget": 0.0, "jitter": 0.0})
	enemies.tick(0.01, 0.01)
	check(t.mode[row] == EnemyTable.Mode.MOVE and absf(t.vel[row].x) < 0.001, "攻撃枠がない間も横歩きを保つ")
	sim.projectiles.director.configure({"enabled": false})
	b.step(row, 0.01)
	b.step(row, float(p.turn_time) + 0.01)
	check(_hazards(sim.projectiles) == 1, "突進の接触線は1本だけ出る")
	enemies.on_enemy_death(row, 100.0)
	enemies.mark_dead(row)
	enemies.cleanup()
	check(_hazards(sim.projectiles) == 0, "撃破時に突進判定を消す")
	row = enemies.spawn(def, Vector2.ZERO, {"facing": 0.0})
	check(t.carry[row] == 0.0 and t.links[row].is_empty() and t.mode[row] == EnemyTable.Mode.MOVE, "再利用した行へ向き直しと攻撃を引き継がない")
	for mode in [EnemyTable.Mode.MOVE, EnemyTable.Mode.WINDUP, EnemyTable.Mode.DASH]:
		t.mode[row] = mode
		check(enemies.gate_check(row, Vector2(30, 0), Vector2.LEFT, &"ram") == EnemyTable.GateResult.ALLOW, "全段階で正面も貫ける")
	# 攻撃枠を取った予告から発動まで、同じ予算トークンを引き継ぐ。
	enemies.clear_all()
	sim.state.ship_pos = Vector2(300, 300)
	row = enemies.spawn(def, Vector2.ZERO, {"facing": 0.0})
	t.fire_t[row] = 0.0
	t.carry[row] = float(p.turn_delay)
	sim.projectiles.director.advance(100.0, enemies)
	sim.projectiles.director.configure({"enabled": true, "budget": 1.0, "jitter": 0.0})
	b.step(row, 0.01)
	var token: int = sim.projectiles.director.token(str(t.id[row]))
	b.step(row, float(p.turn_time) + 0.01)
	check(token > 0 and not t.links[row].is_empty(), "予算内で向き直しと突進を開始できる")
	if not t.links[row].is_empty():
		check(sim.projectiles.lab_hazard_group[t.links[row][0]] == token, "突進の接触線へ取得した攻撃枠を引き継ぐ")
	# 石化すると突進判定を残さない。
	t.stone[row] = 1.0
	b.after_tick(0.01)
	check(_hazards(sim.projectiles) == 0 and t.mode[row] == EnemyTable.Mode.RECOVER, "石化で突進を中断する")
	# 通常の更新順でも横歩き→向き直し→突進→停止を進め、接触線が実際に当たる。
	enemies.clear_all()
	sim.projectiles.director.configure({"enabled": false})
	sim.state.ship_pos = Vector2(250, 100)
	sim.state.ship_invuln = 0.0
	sim.state.ship_shield_t = 0.0
	row = enemies.spawn(def, Vector2.ZERO, {"facing": 0.0})
	var hp := sim.state.ship_hp
	var saw_turn := false
	var saw_dash := false
	var saw_recover := false
	for frame in 360:
		var dt := 1.0 / 60.0
		sim.state.world_time += dt
		enemies.tick(dt, dt)
		sim.projectiles.tick(dt, dt)
		if t.mode[row] == EnemyTable.Mode.WINDUP: saw_turn = true
		if t.mode[row] == EnemyTable.Mode.DASH: saw_dash = true
		if t.mode[row] == EnemyTable.Mode.RECOVER:
			saw_recover = true
			break
	check(saw_turn and saw_dash and saw_recover, "通常の更新ループで向き直し・突進・停止まで進む")
	check(sim.state.ship_hp < hp, "移動する突進の接触線が自機へダメージを与える")
	check(_hazards(sim.projectiles) == 0, "通常の更新でも突進終了後に判定を残さない")
	session.free()
	await get_tree().process_frame
	print("[crab] %d failures" % failed)
	get_tree().quit(1 if failed else 0)

func _hazards(ps: ProjectileSystem) -> int:
	var count := 0
	for alive in ps.hazard_alive: count += int(alive)
	return count

## 描画付きの短い状態確認。出力はリポジトリ外へ保存する。
func _capture(stage: RuntimeStage) -> void:
	var session := RunManager.create_session(self, {"lab": true, "stage": stage, "stage_index": 2, "seed": 42}, true)
	session.auto_step = false
	var sim := session.sim
	sim.field.bodies.clear()
	sim.enemies.clear_all()
	var render := session.view.get_node("RunPresentation") as RunPresentation
	render.view_override = {"center": Vector2(100, 100), "zoom": 1.0}
	var t := sim.enemies.table
	var def := sim.enemies.def_of(&"crab")
	var p := def.params
	sim.state.ship_pos = Vector2(250, 180)
	sim.state.enemy_aim = sim.state.ship_pos
	var row := sim.enemies.spawn(def, Vector2.ZERO, {"facing": PI / 2.0})
	var b := sim.enemies.behavior(&"crab")
	t.buds[row] = 0
	t.bud_t[row] = 0.4
	for phase in ["pause", "sweep_warning", "sweep", "turn", "dash"]:
		match phase:
			"sweep_warning":
				sim.state.ship_pos = Vector2(0, 110)
				t.fire_t[row] = 0.0
				b.step(row, 0.01)
				b.step(row, float(p.telegraph) * 0.6)
			"sweep":
				b.step(row, float(p.telegraph))
				b.step(row, 0.07)
			"turn":
				sim.projectiles.clear_hostile()
				sim.enemies.clear_all()
				sim.state.ship_pos = Vector2(300, 300)
				row = sim.enemies.spawn(def, Vector2.ZERO, {"facing": PI / 2.0})
				t.fire_t[row] = 0.0
				t.carry[row] = float(p.turn_delay)
				b.step(row, 0.01)
				t.target_id[row] = 3
				b.step(row, float(p.turn_time) * 0.5)
			"dash":
				b.step(row, float(p.turn_time))
				t.pos[row] += t.vel[row] * 0.1
				b.after_tick(0.1)
		sim.state.world_time += 0.1
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/speed-crab-%s.png" % phase)
	session.free()
	get_tree().quit()
