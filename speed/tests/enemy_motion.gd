## 移動・旋回・発射時刻の共通処理は、種類の追加と独立した補助へ置く。
extends Node
var failed := 0
var gunner_finished := false
var gunner_cycle := false
var missile_enemy := false
var battleship_enemy := false
var ranged_type_override := ""
var ranged_retry := false
func check(ok: bool, label: String) -> void:
	if ranged_retry and "発射位置・向き・弾" not in label and "戦艦の確認が最後まで進んだ" not in label: return
	if gunner_cycle and label not in ["周期を過ぎる大きな更新でも1更新に1回ずつ発射する","射撃型の確認が最後まで進んだ"]: return
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	if "--cpp-enemy-scalar-precision" in OS.get_cmdline_user_args():
		await check_cpp_gunner()
		check(gunner_finished,"敵の時間と向きの精度確認を最後まで実施する")
		print("[cpp_enemy_scalar_precision] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-battleship-enemy" in OS.get_cmdline_user_args():
		battleship_enemy = true
		ranged_type_override = "battleship"
		ranged_retry = "--cpp-battleship-reuse-fixes" in OS.get_cmdline_user_args()
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--cpp-ranged-type="): ranged_type_override = argument.get_slice("=",1)
		await check_cpp_gunner()
		check(gunner_finished,"戦艦の確認が最後まで進んだ: "+ranged_type_override)
		print("[cpp_battleship_enemy] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-dash-enemy" in OS.get_cmdline_user_args():
		await check_cpp_dash()
		print("[cpp_dash_enemy] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-part-enemy" in OS.get_cmdline_user_args():
		await check_cpp_part()
		print("[cpp_part_enemy] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-drift-enemy" in OS.get_cmdline_user_args():
		await check_cpp_drift()
		print("[cpp_drift_enemy] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-rocket-enemy" in OS.get_cmdline_user_args():
		await check_cpp_rocket()
		print("[cpp_rocket_enemy] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-missile-enemy" in OS.get_cmdline_user_args():
		missile_enemy = true
		await check_cpp_gunner()
		check(gunner_finished,"ミサイル艇の確認が最後まで進んだ")
		print("[cpp_missile_enemy] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-gunner" in OS.get_cmdline_user_args() or "--cpp-gunner-cycle" in OS.get_cmdline_user_args():
		gunner_cycle = "--cpp-gunner-cycle" in OS.get_cmdline_user_args()
		await check_cpp_gunner()
		check(gunner_finished,"射撃型の確認が最後まで進んだ")
		print("[cpp_gunner] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	session.auto_step = false
	var enemies: EnemySystem = session.sim.enemies
	var motion = enemies.get("motion")
	check(motion != null, "共通の移動補助を取得できる")
	if motion != null:
		var def := enemies.def_of(&"drifter").duplicate(true) as EnemyDef
		def.params = {"telegraph": 1.0, "fire_interval": 3.0}
		var row: int = enemies.spawn(def, Vector2.ZERO)
		motion._steer_to(row, Vector2(100, 0), 100.0, 10.0, 0.1)
		check(enemies.table.vel[row].is_equal_approx(Vector2(100, 0)), "指定の速さと加速で目標へ向かう")
		enemies.table.facing[row] = 0.0
		motion._turn_toward(row, PI, 1.0, 0.1)
		check(is_equal_approx(absf(enemies.table.facing[row]), 0.1), "旋回速度の上限を保つ")
		enemies.table.fire_t[row] = 0.5
		check(not motion._gun_timer(row, 0.1) and enemies.table.charge[row] > 0.0, "発射前に予告が進む")
		check(motion._gun_timer(row, 0.5) and enemies.table.fire_t[row] == 3.0, "発射時に次の間隔へ戻す")
		var state: RunState = session.sim.state
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

func gunner_states(run: RunSimulation, core, row: int, id: int, comparison, label: String) -> void:
	if ranged_retry:
		if label in ["normal/6","normal/7"]: ranged_shot_states(run,core,comparison,label)
		return
	if gunner_cycle: return
	var found := false
	for enemy: Dictionary in core.enemies_snapshot():
		if enemy.id!=id: continue
		found = true
		var pos := Vector2(enemy.pos[0],enemy.pos[1])
		var vel := Vector2(enemy.vel[0],enemy.vel[1])
		check(pos.distance_to(run.enemies.table.pos[row])<0.02 and vel.distance_to(run.enemies.table.vel[row])<0.02 and absf(enemy.facing-run.enemies.table.facing[row])<0.0001,label+"の距離保持・旋回・移動")
		check(enemy.dead==run.enemies.table.dead[row],label+"の生死")
	for motion: Dictionary in core.enemy_motion_snapshot():
		if motion.id!=id: continue
		check(is_equal_approx(motion.fire_t,run.enemies.table.fire_t[row]) and is_equal_approx(motion.charge,run.enemies.table.charge[row]),label+"の発射周期と予告")
	check(found,label+"の個体IDが有効")
	ranged_shot_states(run,core,comparison,label)

func ranged_shot_states(run: RunSimulation, core, comparison, label: String) -> void:
	var shots := []
	var ps := run.projectiles
	for i in ps.hostile_alive.size():
		if ps.hostile_alive[i]==0: continue
		shots.append({"pos":ps.hostile_pos[i],"vel":ps.hostile_vel[i],"life":ps.hostile_life[i],"kind":ps.hostile_kind[i]})
	var current := []
	for shot: Dictionary in core.hostiles_snapshot(): current.append({"pos":shot.pos,"vel":shot.vel,"life":shot.life,"kind":shot.kind})
	var difference: String = comparison.difference(comparison.plain(shots),comparison.plain(current))
	check(difference.is_empty(),label+"の発射位置・向き・弾: "+difference)

func check_cpp_gunner() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 900.0
	config.planet_radius = 100.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	var stage := RuntimeStage.new()
	stage.index = 84
	stage.resources = StageResources.new()
	var type: String = ranged_type_override if not ranged_type_override.is_empty() else ("missile" if missile_enemy else "gunner")
	stage.resources.enemy_ids = PackedStringArray([type])
	var output := "res://.content/dev/run_gunner"
	var builder = load("res://tools/content/build_run_content.gd")
	var built: Error = builder.build(stage,config,output,"射撃型の行動と予算".sha256_text())
	check(built==OK,"射撃型の実効値・外観・射撃の定義を生成する")
	if built!=OK: return
	var path := output.path_join("stage_84.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":976},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"射撃型の通常のランと表示を準備する: %s / %s" % [type,session.cpp_error])
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	var initial: Dictionary = bridge.checkpoint()
	if "--cpp-enemy-scalar-precision" in OS.get_cmdline_user_args():
		core.configure_attack_budget({"enabled":false})
		var id: int = bridge.command("dev_spawn",{"definition_id":"gunner","position":target+Vector2(800,120)}).value
		core.set_motion_context(target,target,Vector2(640,360))
		check(core.set_enemy_motion(id,{"fire_t":0.8,"charge":0.1234567890123,"facing":0.2345678901234}),"倍精度の時間と向きを設定できる")
		var state: Dictionary = core.enemy_motion_snapshot()[0]
		check(state.fire_t==0.8 and state.charge==0.1234567890123 and core.enemies_snapshot()[0].facing==0.2345678901234,"敵表の倍精度を入力から状態まで保つ")
		core.step(0.8)
		check(core.hostiles_snapshot().size()==1,"残り時間と同じ更新で射撃し、丸めによって次の更新へ遅れない")
		gunner_finished = true
		session.free()
		return
	var comparison = preload("res://tools/compare_runtime.gd").new()
	var budget_probe = preload("res://tests/native_attack_budget.gd").new()
	for kind in (["normal"] if gunner_cycle or ranged_retry else ["normal","death","reuse"]):
		bridge.restore(initial.value)
		var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
		add_child(lab)
		await lab.reset({"seed":976,"empty":true,"field":{"terrain":true,"rocks":false,"gimmicks":false},"invincible":false,
			"config":{"start_radius":900.0,"planet_radius":100.0}})
		var run: RunSimulation = lab.run
		run.state.ship_pos = target
		run.state.enemy_aim = target
		run.state.view_center = target
		run.state.view_half = Vector2(640,360)
		run.state.world_time = core.inspect().world_time
		run.state.time = core.inspect().time
		run.enemies._lod = core.inspect().ticks
		run.enemies._next_id = 1
		run.state.rng.state = int(core.inspect().rng_state)
		var director = run.projectiles.director
		director.formation_mode = true
		core.set_attack_formation_mode(true)
		director.configure({"enabled":true,"budget":0.0,"jitter":0.0})
		core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
		var definition := run.enemies.def_of(StringName(type))
		var expected_volley := int(definition.params.volley) if battleship_enemy else 1
		var position := target+Vector2(480,120)
		var row := run.enemies.spawn(definition,position)
		var id: int = bridge.command("dev_spawn",{"definition_id":type,"position":position}).value
		check(run.enemies.table.id[row]==id and id==1,"射撃型を同じ個体IDと乱数の位置から生成する: "+kind)
		run.enemies.table.fire_t[row] = 0.25
		core.set_enemy_motion(id,{"fire_t":0.25})
		core.set_motion_context(target,target,Vector2(640,360))
		var warning: Dictionary = {}
		var warning_state: Array = []
		var emitted_count := 0
		var previous_count := 0
		for step in 8:
			if step==2:
				director.configure({"enabled":true,"budget":1.0,"jitter":0.0})
				core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
			if step==3 and kind=="death":
				run.combat.kill_enemy(row,{"cause":&"ram"})
				bridge.command("dev_kill",{"entity_id":id,"cause":"ram"})
			if step==3 and kind=="reuse":
				run.enemies._release_row(row)
				core.remove_enemy(id)
				row = run.enemies.spawn(definition,position)
				var old_id := id
				id = bridge.command("dev_spawn",{"definition_id":type,"position":position}).value
				check(id!=old_id and run.enemies.table.id[row]==id and core.hostiles_snapshot().is_empty(),"予告中の行を再利用しても古い射撃や所有者を引き継がない")
				run.enemies.table.fire_t[row] = 0.25
				core.set_enemy_motion(id,{"fire_t":0.25})
			if step in [4,5]:
				run.enemies.table.held[row] = 1 if step==4 else 0
				core.set_enemy_motion(id,{"held":step==4})
			if step==6 and kind=="normal":
				run.projectiles.clear_hostile()
				bridge.command("dev_clear_hostile",{})
				previous_count = 0
			var dt: float = (float(definition.params.fire_interval)+1.0 if missile_enemy else 3.0) if step==6 else 0.125
			run.state.world_time += dt
			run.state.time += dt
			director.advance(run.state.world_time,run.enemies)
			core.advance_attack_budget(run.state.world_time)
			run.enemies.tick(dt,dt)
			core.step(dt)
			emitted_count += maxi(0,core.hostiles_snapshot().size()-previous_count)
			previous_count = core.hostiles_snapshot().size()
			gunner_states(run,core,row,id,comparison,"%s/%d" % [kind,step])
			if step<2 and not ranged_retry:
				check(core.hostiles_snapshot().is_empty() and run.enemies.table.charge[row]==0.0,"枠を待つ間は予告と射撃を始めず追跡する: %s/%d" % [kind,step])
			if (missile_enemy or battleship_enemy) and not ranged_retry:
				var budget_diff: String = comparison.difference(budget_probe.snapshot(director),core.attack_budget_snapshot())
				check(budget_diff.is_empty(),"射撃する敵の予算と待機・残留枠が一致する: "+budget_diff)
			if step==2 and kind=="normal" and not gunner_cycle and not ranged_retry:
				warning = bridge.checkpoint()
				warning_state = core.enemy_motion_snapshot()
				var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(800,500),Vector2(1600,1000))).value
				var marked := false
				for batch: Dictionary in frame.batches:
					var mark_name := "battleship" if battleship_enemy else ("missile" if missile_enemy else "gunner")
					if batch.has(mark_name): marked = batch[mark_name].size()==(6 if battleship_enemy else 5) and batch[mark_name][4]>0.0
				check(marked,"射撃の予告を表示用の値へ渡す")
				if battleship_enemy:
					for batch: Dictionary in frame.batches:
						if batch.has("battleship"): check(is_equal_approx(batch.battleship[2],run.enemies.table.r[row]) and is_equal_approx(batch.battleship[5],definition.weak_arc),"大型の当たり半径と背面の弱点を同じ本体へ渡す")
				var presentation: RunPresentation = session.view.get_node("RunPresentation")
				presentation._present_cpp(0.0)
				check(presentation.frame_view.apply_frame(frame) and presentation.frame_view.get("_battleship" if battleship_enemy else ("_missile" if missile_enemy else "_gunner")).size()==(6 if battleship_enemy else 5),"射撃型の本体と砲口の光を通常画面へ表示する")
				await get_tree().process_frame
		if kind=="normal" and not ranged_retry:
			check(emitted_count==2*expected_volley and core.hostiles_snapshot().size()==run.projectiles.hostile_slots.live,"周期を過ぎる大きな更新でも1更新に1回ずつ発射する")
			if not gunner_cycle:
				bridge.restore(warning.value)
				check(core.enemy_motion_snapshot()==warning_state,"予告中の位置と射撃状態を復元する")
				core.step(0.125)
				check(core.hostiles_snapshot().size()==expected_volley,"予告中の保持点から同じ発射へ進む")
				if missile_enemy or battleship_enemy:
					var fired: Dictionary = bridge.checkpoint()
					check(bridge.command("dev_kill",{"entity_id":id,"cause":"ram"}).ok,"弾の飛行中に発生元を倒す")
					var parent_gone := true
					var source_count := 0
					for attack: Dictionary in core.attack_snapshot():
						if attack.source_id==id:
							source_count += 1
							parent_gone = parent_gone and not attack.source_alive
					check(parent_gone and source_count==expected_volley and core.hostiles_snapshot().size()==expected_volley,"親消失後も発射済みの弾と出どころを保つ")
					core.step_hostiles(5.0)
					check(core.hostiles_snapshot().is_empty(),"発射済みの弾を命中または寿命で終了する")
					check(bridge.restore(fired.value).ok,"発射済みの敵と弾を値から復帰する")
					var pending_shots: Array = core.hostiles_snapshot()
					core.step_hostiles(0.125)
					var advanced_shots: Array = core.hostiles_snapshot()
					check(bridge.restore(fired.value).ok and core.hostiles_snapshot()==pending_shots,"保持元へ飛行中の変更を漏らさない")
					core.step_hostiles(0.125)
					check(core.hostiles_snapshot()==advanced_shots,"復帰後も同じ追尾と飛行になる")
					var restored_id := id
					var old_handle: PackedInt64Array = core.enemy_handle(restored_id)
					check(bridge.command("dev_remove",{"entity_id":restored_id}).ok,"発生元を撃破と別の退場で片付ける")
					check(not core.valid_enemy_handle(old_handle) and core.hostiles_snapshot().size()==expected_volley,"退場は旧個体の参照を失効し発射済み弾を保つ")
					bridge.release_checkpoint(fired.value)
				bridge.release_checkpoint(warning.value)
		elif kind=="death": check(core.hostiles_snapshot().is_empty(),"予告中に倒れた敵は発射しない")
		lab.free()
	bridge.release_checkpoint(initial.value)
	session.free()
	budget_probe.free()
	gunner_finished = true

func rocket_state(run: RunSimulation, core, row: int, id: int, label: String) -> void:
	for enemy: Dictionary in core.enemies_snapshot():
		if enemy.id!=id: continue
		check(Vector2(enemy.pos[0],enemy.pos[1]).distance_to(run.enemies.table.pos[row])<0.02 and Vector2(enemy.vel[0],enemy.vel[1]).distance_to(run.enemies.table.vel[row])<0.02 and absf(enemy.facing-run.enemies.table.facing[row])<0.0001,label+"の位置・速度・向きが一致する")
		check(enemy.dead==run.enemies.table.dead[row],label+"の死亡印が一致する")
	for motion: Dictionary in core.enemy_motion_snapshot():
		if motion.id==id: check(motion.mode==run.enemies.table.mode[row] and is_equal_approx(motion.timer,maxf(0.0,run.enemies.table.timer[row])),label+"の飛行状態と寿命が一致する")

func check_cpp_rocket() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 900.0
	config.planet_radius = 100.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	var definition := load("res://data/enemies/rocket.tres").duplicate(true) as EnemyDef
	definition.params.life = 0.35
	var stage := RuntimeStage.new()
	stage.index = 85
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["rocket"])
	var output := "res://.content/dev/run_rocket"
	var builder = load("res://tools/content/build_run_content.gd")
	var built: Error = builder.build(stage,config,output,"ロケット敵の行動と爆発".sha256_text(),{&"rocket":definition})
	check(built==OK,"制作からrocketの編集値・行動・爆発表示を生成する")
	if built!=OK: return
	var path := output.path_join("stage_85.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":977},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"ロケット敵の通常の表示とランを準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	var initial: Dictionary = bridge.checkpoint()
	var cases := ["life","fuse","death","reuse"]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--cpp-rocket-case="): cases = [argument.get_slice("=",1)]
	for kind in cases:
		bridge.restore(initial.value)
		var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
		add_child(lab)
		await lab.reset({"seed":977,"empty":true,"field":{"terrain":true,"rocks":false,"gimmicks":false},"invincible":false,"config":{"start_radius":900.0,"planet_radius":100.0}})
		var run: RunSimulation = lab.run
		run.state.ship_pos = target
		run.state.enemy_aim = target
		run.state.view_center = target
		run.state.view_half = Vector2(640,360)
		run.state.world_time = core.inspect().world_time
		run.enemies._lod = core.inspect().ticks
		run.enemies._next_id = 1
		run.state.rng.state = int(core.inspect().rng_state)
		core.set_motion_context(target,target,Vector2(640,360))
		var position := target+Vector2(40 if kind=="fuse" else 500,0)
		var row := run.enemies.spawn(definition,position)
		var id: int = bridge.command("dev_spawn",{"definition_id":"rocket","position":position}).value
		var director = run.projectiles.director
		director.formation_mode = true
		core.set_attack_formation_mode(true)
		director.configure({"enabled":true,"budget":0.0,"jitter":0.0})
		core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
		run.state.world_time += 0.01
		director.advance(run.state.world_time,run.enemies)
		core.advance_attack_budget(run.state.world_time)
		run.enemies.tick(0.01,0.01)
		core.step(0.01)
		rocket_state(run,core,row,id,kind+"の予算待機")
		check(run.enemies.table.mode[row]==EnemyTable.Mode.MOVE and core.hazards_snapshot().is_empty(),"予算を待つ間は飛行と起爆を始めない")
		director.configure({"enabled":true,"budget":1.0,"jitter":0.0})
		core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
		run.state.world_time += 0.01
		director.advance(run.state.world_time,run.enemies)
		core.advance_attack_budget(run.state.world_time)
		run.enemies.tick(0.01,0.01)
		core.step(0.01)
		rocket_state(run,core,row,id,kind+"の初回")
		if kind=="life":
			var body_visual := 0
			for entry: Dictionary in session.cpp_resources.visuals:
				if entry.role==14:
					body_visual = entry.id
					check(entry.points==RunPresentation._placeholder_points(definition.shape),"ロケット敵の矢じりを同じ固定頂点から表示する")
			var body_frame: Dictionary = bridge.read_render(Rect2(target-Vector2(800,500),Vector2(1600,1000))).value
			var body_visible := false
			for batch: Dictionary in body_frame.batches:
				if batch.visual_id==body_visual: body_visible = batch.ids.has(id) and batch.colors[0]==definition.color
			var presentation: RunPresentation = session.view.get_node("RunPresentation")
			check(body_visible and presentation.frame_view.apply_frame(body_frame),"ロケット敵の本体を同じ色・向き・半径で通常画面へ渡す")
			await get_tree().process_frame
		var flight: Dictionary = bridge.checkpoint()
		var flight_state: Array = core.enemy_motion_snapshot()
		if kind=="death":
			run.combat.kill_enemy(row,{"cause":&"ram"})
			check(bridge.command("dev_kill",{"entity_id":id,"cause":"ram"}).ok,"飛行中のロケット敵を倒す")
		if kind=="reuse":
			run.enemies._release_row(row)
			core.remove_enemy(id)
			var old_id := id
			row = run.enemies.spawn(definition,position)
			id = bridge.command("dev_spawn",{"definition_id":"rocket","position":position}).value
			check(id!=old_id and not core.set_enemy_motion(old_id,{"timer":5.0}),"行の再利用で古いロケットのIDと寿命を失効する")
			rocket_state(run,core,row,id,"再利用直後")
		for step in (4 if kind=="life" else 1):
			var dt := 0.125 if kind=="life" else 0.01
			run.state.world_time += dt
			director.advance(run.state.world_time,run.enemies)
			core.advance_attack_budget(run.state.world_time)
			run.enemies.tick(dt,dt)
			core.step(dt)
			rocket_state(run,core,row,id,"%s/%d" % [kind,step])
		if kind=="fuse":
			check(core.hazards_snapshot().size()==1 and run.projectiles.hazard_slots.live==1,"近接起爆で同じ円形爆発を作る")
			var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(800,500),Vector2(1600,1000))).value
			var visible := false
			for shape: Dictionary in frame.shapes:
				if shape.kind==3: visible = is_equal_approx(shape.widths[0],definition.params.blast_radius)
			var presentation: RunPresentation = session.view.get_node("RunPresentation")
			check(visible and presentation.frame_view.apply_frame(frame),"共通の爆発の円と白い輪を通常画面へ渡す")
			await get_tree().process_frame
			check(bridge.command("dev_remove",{"entity_id":id}).ok and core.hazards_snapshot().size()==1,"親を先に退場させても起爆済みの爆発を保つ")
			var blast: Dictionary = bridge.checkpoint()
			run.projectiles._update_hazards(0.01)
			core.step_hazards(0.01)
			var hp: float = core.ship_snapshot().ship_hp
			check(is_equal_approx(hp,run.state.ship_hp) and is_equal_approx(hp,config.base_hp-float(definition.params.blast_dmg)),"爆発は機体へ実効ダメージを一度だけ与える")
			core.step_hazards(0.01)
			check(is_equal_approx(core.ship_snapshot().ship_hp,hp),"爆発の表示が残っていても再命中しない")
			core.step_hazards(0.25)
			check(core.hazards_snapshot().is_empty(),"円形爆発を編集元と同じ寿命で終了する")
			check(bridge.restore(blast.value).ok and core.hazards_snapshot().size()==1,"親消失後の爆発を値から復帰する")
			core.step_hazards(0.01)
			check(is_equal_approx(core.ship_snapshot().ship_hp,hp),"爆発の復帰後も同じ一度の命中になる")
			bridge.release_checkpoint(blast.value)
		elif kind=="life": check(core.hazards_snapshot().is_empty() and run.enemies.table.dead[row]!=0,"飛行寿命で爆発やドロップを出さず退場する")
		elif kind=="death": check(core.hazards_snapshot().is_empty(),"飛行中に倒したロケット敵は自爆しない")
		check(bridge.restore(flight.value).ok and core.enemy_motion_snapshot()==flight_state,"飛行中の向き・残り寿命・予算を値で戻す: "+kind)
		bridge.release_checkpoint(flight.value)
		lab.free()
	bridge.release_checkpoint(initial.value)
	session.free()

func check_cpp_drift() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 900.0
	config.planet_radius = 100.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: config.set(key,0)
	var definition := load("res://data/enemies/hydra_rubble.tres").duplicate(true) as EnemyDef
	definition.params.life = 0.35
	var stage := RuntimeStage.new()
	stage.index = 83
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["hydra_rubble"])
	var output := "res://.content/dev/run_drift"
	var builder = load("res://tools/content/build_run_content.gd")
	var built: Error = builder.build(stage,config,output,"漂流する瓦礫の生成と終了".sha256_text(),{&"hydra_rubble":definition})
	check(built==OK,"漂流する瓦礫の編集値と表示を生成する")
	if built!=OK: return
	var path := output.path_join("stage_83.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":978},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"漂流する瓦礫のランと表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":978,"empty":true,"field":{"terrain":true,"rocks":false,"gimmicks":false},"config":{"start_radius":900.0,"planet_radius":100.0}})
	var run: RunSimulation = lab.run
	run.state.ship_pos = target
	run.state.enemy_aim = target
	run.state.view_center = target
	run.state.view_half = Vector2(640,360)
	run.enemies._lod = core.inspect().ticks
	run.state.rng.state = int(core.inspect().rng_state)
	run.enemies._next_id = 1
	var position := target+Vector2(500,100)
	var options := {"vel":Vector2(150,50),"facing":0.3,"spin":1.7,"guard":0.08,"hit_cd":0.04}
	var row := run.enemies.spawn(definition,position,options)
	var id: int = core.spawn_enemy(&"hydra_rubble",position,options)
	core.set_motion_context(target,target,Vector2(640,360))
	var pending: Dictionary = {}
	var pending_state: Array = []
	var pending_enemies: Array = []
	for tick in 11:
		var change := {}
		match tick:
			1: change = {"held":true}
			2: change = {"held":false,"stone":0.05}
			3: change = {"knock_t":0.05}
			4: change = {"shove_time":0.05,"shove_vel":Vector2(-120,30)}
			5: change = {"slash_hold":true}
			6: change = {"slash_hold":false}
		if not change.is_empty():
			for key in change:
				var column = run.enemies.table.get(key)
				column[row] = int(change[key]) if change[key] is bool else change[key]
				run.enemies.table.set(key,column)
			core.set_enemy_motion(id,change)
		run.enemies.tick(0.05,0.05)
		core.step(0.05)
		rocket_state(run,core,row,id,"漂流/%d" % tick)
		if tick==6:
			pending = bridge.checkpoint()
			pending_state = core.enemy_motion_snapshot()
			pending_enemies = core.enemies_snapshot()
			var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(800,500),Vector2(1600,1000))).value
			var presentation: RunPresentation = session.view.get_node("RunPresentation")
			check(presentation.frame_view.apply_frame(frame) and not frame.batches.is_empty(),"回転した瓦礫の本体を通常画面へ表示する")
			await get_tree().process_frame
	check(run.enemies.table.dead[row]!=0 and core.hazards_snapshot().is_empty(),"寿命で漂流する瓦礫を退場し攻撃を出さない")
	check(bridge.restore(pending.value).ok and core.enemy_motion_snapshot()==pending_state and core.enemies_snapshot()==pending_enemies,"漂流の回転・押し出し・寿命を値で復帰する")
	var before: float = core.enemies_snapshot()[0].hp
	var at := Vector2(core.enemies_snapshot()[0].pos[0],core.enemies_snapshot()[0].pos[1])
	bridge.command("dev_ship_motion",{"position":at-Vector2(10,0),"velocity":Vector2(1200,0)})
	core.rebuild_enemy_grid(config.grid_cell)
	check(core.collide_ship(at-Vector2(80,0),config.ship_radius) and is_equal_approx(core.enemies_snapshot()[0].hp,before),"硬い殻の瓦礫は速い体当たりを弾く")
	check(bridge.command("dev_damage",{"entity_id":id,"amount":10000.0,"cause":"bullet"}).value.killed,"漂流中の瓦礫を武器で倒せる")
	var old: PackedInt64Array = core.enemy_handle(id)
	core.remove_enemy(id)
	var replacement: int = core.spawn_enemy(&"hydra_rubble",position,{})
	check(replacement!=id and not core.valid_enemy_handle(old) and core.enemy_motion_snapshot()[0].spin==0.0 and core.enemy_motion_snapshot()[0].age==0.0,"再利用時に古い回転・寿命・外力を引き継がない")
	bridge.release_checkpoint(pending.value)
	lab.free()
	session.free()

