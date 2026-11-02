## たて座の生成・追跡・旋回を、本番の編集値と更新へ照合する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
const DATA := preload("res://tools/content/build_native_data.gd")
const SHIP := preload("res://tests/runtime/run_ship.gd")
const COMBAT := preload("res://tests/runtime/run_combat.gd")
const HOSTILES := preload("res://tests/runtime/run_hostiles.gd")
var failed := 0
var reflected_finished := false
var reflected_fixes := false
var reflected_lifetime := false
var shield_finished := false
var shield_red := false
func check(ok: bool, label: String) -> void:
	if reflected_lifetime and label not in ["盾の寿命の値を使い切った反射弾を一度だけ回収する","反射弾の確認本体が最後まで進んだ"]: return
	if reflected_fixes and not ("反射弾の状態が現行と一致する" in label or label in ["反射弾を共通の機体被弾へ通す","石化した反射弾は触れると被弾せずに消える","盾の寿命の値を使い切った反射弾を一度だけ回収する","反射弾の確認本体が最後まで進んだ"]): return
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	if "--cpp-shield" in OS.get_cmdline_user_args() or "--cpp-shield-red" in OS.get_cmdline_user_args():
		shield_red = "--cpp-shield-red" in OS.get_cmdline_user_args()
		await check_cpp_shield()
		check(shield_finished,"盾の確認が最後まで進んだ")
		print("[cpp_shield] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-reflected" in OS.get_cmdline_user_args() or "--cpp-reflected-fixes" in OS.get_cmdline_user_args() or "--cpp-reflected-lifetime" in OS.get_cmdline_user_args():
		reflected_fixes = "--cpp-reflected-fixes" in OS.get_cmdline_user_args()
		reflected_lifetime = "--cpp-reflected-lifetime" in OS.get_cmdline_user_args()
		await check_cpp_reflected()
		check(reflected_finished,"反射弾の確認本体が最後まで進んだ")
		print("[cpp_reflected] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	var comparison = COMPARE.new()
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 287, "empty": true, "invincible": false})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	var definition := run.enemies.def_of(&"shield")
	var data := DATA.compile_enemy(definition, run.cfg)
	check(not data.is_empty(), "たて座の編集値を実行用データへ生成できる")
	if not data.is_empty():
		var core = comparison.create_native()
		check(core.configure(data), "たて座を対応する行動として読み込む")
		core.start(287, run.enemies._next_id)
		run.state.rng.seed = 287
		core.set_motion_context(run.state.ship_pos, run.state.view_center, run.state.view_half)
		for position in [Vector2(500,100), Vector2(2500,200), Vector2(-2000,-300)]:
			run.enemies.spawn(definition, position)
			core.spawn_enemy(&"shield", position)
		for tick in 90:
			if tick in [20,50]: run.state.ship_pos = Vector2(130,180) if tick == 20 else Vector2(-170,400)
			core.set_motion_context(run.state.ship_pos, run.state.view_center, run.state.view_half)
			var dt := 1.0/60.0
			run.state.world_time += dt
			run.enemies.tick(dt,dt)
			core.step(dt)
			var difference: String = comparison.difference(comparison.snapshot(run, [], tick).enemies, core.enemies_snapshot())
			check(difference.is_empty(), "追跡・旋回・遠方の更新が一致する: %d %s" % [tick,difference])
			check(str(run.state.rng.state) == core.inspect().rng_state, "敵の移動で乱数消費を変えない")
		core.close()
	lab.free()
	for mode in ["front_touch", "front_ram", "rear_ram", "rear_zero_ram", "side_ram", "glide_cooldown", "front_shots", "back_shots", "boundary_shots", "front_debris"]: await compare_hits(comparison, mode)
	print("[run_shield] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func values(object: Object, keys: Array) -> Dictionary:
	var out := {}
	for key in keys: out[key] = object.get(key)
	return out
func compare_hits(comparison, mode: String, stone := false) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 287, "empty": true, "invincible": false})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	run.ship.setup(run.ship.ctx)
	if mode.ends_with("ram"): run.cfg.ram_speed_ratio = 0.0
	var definition: EnemyDef = run.enemies.def_of(&"shield").duplicate(true)
	if mode == "rear_zero_ram": definition.weak_arc = 0.0
	if mode == "boundary_shots": definition.params.front_arc = PI - 0.00001
	if mode == "glide_cooldown" or stone: definition.hp = 1000.0
	if stone: definition.armor = 1000.0
	var core = comparison.create_native()
	var budget_helper = load("res://tests/runtime/run_attack_budget.gd").new()
	core.configure(DATA.compile_enemy(definition, run.cfg))
	core.configure_ship(values(run.cfg, SHIP.CONFIG_KEYS), values(run.state.stats, SHIP.STAT_KEYS))
	core.configure_combat(values(run.cfg, COMBAT.COMBAT_CONFIG), values(run.state.stats, COMBAT.COMBAT_STATS))
	if mode == "glide_cooldown": core.configure_draw(values(run.cfg, SHIP.DRAW_CONFIG), values(run.state.stats, SHIP.DRAW_STATS))
	var config := values(run.cfg, COMBAT.PICKUP_CONFIG)
	config.xp_bonus = run.spawn.current_phase().xp_bonus
	core.configure_pickups(config, values(run.state.stats, ["xp_mult", "xp_pickup_radius", "pickup_radius", "pickup_speed_mult"]))
	core.configure_projectiles(values(run.cfg, ["hull_debris_life", "hull_debris_knock", "corpse_trail_points"]))
	core.start(287, run.enemies._next_id, run.pickups._gem_next_seq)
	run.state.rng.seed = 287
	if mode == "glide_cooldown":
		var start := run.state.ship_pos
		for tick in 120:
			var command := {"touch": true, "press": tick == 0, "has_cursor": true, "pen_release": tick == 2, "pen": start + Vector2(mini(tick,2)*100,0)}
			for key in command: run.draw.intent.set(key, command[key])
			run.draw.handle_input()
			core.handle_draw(command, tick*17, run.state.camera_zoom)
			run.draw.tick(1.0/60.0, 1.0/60.0)
			core.step_draw(1.0/60.0)
			if run.state.glide: break
		check(run.state.glide and core.ship_snapshot().glide, "実際のなぞりを終えて勢い中にする")
		core.drain_events()
	var origin := run.state.ship_pos
	var position := Vector2.ZERO if mode.ends_with("shots") or mode == "front_debris" else origin + (Vector2(40,0) if mode.begins_with("rear") else Vector2(0,40) if mode == "side_ram" else Vector2(-40,0))
	run.state.events.clear()
	var spawn_options := {"facing":0.00002} if mode == "boundary_shots" else {}
	var row := run.enemies.spawn(definition, position, spawn_options)
	var id: int = core.spawn_enemy(&"shield", position, spawn_options)
	if stone:
		run.enemies.table.stone[row] = 1.0
		check(core.set_enemy_motion(id,{"stone":1.0}),"石化中の接触と射撃を比較する")
	check(comparison.difference(comparison.plain(run.state.events), comparison.plain(core.drain_events())).is_empty(), "強敵の出現を同じ個体IDで通知する")
	run.combat.rebuild_grid()
	core.rebuild_enemy_grid(run.cfg.grid_cell)
	core.set_motion_context(run.state.ship_pos, run.state.view_center, run.state.view_half)
	for repeat in 2:
		run.state.events.clear()
		if mode.ends_with("shots"):
			var from := Vector2(200,0) if mode == "front_shots" else Vector2(-200,0)
			var angle := PI if mode == "front_shots" else 0.0
			var options := {"speed": 1200.0, "life": 1.0, "pierce_left": 5}
			run.projectiles.fire_shot(from, angle, 7.0, options)
			core.fire_shot(from, angle, 7.0, options)
			run.projectiles._update_friendly(0.2)
			core.step_projectiles(0.2)
		elif mode == "front_debris":
			run.projectiles.burst_debris(Vector2(40,0), 1, 0.0, 7.0, Color.RED, -1)
			core.burst_debris(Vector2(40,0), 1, 0.0, 7.0, Color.RED, -1)
			run.projectiles._update_friendly(0.01)
			core.step_projectiles(0.01)
		else:
			var from := origin + (Vector2(-100,0) if mode.begins_with("rear") else Vector2(0,-100) if mode == "side_ram" else Vector2(100,0))
			if mode == "glide_cooldown" and repeat == 0: from = position + Vector2(-60,-200)
			var bounced := run.combat.collide_ship(from, run.cfg.ship_radius, null)
			check(core.collide_ship(from, run.cfg.ship_radius) == bounced, "盾の前面と背面の接触を分ける: " + mode)
		var difference: String = comparison.difference(comparison.snapshot(run, [], 0).enemies, core.enemies_snapshot())
		check(difference.is_empty(), "盾のダメージと押出しが一致する: " + mode + difference)
		difference = comparison.difference(comparison.plain(values(run.state, SHIP.STATE_KEYS)), comparison.plain(core.ship_snapshot()))
		check(difference.is_empty(), "反発と盾の取得が一致する: " + mode + difference)
		var helper = HOSTILES.new()
		difference = comparison.difference(comparison.plain(helper.snapshot(run.projectiles)), comparison.plain(core.hostiles_snapshot()))
		helper.free()
		check(difference.is_empty(), "反射弾と反射の待ち時間が一致する: " + mode + difference)
		difference = comparison.difference(comparison.plain(run.state.events), comparison.plain(core.drain_events()))
		check(difference.is_empty(), "盾の通知順が一致する: " + mode + difference)
		check(str(run.state.rng.state) == core.inspect().rng_state, "背面命中とドロップの乱数が一致する: " + mode)
		check(comparison.difference(budget_helper.snapshot(run.projectiles.director),core.attack_budget_snapshot()).is_empty(),"撃破直後の接触枠も一致する: " + mode)
	if mode == "front_shots" and not stone: check(core.hostiles_snapshot().size() == 1, "反射の待ち時間中は追加の反射弾を出さない")
	if mode == "rear_ram" and not stone: check(run.state.ship_shield_t > 0 and core.ship_snapshot().ship_shield_t > 0, "背面から盾を奪う経路が実際に通る")
	if mode == "glide_cooldown": check(run.state.glide and core.ship_snapshot().glide, "接触待ち時間中の盾の前面接触は勢いを保つ")
	if mode == "rear_ram" and not stone:
		for elapsed in [0.21, 0.01, float(definition.params.shield_time)]:
			run.state.events.clear()
			run.ship.intent.touch = true
			run.ship.tick(elapsed, elapsed)
			core.step_ship(elapsed, elapsed, {"touch": true})
			var fields := {"kind": 0, "pos": run.state.ship_pos, "vel": Vector2.ZERO, "speed": 0.0, "r": 7.0, "life": 1.0, "dmg": 7.0, "slow": 0.2, "turn": 0.0}
			run.projectiles._add_hostile(fields.pos, fields.vel, fields.speed, fields.r, fields.life, fields.dmg, fields.slow, fields.turn, 0)
			core.spawn_hostile(fields)
			run.projectiles._update_hostile(0.01)
			core.step_hostiles(0.01)
			var difference: String = comparison.difference(comparison.plain(values(run.state, SHIP.STATE_KEYS)), comparison.plain(core.ship_snapshot()))
			check(difference.is_empty(), "奪った盾の防御・失効後の被弾が一致する: " + difference)
			difference = comparison.difference(comparison.plain(run.state.events), comparison.plain(core.drain_events()))
			check(difference.is_empty(), "盾の防御と失効通知が一致する: " + difference)
		check(core.ship_snapshot().ship_hp < run.state.stats.max_hp, "盾が切れた後の被弾を実際に通る")
	if stone:
		var pickup_helper = COMBAT.new()
		check(comparison.difference(comparison.plain(pickup_helper.pickup_snapshot(run)),comparison.plain(core.pickups_snapshot())).is_empty(),"石化の撃破でも同じ報酬を生成する")
		pickup_helper.free()
		check(run.state.kills == core.combat_snapshot().kills and run.state.hitstop == core.combat_snapshot().hitstop,"石化の撃破数と停止演出が一致する")
		if mode.ends_with("shots") or mode == "front_debris":
			check(run.enemies.table.hp[row] < definition.base_hp(run.cfg) and core.hostiles_snapshot().is_empty(),"石化中は盾で反射せずダメージを受ける")
		else:
			check(run.enemies.table.dead[row] != 0 and run.enemies.table.hp[row] > 0.0,"石化した敵はHPと装甲に関係なく接触で砕ける")
			check(run.state.ship_shield_t == 0.0,"石化した盾から盾を奪わない")
	budget_helper.free()
	core.close()
	lab.free()

