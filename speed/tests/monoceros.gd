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
	if "--cpp-charge-terrain" in OS.get_cmdline_user_args():
		call_deferred("native_charge_terrain")
		return
	if "--cpp-charge" in OS.get_cmdline_user_args():
		call_deferred("native_charge")
		return
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
	fresh()
	sim.state.ship_pos = Vector2(2400, 0)
	sim.state.enemy_aim = sim.state.ship_pos
	actor._cooldown = 0.0
	step(0.1)
	check(actor.mode == &"idle", "遠方では届かない突進を始めず接近する")
	check(actor.table.pos[actor.body].x > 0.0, "遠方からプレイヤーへ戻る")
	var approached := false
	for frame in 1200:
		step(DT)
		if actor.mode == &"windup":
			approached = actor.table.pos[actor.body].distance_to(sim.state.enemy_aim) <= actor._reach(actor.technique)
			break
	check(approached, "攻撃可能な距離へ戻ってから予告を始める")
	for tech in [&"charge", &"return_charge", &"sweep", &"kick", &"lance", &"horn_wave"]:
		fresh()
		actor._cooldown = 0.0
		actor.phase = 2 if tech == &"lance" else 1
		actor._apply_phase()
		sim.state.enemy_aim = Vector2(-180, 0) if tech == &"kick" else Vector2(400, 0) if tech == &"sweep" else Vector2(600, 0)
		sim.state.ship_pos = sim.state.enemy_aim
		var candidates: Array = actor.flow_adapter.candidates({"request": "any"}).candidates
		check(candidates.any(func(c): return c.id == String(tech)), "仕様の距離・形態で候補へ入る: " + tech)
		var flow := actor.flow_runner.flow.duplicate(true)
		for section in flow.sections: section["allowed_techniques"] = [String(tech)]
		# 指定された区間0で衝撃波を単独確認するため、この複製だけ消費上限を技の消費へ合わせる。
		if tech == &"horn_wave": flow.sections[0]["cap"] = float(actor.action_rules.costs.horn_wave)
		actor.flow_runner.configure(flow)
		actor.flow_runner.index = 2 if tech == &"lance" else 1 if tech == &"return_charge" else 0
		step(DT)
		check(actor.mode == &"windup" and actor.technique == tech, "共通フローから技を開始できる: " + tech)
	fresh()
	actor.start_attack(&"charge")
	sim.state.enemy_aim = Vector2(600, 220)
	sim.state.ship_pos = sim.state.enemy_aim
	step(0.4)
	check(actor.table.facing[actor.body] > 0.1, "予告中は現在の自機へ向き直る")
	until(&"windup", true)
	var locked_angle := actor.table.facing[actor.body]
	sim.state.enemy_aim = Vector2(0, -800)
	sim.state.ship_pos = sim.state.enemy_aim
	step(0.15)
	check(is_equal_approx(actor.table.facing[actor.body], locked_angle), "発進前に方向を固定する")
	while actor.mode == &"windup": step(DT)
	var launch := actor.table.pos[actor.body]
	step(0.3)
	check(absf((actor.table.pos[actor.body] - launch).normalized().cross(Vector2.from_angle(locked_angle))) < 0.001, "発進後は直線で曲がらない")
	step(2.2)
	check(actor.mode == &"idle", "通常突進の後に回復する")
	for tech in [&"charge", &"return_charge"]:
		fresh()
		actor.phase = 2
		actor._apply_phase()
		sim.state.enemy_aim = Vector2(-600, 0)
		sim.state.ship_pos = sim.state.enemy_aim
		actor.start_attack(tech)
		until(&"windup", true)
		var target_direction := (sim.state.enemy_aim - actor.table.pos[actor.body]).normalized()
		check(actor.direction.dot(target_direction) > 0.9999, "背後へ切り返しても固定時点の自機を狙う: " + tech)
		check(Vector2.from_angle(actor.table.facing[actor.body]).dot(actor.direction) > 0.9999, "予告と発進方向を一致させる: " + tech)

	fresh()
	actor.start_attack(&"return_charge")
	var launches := 0
	events.clear()
	actor.presentation_event.connect(func(e): events.append(e.cue))
	var locked_count := 0
	var sign_y := 1.0
	for frame in 1600:
		if actor._runner.get("stage") == &"brake":
			sim.state.enemy_aim = actor.table.pos[actor.body] + Vector2(-500, sign_y * 160)
			sim.state.ship_pos = sim.state.enemy_aim
			sign_y = -sign_y
		var was_locked := actor.locked
		step(DT)
		launches = events.count(&"attack_started")
		if not was_locked and actor.locked: locked_count += 1
		if actor.mode == &"recovery": break
	check(launches == int(actor.rule().get("passes", 0)) and locked_count == launches, "往復は毎回予告と固定を挟んで発進する")
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

	for tech in [&"charge", &"kick", &"lance"]:
		fresh()
		actor.phase = 2
		actor._apply_phase()
		sim.state.ship_pos = Vector2(-180,0) if tech == &"kick" else Vector2(400,0) if tech == &"sweep" else Vector2(600,0)
		sim.state.enemy_aim = sim.state.ship_pos
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
	sim.state.ship_pos = Vector2(400, 0)
	sim.state.enemy_aim = sim.state.ship_pos
	actor.start_attack(&"sweep")
	var sweep_hp := sim.state.ship_hp
	var sweep_points := actor.horn_points()
	sim.state.ship_pos = sweep_points[0].lerp(sweep_points[1], 0.75)
	actor.previous_ship = sim.state.ship_pos
	for frame in 600:
		if actor._runner.get("stage") == &"swing": break
		step(DT)
	check(sim.state.ship_hp == sweep_hp, "踏み込み薙ぎは振り抜く前に角へ触れても無害")
	sweep_points = actor.horn_points()
	sim.state.ship_pos = sweep_points[0].lerp(sweep_points[1], 0.65)
	actor.previous_ship = sim.state.ship_pos
	step(DT)
	check(sim.state.ship_hp < sweep_hp, "踏み込み薙ぎは振り抜く角の形状で被弾する")
	var sweep_hurt_hp := sim.state.ship_hp
	step(0.1)
	check(sim.state.ship_hp == sweep_hurt_hp, "踏み込み薙ぎは一振りで重複被弾を出さない")

	fresh()
	actor._cooldown = 0.0
	check(actor.can_select(&"kick",1,0,260,true)==false, "正面の自機に後ろ蹴りを選ばない")
	sim.state.enemy_aim = Vector2(-180, 0)
	sim.state.ship_pos = sim.state.enemy_aim
	check(actor.can_select(&"kick",1,0,260,true), "序盤から背後への蹴りを選べる")
	actor.start_attack(&"kick")
	step(2.5)
	check(not actor.can_select(&"kick",1,0,260,true), "蹴りのCDで背面攻略の機会を確保する")

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
	check(actor.has_method("begin_entrance"), "ブースターで画面外から飛び込む登場を持つ")
	if actor.has_method("begin_entrance"):
		var target := actor.table.pos[actor.body]
		actor.selection_enabled = false
		actor.call("begin_entrance")
		check(actor.mode == &"entrance" and not actor.can_begin_sequence(), "登場中は攻撃を選ばない")
		check(actor.table.pos[actor.body].distance_to(target) > 100.0, "登場は目標の外側から始まる")
		for frame in 240:
			step(DT)
			if actor.mode == &"idle": break
		check(actor.mode == &"idle" and actor.table.pos[actor.body].is_equal_approx(target), "飛来後に目標で停止する")
	check(actor._presentation.has_method("booster_strength"), "表示側はブースターの噴射強度を持つ")
	if actor._presentation.has_method("booster_strength"):
		var idle_strength: float = actor._presentation.call("booster_strength")
		actor.start_attack(&"charge")
		while actor.mode == &"windup": step(DT)
		check(float(actor._presentation.call("booster_strength")) > idle_strength, "突進で炎の尻尾が大きく噴き出す")

	fresh()
	actor.phase = 2
	actor._apply_phase()
	var lance_trace := {"launch": Vector2.ZERO, "stopped": false, "distance": 0.0, "shatters": 0}
	actor.presentation_event.connect(func(e):
		if e.cue == &"attack_started": lance_trace.launch = actor.table.pos[actor.body]
		if e.cue == &"lance_shatter": lance_trace.shatters += 1)
	actor.start_attack(&"lance")
	var after_shatter := false
	var shatter_hp := sim.state.ship_hp
	for frame in 1200:
		step(DT)
		if actor._runner.get("stage") == &"stop" and not lance_trace.stopped:
			lance_trace.stopped = true
			lance_trace.distance = actor.table.pos[actor.body].distance_to(lance_trace.launch)
		if lance_trace.shatters > 0 and not after_shatter:
			after_shatter = true
			var points := actor.horn_points()
			sim.state.ship_pos = points[0].lerp(points[1], 0.65)
			actor.previous_ship = sim.state.ship_pos
			shatter_hp = sim.state.ship_hp
			sim.state.ship_invuln = 0.0
		if actor.mode == &"recovery": break
	check(lance_trace.stopped and absf(float(lance_trace.distance) - float(actor.rule().distance)) < 0.1, "光の槍は指定の距離を進んで停止する")
	check(lance_trace.shatters == 1 and actor.mode == &"recovery", "光の槍は1回だけ砕けて隙に入る")
	sim.state.ship_invuln = 0.0
	step(0.7)
	check(after_shatter and sim.state.ship_hp == shatter_hp, "砕けた光の槍の角に攻撃判定を残さない")

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
	check(not candidates.is_empty() and candidates.all(func(c): return c.id not in ["lance", "sword_flash", "horn_dance"]), "第1形態の候補に第2形態専用技を混ぜない")
	step(0.1)
	check(actor.flow_runner.active and actor.flow_runner.stamina < actor.flow_runner.flow.maximum_stamina, "共通フローの抽選で技を開始しスタミナを消費する")
	actor.begin_final_strike(1.0)
	step(0.1)
	check(actor.final_strike_t >= 0.0 and actor.mode == &"final", "制限時間の共通演出に対応する")
	fresh()
	sim.state.ship_pos = Vector2(2000, 0)
	sim.state.enemy_aim = sim.state.ship_pos
	actor.start_attack(&"horn_wave")
	for frame in 600:
		step(DT)
		if actor.mode == &"recovery" and not actor.horn_waves.is_empty(): break
	check(actor.mode == &"recovery" and not actor.horn_waves.is_empty(), "角の衝撃波は技が終わったあとも残る")
	if not actor.horn_waves.is_empty():
		var wave: Dictionary = actor.horn_waves.back()
		var radius := float(wave.radius)
		step(DT)
		check(float(wave.radius) > radius, "技が終わったあとも衝撃波が広がる")
		sim.state.ship_pos = Vector2(wave.center) + Vector2.from_angle(float(wave.angle)) * (float(wave.radius) + float(wave.speed) * DT)
		actor.previous_ship = sim.state.ship_pos
		sim.state.ship_invuln = 0.0
		var wave_hp := sim.state.ship_hp
		step(DT)
		check(sim.state.ship_hp < wave_hp and wave.hit, "角の衝撃波の帯に入ると被弾する")
		var wave_hurt_hp := sim.state.ship_hp
		for frame in 10:
			sim.state.ship_invuln = 0.0
			sim.state.ship_pos = Vector2(wave.center) + Vector2.from_angle(float(wave.angle)) * (float(wave.radius) + float(wave.speed) * DT)
			step(DT)
		check(sim.state.ship_hp == wave_hurt_hp, "同じ衝撃波の帯では重複被弾しない")
		step(2.0)
		check(actor.horn_waves.is_empty(), "角の衝撃波は上限の半径で消える")

	fresh()
	actor.phase = 2
	actor._apply_phase()
	sim.state.ship_pos = Vector2(400, 0)
	sim.state.enemy_aim = sim.state.ship_pos
	var slash_trace := {"releases": 0, "hits": {}}
	actor.presentation_event.connect(func(e):
		if e.cue == &"slash_release": slash_trace.releases += 1)
	var record_slash := func(_e):
		var cut := int(slash_trace.releases)
		slash_trace.hits[cut] = int(slash_trace.hits.get(cut, 0)) + 1
	sim.ship.hurt_recorded.connect(record_slash)
	actor.start_attack(&"sword_flash")
	for frame in 1200:
		sim.state.ship_invuln = 0.0
		step(DT)
		if actor.mode == &"recovery": break
	sim.ship.hurt_recorded.disconnect(record_slash)
	check(slash_trace.releases == int(actor.rule().get("cuts", 0)) and slash_trace.releases > 0, "光の剣は指定した回数の斬撃を放つ")
	check(slash_trace.hits.size() == slash_trace.releases and slash_trace.hits.values().all(func(n): return int(n) == 1), "光の剣は静止自機へ各斬撃で1回だけ当たる")
	check(actor.mode == &"recovery", "光の剣は連撃を終えて隙に入る")

	fresh()
	actor.phase = 2
	actor._apply_phase()
	sim.state.ship_pos = Vector2(600, 0)
	sim.state.enemy_aim = sim.state.ship_pos
	var dance_trace := {"launches": 0, "ended": false, "left": true}
	actor.presentation_event.connect(func(e):
		if e.cue == &"attack_started": dance_trace.launches += 1
		if e.cue == &"dance_end": dance_trace.ended = true)
	actor.start_attack(&"horn_dance")
	for frame in 2400:
		var was_circle: bool = actor._runner != null and actor._runner.get("stage") == &"circle"
		var facing := actor.table.facing[actor.body]
		step(DT)
		if was_circle and actor._runner.get("stage") == &"circle":
			dance_trace.left = bool(dance_trace.left) and actor.table.facing[actor.body] < facing
		if actor.mode == &"recovery": break
	check(dance_trace.launches == int(actor.rule().get("passes", 0)) and dance_trace.launches > 0, "光角の乱舞は指定した回数突進する")
	check(dance_trace.left, "光角の乱舞は旋回中に左へ回り続ける")
	check(dance_trace.ended and actor.mode == &"recovery", "光角の乱舞は角を掲げて隙に入る")

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
	sim.state.ship_vel = Vector2.ZERO
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
	var stage_names := [&"charge",&"sweep",&"kick",&"return_charge",&"lance",&"horn_wave",&"sword_flash",&"horn_dance"]
	for tech in stage_names:
		fresh()
		actor.phase = 2 if tech in [&"lance", &"sword_flash", &"horn_dance"] else 1
		actor._apply_phase()
		sim.state.ship_pos = Vector2(-180,0) if tech == &"kick" else Vector2(400,0) if tech in [&"sweep", &"sword_flash"] else Vector2(600,0)
		sim.state.enemy_aim = sim.state.ship_pos
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

