## 敵弾の移動、誘導、被弾、無敵時間、画面外と寿命の終了を現行処理へ照合する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
const SHIP := preload("res://tests/native_ship.gd")
var failed := 0
var bullet_finished := false
var bullet_fixes := false
var mute_checks := false
func check(ok: bool, label: String) -> void:
	if mute_checks: return
	if not ok:
		failed += 1
		push_error(label)
func values(object: Object, keys: Array) -> Dictionary:
	var out := {}
	for key in keys: out[key] = object.get(key)
	return out
func _ready() -> void:
	if "--cpp-bullet" in OS.get_cmdline_user_args() or "--cpp-bullet-fixes" in OS.get_cmdline_user_args():
		bullet_fixes = "--cpp-bullet-fixes" in OS.get_cmdline_user_args()
		mute_checks = bullet_fixes
		await check_cpp_bullet()
		mute_checks = false
		check(bullet_finished,"通常敵弾の確認本体が最後まで進んだ")
		print("[cpp_bullet] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	var comparison = COMPARE.new()
	var probe = comparison.create_native()
	if not probe.has_method("spawn_hostile"):
		check(false, "敵弾と被弾をネイティブランが所有する")
	else:
		await compare_bullets(comparison)
	probe.close()
	print("[native_hostiles] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func add_shot(run: RunSimulation, core, fields: Dictionary) -> void:
	var row := run.projectiles._add_hostile(fields.pos, fields.vel, fields.speed, fields.r, fields.life, fields.dmg, fields.slow, fields.turn, fields.kind)
	run.projectiles.hostile_wait[row] = fields.get("wait", 0.0)
	run.projectiles.hostile_stone[row] = fields.get("stone", 0.0)
	check(core.spawn_hostile(fields) == row, "敵弾の行を同じ順で生成・再利用する")
func compare_bullets(comparison) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 348, "empty": true, "invincible": false})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	run.ship.setup(run.ship.ctx)
	run.state.stats.invulnerability = 0.25
	var core = comparison.create_native()
	core.configure_ship(values(run.cfg, SHIP.CONFIG_KEYS), values(run.state.stats, SHIP.STAT_KEYS))
	core.start(348)
	var origin := run.state.ship_pos
	var base := {"kind": 0, "pos": origin + Vector2(100,0), "vel": Vector2(-1200,0), "speed": 1200.0, "r": 7.0, "life": 0.5, "dmg": 7.0, "slow": 0.3, "turn": 0.0}
	add_shot(run, core, base.merged({"pos": origin + Vector2(1000,0), "vel": Vector2(-120000,0), "speed": 120000.0}, true))
	add_shot(run, core, base.merged({"kind": 1, "pos": origin + Vector2(2000,0), "vel": Vector2(550,0), "speed": 550.0, "life": 3.0, "turn": 2.4}, true))
	for kind in [0, 0, 2]: add_shot(run, core, base.merged({"kind": kind}, true))
	add_shot(run, core, base.merged({"kind": 1, "pos": origin + Vector2(250,100), "vel": Vector2(0, 550), "speed": 550.0, "life": 3.0, "turn": 2.4}, true))
	add_shot(run, core, base.merged({"pos": origin + Vector2(2000,0), "vel": Vector2(1200,0)}, true))
	add_shot(run, core, base.merged({"pos": origin + Vector2(100,0), "wait": 0.1}, true))
	add_shot(run, core, base.merged({"pos": origin + Vector2(200,0), "stone": 0.08}, true))
	check(core.spawn_hostile(base.merged({"kind": 3}, true)) == -1, "未移行の圧縮弾を通常弾として受けない")
	var hits := 0
	for tick in 150:
		if tick == 60:
			# 寿命を使い切る更新でも、その線分で機体に当たる。
			add_shot(run, core, base.merged({"pos": run.state.ship_pos, "life": 0.001}, true))
		var real_dt := 1.0/60.0
		run.ship.intent.touch = true
		run.ship.tick(real_dt, real_dt)
		core.step_ship(real_dt, real_dt, {"touch": true})
		run.state.enemy_aim = run.state.ship_pos
		run.state.view_center = run.state.ship_pos
		run.state.view_half = Vector2(640,360)
		core.set_motion_context(run.state.enemy_aim, run.state.view_center, run.state.view_half)
		run.state.events.clear()
		run.projectiles._update_hostile(real_dt)
		check(core.step_hostiles(real_dt), "敵弾を世界時間で進める")
		var difference: String = comparison.difference(comparison.plain(snapshot(run.projectiles)), comparison.plain(core.hostiles_snapshot()))
		check(difference.is_empty(), "敵弾の誘導・待機・石化・終了が一致する: %d %s" % [tick, difference])
		difference = comparison.difference(comparison.plain(values(run.state, SHIP.STATE_KEYS)), comparison.plain(core.ship_snapshot()))
		check(difference.is_empty(), "被弾・減速・無敵時間が一致する: %d %s" % [tick, difference])
		difference = comparison.difference(comparison.plain(run.state.events), comparison.plain(core.drain_events()))
		check(difference.is_empty(), "被弾通知が一致する: %d %s" % [tick, difference])
		var frame_hits := 0
		for event in run.state.events:
			if event.type == &"hurt":
				hits += 1
				frame_hits += 1
		if tick in [0, 60]: check(frame_hits == 1, "高速な通過と寿命切れの接触を実際に通る")
	check(hits >= 2, "無敵の終了後の再被弾が実際に通る")
	core.close()
	check(core.spawn_hostile(base) == -1 and not core.step_hostiles(0.1), "終了したランで敵弾を動かさない")
	lab.free()