func check_cpp_part() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 900.0
	config.planet_radius = 100.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: config.set(key,0)
	var types := ["hydra_bite","hydra_beam","hydra_thunder","hydra_debris","hydra_vortex","hydra_immortal"]
	var stage := RuntimeStage.new()
	stage.index = 82
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"]+types)
	var output := "res://.content/dev/run_part"
	var builder = load("res://tools/content/build_run_content.gd")
	var built: Error = builder.build(stage,config,output,"親に従う部位の生成と解放".sha256_text())
	check(built==OK,"親と6種類の部位の編集値と外観を生成する")
	if built!=OK: return
	var path := output.path_join("stage_82.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":979},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"部位の通常のランと表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	core.set_motion_context(target,target,Vector2(640,360))
	var parent: int = core.spawn_enemy(&"drifter",target+Vector2(500,0),{"is_boss":true,"attack_group":7,"attack_value":2.0,"attack_priority":3.0})
	core.set_enemy_motion(parent,{"held":true})
	var ids := PackedInt64Array()
	for i in types.size():
		var made: Dictionary = bridge.command("dev_spawn_part",{"parent_id":parent,"definition_id":types[i],"position":target+Vector2(200,i*50-150)})
		check(made.ok,"親から部位を生成する: "+types[i])
		if not made.ok:
			session.free()
			return
		ids.append(made.value)
		for item: Dictionary in core.enemy_motion_snapshot():
			if item.id==int(made.value): check(item.parent_id==parent and item.held==1,"部位は親のIDと保持状態を受け取る")
	core.set_enemy_motion(parent,{"held":false})
	for id in ids: core.set_enemy_motion(id,{"held":false,"vel":Vector2(120,30)})
	var moved := target+Vector2(240,-150)
	check(bridge.command("dev_move_part",{"parent_id":parent,"entity_id":int(ids[0]),"position":moved,"facing":0.7}).ok,"親から部位の位置と向きを更新する")
	core.step(0.05)
	var stopped := true
	for enemy: Dictionary in core.enemies_snapshot():
		if ids.has(enemy.id): stopped = stopped and Vector2(enemy.vel[0],enemy.vel[1])==Vector2.ZERO
	check(stopped,"部位は自分では移動せず速度を止める")
	var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(800,500),Vector2(1600,1000))).value
	var visible := PackedInt64Array()
	for batch: Dictionary in frame.batches:
		for id in batch.ids:
			if ids.has(id): visible.append(id)
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	check(visible.size()==types.size() and presentation.frame_view.apply_frame(frame),"親から配置した6種類の部位を通常画面へ表示する")
	await get_tree().process_frame
	var pending: Dictionary = bridge.checkpoint()
	var enemies: Array = core.enemies_snapshot()
	var motion: Array = core.enemy_motion_snapshot()
	var damage: Dictionary = bridge.command("dev_damage",{"entity_id":int(ids[0]),"amount":1.0,"cause":"bullet","direction":Vector2.RIGHT,"knock":1000.0})
	check(damage.ok and damage.value.applied==1.0,"部位に独立したHPでダメージを与える")
	for enemy: Dictionary in core.enemies_snapshot():
		if enemy.id==int(ids[0]): check(Vector2(enemy.vel[0],enemy.vel[1])==Vector2.ZERO,"ボス部位に武器のノックバックを掛けない")
	check(bridge.command("dev_kill",{"entity_id":int(ids[0]),"cause":"bullet"}).value.killed,"部位だけを途中で破壊する")
	check(core.enemy_motion_snapshot()[0].parts_alive==5,"親の生きている部位数から壊れた部位を除く")
	check(bridge.restore(pending.value).ok and core.enemies_snapshot()==enemies and core.enemy_motion_snapshot()==motion,"親子ID・保持・HP・部位の並びを値から復帰する")
	check(bridge.command("dev_kill",{"entity_id":parent,"cause":"bullet"}).value.killed,"部位より先に親を倒す")
	core.step(0.05)
	var all_dead := true
	for enemy: Dictionary in core.enemies_snapshot():
		if ids.has(enemy.id): all_dead = all_dead and enemy.dead!=0
	check(all_dead,"親の死亡後に全ての部位へ死亡印を付ける")
	check(bridge.restore(pending.value).ok,"親の退場と行の再利用の場面へ戻す")
	var old_parent: PackedInt64Array = core.enemy_handle(parent)
	core.remove_enemy(parent)
	var replacement: int = core.spawn_enemy(&"drifter",target+Vector2(500,0),{})
	check(not core.valid_enemy_handle(old_parent) and not bridge.command("dev_move_part",{"parent_id":replacement,"entity_id":int(ids[0]),"position":target,"facing":0.0}).ok,"親の行を再利用しても旧部位を新しい親へ結び直さない")
	core.step(0.05)
	all_dead = true
	for enemy: Dictionary in core.enemies_snapshot():
		if ids.has(enemy.id): all_dead = all_dead and enemy.dead!=0
	check(all_dead,"先に退場した親を参照する部位を終了する")
	var old_part: PackedInt64Array = core.enemy_handle(int(ids[0]))
	core.remove_enemy(int(ids[0]))
	var made: Dictionary = bridge.command("dev_spawn_part",{"parent_id":replacement,"definition_id":types[0],"position":target+Vector2(200,0)})
	check(made.ok and int(made.value)!=int(ids[0]) and not core.valid_enemy_handle(old_part),"部位の行の再利用で古い親子IDを失効する")
	bridge.release_checkpoint(pending.value)
	session.free()