func reflected_states(run: RunSimulation, core, label: String) -> void:
	var reader = HOSTILES.new()
	var expected: Array = reader.snapshot(run.projectiles)
	reader.free()
	for row: Dictionary in expected:
		row.stone = maxf(0.0,row.stone)
		row.wait = maxf(0.0,row.wait)
	var comparison = COMPARE.new()
	var difference: String = comparison.difference(comparison.plain(expected),comparison.plain(core.hostiles_snapshot()))
	check(difference.is_empty(),label+"：反射弾の状態が現行と一致する "+difference)

func reflected_shot(run: RunSimulation, core, source: int, target: Vector2, radius: float) -> void:
	run.enemies.table.fire_t[source] = 0.0
	run.combat.rebuild_grid()
	var options := {"speed":1200.0,"r":radius,"life":4.0}
	run.projectiles.fire_shot(target,PI,10.0,options)
	check(core.fire_shot(target,PI,10.0,options),"盾の前面へ味方弾を作る")
	run.projectiles._update_friendly(0.5)
	check(core.step_projectiles(0.5),"味方弾の共通更新で盾の反射を通す")

func check_cpp_reflected() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 900.0
	config.planet_radius = 100.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	var stage := RuntimeStage.new()
	stage.index = 87
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["shield"])
	var output := "res://.content/dev/run_reflected"
	var builder = load("res://tools/content/build_run_content.gd")
	check(builder!=null and builder.can_instantiate(),"反射弾の生成入口を読み込める")
	if builder==null or not builder.can_instantiate(): return
	var built: Error = builder.build(stage,config,output,"盾からの反射弾の生成・飛行・終了".sha256_text())
	check(built==OK,"盾の実効値・反射弾・表示キーを生成する")
	if built!=OK: return
	var path := output.path_join("stage_87.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":287},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"盾とピンクの反射弾の資源を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target := Vector2(-900,0)
	bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2.ZERO})
	core.set_motion_context(target,target,Vector2(640,360))
	var source_position := Vector2(-1200,0)
	var source_id: int = bridge.command("dev_spawn",{"definition_id":"shield","position":source_position}).value
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":287,"empty":true,"field":{"terrain":true,"rocks":false,"gimmicks":false},"invincible":false,
		"config":{"start_radius":900.0,"planet_radius":100.0}})
	var run: RunSimulation = lab.run
	run.state.ship_pos = target
	run.state.ship_vel = Vector2.ZERO
	run.state.view_center = target
	run.state.view_half = Vector2(640,360)
	var definition: EnemyDef = run.enemies.def_of(&"shield")
	var source: int = run.enemies.spawn(definition,source_position)
	var empty: Dictionary = bridge.checkpoint()
	var pending: Dictionary = {}
	if not reflected_lifetime:
		for radius in [1.0,7.0,17.0]:
			check(bridge.restore(empty.value).ok,"半径ごとの反射の場面を初期化する")
			run.projectiles.clear_hostile()
			reflected_shot(run,core,source,target,radius)
			reflected_states(run,core,"盾の反射と半径の上下限")
			var shots: Array = core.hostiles_snapshot()
			check(shots.size()==1 and shots[0].kind==2 and is_equal_approx(shots[0].life,float(definition.params.reflect_life)),"盾の寿命の値で危険な反射弾を1つ作る")
			var record: Dictionary = core.attack_snapshot()[0]
			check(record.source_id==source_id and record.source_alive,"反射元の敵IDと生存参照を分けて保持する")
			check(core.projectiles_snapshot().is_empty(),"盾に当たった味方弾を同じ更新で消す")
		# この弾を、同じ更新順と保持点から先へ進める。
		pending = bridge.checkpoint()
		var saved_hp: float = core.enemies_snapshot()[0].hp
		run.projectiles.fire_shot(target,PI,10.0,{"speed":1200.0,"r":7.0,"life":4.0})
		core.fire_shot(target,PI,10.0,{"speed":1200.0,"r":7.0,"life":4.0})
		run.projectiles._update_friendly(0.5)
		core.step_projectiles(0.5)
		check(core.hostiles_snapshot().size()==1 and core.enemies_snapshot()[0].hp==saved_hp,"反射の待機中も味方弾を止め、反射弾とダメージを重ねない")
		run.projectiles._update_hostile(0.1)
		core.step_hostiles(0.1)
		reflected_states(run,core,"反射後の直進")
		var visual := 0
		var stone_visual := 0
		for entry: Dictionary in session.cpp_resources.visuals:
			if entry.role==13: visual = entry.id
			if entry.role==12: stone_visual = entry.id
		var frame: Dictionary = bridge.read_render(Rect2(-1800,-500,1500,1000)).value
		var visible := false
		for batch: Dictionary in frame.batches:
			if batch.visual_id==visual: visible = batch.ids.size()==1 and is_equal_approx(batch.transforms[0],10.0)
		check(visible,"反射弾の半径・位置・進む向きを専用のまとめ描きへ渡す")
		var presentation: RunPresentation = session.view.get_node("RunPresentation")
		presentation._present_cpp(0.0)
		check(presentation.frame_view.batches.has(visual),"ピンクの尾・本体・明るい芯の反射弾を通常画面へ出す")
		var shown: InstanceBatch = presentation.frame_view.batches.get(visual)
		if shown!=null:
			var arrays: Array = shown.multimesh.mesh.surface_get_arrays(0)
			check(arrays[Mesh.ARRAY_COLOR].has(Color("#ff84df")) and arrays[Mesh.ARRAY_COLOR].has(Color("#f45ec5")) and arrays[Mesh.ARRAY_COLOR].has(Color("#fff0fc")),"反射弾の尾・本体・芯の色を保つ")
		bridge.command("dev_kill",{"entity_id":source_id,"cause":"ram"})
		check(core.hostiles_snapshot().size()==1 and not core.attack_snapshot()[0].source_alive,"盾が倒れても反射弾を寿命まで残す")
		run.projectiles._update_hostile(0.5)
		core.step_hostiles(0.5)
		reflected_states(run,core,"機体への命中と終了")
		var hit: Dictionary = core.ship_snapshot()
		check(is_equal_approx(hit.ship_hp,run.state.ship_hp) and is_equal_approx(hit.ship_hp,config.base_hp-float(definition.params.reflect_dmg)),"反射弾を共通の機体被弾へ通す")
		bridge.restore(pending.value)
		core.step_hostiles(0.1)
		core.step_hostiles(0.5)
		check(core.hostiles_snapshot().is_empty() and core.ship_snapshot()==hit,"保持点から反射弾と同じ命中・消滅を再現する")
		bridge.restore(pending.value)
		run.projectiles.clear_hostile()
		run.state.ship_hp = config.base_hp
		run.state.ship_invuln = 0.0
		reflected_shot(run,core,source,target,17.0)
		# C++には保持点の弾があるため、上で新規に追加された分を残さない。
		# 盾は保持点のクールダウン中なので、新しい反射弾は生成されない。
		run.projectiles.stone_hostile(Rect2(-1800,-500,1500,1000),0.1)
		bridge.command("dev_stone_hostiles",{"duration":0.1,"view":Rect2(-1800,-500,1500,1000)})
		run.projectiles._update_hostile(0.05)
		core.step_hostiles(0.05)
		reflected_states(run,core,"石化した反射弾")
		frame = bridge.read_render(Rect2(-1800,-500,1500,1000)).value
		var stone_shown := false
		for batch: Dictionary in frame.batches:
			if batch.visual_id==stone_visual: stone_shown = batch.ids.size()==1
		check(stone_shown,"石化した反射弾にも同じ灰色の表示を重ねる")
		var at: Vector2 = run.projectiles.hostile_pos[0]
		run.state.ship_pos = at
		bridge.command("dev_ship_motion",{"position":at,"velocity":Vector2.ZERO})
		run.projectiles._update_hostile(0.02)
		core.step_hostiles(0.02)
		check(core.hostiles_snapshot().is_empty() and is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp),"石化した反射弾は触れると被弾せずに消える")
	# 十分に広い表示範囲で、地形と機体を避け、反射弾自体の寿命で終了させる。
	bridge.restore(empty.value)
	run.projectiles.clear_hostile()
	var far_source_position := Vector2(1500,1500)
	var far_source: int = run.enemies.spawn(definition,far_source_position)
	bridge.command("dev_spawn",{"definition_id":"shield","position":far_source_position})
	reflected_shot(run,core,far_source,Vector2(1800,1500),7.0)
	var outside := Vector2(-3000,3000)
	run.state.ship_pos = outside
	run.state.view_center = Vector2(2000,1500)
	run.state.view_half = Vector2(10000,10000)
	bridge.command("dev_ship_motion",{"position":outside,"velocity":Vector2.ZERO})
	core.set_motion_context(outside,run.state.view_center,run.state.view_half)
	run.projectiles._update_hostile(float(definition.params.reflect_life)+0.01)
	core.step_hostiles(float(definition.params.reflect_life)+0.01)
	if not reflected_lifetime: reflected_states(run,core,"地形・機体・画面外に依存しない寿命終了")
	var lifetime := 0
	# 個別Systemを直接進める確認では、通常Runnerの末尾に相当する通知の確定も行う。
	for event: Dictionary in core.drain_events():
		if event.type==&"attack_retired" and event.reason=="lifetime": lifetime += 1
	check(core.hostiles_snapshot().is_empty() and lifetime==1,"盾の寿命の値を使い切った反射弾を一度だけ回収する")
	if not pending.is_empty(): bridge.release_checkpoint(pending.value)
	bridge.release_checkpoint(empty.value)
	await get_tree().process_frame
	lab.free()
	session.free()
	reflected_finished = true

