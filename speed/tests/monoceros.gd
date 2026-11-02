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
	if "--cpp-sword" in OS.get_cmdline_user_args():
		call_deferred("native_sword")
		return
	if "--cpp-dance" in OS.get_cmdline_user_args():
		call_deferred("native_dance")
		return
	if "--cpp-wave" in OS.get_cmdline_user_args():
		call_deferred("native_wave")
		return
	if "--cpp-return" in OS.get_cmdline_user_args():
		call_deferred("native_return")
		return
	if "--cpp-combo-tail" in OS.get_cmdline_user_args() or "--cpp-combo-cancel" in OS.get_cmdline_user_args():
		call_deferred("native_combo_tail")
		return
	if "--cpp-combo" in OS.get_cmdline_user_args() or "--cpp-combo-retry" in OS.get_cmdline_user_args():
		call_deferred("native_combo")
		return
	if "--cpp-lance" in OS.get_cmdline_user_args() or "--cpp-lance-retry" in OS.get_cmdline_user_args():
		call_deferred("native_lance")
		return
	if "--cpp-sweep" in OS.get_cmdline_user_args():
		call_deferred("native_sweep")
		return
	if "--cpp-kick-retry" in OS.get_cmdline_user_args():
		call_deferred("native_kick_retry")
		return
	if "--cpp-kick" in OS.get_cmdline_user_args():
		call_deferred("native_kick")
		return
	if "--cpp-data-legacy" in OS.get_cmdline_user_args() or "--cpp-data-legacy-retry" in OS.get_cmdline_user_args():
		call_deferred("native_data_legacy")
		return
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
func charge_fixture(flow_enabled := false, obstacle := false, planet_x := 450.0, moon := false, name := "charge", dance_timeout := false) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	if planet_x==500.0 or moon or name in ["kick","sweep","lance","return_charge","horn_wave","horn_dance","sword_flash"]: cfg.character_scale = 1.0
	var definition = load("res://data/bosses/monoceros.tres").duplicate(true)
	definition.params.initial_wait = 0.0
	definition.params.approach_speed = 0.0
	definition.params.stuck_time = 0.05
	definition.params.extract_time = 0.05
	var package: Dictionary = builder.boss_body_package(definition,cfg)
	var move = load("res://data/bosses/monoceros_moves/%s.tres"%name).duplicate(true)
	if move.has_field("warn"): move.warn = 0.25
	if move.has_field("active"): move.active = 0.2
	if move.has_field("active_p2"): move.active_p2 = 0.2
	move.recover = 0.05
	move.cd = 0.0
	if move.has_field("distance"): move.distance = 600.0
	if name=="kick":
		move.reach = 240.0
		move.hold = 0.1
		move.return_speed = TAU
	if name=="sword_flash":
		move.cuts = 2
		move.first_windup = 0.1
		move.windup = 0.05
		move.lock_time = 0.05
		move.pull = 0.6
		move.swing_time = 0.1
		move.lunge_speed = 100.0
		move.lunge_decay = 10.0
		move.slash_min = 80.0
		move.slash_max = 200.0
		move.slash_length = 200.0
		move.slash_angle = PI*0.5
		move.slash_width = 20.0
		move.slash_hit_time = 0.05
		move.cut_gap = 0.05
		move.return_time = 0.1
	if name=="horn_dance":
		move.aim_time = 0.1
		move.aim_lock = 0.05
		move.passes = 2
		move.speed = 1000.0
		move.min_run = 200.0
		move.overshoot = 50.0
		move.circle_turn = 2.0
		move.circle_speed = 400.0
		move.circle_late_time = 0.1
		move.circle_speed_late = 200.0
		move.circle_decel = 2000.0
		move.circle_accel = 1000.0
		move.align_angle = PI
		move.align_min_distance = 100000.0 if dance_timeout else 0.0
		move.align_min_time = 0.05
		move.circle_max_time = 0.2
		move.head_lead = 0.4
		move.end_time = 0.1
		move.end_decay = 10.0
	if name=="horn_wave":
		move.windup = 0.1
		move.swing_time = 0.1
		move.recharge = 0.1
		move.return_time = 0.1
		move.pull = 0.8
		move.release_offset = 0.0
		move.wave_start = 50.0
		move.wave_speed = 100.0
		move.wave_max = 300.0
		move.wave_half_angle = 0.2
		move.wave_width = 20.0
	if name=="return_charge":
		move.warn = 0.2
		move.distance = 600.0 if planet_x==500.0 else 200.0
		move.passes = 2
		move.passes_p2 = 3
		move.overshoot = 50.0
		move.brake_time = 0.1
		move.brake_speed_ratio = 0.5
		move.turn_time = 0.2
		move.turn_lock = 0.1
		move.head_lead = 0.4
	if name=="lance":
		move.warn = 0.2
		move.lock_time = 0.05
		move.aim_turn = 2.0
		move.back_speed = 40.0
		move.speed = 1000.0
		move.distance = 600.0 if planet_x==500.0 else 200.0
		move.stop_time = 0.2
		move.stop_decay = 9.0
		move.shatter_time = 0.1
		move.boom_interval = 0.025
	if name=="sweep":
		move.active = 0.1
		move.approach_speed_start = 100.0
		move.approach_accel = 1000.0
		move.approach_speed_max = 200.0
		move.approach_turn = 1.0
		move.approach_min = 0.1
		move.approach_max = 0.3
		move.stop_range = 300.0
		move.twist_time = 0.2
		move.twist = 0.6
		move.stop_time = 0.2
		move.stop_decel = 1000.0
		move.windup_twist = 0.8
		move.arc = 1.6
		move.hold = 0.1
		move.return_time = 0.2
	var records: Dictionary = package.records
	for key in builder.boss_technique_records(definition,move): records[key] = builder.boss_technique_records(definition,move)[key]
	if flow_enabled:
		var rules = load("res://data/bosses/ai/monoceros_action_rules.tres").duplicate(true)
		rules.techniques.assign([move])
		rules.combos = {}
		rules.conditions = {}
		rules.conditions[name] = {"min":0.0,"max":1000.0} if name!="kick" else {"min":0.0,"max":260.0,"angle":180.0,"half_angle":37.24225668350351}
		rules.selection_bias = {}
		rules.costs = {}
		rules.costs[name] = 1.0
		rules.condition_groups = {}
		rules.graph_nodes = {}
		var program = load("res://scripts/data_types/boss_flow_def.gd").new()
		program.maximum_stamina = 10.0
		program.sections = [{"request":"major" if name in ["lance","horn_dance"] else "normal","weights":({"major":1.0} if name in ["lance","horn_dance"] else {"combo":1.0} if name=="return_charge" else {"single":1.0}),"cap":1.0,"action_count":1,"next":0}]
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
	var captured: Array = []
	bridge.subscribe("確認",func(packet): captured.append_array(packet.events); return true)
	bridge.command("dev_ship_motion",{"position":Vector2(300,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(300,0),Vector2(300,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	return {"bridge":bridge,"id":id,"move":move,"definition":definition,"records":records,"events":captured}

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

## PureDataを旧生成・通常のActorへ渡す、残っていた互換条件だけ確認する。
func native_data_legacy() -> void:
	var compiler = load("res://tools/content/build_boss_program.gd")
	var result: Dictionary = {"error":OK,"program":load("res://.content/tests/monoceros_pure_data.tres")} if "--cpp-data-legacy-retry" in OS.get_cmdline_user_args() else compiler.build_boss("monoceros","res://.content/tests/monoceros_pure_data.tres")
	if "--cpp-data-legacy-retry" not in OS.get_cmdline_user_args(): check(result.error==OK,"分離した編集値から通常のボス生成を完了する")
	if result.error!=OK:
		get_tree().quit(1)
		return
	var owner := MonocerosBoss.new()
	owner.def = load("res://data/bosses/monoceros.tres")
	var ctx := RunContext.new()
	ctx.state = RunState.new()
	owner.ctx = ctx
	owner.configure_flow(result.program)
	var move: BossTechnique = result.program.data.rules.techniques.filter(func(value): return value.technique==&"charge")[0]
	var runner = preload("res://scripts/bosses/legacy_technique_runners.gd").make(move)
	check(move.make_runner()==null and owner._move_kinds[&"charge"]==&"charge" and runner.kind()==&"charge","Resourceに実行コードを戻さず通常Actorの設定と実行Runnerを解決する")
	owner.free()
	print("[cpp_monoceros_data_legacy] failures=",failed)
	get_tree().quit(1 if failed else 0)

func kick_fixture(automatic := false, front := false) -> Dictionary:
	var f := charge_fixture(automatic,false,450.0,false,"kick")
	var bridge = f.bridge
	var target := Vector2(180,0) if front else Vector2(-180,0)
	bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(target,target,Vector2(640,360))
	bridge._core.set_enemy_motion(f.id,{"facing":0.0})
	return f

func native_kick() -> void:
	var fixture := kick_fixture(true)
	var bridge = fixture.bridge
	var definition: Dictionary = fixture.records.BossTechniqueDefinition[0]
	check(definition.kind==1 and definition.reach==240.0 and definition.hold==0.1 and definition.return_speed==TAU,"後ろ蹴りのResource実効値を型付き定義へ生成する")
	check(fixture.records.BossTechniqueStage[0].at==0.03 and fixture.records.BossTechniqueStage[1].at==0.25 and fixture.records.BossTechniqueStage[2].at==0.45,"後ろ蹴りの予告・固定・発進・終了を編集値から生成する")
	bridge._core.step(0.01)
	var state: Dictionary = bridge.command("dev_boss_state").value[0]
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(state.stage==0 and body.facing==0.0 and state.direction.is_equal_approx(Vector2.LEFT),"背後で技を自然選択し本体の向きを変えず狙う")
	var view = load("res://scenes/bosses/monoceros_presentation.tscn").instantiate()
	view.set_script(load("res://scripts/render/bosses/monoceros.gd"))
	add_child(view)
	view.apply_frame(body,state)
	bridge._core.step(0.1)
	state = bridge.command("dev_boss_state").value[0]
	body = bridge.command("dev_boss_body_state").value[0]
	view.apply_frame(body,state)
	var leg: Node2D = view.parts.get_node("RearLeftLeg")
	check(state.locked and leg.rotation!=0.0 and leg.get_node("Foot").position.y<view._leg_rest["RearLeftLeg"],"予告中は向きを固定し後脚を畳む表示へ接続する")
	bridge._core.step(0.15)
	state = bridge.command("dev_boss_state").value[0]
	check(state.stage==1 and state.position==Vector2.ZERO and state.horn[1].is_equal_approx(Vector2(-240,0)),"発進しても移動せず蹄の到達距離の線分を使う")
	bridge._core.step(0.1)
	state = bridge.command("dev_boss_state").value[0]
	body = bridge.command("dev_boss_body_state").value[0]
	view.apply_frame(body,state)
	var hp: float = bridge._core.ship_snapshot().ship_hp
	check(state.hit and leg.scale.y>1.0 and view.horn.self_modulate.r==1.0,"後方線分で一回命中し脚を伸ばして角は発光させない")
	var events: Array = fixture.events
	check(events.any(func(event): return event.type==&"combat_player_damage" and event.payload.cause==&"horn" and event.payload.source==&"monoceros" and event.payload.technique==&"kick"),"後ろ蹴りの原因・出所・技IDを記録へ渡す")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.05)
	check(bridge._core.ship_snapshot().ship_hp==hp,"同じ蹴りの重複被弾を防ぐ")
	check(held.ok and bridge.restore(held.value).ok and bridge.command("dev_boss_state").value[0].hit,"実行途中の固定方向と命中済み状態を復帰する")
	bridge.release_checkpoint(held.value)
	bridge._core.step(0.1)
	state = bridge.command("dev_boss_state").value[0]
	check(state.stage==2 and is_equal_approx(state.remaining,0.65),"終了時に停止・PI/戻り速度・回復を合計して待つ")
	bridge._core.step(0.1)
	state = bridge.command("dev_boss_state").value[0]
	check(is_zero_approx(state.settle_progress),"攻撃後の停止中は後脚の姿勢を保持する")
	bridge._core.step(0.25)
	state = bridge.command("dev_boss_state").value[0]
	body = bridge.command("dev_boss_body_state").value[0]
	view.apply_frame(body,state)
	var restored = load("res://scenes/bosses/monoceros_presentation.tscn").instantiate()
	restored.set_script(load("res://scripts/render/bosses/monoceros.gd"))
	add_child(restored)
	restored.apply_frame(body,state)
	check(is_equal_approx(state.settle_progress,0.5) and is_equal_approx(restored.parts.get_node("RearLeftLeg").rotation,leg.rotation),"姿勢戻しの途中から表示を作っても同じ後脚へ復帰する")
	var angle := leg.rotation
	view.apply_frame(body,state)
	check(leg.rotation==angle,"世界停止中は後脚の戻しを進めない")
	bridge._core.step(0.31)
	bridge._core.step(0.01)
	bridge._core.step(0.2)
	check(bridge.command("dev_boss_state").value[0].id>state.id,"姿勢戻しと回復が終わったら次の蹴りを自然選択する")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"後ろ蹴りの通知を共通配信へ渡す")
	bridge.dispose()
	view.queue_free()
	restored.queue_free()
	fixture = kick_fixture(false,true)
	bridge = fixture.bridge
	bridge.command("dev_boss_technique",{"entity_id":fixture.id,"definition":1})
	bridge._core.step(0.25)
	check(bridge.command("dev_boss_state").value[0].stage==2,"発進時の後方角度から外れた強制蹴りは回復へ戻す")
	bridge.dispose()
	for disappear in [false,true]:
		fixture = kick_fixture()
		bridge = fixture.bridge
		var ticket: Dictionary = bridge.command("dev_boss_technique",{"entity_id":fixture.id,"definition":1})
		bridge._core.step(0.1)
		if disappear: bridge.command("dev_kill",{"entity_id":fixture.id,"cause":"debug"})
		else: bridge.command("dev_cancel_technique",{"ticket":ticket.value})
		bridge._core.step(0.2)
		state = bridge.command("dev_boss_state").value[0]
		check(state.stage==7 and not state.hit and bridge.read_frame().ok,"参加者消失で蹄を取消する" if disappear else "予告取消後に蹄の段階と当たりを残さない")
		bridge.dispose()
	await get_tree().process_frame
	print("[cpp_monoceros_kick] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 配信先で受け取った記録と、固定更新の次行動境界の失敗条件だけ確認し直す。
func native_kick_retry() -> void:
	var fixture := kick_fixture(true)
	var bridge = fixture.bridge
	bridge._core.step(0.01)
	bridge._core.step(0.25)
	bridge._core.step(0.1)
	var state: Dictionary = bridge.command("dev_boss_state").value[0]
	check(fixture.events.any(func(event): return event.type==&"combat_player_damage" and event.payload.cause==&"horn" and event.payload.source==&"monoceros" and event.payload.technique==&"kick"),"後ろ蹴りの原因・出所・技IDを記録へ渡す")
	bridge._core.step(0.1)
	bridge._core.step(0.66)
	bridge._core.step(0.01)
	bridge._core.step(0.2)
	var next: Dictionary = bridge.command("dev_boss_state").value[0]
	check(next.id>state.id and next.stage==0,"姿勢戻しと回復が終わったら次の蹴りを自然選択する")
	bridge.dispose()
	print("[cpp_monoceros_kick_retry] failures=",failed)
	get_tree().quit(1 if failed else 0)

func sweep_fixture(automatic := false) -> Dictionary:
	var f := charge_fixture(automatic,false,450.0,false,"sweep")
	f.bridge.command("dev_ship_motion",{"position":Vector2(150,0),"velocity":Vector2.ZERO})
	f.bridge._core.set_motion_context(Vector2(150,0),Vector2(150,0),Vector2(640,360))
	return f

func native_sweep() -> void:
	var fixture := sweep_fixture(true)
	var bridge = fixture.bridge
	var definition: Dictionary = fixture.records.BossTechniqueDefinition[0]
	check(definition.kind==2 and definition.approach_accel==1000.0 and definition.arc==1.6 and fixture.records.BossTechniqueStage.is_empty(),"薙ぎの固有値を生成し戦闘method trackを使わない")
	var legacy = preload("res://scripts/bosses/legacy_technique_runners.gd").definition(fixture.move)
	check(is_equal_approx(legacy.attack_length(),0.9) and is_equal_approx(legacy.reach_limit(177.6),232.6) and fixture.move.make_runner()==null,"PureDataを保ち旧入口の攻撃長と加速積分の到達距離を解決する")
	bridge._core.step(0.01)
	var state: Dictionary = bridge.command("dev_boss_state").value[0]
	check(state.stage==0 and state.sequence_stage==0 and state.side==1,"本体フローから最初の方向の踏み込みを自然選択する")
	bridge._core.step(0.1)
	state = bridge.command("dev_boss_state").value[0]
	check(state.sequence_stage==0 and state.speed==200.0 and state.position.is_equal_approx(Vector2(20,0)),"踏み込みは加速上限で進み最短時間と同値では止まらない")
	bridge._core.step(0.01)
	state = bridge.command("dev_boss_state").value[0]
	check(state.sequence_stage==1 and state.locked and state.sequence_elapsed==0.0,"距離と最短時間を満たしたtickで停止へ進み方向を固定する")
	bridge._core.step(0.1)
	state = bridge.command("dev_boss_state").value[0]
	check(state.speed==100.0 and state.position.is_equal_approx(Vector2(32,0)) and is_equal_approx(state.angle,-0.75) and state.booster==0.3,"停止中は線形減速と首の溜めを同じ時計で進める")
	bridge._core.step(0.1)
	state = bridge.command("dev_boss_state").value[0]
	check(state.stage==1 and state.sequence_stage==2 and state.sequence_elapsed==0.0 and state.position.is_equal_approx(Vector2(32,0)),"停止時刻で振り抜きへ入り同じtickでは振らない")
	bridge._core.step(0.1)
	state = bridge.command("dev_boss_state").value[0]
	check(state.hit and state.sequence_stage==3 and is_equal_approx(state.angle,0.8),"0.008秒ごとの回転掃引で角の通過を一回命中させ保持へ進む")
	check(fixture.events.any(func(event): return event.type==&"combat_player_damage" and event.payload.technique==&"sweep" and event.payload.cause==&"horn" and event.payload.source==&"monoceros"),"回転掃引の原因と出所・技IDを配信先へ渡す")
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.1)
	state = bridge.command("dev_boss_state").value[0]
	check(state.sequence_stage==4 and state.angle==0.8 and bridge._core.ship_snapshot().ship_hp==hp,"振り切った姿勢を保持し追加の被弾を起こさず戻しへ進む")
	bridge._core.step(0.1)
	state = bridge.command("dev_boss_state").value[0]
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var view = load("res://scenes/bosses/monoceros_presentation.tscn").instantiate()
	view.set_script(load("res://scripts/render/bosses/monoceros.gd"))
	add_child(view)
	view.apply_frame(body,state)
	check(is_equal_approx(state.angle,0.4) and is_equal_approx(view.parts.get_node("Head").rotation,0.4) and view.horn.self_modulate.r>1.0,"途中から作った本体表示も薙ぎの首の角度と金色の発光へ合わせる")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.11)
	var expected: Dictionary = bridge.command("dev_boss_state").value[0]
	check(expected.stage==2 and is_equal_approx(expected.remaining,0.05),"戻しが終わったら回復へ進む")
	check(held.ok and bridge.restore(held.value).ok,"戻し途中の段階・角度・左右と命中済み状態を保持復帰する")
	bridge._core.step(0.11)
	check(bridge.command("dev_boss_state").value[0]==expected,"途中復帰後も同じ戻し終了の状態へ進む")
	bridge.release_checkpoint(held.value)
	bridge._core.step(0.051)
	bridge._core.step(0.01)
	bridge._core.step(0.2)
	state = bridge.command("dev_boss_state").value[0]
	check(state.id>expected.id and state.side==-1 and state.sequence_stage==0,"自然終了後の次の薙ぎは逆向きから踏み込む")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"薙ぎの段階と命中の通知を共通配信へ渡す")
	bridge.dispose()
	view.queue_free()
	for disappear in [false,true]:
		fixture = sweep_fixture()
		bridge = fixture.bridge
		var ticket: Dictionary = bridge.command("dev_boss_technique",{"entity_id":fixture.id,"definition":1})
		bridge._core.step(0.11)
		bridge._core.step(0.2)
		if disappear: bridge.command("dev_kill",{"entity_id":fixture.id,"cause":"debug"})
		else: bridge.command("dev_cancel_technique",{"ticket":ticket.value})
		bridge._core.step(0.2)
		state = bridge.command("dev_boss_state").value[0]
		check(state.stage==7 and not state.hit and bridge.read_frame().ok,"本体消失で回転掃引を閉じる" if disappear else "振り抜きの取消後は掃引の命中を残さない")
		bridge.dispose()
	var compiler = load("res://tools/content/build_boss_program.gd")
	var program: Dictionary = compiler.build_boss("monoceros","res://.content/tests/monoceros_sweep_pure_data.tres")
	check(program.error==OK,"薙ぎのPureDataを含む既存の通常生成を完了する")
	if program.error==OK:
		var owner := MonocerosBoss.new()
		owner.def = load("res://data/bosses/monoceros.tres")
		owner.ctx = RunContext.new()
		owner.ctx.state = RunState.new()
		owner.configure_flow(program.program)
		check(owner._move_kinds[&"sweep"]==&"sweep" and owner._attack_length(&"sweep")>0.0,"通常Actorの設定と攻撃長も分離した薙ぎへ接続する")
		owner.free()
	await get_tree().process_frame
	print("[cpp_monoceros_sweep] failures=",failed)
	get_tree().quit(1 if failed else 0)