## B00で確認済みの時刻・掃引・取消・復帰は繰り返さず、本体と技の残る接続を確認する。
func charge_fixture(flow_enabled := false, obstacle := false, planet_x := 450.0, moon := false) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	if planet_x==500.0 or moon: cfg.character_scale = 1.0
	var definition = load("res://data/bosses/monoceros.tres").duplicate(true)
	definition.params.initial_wait = 0.0
	definition.params.approach_speed = 0.0
	definition.params.stuck_time = 0.05
	definition.params.extract_time = 0.05
	var package: Dictionary = builder.boss_body_package(definition,cfg)
	var move = load("res://data/bosses/monoceros_moves/charge.tres").duplicate(true)
	move.warn = 0.25
	move.active = 0.2
	move.active_p2 = 0.2
	move.recover = 0.05
	move.cd = 0.0
	move.distance = 600.0
	var records: Dictionary = package.records
	for key in builder.boss_technique_records(definition,move): records[key] = builder.boss_technique_records(definition,move)[key]
	if flow_enabled:
		var rules = load("res://data/bosses/ai/monoceros_action_rules.tres").duplicate(true)
		rules.techniques.assign([move])
		rules.combos = {}
		rules.conditions = {"charge":{"min":0.0,"max":1000.0}}
		rules.selection_bias = {}
		rules.costs = {"charge":1.0}
		rules.condition_groups = {}
		rules.graph_nodes = {}
		var program = load("res://scripts/data_types/boss_flow_def.gd").new()
		program.maximum_stamina = 10.0
		program.sections = [{"request":"normal","weights":{"single":1.0},"cap":1.0,"action_count":1,"next":0}]
		var flows: Dictionary = builder.boss_flow_records(rules,program,records.BossTechniqueDefinition)
		for key in flows: records[key] = flows[key]
	if obstacle:
		var key: int = records.ResourceKey.size()+1
		records.ResourceKey.append({"id":key,"role":9})
		records.FieldBodyDefinition = [{"id":1,"kind":0,"x":planet_x,"y":0.0,"radius":100.0,"visual":key}]
	if moon:
		var key: int = records.ResourceKey.size()+1
		records.ResourceKey.append({"id":key,"role":10})
		records.MoonDefinition = [{"id":1,"count":1,"orbit_min":500.0,"orbit_max":500.0,"angle_jitter":0.0,"radius_min":100.0,"radius_max":100.0,"angular_speed":0.0,"visual":key}]
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var config: Dictionary = bridge.configure(builder.Schema.write_content(records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":154,"mode":1,"stage_id":"B_monoceros_charge","profile":{},"settings":{"hitstop":false}})
	if not config.ok: return {}
	bridge.start(154,{"position":Vector2(300,0)})
	bridge.subscribe("確認",func(_packet): return true)
	bridge.command("dev_ship_motion",{"position":Vector2(300,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(300,0),Vector2(300,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	return {"bridge":bridge,"id":id,"move":move,"definition":definition}

func native_charge() -> void:
	var fixture := charge_fixture(true)
	check(not fixture.is_empty(),"分離した編集Resourceを型付きの本体・フロー・突進へ生成する")
	if fixture.is_empty():
		get_tree().quit(1)
		return
	var bridge = fixture.bridge
	bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value.size()==1 and bridge.command("dev_boss_state").value[0].stage==0,"本体の通常フローが突進の予告を選ぶ")
	bridge._core.step(0.25)
	var attack: Dictionary = bridge.command("dev_boss_state").value[0]
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var view = load("res://scenes/bosses/monoceros_presentation.tscn").instantiate()
	view.set_script(load("res://scripts/render/bosses/monoceros.gd"))
	add_child(view)
	view.apply_frame(body,attack)
	check(view.horn.self_modulate.r>1.0 and attack.technique=="charge","本体から選んだ突進の実行中に角を共通色で発光させる")
	bridge._core.step(0.2)
	bridge._core.step(0.05)
	bridge._core.step(0.01)
	bridge.command("dev_ship_motion",{"position":Vector2(1000,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(1000,0),Vector2(1000,0),Vector2(640,360))
	bridge._core.step(0.2)
	check(bridge.command("dev_boss_state").value[0].id>attack.id and bridge.command("dev_boss_state").value[0].stage==0,"自然終了後は次の通常行動の突進を選ぶ")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"選択から次行動までの通知を登録済み契約で配信する")
	bridge.dispose()
	view.queue_free()
	fixture = charge_fixture(false,true)
	bridge = fixture.bridge
	bridge.command("dev_boss_technique",{"entity_id":fixture.id,"definition":1})
	bridge._core.step(0.25)
	attack = bridge.command("dev_boss_state").value[0]
	check(attack.stage==6 and attack.reposition>0.0 and not bridge.command("dev_boss_technique",{"entity_id":fixture.id,"definition":1}).ok,"地形が発進経路を塞いだ後は位置替え中の再発進を拒否する")
	bridge._core.step(0.1)
	body = bridge.command("dev_boss_body_state").value[0]
	check(body.position.y!=0.0 and bridge.read_frame().ok,"失敗した突進から本体の横への位置替えへ進む")
	bridge.dispose()
	fixture = charge_fixture()
	bridge = fixture.bridge
	var ticket: Dictionary = bridge.command("dev_boss_technique",{"entity_id":fixture.id,"definition":1})
	bridge.command("dev_kill",{"entity_id":fixture.id,"cause":"debug"})
	bridge._core.step(0.01)
	check(ticket.ok and bridge.command("dev_boss_state").value[0].stage==7 and not bridge.command("dev_boss_body_state").value[0].participants[0].active and bridge.read_frame().ok,"本体参加者が消失した突進は取消で閉じ形状を残さない")
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_monoceros_charge] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 未実施の地形による技の終了だけを、同じ既存検査から確認する。
func native_charge_terrain() -> void:
	var fixture := charge_fixture(false,true,500.0)
	var bridge = fixture.bridge
	bridge.command("dev_boss_technique",{"entity_id":fixture.id,"definition":1})
	bridge._core.step(0.25)
	bridge._core.step(0.2)
	var state: Dictionary = bridge.command("dev_boss_state").value[0]
	check(state.stage==3 and state.position.x>0.0 and state.position.x<304.0,"発進後に惑星へ角が先に触れると刺さりで停止する")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.05)
	state = bridge.command("dev_boss_state").value[0]
	check(state.stage==4,"刺さり時間が終わると引き抜きへ進む")
	bridge._core.step(0.05)
	state = bridge.command("dev_boss_state").value[0]
	check(state.stage==5 and bridge.read_frame().ok,"引き抜きが自然終了し角の形状を閉じる")
	check(held.ok and bridge.restore(held.value).ok and bridge.command("dev_boss_state").value[0].stage==3,"刺さった地形と相対位置を途中復帰で保つ")
	bridge.release_checkpoint(held.value)
	bridge.dispose()
	fixture = charge_fixture(false,false,450.0,true)
	bridge = fixture.bridge
	bridge.command("dev_boss_technique",{"entity_id":fixture.id,"definition":1})
	bridge._core.step(0.25)
	bridge._core.step(0.2)
	state = bridge.command("dev_boss_state").value[0]
	check(state.stage==2 and is_equal_approx(state.position.x,304.0) and bridge.read_frame().ok,"月には角が刺さらず本体の接触で回復へ移る")
	bridge.dispose()
	get_tree().quit(1 if failed else 0)
	print("[cpp_monoceros_charge_terrain] failures=",failed)
