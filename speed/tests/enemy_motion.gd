## 移動・旋回・発射時刻の共通処理は、種類の追加と独立した補助へ置く。
extends Node
var failed := 0
var gunner_finished := false
var gunner_cycle := false
var missile_enemy := false
func check(ok: bool, label: String) -> void:
	if gunner_cycle and label not in ["周期を過ぎる大きな更新でも1更新に1回ずつ発射する","射撃型の確認が最後まで進んだ"]: return
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
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
	var type := "missile" if missile_enemy else "gunner"
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
	check(session.bridge!=null,"射撃型の通常のランと表示を準備する")
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
	for kind in (["normal"] if gunner_cycle else ["normal","death","reuse"]):
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
			if step<2:
				check(core.hostiles_snapshot().is_empty() and run.enemies.table.charge[row]==0.0,"枠を待つ間は予告と射撃を始めず追跡する: %s/%d" % [kind,step])
			if missile_enemy:
				var budget_diff: String = comparison.difference(budget_probe.snapshot(director),core.attack_budget_snapshot())
				check(budget_diff.is_empty(),"ミサイル艇の予算と待機・残留枠が一致する: "+budget_diff)
			if step==2 and kind=="normal" and not gunner_cycle:
				warning = bridge.checkpoint()
				warning_state = core.enemy_motion_snapshot()
				var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(800,500),Vector2(1600,1000))).value
				var marked := false
				for batch: Dictionary in frame.batches:
					var mark_name := "missile" if missile_enemy else "gunner"
					if batch.has(mark_name): marked = batch[mark_name].size()==5 and batch[mark_name][4]>0.0
				check(marked,"射撃の予告を表示用の値へ渡す")
				var presentation: RunPresentation = session.view.get_node("RunPresentation")
				presentation._present_cpp(0.0)
				check(presentation.frame_view.apply_frame(frame) and presentation.frame_view.get("_missile" if missile_enemy else "_gunner").size()==5,"射撃型の本体と砲口の光を通常画面へ表示する")
				await get_tree().process_frame
		if kind=="normal":
			check(emitted_count==2 and core.hostiles_snapshot().size()==run.projectiles.hostile_slots.live,"周期を過ぎる大きな更新でも1更新に1回ずつ発射する")
			if not gunner_cycle:
				bridge.restore(warning.value)
				check(core.enemy_motion_snapshot()==warning_state,"予告中の位置と射撃状態を復元する")
				core.step(0.125)
				check(core.hostiles_snapshot().size()==1,"予告中の保持点から同じ発射へ進む")
				if missile_enemy:
					var fired: Dictionary = bridge.checkpoint()
					var shot_id: int = core.attack_snapshot()[0].id
					check(bridge.command("dev_kill",{"entity_id":id,"cause":"ram"}).ok,"飛行中にミサイル艇を倒す")
					var parent_gone := false
					for attack: Dictionary in core.attack_snapshot():
						if attack.id==shot_id: parent_gone = attack.source_id==id and not attack.source_alive
					check(parent_gone and core.hostiles_snapshot().size()==1,"親消失後も発射済みの誘導弾と出どころを保つ")
					core.step_hostiles(5.0)
					check(core.hostiles_snapshot().is_empty(),"誘導弾を命中または寿命で終了する")
					check(bridge.restore(fired.value).ok,"発射済みの敵と誘導弾を値から復帰する")
					var pending_shots: Array = core.hostiles_snapshot()
					core.step_hostiles(0.125)
					var advanced_shots: Array = core.hostiles_snapshot()
					check(bridge.restore(fired.value).ok and core.hostiles_snapshot()==pending_shots,"保持元へ飛行中の変更を漏らさない")
					core.step_hostiles(0.125)
					check(core.hostiles_snapshot()==advanced_shots,"復帰後も同じ追尾と飛行になる")
					var restored_id := id
					var old_handle: PackedInt64Array = core.enemy_handle(restored_id)
					check(bridge.command("dev_remove",{"entity_id":restored_id}).ok,"ミサイル艇を撃破と別の退場で片付ける")
					check(not core.valid_enemy_handle(old_handle) and core.hostiles_snapshot().size()==1,"退場は旧個体の参照を失効し発射済み弾を保つ")
					bridge.release_checkpoint(fired.value)
				bridge.release_checkpoint(warning.value)
		elif kind=="death": check(core.hostiles_snapshot().is_empty(),"予告中に倒れた敵は発射しない")
		lab.free()
	bridge.release_checkpoint(initial.value)
	session.free()
	budget_probe.free()
	gunner_finished = true