func native_lance() -> void:
	var fixture := charge_fixture(true,false,450.0,false,"lance")
	if "--cpp-lance-retry" not in OS.get_cmdline_user_args(): check(not fixture.is_empty(),"光の槍の生成と読込を完了する")
	if fixture.is_empty(): get_tree().quit(1); return
	var bridge = fixture.bridge
	var definition: Dictionary = fixture.records.BossTechniqueDefinition[0]
	if "--cpp-lance-retry" not in OS.get_cmdline_user_args(): check(definition.kind==3 and definition.active==0.2 and definition.width==48.0 and definition.head_length==60.0 and fixture.records.BossTechniqueStage.is_empty(),"光の槍の実効値と段階時計を生成しmethod trackを残さない")
	var legacy = preload("res://scripts/bosses/legacy_technique_runners.gd").definition(fixture.move)
	if "--cpp-lance-retry" not in OS.get_cmdline_user_args(): check(fixture.move.make_runner()==null and is_equal_approx(legacy.attack_length(),0.6) and legacy.reach_limit(100.0)==360.0,"光の槍をPureDataへ分離し通常入口のRunnerと到達距離を保つ")
	bridge.command("dev_ship_motion",{"position":Vector2(150,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(150,0),Vector2(150,0),Vector2(640,360))
	bridge._core.step(0.01)
	var state: Dictionary = bridge.command("dev_boss_state").value[0]
	check(state.sequence_stage==0 and state.stage==0,"本体フローで光の槍を自然選択する")
	bridge._core.step(0.1)
	state = bridge.command("dev_boss_state").value[0]
	check(state.position.is_equal_approx(Vector2(-4,0)) and is_equal_approx(state.form,0.75) and not state.locked,"溜め中は後退し二次補間で槍の長さと光を形成する")
	var visual = load("res://scripts/bosses/monoceros/lance_visual.gd").new()
	add_child(visual)
	visual.apply_frame([state],0.1)
	visual.apply_frame([state],0.15)
	check(not visual.particles.is_empty(),"途中の表示からも光を集める粒を再構成する")
	bridge._core.step(0.05)
	state = bridge.command("dev_boss_state").value[0]
	var facing: float = state.facing
	check(state.locked,"発進のlock_time秒前に向きを固定する")
	bridge._core.step(0.05)
	state = bridge.command("dev_boss_state").value[0]
	check(state.stage==1 and state.sequence_stage==1 and state.facing==facing and state.form==1.0,"溜め時刻で発進し同じtickでは走らない")
	var events: Array = fixture.events
	check(events.any(func(e): return e.type==&"lance_launch"),"発進の光を登録済み通知で配信する")
	bridge._core.step(0.1)
	state = bridge.command("dev_boss_state").value[0]
	check(state.hit and is_equal_approx(state.traveled,100.0) and is_equal_approx(state.horn[1].x-state.position.x,237.6),"槍先を含む線分と固有の太さで一回命中する")
	check(events.any(func(e): return e.type==&"combat_player_damage" and e.payload.cause==&"horn" and e.payload.source==&"monoceros" and e.payload.technique==&"lance") and events.filter(func(e): return e.type==&"sonic_boom").size()==4,"命中の原因と技を記録し一tick内のブームを全て配信する")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.1)
	var expected: Dictionary = bridge.command("dev_boss_state").value[0]
	check(expected.sequence_stage==2 and expected.traveled==200.0,"所定距離を越えず停止段階へ移る")
	check(held.ok and bridge.restore(held.value).ok,"槍の形成度・走行距離・ブーム余りを途中復帰する")
	bridge._core.step(0.1)
	check(bridge.command("dev_boss_state").value[0]==expected,"復帰後も同じ停止段階と槍の形へ進む")
	bridge.release_checkpoint(held.value)
	var hp: float = bridge._core.ship_snapshot().ship_hp
	bridge._core.step(0.1)
	state = bridge.command("dev_boss_state").value[0]
	check(state.sequence_stage==2 and is_equal_approx(state.speed,1000.0*exp(-0.9)) and state.form==0.0 and state.glow==0.0 and bridge._core.ship_snapshot().ship_hp==hp,"停止中は指数減速し光を砕いて当たりを追加しない")
	check(fixture.events.any(func(e): return e.type==&"lance_shatter" and e.payload.horn[1].x>e.payload.horn[0].x),"砕ける前の槍先を通知に保つ")
	bridge._core.step(0.1)
	check(bridge.command("dev_boss_state").value[0].stage==2,"停止時間が終わったら回復へ進む")
	bridge._core.step(0.051)
	bridge._core.step(0.01)
	bridge._core.step(0.2)
	check(bridge.command("dev_boss_state").value[0].id>state.id,"自然終了後に次の行動を選択する")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"光の槍の通知を共通配信へ渡す")
	bridge.dispose()
	visual.queue_free()
	for disappear in [false,true]:
		fixture = charge_fixture(false,false,450.0,false,"lance")
		bridge = fixture.bridge
		var ticket: Dictionary = bridge.command("dev_boss_technique",{"entity_id":fixture.id,"definition":1})
		bridge._core.step(0.2)
		if disappear: bridge.command("dev_kill",{"entity_id":fixture.id,"cause":"debug"})
		else: bridge.command("dev_cancel_technique",{"ticket":ticket.value})
		bridge._core.step(0.2)
		state = bridge.command("dev_boss_state").value[0]
		check(state.stage==7 and not state.hit and bridge.read_frame().ok,"本体消失で槍を閉じる" if disappear else "取消後に槍の当たりを残さない")
		bridge.dispose()
	fixture = charge_fixture(false,true,500.0,false,"lance")
	bridge = fixture.bridge
	bridge.command("dev_boss_technique",{"entity_id":fixture.id,"definition":1})
	bridge._core.step(0.2)
	bridge._core.step(0.4)
	state = bridge.command("dev_boss_state").value[0]
	check(state.sequence_stage==2 and state.stage==1,"光の槍の走行は惑星で刺さらず停止へ進む")
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_monoceros_lance] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 連撃専用の旧Runnerは存在せず、編集側のsequenceを共通フローで進める。
func combo_fixture() -> Dictionary:
	var f := charge_fixture()
	f.bridge.dispose()
	var builder = load("res://tools/content/build_run_content.gd")
	var sweep = load("res://data/bosses/monoceros_moves/sweep.tres").duplicate(true)
	sweep.approach_speed_start = 0.0
	sweep.approach_speed_max = 0.0
	sweep.approach_min = 0.0
	sweep.approach_max = 0.01
	sweep.stop_time = 0.01
	sweep.active = 0.01
	sweep.hold = 0.01
	sweep.return_time = 0.01
	sweep.recover = 0.01
	sweep.cd = 0.0
	f.move.distance = 1.0
	f.move.warn = 0.02
	f.move.active = 0.02
	f.move.recover = 0.02
	var records: Dictionary = f.records
	var techniques: Dictionary = builder.boss_technique_set_records(f.definition,[f.move,sweep])
	for key in techniques: records[key] = techniques[key]
	var rules = load("res://scripts/data_types/boss_action_rules.gd").new()
	rules.adapter = &"monoceros"
	rules.techniques.assign([f.move,sweep])
	rules.combos = {"charge_sweep":{"type":"sequence","children":[{"type":"action","id":"charge"},{"type":"action","id":"sweep"}]}}
	rules.costs = {"charge_sweep":1.0}
	var flow = load("res://scripts/data_types/boss_flow_def.gd").new()
	flow.maximum_stamina = 10.0
	flow.sections = [{"request":"any","weights":{"combo":1.0},"allowed_techniques":["charge_sweep"],"cap":1.0,"action_count":1,"next":0}]
	var compiled: Dictionary = builder.boss_flow_records(rules,flow,techniques.BossTechniqueDefinition)
	for key in compiled: records[key] = compiled[key]
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	if not bridge.configure(builder.Schema.write_content(records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":184,"mode":1,"stage_id":"B_monoceros_combo","profile":{},"settings":{"hitstop":false}}).ok: return {}
	bridge.start(184,{"position":Vector2(100,0)})
	bridge.subscribe("確認",func(_packet): return true)
	bridge.command("dev_ship_motion",{"position":Vector2(100,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(100,0),Vector2(100,0),Vector2(640,360))
	f.id = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	f.bridge = bridge
	return f

func native_combo() -> void:
	var f := combo_fixture()
	if "--cpp-combo-retry" not in OS.get_cmdline_user_args(): check(not f.is_empty(),"突進と薙ぎを一つの技表へ生成しsequenceとして読み込む")
	if f.is_empty(): get_tree().quit(1); return
	var bridge = f.bridge
	bridge._core.step(0.01)
	bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value[0].technique=="charge","連撃を自然選択し最初の突進を開始する")
	var finished := false
	for i in 20:
		bridge._core.step(0.02)
		var flow: Dictionary = bridge.command("dev_boss_flow_state").value[0]
		if flow.nodes[0].cursor==1:
			finished = true
			break
	var state: Dictionary = bridge.command("dev_boss_state").value[0]
	check(finished and state.stage==5 and state.technique=="charge","突進の回復終了tickでは次の薙ぎを始めない")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.01)
	var expected: Dictionary = bridge.command("dev_boss_state").value[0]
	check(expected.technique=="sweep" and expected.stage==0 and expected.id>state.id,"次tickで薙ぎの独立した段階時計を始める")
	var render: Dictionary = bridge.read_render(Rect2(-1000,-1000,2000,2000),1.0)
	check(render.ok and render.value.boss_techniques[0].technique=="sweep" and render.value.boss_techniques[0].horn.size()==2,"連撃中の表示は実行中の薙ぎとその判定線だけを読む")
	check(held.ok and bridge.restore(held.value).ok,"子の切替境界で連撃カーソルと技チケットを復帰する")
	bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value[0]==expected,"境界復帰後も同じ薙ぎを開始する")
	bridge.release_checkpoint(held.value)
	for i in 20: bridge._core.step(0.02)
	check(bridge.command("dev_boss_state").value[0].id>expected.id,"薙ぎ終了後に連撃が自然終了して次の行動へ進む")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"連撃の通知を共通配信へ渡す")
	bridge.dispose()
	for disappear in [false,true]:
		f = combo_fixture()
		bridge = f.bridge
		bridge._core.step(0.01)
		bridge._core.step(0.01)
		if disappear: bridge.command("dev_kill",{"entity_id":f.id,"cause":"debug"})
		else: bridge.command("dev_cancel_flow",{"entity_id":f.id})
		bridge._core.step(0.02)
		state = bridge.command("dev_boss_state").value[0]
		check(state.stage==7 and state.technique=="charge" and bridge.read_frame().ok,"参加者消失で後続の薙ぎを始めない" if disappear else "連撃の取消で後続の薙ぎを始めない")
		bridge.dispose()
	print("[cpp_monoceros_combo] failures=",failed)
	get_tree().quit(1 if failed else 0)

