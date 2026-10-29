## かじき座の停止予告・現在位置の固定照準・高速掃引・共通撃破との接続。
extends Node
var failed := 0
var sim: RunSimulation
var t: EnemyTable
var b: EnemyBehavior

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	var stage := load("res://tools/content/build_runtime_stage.gd").compile(ContentManager.stage(1)) as RuntimeStage
	if "--capture" in OS.get_cmdline_user_args():
		await _capture(stage)
		return
	var config := ContentManager.cfg.duplicate(true) as GameConfig
	config.drop_base = 0.0
	var session := RunManager.create_session(self, {"lab": true, "stage": stage, "stage_index": 1, "seed": 42, "config": config}, false)
	session.auto_step = false
	sim = session.sim
	t = sim.enemies.table
	reset()
	var visual := preload("res://scripts/render/enemies/marlin.gd")
	var view := Rect2(-100, -60, 200, 120)
	for from in [Vector2(-200, 0), Vector2(200, 0), Vector2(0, -200), Vector2(0, 200), Vector2(-200, -120)]:
		var line: PackedVector2Array = visual.clip_warning(from, Vector2.ZERO, view)
		check(line.size() == 2 and view.grow(0.01).has_point(line[0]) and line[1] == Vector2.ZERO,
			"画面外からの進入点と進路を画面内に示す")
		check((line[1] - line[0]).normalized().is_equal_approx((-from).normalized()), "予告の方向を実際の固定方向に保つ")
	check(visual.clip_warning(Vector2(-200, 80), Vector2(200, 80), view).is_empty(), "画面を通らない進路を画面端へ寄せない")
	check(visual.clip_warning(Vector2(-200, 0), Vector2(-150, 0), view).is_empty(), "画面へ届かない突進を描かない")
	var onscreen: PackedVector2Array = visual.clip_warning(Vector2.ZERO, Vector2(50, 0), view)
	check(onscreen == PackedVector2Array([Vector2.ZERO, Vector2(50, 0)]), "画面内の吻先と終点を保持する")
	var def := sim.enemies.def_of(&"marlin")
	for key in ["spray", "spray_step", "spread", "bullet_speed", "bullet_dmg"]:
		check(not def.params.has(key), "不要な弾設定%sを持たない" % key)
	check(StageEnemyTuning.keys_for(def).has("params.recover"), "休みをステージ別に調整できる")
	check(StageEnemyTuning.keys_for(def).has("speed"), "回遊速度を既存の調整画面で変更できる")
	var tuned := StageEnemyTuning.resolve(def, {"speed": 700.0, "params.recover": 1.2, "params.dash_speed": 2400.0})
	check(tuned.speed == 700.0 and tuned.params.recover == 1.2 and tuned.params.dash_speed == 2400.0 and def.speed == 560.0,
		"ステージ別上書きを共通定義と分離できる")
	sim.state.ship_pos = Vector2(-1000, 1000)
	sim.state.enemy_aim = sim.state.ship_pos
	var row := sim.enemies.spawn(def, Vector2(1000, 1000), {"vel": Vector2(200, 300)})
	b = sim.enemies.behavior(&"marlin")
	check(is_equal_approx(t.facing[row], Vector2(200, 300).angle()), "回遊開始時の鼻先は既存速度に揃う")
	t.fire_t[row] = 3.0
	var from := t.pos[row]
	var initial_facing := t.facing[row]
	for frame in 30:
		var prior := t.pos[row]
		var prior_facing := t.facing[row]
		sim.enemies.tick(0.05, 0.05)
		var travel := t.pos[row] - prior
		check(t.mode[row] == EnemyTable.Mode.MOVE and absf(Geom.angle_diff(t.facing[row], prior_facing)) <= t.turn[row] * 0.05 + 0.002, "回遊は旋回速度を守る")
		check(t.vel[row].length() > 0.0 and absf(Geom.angle_diff(t.vel[row].angle(), t.facing[row])) < 0.002, "回遊の顔と速度を一致させる")
		check(travel.length() > 0.0 and absf(Geom.angle_diff(travel.angle(), t.facing[row])) < 0.002, "回遊の顔と移動軌跡を一致させる")
	check(absf(Geom.angle_diff(t.facing[row], initial_facing)) > 0.5, "回遊中は目標へ向けて実際に旋回する")
	check(t.pos[row] != from and t.mode[row] == EnemyTable.Mode.MOVE, "回遊中は移動する")
	sim.state.ship_pos = t.pos[row] + Vector2(600, 0)
	sim.state.enemy_aim = t.pos[row] + Vector2(0, 600)
	t.fire_t[row] = float(def.params.telegraph) + 0.05
	from = t.pos[row]
	sim.enemies.tick(0.1, 0.1)
	check(t.mode[row] == EnemyTable.Mode.WINDUP and t.pos[row] == from and t.vel[row] == Vector2.ZERO, "回遊から急停止して予告へ入る")
	check(t.anchor[row] == sim.state.ship_pos and absf(t.facing[row]) < 0.001, "遅延照準と違う現在位置を停止時に固定する")
	sim.state.ship_pos += Vector2(0, 800)
	sim.state.enemy_aim = sim.state.ship_pos
	for frame in 7:
		sim.enemies.tick(0.1, 0.1)
		check(t.pos[row] == from and t.charge[row] > 0.0, "予告の全期間で停止して光る")
	for frame in 3:
		sim.enemies.tick(0.05, 0.05)
		if t.mode[row] == EnemyTable.Mode.DASH: break
	check(t.mode[row] == EnemyTable.Mode.DASH and t.vel[row].x > 0.0 and absf(t.vel[row].y) < 0.001, "停止時の方向へ直線突進する")
	var direction := t.vel[row].normalized()
	sim.state.ship_pos = t.pos[row] - Vector2(600, 500)
	sim.enemies.tick(0.1, 0.1)
	check(t.vel[row].normalized().is_equal_approx(direction), "発進後も自機を追尾しない")
	for frame in 20:
		sim.enemies.tick(0.1, 0.1)
		if t.mode[row] == EnemyTable.Mode.RECOVER: break
	check(sim.projectiles.hostile_alive.count(1) == 0, "突進で左右弾を発射しない")
	check(t.mode[row] == EnemyTable.Mode.RECOVER and t.charge[row] == 0.0, "突進後に予告を残さず休む")
	check(t.vel[row] == Vector2.ZERO, "突進終了時に古い高速速度を残さない")
	check(t.fire_t[row] == float(def.params.fire_interval), "既存の攻撃間隔を保つ")
	for frame in 20:
		sim.enemies.tick(0.05, 0.05)
		if t.mode[row] == EnemyTable.Mode.MOVE: break
	check(t.mode[row] == EnemyTable.Mode.MOVE and t.vel[row] == Vector2.ZERO, "休みの終わりまで静止する")
	sim.enemies.tick(0.05, 0.05)
	check(t.vel[row].length() > 0.0 and absf(Geom.angle_diff(t.vel[row].angle(), t.facing[row])) < 0.002, "休み明けも顔の方向へ加速する")

	# 一更新で複数の小対象を飛び越える。前フレームの戦闘格子にいない対象も拾う。
	reset()
	row = dash(Vector2.ZERO, 10000.0, 0.1)
	var victims: Array[int] = []
	for x in [100, 400, 900]: victims.append(victim(Vector2(x, 0)))
	var outside := victim(Vector2(400, 150))
	var rock := meteor(Vector2(600, 0))
	victims.append(rock.row)
	var kills := sim.state.kills
	var xp := sim.state.xp_dropped
	var expected_xp := 0.0
	for j in victims: expected_xp += t.xp[j] * sim.state.stats.xp_mult * (sim.spawn.current_phase().xp_bonus if sim.spawn.current_phase().xp_bonus > 0.0 else 1.0)
	sim.enemies.tick(0.1, 0.1)
	for j in victims: check(t.dead[j] != 0, "高速突進の途中にいる敵を撃破する")
	check(t.dead[outside] == 0, "進路の外の敵を壊さない")
	check(sim.state.kills == kills + victims.size(), "途中の敵をそれぞれ一度だけ撃破として数える")
	check(is_equal_approx(sim.state.xp_dropped - xp, expected_xp), "共通撃破の経験値を一度ずつ落とす")
	sim.field.gimmick(&"meteors").tick(0.1, 0.1)
	check(rock.destroyed and rock.row == -1, "破壊した隕石を配置元でも破壊済みとして扱う")
	sim.enemies.cleanup()
	sim.field.gimmick(&"meteors").tick(0.2, 0.2)
	check(rock.destroyed and rock.row == -1, "隕石は行の解放後も再出現しない")
	var xp_after := sim.state.xp_dropped
	b.before_move(row, 0.1)
	check(sim.state.kills == kills + victims.size() and sim.state.xp_dropped == xp_after, "重なった移動区間で撃破と報酬を重ねない")

	# 惑星はBody、隕石はRockとして区別し、通常の地形と破壊対象を保つ。
	reset()
	row = dash(Vector2.ZERO, 10000.0, 0.2)
	rock = meteor(Vector2(100, 0))
	var planet := sim.field.planet
	planet.pos = Vector2(600, 0)
	planet.r = 40.0
	sim.field.bodies.append(planet)
	sim.field._update_body_grid()
	sim.enemies.tick(0.1, 0.1)
	check(t.dead[rock.row] != 0, "惑星と同じ進路にある隕石を壊す")
	check(sim.field.bodies.has(planet) and planet.pos == Vector2(600, 0) and planet.r == 40.0, "惑星の実体・位置・半径を保持する")
	var terrain_hit = sim.field.first_body_hit(Vector2.ZERO, Vector2(1000, 0), 1.0)
	check(terrain_hit != null and terrain_hit.body == planet, "惑星を共通の地形衝突格子に保持する")
	sim.field.refresh_bodies()
	check(sim.field.bodies.has(planet) and sim.field.near_body(planet.pos, 1.0), "次の地形更新後も惑星を保持する")
	check(sim.state.events.filter(func(event): return event.type == &"explode" and event.get("cause") == &"marlin").is_empty(), "惑星の破壊演出を発生させない")
	check(t.mode[row] == EnemyTable.Mode.DASH, "地形接触で専用の行動遷移を追加しない")

	# 同じフレームに二体が通っても、同じ敵を二重に倒さない。
	reset()
	row = dash(Vector2.ZERO, 1000.0, 0.3)
	dash(Vector2(0, 100), 1000.0, 0.3)
	var target := victim(Vector2(150, 50))
	t.r[target] = 80.0
	kills = sim.state.kills
	sim.enemies.tick(0.2, 0.2)
	check(t.dead[target] != 0 and sim.state.kills == kills + 1, "複数のカジキが同じ対象を重複撃破しない")
	# 期限を越える大きな更新でも、突進時間ぶんの距離だけを進める。
	reset()
	row = dash(Vector2.ZERO, 1000.0, 0.05)
	var beyond := victim(Vector2(200, 0))
	sim.enemies.tick(0.5, 0.5)
	check(t.pos[row].is_equal_approx(Vector2(50, 0)) and t.dead[beyond] == 0, "残り時間を越えて移動・破壊しない")

	# 既存の例外：無敵、ボスと部位、丸鋸・固定瓦礫、特殊防御。
	reset()
	row = dash(Vector2.ZERO, 10000.0, 0.2)
	var invuln := victim(Vector2(100, 0))
	t.guard[invuln] = 10.0
	var boss := sim.enemies.spawn_boss(&"monoceros", Vector2(250, 0), 30.0, 100.0, 10.0, 0.0, 0.0, 0.0, 0.0, Color.WHITE)
	var part := sim.enemies.spawn_part(boss, sim.enemies.def_of(&"drifter"), Vector2(300, 0))
	var saw := sim.enemies.spawn(sim.enemies.def_of(&"saw"), Vector2(400, 0))
	var rubble := sim.enemies.spawn(sim.enemies.def_of(&"hydra_rubble"), Vector2(500, 0))
	var shield := sim.enemies.spawn(sim.enemies.def_of(&"shield"), Vector2(700, 0), {"facing": PI})
	# 盾の前面へ左から当てる。
	b.before_move(row, 0.1)
	for j in [invuln, boss, part, saw]: check(t.dead[j] == 0, "既存の無敵・ボス・破壊不能の例外を尊重する")
	check(t.dead[rubble] != 0, "武器で壊せる瓦礫の規則に従う")
	check(t.dead[shield] == 0, "特殊な倒し方を正面から無視しない")
	var regular_parent := victim(Vector2(2000, 1000))
	var regular_part := sim.enemies.spawn_part(regular_parent, sim.enemies.def_of(&"drifter"), Vector2(150, 0))
	b.before_move(row, 0.05)
	check(t.dead[regular_part] != 0, "通常敵の部位はボスの例外へ含めない")

	# 共通の地形衝突より先まで破壊しない。惑星・月・固定外周で同じAPIを使う。
	for terrain in ["planet", "moon", "arena"]:
		reset()
		row = dash(Vector2.ZERO, 10000.0, 0.2)
		if terrain == "arena": sim.field.battle_arenas["test"] = Rect2(-200, -200, 500, 400)
		else: body(Vector2(300, 0), 40.0, terrain == "planet")
		target = victim(Vector2(500, 0))
		planet = body(Vector2(700, 0), 50.0, true)
		sim.enemies.tick(0.1, 0.1)
		check(t.pos[row].x < 301.0 and t.dead[target] == 0 and sim.field.bodies.has(planet), "遮る地形の先まで破壊しない")

	# 画面外LOD・攻撃予算待ち・石化・吹き飛ばし・行再利用。
	reset()
	row = dash(Vector2(10000, 10000), 10000.0, 0.2)
	target = victim(Vector2(10500, 10000))
	sim.enemies.tick(0.1, 0.1)
	check(t.dead[target] != 0 and is_equal_approx(t.timer[row], 0.1), "画面外でも突進の時間と破壊判定を省略しない")
	reset()
	row = sim.enemies.spawn(def, Vector2(1000, 1000))
	t.fire_t[row] = float(def.params.telegraph)
	sim.projectiles.director.configure({"enabled": true, "budget": 0.0, "jitter": 0.0})
	sim.enemies.tick(0.1, 0.1)
	check(t.mode[row] == EnemyTable.Mode.MOVE and t.vel[row] != Vector2.ZERO, "攻撃枠を待つ間は回遊を続ける")
	sim.projectiles.director.configure({"enabled": false})
	sim.enemies.tick(0.1, 0.1)
	check(t.mode[row] == EnemyTable.Mode.WINDUP and t.vel[row] == Vector2.ZERO, "許可後に停止予告へ入る")
	for stopped in ["stone", "knock"]:
		reset()
		row = dash(Vector2.ZERO, 10000.0, 0.2)
		target = victim(Vector2(500, 0))
		if stopped == "stone": t.stone[row] = 1.0
		else:
			t.knock_t[row] = 1.0
			t.vel[row] = Vector2.RIGHT * 10000.0
		sim.enemies.tick(0.1, 0.1)
		check(t.dead[target] == 0, "石化・吹き飛ばし中の移動で突進破壊を発生させない")
	sim.enemies.mark_dead(row)
	sim.enemies.cleanup()
	row = sim.enemies.spawn(def, Vector2.ZERO)
	check(t.mode[row] == EnemyTable.Mode.MOVE and t.charge[row] == 0.0, "再利用した行へ予告と突進を引き継がない")
	session.free()
	await get_tree().process_frame
	print("[marlin] %d failures" % failed)
	get_tree().quit(1 if failed else 0)