func snapshot(ps: ProjectileSystem) -> Array:
	var out: Array = []
	for i in ps.hostile_alive.size():
		if ps.hostile_alive[i] == 0: continue
		out.append({"row": i, "kind": ps.hostile_kind[i], "pos": ps.hostile_pos[i], "vel": ps.hostile_vel[i], "life": ps.hostile_life[i], "gap": ps.hostile_gap[i], "stone": ps.hostile_stone[i], "wait": ps.hostile_wait[i]})
	return out

func bullet_pair_step(run: RunSimulation, core, dt: float, label: String) -> void:
	run.projectiles._update_hostile(dt)
	check(core.step_hostiles(dt),label+"：C++の敵弾を進める")
	var expected := snapshot(run.projectiles)
	# 残り時間の負値を読まない石化・待機は、設計の残り時間部品で0へそろえる。
	for row: Dictionary in expected:
		row.stone = maxf(0.0,row.stone)
		row.wait = maxf(0.0,row.wait)
	var comparison = COMPARE.new()
	var difference: String = comparison.difference(comparison.plain(expected),comparison.plain(core.hostiles_snapshot()))
	check(difference.is_empty(),label+"：位置・速度・寿命・地形の余裕・石化が現行と一致する "+difference)

func check_cpp_bullet() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 1500.0
	config.planet_radius = 100.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	config.atk_scale = 3.0
	var stage := RuntimeStage.new()
	stage.index = 86
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/run_bullet"
	var builder = load("res://tools/content/build_run_content.gd")
	check(builder!=null and builder.can_instantiate(),"敵弾の生成入口を読み込める")
	if builder==null or not builder.can_instantiate(): return
	var built: Error = builder.build(stage,config,output,"通常敵弾の発生元・飛行・被弾・終了".sha256_text())
	check(built==OK,"敵弾の固定値・当たりの規則・表示キーを生成する")
	if built!=OK: return
	var path := output.path_join("stage_86.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":348},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"敵弾の表示を準備して出撃する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":348,"empty":true,"field":{"terrain":true,"rocks":false,"gimmicks":false},"invincible":false,"config":{"start_radius":1500.0,"planet_radius":100.0,"atk_scale":3.0}})
	var run: RunSimulation = lab.run
	var target := Vector2(-900,0)
	run.state.ship_pos = target
	run.state.ship_vel = Vector2(100,0)
	run.state.view_center = target
	run.state.view_half = Vector2(640,360)
	check(bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2(100,0)}).ok,"固定の機体位置と速度を設定する")
	var intent := Intent.new()
	bridge.step(1.0/120.0,bridge.pack_intent(intent),{"logical_size":Vector2(640,480)})
	bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2(100,0)})
	core.set_motion_context(target,target,Vector2(640,360))
	var source_position := Vector2(-1500,0)
	var source_row: int = run.enemies.spawn(run.enemies.def_of(&"drifter"),source_position)
	var source_id: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":source_position}).value
	var empty: Dictionary = bridge.checkpoint()
	var source_values := {"bullet_dmg":11.0,"slow":0.3}
	run.projectiles.fire_enemy(source_row,0.0,600.0,&"bullet",source_values)
	var emitted: Dictionary = bridge.command("dev_fire_enemy",{"source_id":source_id,"angle":0.0,"speed":600.0,"damage":11.0,"slow":0.3})
	check(emitted.ok,"発生元の位置・半径から通常敵弾を発射する")
	if not emitted.ok:
		lab.free()
		session.free()
		return
	var comparison = COMPARE.new()
	check(comparison.difference(comparison.plain(snapshot(run.projectiles)),comparison.plain(core.hostiles_snapshot())).is_empty(),"発射位置・速度・半径・寿命は現行の生成処理と一致する")
	var pending: Dictionary = bridge.checkpoint()
	mute_checks = false
	bullet_pair_step(run,core,1.0/60.0,"直進")
	var visual := 0
	var stone_visual := 0
	for entry: Dictionary in session.cpp_resources.visuals:
		if entry.role==11: visual = entry.id
		if entry.role==12: stone_visual = entry.id
	var frame: Dictionary = bridge.read_render(Rect2(-1800,-500,1500,1000)).value
	var visible := false
	for batch: Dictionary in frame.batches:
		if batch.visual_id==visual: visible = batch.ids.has(int(emitted.value.id)) and is_equal_approx(batch.transforms[0],7.0)
	if not bullet_fixes: check(visible,"同じ当たり半径・攻撃IDの敵弾をまとめて表示する")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	presentation._present_cpp(0.0)
	check(presentation.frame_view.batches.has(visual),"赤い外側と暗い内側の共通の弾を通常画面へ渡す")
	if not bullet_fixes:
		check(bridge.command("dev_kill",{"entity_id":source_id,"cause":"ram"}).ok,"弾の飛行中に発生元を倒す")
		var source_kept := false
		for attack: Dictionary in core.attack_snapshot():
			if attack.id==int(emitted.value.id): source_kept = attack.source_id==source_id and not attack.source_alive
		check(source_kept,"発生元の死後も弾と出どころのIDを保持する")
		bullet_pair_step(run,core,1.0,"高速な機体横断")
		var hit: Dictionary = core.ship_snapshot()
		check(core.hostiles_snapshot().is_empty() and is_equal_approx(hit.ship_hp,run.state.ship_hp) and hit.ship_vel.is_equal_approx(run.state.ship_vel) and is_equal_approx(hit.ship_hp,config.base_hp-11.0),"命中で一度だけ被弾・減速し、通常敵弾へatk_scaleを重ねて掛けない")
		check(bridge.restore(pending.value).ok,"発生元・弾・機体を保持点へ戻す")
		core.step_hostiles(1.0/60.0)
		core.step_hostiles(1.0)
		check(core.hostiles_snapshot().is_empty() and core.ship_snapshot()==hit,"復帰後にも同じ飛行・被弾・消滅になる")
		check(bridge.restore(pending.value).ok,"石化の固定場面へ戻す")
		run.projectiles.clear_hostile()
		run.state.ship_hp = config.base_hp
		run.state.ship_invuln = 0.0
		run.state.ship_vel = Vector2(100,0)
		run.projectiles.fire_enemy(source_row,0.0,600.0,&"bullet",source_values)
		run.projectiles.stone_hostile(Rect2(-1800,-500,1500,1000),0.1)
		check(bridge.command("dev_stone_hostiles",{"duration":0.1,"view":Rect2(-1800,-500,1500,1000)}).ok,"石化を共通の敵弾へ適用する")
		bullet_pair_step(run,core,0.05,"石化中の位置と寿命")
		frame = bridge.read_render(Rect2(-1800,-500,1500,1000)).value
		var stone_visible := false
		for batch: Dictionary in frame.batches:
			if batch.visual_id==stone_visual: stone_visible = batch.ids.has(int(emitted.value.id)) and is_equal_approx(batch.transforms[0],7.0*1.3)
		check(stone_visible,"石化した弾の灰色の円を同じ攻撃IDへ重ねる")
		var stone_at: Vector2 = run.projectiles.hostile_pos[0]
		run.state.ship_pos = stone_at
		run.state.ship_vel = Vector2.ZERO
		bridge.command("dev_ship_motion",{"position":stone_at,"velocity":Vector2.ZERO})
		bullet_pair_step(run,core,0.02,"石化した弾への接触")
		check(core.hostiles_snapshot().is_empty() and is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp),"石化中の弾は触れると被弾させず消える")
	var base := {"kind":0,"speed":1200.0,"r":7.0,"life":4.0,"dmg":7.0,"slow":0.0,"turn":0.0}
	for scenario in [
		{"name":"寿命を使い切る更新の命中","pos":target+Vector2(200,0),"vel":Vector2(-1200,0),"life":0.001,"ship":target,"dt":0.25,"live":false,"hurt":true},
		{"name":"画面外で遠ざかる弾","pos":target+Vector2(2000,0),"vel":Vector2(1200,0),"life":4.0,"ship":target,"dt":0.1,"live":false,"hurt":false},
		{"name":"画面外から近づく弾","pos":target+Vector2(2000,0),"vel":Vector2(-1200,0),"life":4.0,"ship":target,"dt":0.1,"live":true,"hurt":false},
		{"name":"機体より先の地形","pos":Vector2(-300,0),"vel":Vector2(1200,0),"life":4.0,"ship":Vector2(500,0),"dt":0.5,"live":false,"hurt":false}]:
		if bullet_fixes and scenario.name not in ["画面外から近づく弾","機体より先の地形"]: continue
		check(bridge.restore(empty.value).ok,"終了条件の独立した固定場面へ戻す")
		run.projectiles.clear_hostile()
		run.state.ship_hp = config.base_hp
		run.state.ship_invuln = 0.0
		run.state.ship_pos = scenario.ship
		run.state.ship_vel = Vector2.ZERO
		run.state.view_center = scenario.ship
		bridge.command("dev_ship_motion",{"position":scenario.ship,"velocity":Vector2.ZERO})
		core.set_motion_context(scenario.ship,scenario.ship,Vector2(640,360))
		add_shot(run,core,base.merged({"pos":scenario.pos,"vel":scenario.vel,"life":scenario.life},true))
		bullet_pair_step(run,core,scenario.dt,scenario.name)
		if not bullet_fixes: check((not core.hostiles_snapshot().is_empty())==scenario.live and is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp-(7.0 if scenario.hurt else 0.0)),scenario.name+"：継続・消滅・被弾が正しい")
	bridge.release_checkpoint(pending.value)
	bridge.release_checkpoint(empty.value)
	await get_tree().process_frame
	lab.free()
	session.free()
	bullet_finished = true