func native_combo_tail() -> void:
	var f := combo_fixture()
	var bridge = f.bridge
	bridge._core.step(0.01)
	if "--cpp-combo-cancel" not in OS.get_cmdline_user_args(): check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"連撃の通知を共通配信へ渡す")
	bridge.dispose()
	var state: Dictionary
	for disappear in ([false] if "--cpp-combo-cancel" in OS.get_cmdline_user_args() else [false,true]):
		f = combo_fixture()
		bridge = f.bridge
		bridge._core.step(0.01)
		bridge._core.step(0.01)
		if disappear: bridge.command("dev_kill",{"entity_id":f.id,"cause":"debug"})
		else: bridge.command("dev_cancel_flow",{"entity_id":f.id})
		bridge._core.step(0.02)
		state = bridge.command("dev_boss_state").value[0]
		check(state.stage==7 and state.technique=="charge" and bridge.read_frame().ok,"参加者消失で後続の薙ぎを始めない" if disappear else "連撃の取消で後続の薙ぎを始めない")
		bridge.dispose()
	print("[cpp_monoceros_combo] failures=",failed)
	get_tree().quit(1 if failed else 0)

func native_return() -> void:
	var f := charge_fixture(true,false,450.0,false,"return_charge")
	check(not f.is_empty(),"往復突進の編集値と型付き段階を生成して読み込む")
	if f.is_empty(): get_tree().quit(1); return
	var bridge = f.bridge
	check(f.records.BossTechniqueDefinition[0].kind==4 and f.records.BossTechniqueDefinition[0].passes==2 and f.records.BossTechniqueDefinition[1].passes==3 and f.records.BossTechniqueStage.is_empty(),"形態ごとの回数と速さを生成しmethod trackを残さない")
	var legacy = preload("res://scripts/bosses/legacy_technique_runners.gd").definition(f.move)
	check(f.move.make_runner()==null and is_equal_approx(legacy.attack_length(),0.9) and legacy.reach_limit(100.0)==300.0,"PureDataを保ち通常入口の攻撃長と到達距離を解決する")
	bridge.command("dev_ship_motion",{"position":Vector2(150,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(150,0),Vector2(150,0),Vector2(640,360))
	bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value[0].sequence_stage==0,"共通フローが往復突進を自然選択する")
	bridge._core.step(0.2)
	var state: Dictionary = bridge.command("dev_boss_state").value[0]
	check(state.stage==1 and state.sequence_stage==1 and state.travel==200.0 and state.traveled==0.0,"自機までの距離とovershootを上限距離で止めて発進する")
	bridge._core.step(0.2)
	state = bridge.command("dev_boss_state").value[0]
	check(state.hit and state.sequence_stage==2 and state.completed==1 and state.position.is_equal_approx(Vector2(200,0)),"最初の突進は上限で止まり一回命中して減速へ進む")
	bridge._core.step(0.05)
	state = bridge.command("dev_boss_state").value[0]
	check(state.position.is_equal_approx(Vector2(212.5,0)) and is_equal_approx(state.brake_progress,0.5),"減速は速さの割合を線形に減らし前方の逆噴射へ接続する")
	bridge._core.step(0.05)
	bridge._core.step(0.05)
	state = bridge.command("dev_boss_state").value[0]
	check(state.sequence_stage==3 and not state.locked and is_equal_approx(absf(state.facing),PI*0.5) and is_equal_approx(absf(state.angle-state.facing),0.4),"振り向きはsmoothstepで回り頭が最大head_leadだけ先に向く")
	var view = load("res://scenes/bosses/monoceros_presentation.tscn").instantiate()
	view.set_script(load("res://scripts/render/bosses/monoceros.gd"))
	add_child(view)
	view.apply_frame(bridge.command("dev_boss_body_state").value[0],state)
	check(is_equal_approx(absf(view.parts.get_node("Head").rotation),0.4) and view.horn.self_modulate.r==1.0,"振り向き途中から作った表示も頭の先行角と角の光を復元する")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.05)
	var expected: Dictionary = bridge.command("dev_boss_state").value[0]
	check(expected.locked and is_equal_approx(absf(expected.angle),PI),"次回のturn_lock秒前に振り向きと頭を固定する")
	check(held.ok and bridge.restore(held.value).ok,"減速後の向き直り・完了回数・技時計を途中復帰する")
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0]==expected,"復帰しても同じ方向と時刻で固定する")
	bridge.release_checkpoint(held.value)
	bridge._core.step(0.1)
	state = bridge.command("dev_boss_state").value[0]
	check(state.sequence_stage==1 and not state.hit and state.travel==112.5,"二回目の突進は現在の自機から距離を決め直し命中済みを戻す")
	bridge._core.step(0.12)
	state = bridge.command("dev_boss_state").value[0]
	check(state.stage==2 and state.completed==2 and state.hit,"所定回数の最後も独立して命中し回復へ進む")
	bridge._core.step(0.051)
	bridge._core.step(0.01)
	bridge._core.step(0.2)
	check(bridge.command("dev_boss_state").value[0].id>state.id,"往復突進の自然終了後に次の行動へ進む")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"往復突進の命中と段階を共通配信へ渡す")
	bridge.dispose()
	for disappear in [false,true]:
		f = charge_fixture(false,false,450.0,false,"return_charge")
		bridge = f.bridge
		var ticket: Dictionary = bridge.command("dev_boss_technique",{"entity_id":f.id,"definition":1})
		bridge._core.step(0.2)
		if disappear: bridge.command("dev_kill",{"entity_id":f.id,"cause":"debug"})
		else: bridge.command("dev_cancel_technique",{"ticket":ticket.value})
		bridge._core.step(0.2)
		state = bridge.command("dev_boss_state").value[0]
		check(state.stage==7 and not state.hit and bridge.read_frame().ok,"参加者消失で往復突進を閉じる" if disappear else "往復突進の取消後に当たりと次の往復を残さない")
		bridge.dispose()
	f = charge_fixture(false,true,500.0,false,"return_charge")
	bridge = f.bridge
	bridge.command("dev_boss_technique",{"entity_id":f.id,"definition":1})
	bridge._core.step(0.2)
	bridge._core.step(0.3)
	state = bridge.command("dev_boss_state").value[0]
	check(state.stage==3 and state.completed==0,"往復突進も共有した角掃引で惑星へ刺さり次の往復を始めない")
	bridge.dispose()
	view.queue_free()
	await get_tree().process_frame
	print("[cpp_monoceros_return] failures=",failed)
	get_tree().quit(1 if failed else 0)