func check_cpp_shield() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 900.0
	config.planet_radius = 100.0
	config.base_hp = 100.0
	config.base_attack = 100.0
	config.ram_speed_ratio = 0.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	var stage := RuntimeStage.new()
	stage.index = 82
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["shield"])
	var output := "res://.content/dev/run_shield"
	var builder = load("res://tools/content/build_run_content.gd")
	var built: Error = builder.build(stage,config,output,"盾の防御・取得・表示".sha256_text())
	if not shield_red: check(built==OK,"盾の実効値と外観を生成する")
	if built!=OK: return
	var path := output.path_join("stage_82.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":287},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	if not shield_red: check(session.bridge!=null,"盾の通常のランと表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	if shield_red:
		bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2(1000,0)})
		bridge.command("dev_spawn",{"definition_id":"shield","position":target+Vector2(25,0)})
		core.collide_ship(target-Vector2(100,0),config.ship_radius)
		bridge.command("set_ui_overlay",{"active":false})
		check(core.ship_snapshot().ship_shield_t>0.0 and bridge.read_frame().value.ui.get("ship_shield_visual",0)>0,"奪った盾の外観を保持して表示へ渡す")
		session.free()
		shield_finished = true
		return
	var initial: Dictionary = bridge.checkpoint()
	var notices := []
	bridge.subscribe("shield_check",func(frame: Dictionary):
		for event: Dictionary in frame.events:
			if event.type in [&"shield_stolen",&"shield_block",&"shield_expired"]: notices.append({"type":event.type,"data":event.payload})
		return true)
	var comparison = COMPARE.new()
	for mode in ["front_ram","rear_ram","front_shots","back_shots","movement"]:
		bridge.restore(initial.value)
		notices.clear()
		var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
		add_child(lab)
		await lab.reset({"seed":287,"empty":true,"field":{"terrain":true,"rocks":false,"gimmicks":false},"invincible":false,
			"config":{"start_radius":900.0,"planet_radius":100.0,"base_hp":100.0,"base_attack":100.0,"ram_speed_ratio":0.0}})
		var run: RunSimulation = lab.run
		run.state.ship_pos = target
		run.state.ship_vel = Vector2.ZERO
		run.state.enemy_aim = target
		run.state.view_center = target
		run.state.view_half = Vector2(640,360)
		run.enemies._next_id = 1
		run.enemies._lod = core.inspect().ticks
		run.state.rng.state = int(core.inspect().rng_state)
		var definition := run.enemies.def_of(&"shield")
		var position := target+Vector2(25,0) if mode=="rear_ram" else target-Vector2(25,0) if mode=="front_ram" else target+Vector2(480,200)
		var row := run.enemies.spawn(definition,position)
		var id: int = bridge.command("dev_spawn",{"definition_id":"shield","position":position}).value
		run.combat.rebuild_grid()
		core.set_motion_context(target,target,Vector2(640,360))
		if mode.ends_with("ram"):
			var velocity := Vector2(1000,0) if mode=="rear_ram" else Vector2(-1000,0)
			run.state.ship_vel = velocity
			bridge.command("dev_ship_motion",{"position":target,"velocity":velocity})
			var from := target-velocity.normalized()*100.0
			var bounced := run.combat.collide_ship(from,config.ship_radius,null)
			check(core.collide_ship(from,config.ship_radius)==bounced,"盾への体当たりの前後判定: "+mode)
		elif mode.ends_with("shots"):
			var from := position+Vector2(200,0) if mode=="front_shots" else position-Vector2(200,0)
			var angle := PI if mode=="front_shots" else 0.0
			for repeat in 2:
				var options := {"speed":1200.0,"life":1.0,"pierce_left":5,"knock":0.0,"weapon_id":&"W01"}
				run.projectiles.fire_shot(from,angle,2.0,options)
				core.fire_shot(from,angle,2.0,options)
				run.projectiles._update_friendly(0.2)
				core.step_projectiles(0.2)
			check(core.hostiles_snapshot().size()==(1 if mode=="front_shots" else 0),"前面だけ反射し待ち時間中の反射を重ねない: "+mode)
		else:
			for step in 4:
				run.enemies.tick(0.125,0.125)
				core.step(0.125)
			var moved: Dictionary = core.enemies_snapshot()[0]
			check(Vector2(moved.pos[0],moved.pos[1]).distance_to(run.enemies.table.pos[row])<0.02 and Vector2(moved.vel[0],moved.vel[1]).distance_to(run.enemies.table.vel[row])<0.02 and absf(moved.facing-run.enemies.table.facing[row])<0.0001,"盾の追跡・旋回を共通の操舵へ通す")
			var relocated := target+Vector2(500,-100)
			check(bridge.command("dev_relocate",{"entity_id":id,"position":relocated}).ok and core.enemies_snapshot()[0].id==id,"再配置で盾の個体IDを保つ")
			bridge.command("dev_kill",{"entity_id":id,"cause":"ram"})
			check(core.enemies_snapshot()[0].dead==1,"再配置した盾も通常の撃破へ通る")
			lab.free()
			continue
		check(is_equal_approx(core.enemies_snapshot()[0].hp,run.enemies.table.hp[row]) and core.enemies_snapshot()[0].dead==run.enemies.table.dead[row],"前後からの命中と盾の生死が一致する: "+mode)
		check(is_equal_approx(core.ship_snapshot().ship_shield_t,run.state.ship_shield_t),"盾の取得と持続時間が一致する: "+mode)
		bridge.command("set_ui_overlay",{"active":false})
		if mode=="rear_ram":
			check(notices.size()>0 and notices[0].type==&"shield_stolen" and notices[0].data.get("enemy_type")==&"shield","奪った敵の種類を表示通知へ渡す")
			var held: Dictionary = bridge.checkpoint()
			var presentation: RunPresentation = session.view.get_node("RunPresentation")
			presentation._present_cpp(0.0)
			var holder: Node = presentation.frame_view.get("_shield_holder")
			check(holder!=null and holder.get_node_or_null("ScutumGuardLighting/ScutumGuard/Armor")!=null,"奪った盾の本体・装甲・法線を機体へ表示する")
			await get_tree().process_frame
			for elapsed in [0.21,0.01,float(definition.params.shield_time)]:
				run.ship.intent.touch = true
				run.ship.tick(elapsed,elapsed)
				core.step_ship(elapsed,elapsed,{"touch":true})
				run.state.view_center = run.state.ship_pos
				core.set_motion_context(core.ship_snapshot().ship_pos,run.state.ship_pos,Vector2(640,360))
				var values := {"kind":0,"pos":run.state.ship_pos,"vel":Vector2.ZERO,"speed":0.0,"r":7.0,"life":1.0,"dmg":7.0,"slow":0.2,"turn":0.0}
				run.projectiles._add_hostile(values.pos,values.vel,values.speed,values.r,values.life,values.dmg,values.slow,values.turn,0)
				core.spawn_hostile(values)
				run.projectiles._update_hostile(0.01)
				core.step_hostiles(0.01)
				check(is_equal_approx(core.ship_snapshot().ship_hp,run.state.ship_hp) and is_equal_approx(core.ship_snapshot().ship_shield_t,run.state.ship_shield_t),"取得後の防御・待ち時間・失効後の被弾が一致する")
			bridge.command("set_ui_overlay",{"active":false})
			presentation._present_cpp(0.0)
			check(core.ship_snapshot().ship_hp<config.base_hp and not holder.get_node("ScutumGuardLighting").visible,"失効した盾は表示を消して被弾する")
			bridge.restore(held.value)
			bridge.collect_frame()
			presentation._present_cpp(0.0)
			check(bridge.read_frame().value.ui.get("ship_shield_visual",0)>0 and holder.get_node("ScutumGuardLighting").visible,"盾を奪った保持点から外観と防御を復元する")
			bridge.release_checkpoint(held.value)
		lab.free()
	bridge.release_checkpoint(initial.value)
	session.free()
	shield_finished = true