func check_cpp_dash() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 900.0
	config.planet_radius = 100.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: config.set(key,0)
	var stage := RuntimeStage.new()
	stage.index = 81
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["darter"])
	var output := "res://.content/dev/run_dash"
	var builder = load("res://tools/content/build_run_content.gd")
	var built: Error = builder.build(stage,config,output,"突進する敵の予告と硬直".sha256_text())
	check(built==OK,"突進する敵の編集値と外観を生成する")
	if built!=OK: return
	var path := output.path_join("stage_81.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":980},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"突進する敵のランと表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	var initial: Dictionary = bridge.checkpoint()
	var comparison = preload("res://tools/compare_runtime.gd").new()
	var budget_probe = preload("res://tests/native_attack_budget.gd").new()
	var cases := ["normal","death","reuse"]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--cpp-dash-case="): cases = [argument.get_slice("=",1)]
	for kind in cases:
		bridge.restore(initial.value)
		var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
		add_child(lab)
		await lab.reset({"seed":980,"empty":true,"field":{"terrain":true,"rocks":false,"gimmicks":false},"config":{"start_radius":900.0,"planet_radius":100.0}})
		var run: RunSimulation = lab.run
		run.state.ship_pos = target
		run.state.enemy_aim = target
		run.state.view_center = target
		run.state.view_half = Vector2(640,360)
		run.state.world_time = core.inspect().world_time
		run.enemies._lod = core.inspect().ticks
		run.state.rng.state = int(core.inspect().rng_state)
		run.enemies._next_id = 1
		core.set_motion_context(target,target,Vector2(640,360))
		var definition := run.enemies.def_of(&"darter")
		var position := target+Vector2(300,100)
		var row := run.enemies.spawn(definition,position)
		var id: int = core.spawn_enemy(&"darter",position,{})
		var director = run.projectiles.director
		director.formation_mode = true
		core.set_attack_formation_mode(true)
		director.configure({"enabled":true,"budget":0.0,"jitter":0.0})
		core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
		var modes := [EnemyTable.Mode.MOVE]
		var pending: Dictionary = {}
		var pending_state: Array = []
		var next_state: Array = []
		for tick in (21 if kind=="normal" else 5):
			if tick==1:
				director.configure({"enabled":true,"budget":1.0,"jitter":0.0})
				core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
			if tick==3 and kind=="death":
				run.combat.kill_enemy(row,{"cause":&"bullet"})
				bridge.command("dev_kill",{"entity_id":id,"cause":"bullet"})
			if tick==3 and kind=="reuse":
				run.enemies._release_row(row)
				core.remove_enemy(id)
				var old_id := id
				row = run.enemies.spawn(definition,position)
				id = core.spawn_enemy(&"darter",position,{})
				check(id!=old_id and not core.set_enemy_motion(old_id,{"facing":1.0}),"予告中の行を再利用しても旧突進のIDを受け付けない")
			run.state.world_time += 0.125
			director.advance(run.state.world_time,run.enemies)
			core.advance_attack_budget(run.state.world_time)
			run.enemies.tick(0.125,0.125)
			core.step(0.125)
			modes.append(run.enemies.table.mode[row])
			var difference: String = comparison.difference(budget_probe.snapshot(director),core.attack_budget_snapshot())
			check(difference.is_empty(),"突進する敵の予算・待機・解放が一致する: "+kind+" "+difference)
			for enemy: Dictionary in core.enemies_snapshot():
				if enemy.id==id: check(Vector2(enemy.pos[0],enemy.pos[1]).distance_to(run.enemies.table.pos[row])<0.02 and Vector2(enemy.vel[0],enemy.vel[1]).distance_to(run.enemies.table.vel[row])<0.02 and absf(enemy.facing-run.enemies.table.facing[row])<0.0001 and enemy.dead==run.enemies.table.dead[row],"突進する敵の姿勢・移動・生死が一致する: %s/%d" % [kind,tick])
			for item: Dictionary in core.enemy_motion_snapshot():
				if item.id==id: check(item.mode==run.enemies.table.mode[row] and is_equal_approx(item.timer,run.enemies.table.timer[row]),"予告・突進・硬直の状態と時間が一致する: %s/%d" % [kind,tick])
			if tick==0: check(run.enemies.table.mode[row]==EnemyTable.Mode.MOVE,"予算0では予告を始めず追跡する")
			if tick==2 and kind=="normal":
				pending = bridge.checkpoint()
				pending_state = core.enemy_motion_snapshot()
				var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(800,500),Vector2(1600,1000))).value
				var presentation: RunPresentation = session.view.get_node("RunPresentation")
				check(presentation.frame_view.apply_frame(frame) and not frame.batches.is_empty(),"予告中の姿勢を通常画面へ表示する")
				await get_tree().process_frame
			if tick==3 and kind=="normal": next_state = core.enemy_motion_snapshot()
		if kind=="normal":
			check(modes.has(EnemyTable.Mode.WINDUP) and modes.has(EnemyTable.Mode.DASH) and modes.has(EnemyTable.Mode.RECOVER) and modes[-1]==EnemyTable.Mode.MOVE,"追跡・予告・突進・硬直を一巡する")
			check(bridge.restore(pending.value).ok and core.enemy_motion_snapshot()==pending_state,"予告中の向きと残り時間を値で復帰する")
			core.step(0.125)
			check(core.enemy_motion_snapshot()==next_state,"予告中の復帰後に同じ突進へ進む")
			bridge.release_checkpoint(pending.value)
		elif kind=="death": check(core.enemies_snapshot()[0].dead!=0,"予告中に倒した敵は突進を再開しない")
		lab.free()
	budget_probe.free()
	bridge.release_checkpoint(initial.value)
	session.free()