func wave_rows(bridge) -> Array:
	return bridge.command("dev_boss_body_state").value[0].horn_waves

func native_wave() -> void:
	var f := charge_fixture(true,false,450.0,false,"horn_wave")
	check(not f.is_empty(),"角の衝撃波の編集値と型付き状態を読み込む")
	if f.is_empty(): get_tree().quit(1); return
	var bridge = f.bridge
	var definition: Dictionary = f.records.BossTechniqueDefinition[0]
	check(definition.kind==5 and definition.warn==0.1 and definition.wave_width==20.0 and definition.wave_half_angle==0.2 and f.records.BossTechniqueStage.is_empty(),"windupをwarnへ変換し波の実効値を生成してmethod trackを残さない")
	var legacy = preload("res://scripts/bosses/legacy_technique_runners.gd").definition(f.move)
	check(f.move.make_runner()==null and is_equal_approx(legacy.attack_length(),0.5) and legacy.reach_limit(100.0)==300.0,"衝撃波をPureDataへ分離し旧入口の攻撃長と到達距離を保つ")
	bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value[0].stage==0,"制作値から共通フローで角の衝撃波を単独選択する")
	bridge._core.step(0.1)
	var state: Dictionary = bridge.command("dev_boss_state").value[0]
	check(state.sequence_stage==1 and is_equal_approx(state.angle,-0.8) and wave_rows(bridge).is_empty(),"溜め終わりに首を引いた角度を保ち同じtickには波を放たない")
	bridge._core.step(0.05)
	var waves := wave_rows(bridge)
	check(waves.size()==1 and waves[0].radius==50.0 and is_zero_approx(waves[0].angle),"振り抜きのsmoothstep閾値で一度放ち発生tickでは広げない")
	check(f.events.any(func(e): return e.type==&"wave_release"),"波の放出位置を登録済み通知で配信する")
	bridge.command("dev_ship_motion",{"position":Vector2(55,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(55,0),Vector2(55,0),Vector2(640,360))
	bridge._core.step(0.05)
	waves = wave_rows(bridge)
	check(waves[0].radius==55.0 and waves[0].hit,"次tickから等速で広げ点の自機と扇形帯で一回命中する")
	check(f.events.any(func(e): return e.type==&"combat_player_damage" and e.payload.cause==&"horn_wave" and e.payload.source==&"monoceros" and e.payload.technique==&"horn_wave"),"衝撃波の原因・出所・技を共通の戦闘記録へ渡す")
	var view = load("res://scripts/bosses/monoceros/horn_wave_visual.gd").new()
	add_child(view)
	view.apply_frame(waves,0.2)
	check(view.retained and view.frame_waves[0].radius==55.0 and view.frame_waves[0].half==0.2,"残留波の表示も当たりと同じ半径・弧・幅を読む")
	var hp: float = bridge._core.ship_snapshot().ship_hp
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.1)
	bridge._core.step(0.05)
	var expected := wave_rows(bridge)
	check(expected.size()==2 and expected[0].radius==70.0 and expected[1].radius==50.0,"溜め直して反対方向の振り抜きから二発目を放つ")
	check(held.ok and bridge.restore(held.value).ok,"残留波の所有・半径・命中済みと再充填途中の技を復帰する")
	bridge._core.step(0.1)
	bridge._core.step(0.05)
	check(wave_rows(bridge)==expected and bridge._core.ship_snapshot().ship_hp==hp,"復帰後も同じ二つの波へ進み最初の波で再被弾しない")
	bridge.release_checkpoint(held.value)
	bridge._core.step(0.05)
	bridge._core.step(0.1)
	bridge._core.step(0.051)
	state = bridge.command("dev_boss_state").value[0]
	check(state.stage==5 and wave_rows(bridge).size()==2,"技の自然終了後も放った波は残る")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"衝撃波の通知を共通配信へ渡す")
	bridge.dispose()
	view.queue_free()
	for disappear in [false,true]:
		f = charge_fixture(false,false,450.0,false,"horn_wave")
		bridge = f.bridge
		var ticket: Dictionary = bridge.command("dev_boss_technique",{"entity_id":f.id,"definition":1})
		bridge._core.step(0.1)
		bridge._core.step(0.05)
		if disappear: bridge.command("dev_kill",{"entity_id":f.id,"cause":"debug"})
		else: bridge.command("dev_cancel_technique",{"ticket":ticket.value})
		bridge._core.step(0.1)
		check(wave_rows(bridge).is_empty() if disappear else wave_rows(bridge).size()==1 and wave_rows(bridge)[0].radius==60.0,"参加者の撃破で残留波を消す" if disappear else "技の取消では放った波が残り次tickから進む")
		if not disappear:
			bridge.command("dev_cancel_boss",{"entity_id":f.id})
			check(wave_rows(bridge).is_empty(),"ボス取消ではClearWithBossで残留波を終了する")
		bridge.dispose()
	f = charge_fixture(false,false,450.0,false,"horn_wave")
	bridge = f.bridge
	bridge.command("dev_boss_technique",{"entity_id":f.id,"definition":1})
	bridge._core.step(0.1)
	bridge._core.step(0.05)
	var outside := Vector2.from_angle(0.25)*55.0
	bridge.command("dev_ship_motion",{"position":outside,"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(outside,outside,Vector2(640,360))
	bridge._core.step(0.05)
	check(not wave_rows(bridge)[0].hit,"角度の境界には自機半径を足さず弧の外側を避けられる")
	bridge._core.step(2.45)
	check(wave_rows(bridge).is_empty(),"自然寿命の最大半径で波を回収する")
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_monoceros_wave] failures=",failed)
	get_tree().quit(1 if failed else 0)

func native_dance() -> void:
	var f := charge_fixture(true,false,450.0,false,"horn_dance")
	check(not f.is_empty(),"光角の乱舞の制作値を型付き状態へ生成して単独発動する")
	if f.is_empty(): get_tree().quit(1); return
	var bridge = f.bridge
	var definition: Dictionary = f.records.BossTechniqueDefinition[0]
	check(definition.kind==6 and definition.passes==2 and definition.warn==0.1 and definition.min_run==200.0 and f.records.BossTechniqueStage.is_empty(),"乱舞の全固有値と見積り時計を生成しmethod trackを残さない")
	var legacy = preload("res://scripts/bosses/legacy_technique_runners.gd").definition(f.move)
	check(f.move.make_runner()==null and is_equal_approx(legacy.attack_length(),1.5) and is_inf(legacy.reach_limit(100.0)),"PureDataを保ち旧入口の攻撃長と無制限の到達距離を解決する")
	bridge.command("dev_ship_motion",{"position":Vector2(150,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(150,0),Vector2(150,0),Vector2(640,360))
	bridge._core.step(0.01)
	bridge._core.step(0.05)
	var state: Dictionary = bridge.command("dev_boss_state").value[0]
	check(state.stage==0 and state.locked and is_equal_approx(state.glow,0.5),"最初の照準はaim_lock前に固定し同じ時計で角を光らせる")
	bridge._core.step(0.05)
	state = bridge.command("dev_boss_state").value[0]
	check(state.stage==1 and state.sequence_stage==1 and state.travel==200.0 and state.run_speed==1000.0,"初回の突進はmin_runと現在の自機までの距離で決める")
	bridge._core.step(0.2)
	state = bridge.command("dev_boss_state").value[0]
	check(state.hit and state.completed==1 and state.sequence_stage==2 and state.position.is_equal_approx(Vector2(200,0)),"各回の突進は共有した掃引で命中し所定距離で左旋回へ進む")
	bridge._core.step(0.05)
	state = bridge.command("dev_boss_state").value[0]
	check(state.sequence_stage==2 and is_equal_approx(state.heading,-0.1) and state.speed==900.0 and is_equal_approx(state.angle,-0.5) and state.booster==1.2,"旋回は左回りで減速し最短時間と同値では発進せず頭だけ先に向く")
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	var view = load("res://scenes/bosses/monoceros_presentation.tscn").instantiate()
	view.set_script(load("res://scripts/render/bosses/monoceros.gd"))
	add_child(view)
	view.apply_frame(body,state)
	check(is_equal_approx(view.parts.get_node("Head").rotation,-0.4) and view.booster_strength()==1.2,"途中から作った表示も旋回中の頭の先行角と噴射へ合わせる")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.05)
	var expected: Dictionary = bridge.command("dev_boss_state").value[0]
	check(expected.sequence_stage==1 and not expected.hit and expected.run_speed==1000.0 and expected.travel==200.0,"向き・距離・最短時間を満たすと現在の自機へ即時に向き直して再発進する")
	check(held.ok and bridge.restore(held.value).ok,"旋回の向き・速さ・完了回数と命中済みを途中復帰する")
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0]==expected,"復帰後も同じ旋回位置から再発進する")
	bridge.release_checkpoint(held.value)
	bridge._core.step(0.2)
	state = bridge.command("dev_boss_state").value[0]
	check(state.completed==2 and state.sequence_stage==3 and state.hit,"最後の突進も独立して命中し角を掲げる段階へ進む")
	bridge._core.step(0.05)
	state = bridge.command("dev_boss_state").value[0]
	check(is_equal_approx(state.speed,1000.0*exp(-0.5)) and is_equal_approx(state.glow,0.1),"終了段階は指数減速し角の光を時間で戻す")
	bridge._core.step(0.05)
	bridge._core.step(0.051)
	check(bridge.command("dev_boss_state").value[0].stage==5,"掲げる時間と回復が終わったら自然終了する")
	check(f.events.any(func(e): return e.type==&"combat_player_damage" and e.payload.cause==&"horn" and e.payload.source==&"monoceros" and e.payload.technique==&"horn_dance"),"乱舞の命中を原因・出所・技付きで記録へ渡す")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"乱舞の段階と命中を共通配信へ渡す")
	bridge.dispose()
	view.queue_free()
	for disappear in [false,true]:
		f = charge_fixture(false,false,450.0,false,"horn_dance")
		bridge = f.bridge
		var ticket: Dictionary = bridge.command("dev_boss_technique",{"entity_id":f.id,"definition":1})
		bridge._core.step(0.1)
		if disappear: bridge.command("dev_kill",{"entity_id":f.id,"cause":"debug"})
		else: bridge.command("dev_cancel_technique",{"ticket":ticket.value})
		bridge._core.step(0.2)
		state = bridge.command("dev_boss_state").value[0]
		check(state.stage==7 and not state.hit and bridge.read_frame().ok,"参加者消失で乱舞を閉じる" if disappear else "取消後に乱舞の当たりと旋回を残さない")
		bridge.dispose()
	f = charge_fixture(false,false,450.0,false,"horn_dance",true)
	bridge = f.bridge
	bridge.command("dev_boss_technique",{"entity_id":f.id,"definition":1})
	bridge._core.step(0.1)
	bridge._core.step(0.35)
	bridge._core.step(0.2)
	state = bridge.command("dev_boss_state").value[0]
	check(state.sequence_stage==2 and state.speed==600.0,"遅れた旋回はlate速度へ減速し最大時間と同値では打ち切らない")
	bridge._core.step(0.01)
	check(bridge.command("dev_boss_state").value[0].sequence_stage==3,"旋回最大時間を越えたら乱舞を終える")
	bridge.dispose()
	f = charge_fixture(false,true,500.0,false,"horn_dance")
	bridge = f.bridge
	bridge.command("dev_boss_technique",{"entity_id":f.id,"definition":1})
	bridge._core.step(0.1)
	bridge._core.step(0.3)
	check(bridge.command("dev_boss_state").value[0].stage==3,"乱舞の突進も惑星へ角が刺さると旋回へ進まない")
	bridge.dispose()
	await get_tree().process_frame
	print("[cpp_monoceros_dance] failures=",failed)
	get_tree().quit(1 if failed else 0)

