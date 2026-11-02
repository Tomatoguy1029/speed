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

func rocket_state(run: RunSimulation, core, row: int, id: int, label: String) -> void:
	for enemy: Dictionary in core.enemies_snapshot():
		if enemy.id!=id: continue
		check(Vector2(enemy.pos[0],enemy.pos[1]).distance_to(run.enemies.table.pos[row])<0.02 and Vector2(enemy.vel[0],enemy.vel[1]).distance_to(run.enemies.table.vel[row])<0.02 and absf(enemy.facing-run.enemies.table.facing[row])<0.0001,label+"の初回照準と飛行が一致する")
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
