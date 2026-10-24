## 合意した攻撃・惑星・形態予約・共通撃破経路の短い受け入れ確認。
extends Node
var failed := 0
var sim: RunSimulation
var actor: MonocerosBoss
var session: Node
var events: Array[StringName] = []
const DT := 1.0 / 120.0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var stage := load("res://tools/content/build_runtime_stage.gd").compile(ContentManager.stage(1)) as RuntimeStage
	session = RunManager.create_session(self, {"lab": true, "stage": stage, "stage_index": 1, "seed": 42}, "--capture" in OS.get_cmdline_user_args())
	session.auto_step = false
	sim = session.sim
	if "--capture" in OS.get_cmdline_user_args():
		await capture()
		return
	fresh()
	check(actor.get_node_or_null("LimboHSM") == null and actor.get("flow_runner") != null, "一角獣は共通フローを使いLimboAIへ依存しない")
	check(ContentManager.stage(1).boss_id == &"monoceros", "ステージ1は専用ボスを参照する")
	check(actor.table.max_hp[actor.body] == actor.def.hp * sim.cfg.enemy_hp_mult, "専用HPを共通倍率付きで使う")
	check(actor.table.armor[actor.body] == actor.def.armor * sim.cfg.enemy_armor_mult, "専用装甲を使う")
	check(actor.table.gate[actor.body] == EnemyTable.Gate.NONE and actor.table.weak_arc[actor.body] == 0.0, "全方向から本体を攻撃できる")
	actor.start_attack(&"charge")
	sim.state.enemy_aim = Vector2(600, 220)
	step(0.4)
	check(actor.table.facing[actor.body] > 0.1, "予告中は遅延照準へ向き直る")
	until(&"windup", true)
	var locked_angle := actor.table.facing[actor.body]
	sim.state.enemy_aim = Vector2(0, -800)
	step(0.15)
	check(is_equal_approx(actor.table.facing[actor.body], locked_angle), "発進前に方向を固定する")
	while actor.mode == &"windup": step(DT)
	var launch := actor.table.pos[actor.body]
	step(0.3)
	check(absf((actor.table.pos[actor.body] - launch).normalized().cross(Vector2.from_angle(locked_angle))) < 0.001, "発進後は直線で曲がらない")
	step(2.2)
	check(actor.mode == &"idle", "通常突進の後に回復する")

	fresh()
	actor.start_attack(&"return_charge")
	var launches := 0
	var locked_count := 0
	var sign_y := 1.0
	for frame in 1600:
		if actor.mode == &"turnaround":
			sim.state.enemy_aim = actor.table.pos[actor.body] + Vector2(-500, sign_y * 160)
			sign_y = -sign_y
		var before := actor.mode
		var was_locked := actor.locked
		step(DT)
		if before == &"windup" and actor.mode == &"active": launches += 1
		if not was_locked and actor.locked: locked_count += 1
		if actor.mode == &"recovery": break
	check(launches == int(actor.def.params.return_passes) and locked_count == launches, "往復は毎回予告と固定を挟んで発進する")
	check(actor.recovery >= float(actor.rule().recover) - DT, "往復の最後に全体の隙を確保する")

	fresh()
	var planet := sim.field.planet
	planet.pos = Vector2(300, 0)
	planet.r = 80.0
	sim.field.bodies.append(planet)
	sim.field.refresh_bodies()
	actor.start_attack(&"charge")
	step(1.1)
	check(actor.mode == &"idle" and actor.reposition > 0.0, "狙いまで惑星が塞ぐ時は発進せず移動する")
	var at := actor.table.pos[actor.body]
	step(0.3)
	check(actor.table.pos[actor.body].distance_to(at) > 1.0, "遮蔽時に場所を変える")

	for tech in [&"charge", &"return_charge"]:
		fresh()
		planet = sim.field.planet
		planet.pos = Vector2(1020, 0)
		planet.r = 80.0
		sim.field.bodies.append(planet)
		sim.field.refresh_bodies()
		actor.start_attack(tech)
		for frame in 400:
			step(DT)
			if actor.mode == &"stuck": break
		check(actor.mode == &"stuck", "かわされた先の惑星へ角が刺さる: " + tech)
		check(actor.passes_left == 0 and not actor.combo_pending, "角刺さりで連撃を中断する")
		actor.table.hp[actor.body] = actor.table.max_hp[actor.body] * 0.4
		actor.on_body_damaged()
		step(1.0)
		check(actor.phase == 1 and actor.mode == &"stuck", "角刺さりの攻撃機会を形態移行で潰さない")
		step(2.05)
		check(actor.phase == 1 and actor.mode == &"extract", "もがいた後に角を抜く")
		step(0.8)
		check(actor.phase == 2, "抜いた後に予約した形態へ進む")
		check(sim.field.bodies.size() == 1 and planet.r == 80.0 and planet.pos == Vector2(1020,0), "惑星を生成・破壊・移動しない")

	for tech in [&"charge", &"sweep", &"kick", &"lance"]:
		fresh()
		actor.phase = 2
		actor.start_attack(tech)
		var hp := sim.state.ship_hp
		step(float(actor.rule().warn) - 0.02)
		var points := actor.horn_points()
		sim.state.ship_pos = points[0].lerp(points[1],0.75)
		actor.previous_ship = sim.state.ship_pos
		check(sim.state.ship_hp == hp, "予告中は無害: " + tech)
		while actor.mode == &"windup": step(DT)
		points = actor.horn_points()
		sim.state.ship_pos = points[0].lerp(points[1],0.65)
		actor.previous_ship = sim.state.ship_pos
		step(DT)
		check(sim.state.ship_hp < hp, "表示と共有する角／蹄の形状で被弾する: " + tech)
		var hurt_hp := sim.state.ship_hp
		step(0.1)
		check(sim.state.ship_hp == hurt_hp, "一振りで重複被弾を出さない: " + tech)

	fresh()
	actor._cooldown = 0.0
	check(actor.can_select(&"kick",1,0,260,true)==false, "正面の自機に後ろ蹴りを選ばない")
	sim.state.enemy_aim = Vector2(-180, 0)
	check(actor.can_select(&"kick",1,0,260,true), "序盤から背後への蹴りを選べる")
	actor.start_attack(&"kick")
	step(2.5)
	check(not actor.can_select(&"kick",1,0,260,true), "蹴りのCDで背面攻略の機会を確保する")

	fresh()
	actor.phase = 2
	actor.start_attack(&"combo")
	step(2.5)
	check(actor.technique == &"sweep" and actor.mode == &"windup", "後半は突進後に予告付きの薙ぎへつなぐ")
	step(1.5)
	check(actor.mode == &"recovery" and not actor.combo_pending, "連携の最後に隙を作る")

	fresh()
	actor.start_attack(&"charge")
	step(1.2)
	actor.table.hp[actor.body] *= 0.4
	actor.on_body_damaged()
	step(0.8)
	check(actor.phase_pending and actor.phase == 1 and actor.mode == &"recovery", "HP閾値は攻撃とその後の隙が終わるまで待つ")
	step(1.5)
	check(actor.phase == 2 and actor.mode == &"phase", "通常の隙を消費してから移行する")
	step(1.1)
	check(actor.phase == 2 and actor.get("flow_runner") != null, "第2形態も共通フローで行動を選ぶ")

	fresh()
	# 通常ランの共通撃破通知を使い、伝説モジュールへ進む接続点まで確認する。
	sim.state.lab_mode = false
	actor.start_attack(&"return_charge")
	sim.combat.damage_enemy(actor.body, actor.table.max_hp[actor.body]+1.0, {"cause": &"ram"})
	check(sim.state.boss_dead and actor.mode == &"defeated" and not actor.timeline.is_playing(), "死亡で技を停止し共通撃破を通知する")
	check(sim.state.stage.legendary_module_id == &"legendary_stern", "とも座の伝説モジュールへ接続する")
	fresh()
	check(actor.phase == 1 and not actor.phase_pending and actor.mode == &"idle", "再生成で攻撃・形態・角刺さりをリセットする")
	actor._cooldown = 0.0
	var candidates: Array = actor.flow_adapter.candidates({"request": "any"}).candidates
	check(not candidates.is_empty() and candidates.all(func(c): return c.id not in ["lance", "combo"]), "第1形態の候補に第2形態専用技を混ぜない")
	step(0.1)
	check(actor.flow_runner.active and actor.flow_runner.stamina < actor.flow_runner.flow.maximum_stamina, "共通フローの抽選で技を開始しスタミナを消費する")
	actor.begin_final_strike(1.0)
	step(0.1)
	check(actor.final_strike_t >= 0.0 and actor.mode == &"final", "制限時間の共通演出に対応する")
	session.free()
	await get_tree().process_frame
	print("[monoceros] failures=",failed)
	get_tree().quit(1 if failed else 0)