func native_sword() -> void:
	var f := charge_fixture(true,false,450.0,false,"sword_flash")
	check(not f.is_empty(),"光の剣の連撃の編集値を型付き状態へ生成して単独発動する")
	if f.is_empty(): get_tree().quit(1); return
	var bridge = f.bridge
	var definition: Dictionary = f.records.BossTechniqueDefinition[0]
	check(definition.kind==7 and definition.cuts==2 and definition.first_windup==0.1 and definition.warn==0.05 and definition.slash_width==20.0 and f.records.BossTechniqueStage.is_empty(),"初回と次回の溜め・斬撃の固有値を生成しmethod trackを残さない")
	var legacy = preload("res://scripts/bosses/legacy_technique_runners.gd").definition(f.move)
	check(f.move.make_runner()==null and is_equal_approx(legacy.attack_length(),0.55) and legacy.reach_limit(100.0)==300.0,"PureDataを保ち旧入口の攻撃長と到達距離を解決する")
	bridge.command("dev_ship_motion",{"position":Vector2(150,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(150,0),Vector2(150,0),Vector2(640,360))
	bridge._core.step(0.01)
	bridge._core.step(0.05)
	var state: Dictionary = bridge.command("dev_boss_state").value[0]
	check(state.stage==0 and state.locked and is_equal_approx(state.angle,-0.45) and state.target==Vector2(150,0),"初回の溜めは現在の位置を固定し首を引く")
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0].sequence_stage==1,"初回の溜め時間で振り抜きへ進む")
	bridge._core.step(0.05)
	state = bridge.command("dev_boss_state").value[0]
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(state.released and state.hit and is_equal_approx(state.speed,100.0*exp(-0.5)) and is_equal_approx(state.position.x,100.0*exp(-0.5)*0.05),"前進を指数減速し振り抜きの半分で斬撃を一回放つ")
	check(body.last_slash[0].is_equal_approx(Vector2(150,-100)) and body.last_slash[1].is_equal_approx(Vector2(150,100)),"固定した対象までの距離を使い斜めの有限線分を生成する")
	check(f.events.any(func(e): return e.type==&"combat_player_damage" and e.payload.cause==&"sword_flash" and e.payload.source==&"monoceros" and e.payload.technique==&"sword_flash"),"斬撃の原因をsword_flashへ分けて記録へ渡す")
	var visual = load("res://scripts/bosses/monoceros/sword_flash_visual.gd").new()
	add_child(visual)
	var releases: Array = f.events.filter(func(e): return e.type==&"slash_release")
	check(releases.size()==1,"斬撃の線と幅を登録済み通知で一回配信する")
	visual.frame_event({"type":&"slash_release","line":releases[0].payload.line,"width":releases[0].payload.width})
	visual.apply_frame(0.15)
	check(visual.effects.size()==8 and visual.effects[0].line==body.last_slash and visual.effects[0].width==20.0,"表示乱数の針と斬撃は通知の判定線から作り戦闘へ書き戻さない")
	var held: Dictionary = bridge.checkpoint()
	bridge._core.step(0.05)
	var expected: Dictionary = bridge.command("dev_boss_state").value[0]
	check(expected.sequence_stage==2 and not expected.locked,"振り抜きと命中時間の終了後は次の斬りの間へ進む")
	check(held.ok and bridge.restore(held.value).ok,"放出した線分・命中済み・放出時刻を途中復帰する")
	bridge._core.step(0.05)
	check(bridge.command("dev_boss_state").value[0]==expected and bridge.command("dev_boss_body_state").value[0].last_slash==body.last_slash,"復帰後も同じ線分を保持して次の斬りへ進む")
	bridge.release_checkpoint(held.value)
	bridge._core.step(0.05)
	state = bridge.command("dev_boss_state").value[0]
	check(state.stage==1 and state.sequence_stage==0 and state.cut==1 and state.side==-1,"二回目の溜めはactiveのまま反対側から始める")
	bridge._core.step(0.05)
	bridge._core.step(0.05)
	state = bridge.command("dev_boss_state").value[0]
	check(state.cut==1 and state.released and state.hit and bridge.command("dev_boss_body_state").value[0].last_slash[0].y>0.0,"次の斬撃では命中済みを戻し線の向きを反転する")
	bridge._core.step(0.05)
	bridge._core.step(0.1)
	bridge._core.step(0.051)
	check(bridge.command("dev_boss_state").value[0].stage==5 and bridge.command("dev_boss_body_state").value[0].last_slash.size()==2,"首を戻して自然終了し最後の線は値として保持する")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"光の剣の通知を共通配信へ渡す")
	bridge.dispose()
	visual.queue_free()
	for disappear in [false,true]:
		f = charge_fixture(false,false,450.0,false,"sword_flash")
		bridge = f.bridge
		var ticket: Dictionary = bridge.command("dev_boss_technique",{"entity_id":f.id,"definition":1})
		bridge._core.step(0.1)
		if disappear: bridge.command("dev_kill",{"entity_id":f.id,"cause":"debug"})
		else: bridge.command("dev_cancel_technique",{"ticket":ticket.value})
		bridge._core.step(0.2)
		state = bridge.command("dev_boss_state").value[0]
		check(state.stage==7 and not state.hit and not f.events.any(func(e): return e.type==&"slash_release") and bridge.read_frame().ok,"参加者消失で斬撃を放たない" if disappear else "取消後に斬撃の当たりを残さない")
		bridge.dispose()
	await get_tree().process_frame
	print("[cpp_monoceros_sword] failures=",failed)
	get_tree().quit(1 if failed else 0)