func reset() -> void:
	sim.enemies.clear_all()
	sim.projectiles.clear_hostile()
	sim.projectiles.director.configure({"enabled": false})
	sim.field.bodies.clear()
	sim.field.rocks.clear()
	sim.field.moons.clear()
	sim.field.battle_arenas.clear()
	sim.field._build_moon_bands()
	sim.field.refresh_bodies()
	sim.state.ship_pos = Vector2(2000, 2000)
	sim.state.enemy_aim = Vector2.ZERO
	sim.state.phase = RunState.Phase.PLAY
	sim.state.events.clear()

func dash(pos: Vector2, speed: float, duration: float) -> int:
	var def := sim.enemies.def_of(&"marlin").duplicate(true) as EnemyDef
	def.params.dash_speed = speed
	var row := sim.enemies.spawn(def, pos)
	b = sim.enemies.behavior(&"marlin")
	t.mode[row] = EnemyTable.Mode.DASH
	t.timer[row] = duration
	t.facing[row] = 0.0
	return row

func victim(pos: Vector2) -> int:
	return sim.enemies.spawn(sim.enemies.def_of(&"drifter"), pos)

func meteor(pos: Vector2) -> FieldSystem.Rock:
	var rock := FieldSystem.Rock.new()
	rock.kind = &"belt"
	rock.pos = pos
	rock.size = 20.0
	rock.lab_manual = true
	var rock_index := sim.field.rocks.size()
	sim.field.rocks.append(rock)
	rock.row = sim.enemies.spawn(sim.enemies.def_of(&"meteor"), pos, {"meteor_index": rock_index, "size": rock.size})
	rock.row_id = t.id[rock.row]
	return rock