func fresh() -> void:
	sim.bosses.remove_boss()
	sim.enemies.clear_all()
	sim.projectiles.clear_hostile()
	sim.projectiles.director.configure({"enabled": false})
	sim.field.bodies.clear()
	sim.field.rocks.clear()
	sim.field.moons.clear()
	sim.field.battle_arenas.clear()
	sim.field._build_moon_bands()
	sim.field.refresh_bodies()
	sim.state.phase = RunState.Phase.PLAY
	sim.state.boss_dead = false
	sim.state.lab_mode = true
	sim.state.ship_pos = Vector2(600, 0)
	sim.state.enemy_aim = sim.state.ship_pos
	sim.state.ship_hp = sim.state.stats.max_hp
	sim.state.ship_invuln = 0.0
	sim.ship.invincible = false
	sim.bosses.spawn(load("res://data/bosses/monoceros.tres"),Vector2.ZERO)
	actor = sim.bosses.actor as MonocerosBoss
	actor._cooldown = 1000.0
	actor.table.facing[actor.body] = 0.0

func step(seconds: float) -> void:
	for frame in ceili(seconds / DT):
		sim.state.world_time += DT
		sim.state.time += DT
		actor.sim_tick(DT,DT)

func until(target: StringName, lock := false) -> void:
	for frame in 600:
		if actor.mode==target and (not lock or actor.locked): return
		step(DT)
	check(false,"状態の待機期限: "+target)

func capture() -> void:
	fresh()
	var render := session.view.get_node("RunPresentation") as RunPresentation
	render.view_override = {"center": Vector2(350, 0), "zoom": 0.65}
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.position = Vector2(24,130)
	label.add_theme_font_size_override("font_size",24)
	layer.add_child(label)
	var stage_names := [&"charge",&"sweep",&"kick",&"return_charge",&"lance"]
	for tech in stage_names:
		fresh()
		actor.phase = 2 if tech==&"lance" else 1
		actor.start_attack(tech)
		for frame in 170:
			step(1.0/60.0)
			label.text = "いっかくじゅう座（仮） %s / %s" % [tech,actor.mode]
			await get_tree().process_frame
			if frame in [35,75]:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("/tmp/speed-monoceros-%s-%d.png"%[tech,frame])
	session.free()
	get_tree().quit()