func body(pos: Vector2, radius: float, planet: bool) -> FieldSystem.Body:
	var result := FieldSystem.Body.new()
	result.pos = pos
	result.r = radius
	result.is_planet = planet
	sim.field.bodies.append(result)
	sim.field._update_body_grid()
	return result

## 本番の描画を使う短い見本。Godotの --write-movie と併用できる。
func _capture(stage: RuntimeStage) -> void:
	var session := RunManager.create_session(self, {"lab": true, "stage": stage, "stage_index": 1, "seed": 42}, true)
	session.auto_step = false
	sim = session.sim
	t = sim.enemies.table
	reset()
	var render := session.view.get_node("RunPresentation") as RunPresentation
	render.view_override = {"center": Vector2.ZERO, "zoom": 0.65}
	if "--warnings" in OS.get_cmdline_user_args():
		await _capture_warnings(session, render)
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.position = Vector2(24, 130)
	label.add_theme_font_size_override("font_size", 26)
	layer.add_child(label)
	sim.state.ship_pos = Vector2(400, 0)
	sim.state.enemy_aim = sim.state.ship_pos
	sim.state.ship_invuln = 100.0
	var row := sim.enemies.spawn(sim.enemies.def_of(&"marlin"), Vector2(-500, -160), {"vel": Vector2(0, 560)})
	t.fire_t[row] = 2.0
	var placed := false
	for frame in 270:
		var dt := 1.0 / 60.0
		sim.state.world_time += dt
		sim.enemies.tick(dt, dt)
		if t.mode[row] == EnemyTable.Mode.WINDUP and not placed:
			placed = true
			for fraction in [0.25, 0.7]: victim(t.pos[row].lerp(t.anchor[row], fraction))
			meteor(t.pos[row].lerp(t.anchor[row], 0.48))
			body(Vector2(0, -240), 65.0, true)
			sim.field.planet.pos = Vector2(1e7, 1e7)
		label.text = {EnemyTable.Mode.MOVE: "高速回遊", EnemyTable.Mode.WINDUP: "急停止 → キランと予告（惑星は保持）",
			EnemyTable.Mode.DASH: "直線突進・敵と隕石を破壊", EnemyTable.Mode.RECOVER: "突進終了"}.get(t.mode[row], "")
		sim.combat.rebuild_grid()
		sim.projectiles.tick(dt, dt)
		sim.enemies.cleanup()
		sim.flush_events()
		if frame >= 190:
			render.view_override = {"center": t.pos[row], "zoom": 0.65}
		await get_tree().process_frame
		if frame in [25, 50, 75, 110, 150, 200, 215, 240]:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/speed-marlin-motion-%03d.png" % frame)
	session.free()
	get_tree().quit()

## 同じ描画経路で停止直後・発進直前・画面外の予告を比較する。
func _capture_warnings(session: Node, render: RunPresentation) -> void:
	sim.state.ship_pos = Vector2(400, 0)
	sim.state.ship_invuln = 100.0
	var row := sim.enemies.spawn(sim.enemies.def_of(&"marlin"), Vector2(-500, -160))
	for sample in ["on-early", "on-late", "off-left", "off-top"]:
		t.pos[row] = Vector2(-500, -160)
		if sample == "off-left": t.pos[row] = Vector2(render.view_rect().position.x - 150.0, -100)
		if sample == "off-top": t.pos[row] = Vector2(-100, render.view_rect().position.y - 150.0)
		t.facing[row] = (sim.state.ship_pos - t.pos[row]).angle()
		t.anchor[row] = sim.state.ship_pos
		t.mode[row] = EnemyTable.Mode.WINDUP
		t.charge[row] = 0.01 if sample == "on-early" else 0.9
		for frame in 30: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/speed-marlin-warning-%s.png" % sample)
	session.free()
	get_tree().quit()
