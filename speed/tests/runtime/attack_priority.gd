## 攻撃優先度・予算予約・照準の開始条件と取消の対象チェック。
extends Node
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS
var failed := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
	if "--cpp-sniper" in OS.get_cmdline_user_args():
		await check_cpp_sniper()
		print("[cpp_sniper] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":932,"empty":true,"stage":4})
	var em: EnemySystem = lab.run.enemies
	var pm: ProjectileSystem = lab.run.projectiles
	var stage := StageDef.new()
	stage.enemy_attack_values = {"telescope":1.0}
	stage.enemy_attack_priorities = {"aquarius":5.0}
	lab.run.state.stage = stage
	check(stage.enemy_attack_priority(&"telescope") == 0.0 and stage.enemy_attack_priority(&"aquarius") == 5.0, "Neutral default and configured priority")
	var d = load("res://scripts/encounters/attack_director.gd").new()
	d.projectiles = pm
	d.formation_mode = true
	d.configure({"enabled":true,"budget":4.0,"jitter":0.0})
	pm.director = d
	var a := em.spawn(em.def_of(&"telescope"), Vector2(400,0))
	var b := em.spawn(em.def_of(&"telescope"), Vector2(400,30))
	var c := em.spawn(em.def_of(&"telescope"), Vector2(400,-30))
	check(d.request("a",["beam"],a,em.table.id[a],1.0,0.0,1.0), "First light attack")
	check(d.request("b",["beam"],b,em.table.id[b],1.0,0.0,1.0), "Second light attack")
	check(not d.request("heavy",["beam"],c,em.table.id[c],1.0,5.0,4.0), "Heavy waits without exceeding capacity")
	check(not d.request("light",["beam"],a,em.table.id[a],1.0,0.0,1.0), "Lower priority cannot refill reserved budget")
	em.table.stone[c] = 1.0
	d.advance(0.1,em)
	check(not d.waiting.has("heavy"), "Incapacitated waiting actor cannot block other attackers")
	em.table.stone[c] = 0.0
	d.request("heavy",["beam"],c,em.table.id[c],1.0,5.0,4.0)
	d.advance(2.0,em)
	check(not d.request("light",["beam"],a,em.table.id[a],1.0,0.0,1.0), "Pending heavy wins even when light requests first")
	check(d.request("heavy",["beam"],c,em.table.id[c],1.0,5.0,4.0) and d.used_cost() == 4.0, "Heavy eventually acquires all four slots")
	d.advance(4.0,em)
	d.waiting.clear()
	check(not d.request("impossible",["beam"],a,em.table.id[a],1.0,100.0,5.0), "Over-budget request remains denied")
	check(d.request("small",["beam"],b,em.table.id[b],1.0,0.0,0.5), "Impossible request cannot block viable fractional attack")
	pm.lab_context = d.token("small")
	var h := pm.fire_wall(Vector2.ZERO,0.0,10.0,2.0,0.0,100.0,1.0,Color.WHITE)
	d.cancel_attack("small",em.table.id[b])
	d.advance(6.0,em)
	check(d.used_cost() == 0.5, "Canceled actor retains its live hazard budget")
	pm.release_hazard(h)
	d.advance(7.0,em)
	check(d.used_cost() == 0.0, "Budget returns after hazard release")
	d.waiting.clear()
	check(d.request("shared",["beam"],a,em.table.id[a],1.0,0.0,1.5), "Shared override starts")
	check(d.request("shared",["beam"],b,em.table.id[b],1.0,0.0,1.5) and d.used_cost() == 1.5, "Shared override charged once")
	d.cancel_attack("shared",em.table.id[a])
	check(d.groups[d.token("shared")].members.has(str(em.table.id[b])), "Cancel preserves shared sibling")
	d.advance(9.0,em)
	d.waiting.clear()
	d.settings.budget = 2.0
	lab.run.field.bodies.clear()
	lab.run.state.ship_pos = Vector2.ZERO
	em._aim = Vector2.ZERO
	for row in [a,b,c]:
		em.table.pos[row] = Vector2(400,0)
		em.table.facing[row] = PI
		em.table.mode[row] = RunIds.EnemyModeId.Move
		em.table.charge[row] = 0.0
	lab.run.combat.rebuild_grid()
	for row in [a,b,c]: em.behavior(&"sniper").step(row,0.01)
	check(em.table.charge[a] > 0.0 and d.token(str(em.table.id[a])) > 0, "Budget reserved before first lock-on progress")
	check(em.behavior(&"sniper").telescope_aiming(a) and em.behavior(&"sniper").telescope_aiming(b) and not em.behavior(&"sniper").telescope_aiming(c), "Only two telegraphs with budget two")
	em.table.pos[a] = Vector2(2000,0)
	em.behavior(&"sniper").step(a,0.01)
	check(not em.behavior(&"sniper").telescope_aiming(a) and em.table.charge[a] == 0.0, "Outside existing range hides and cancels aim")
	d.advance(9.1,em)
	check(d.token(str(em.table.id[a])) == 0, "Out-of-range reservation releases")
	var body := FieldSystem.Body.new()
	body.pos = Vector2(200,0)
	body.r = 80.0
	lab.run.field.bodies.append(body)
	em.behavior(&"sniper").step(b,0.01)
	check(not em.behavior(&"sniper").telescope_aiming(b), "Occlusion cancels telegraph")
	d.advance(9.2,em)
	check(d.token(str(em.table.id[b])) == 0, "Occlusion reservation releases")
	# 扇の候補絞り込みが48本の従来の円交差結果を保つ。
	lab.run.field.bodies.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 823
	for k in 80:
		var obstacle := FieldSystem.Body.new()
		obstacle.pos = Vector2.from_angle(rng.randf_range(-PI,PI)) * rng.randf_range(30.0,1500.0)
		obstacle.r = rng.randf_range(2.0,150.0)
		lab.run.field.bodies.append(obstacle)
	em.table.pos[a] = Vector2.ZERO
	for angle in [0.0,1.2,-2.4]:
		for charge in [0.0,0.7,1.0]:
			em.table.facing[a] = angle
			em.table.charge[a] = charge
			em.behavior(&"sniper")._cast_telescope(a)
			var rays: PackedFloat32Array = em.behavior(&"sniper").telescope_rays(a)
			var lens: Vector2 = em.behavior(&"sniper").telescope_lens(a)
			var half: float = em.behavior(&"sniper").telescope_half(a)
			var same := true
			for n in 48:
				var direction := Vector2.from_angle(angle-half+2.0*half*n/47.0)
				var reach := 1000.0
				for obstacle in lab.run.field.bodies:
					var offset: Vector2 = obstacle.pos-lens
					var along := offset.dot(direction)
					if along < -obstacle.r: continue
					var distance_squared := offset.length_squared()-along*along
					if distance_squared > obstacle.r*obstacle.r: continue
					reach = minf(reach,maxf(0.0,along-sqrt(obstacle.r*obstacle.r-distance_squared)))
				if absf(rays[n]-reach)>0.001: same=false
			check(same,"48 ray blocker equivalence")
			lab.run.state.ship_pos = Vector2.from_angle(angle+half*0.7)*600.0
			var target_angle: float = (lab.run.state.ship_pos-lens).angle()
			var full_reach: float = em.behavior(&"sniper").telescope_reach(a,target_angle)
			em.behavior(&"sniper")._cast_telescope(a,true)
			check(absf(em.behavior(&"sniper").telescope_reach(a,target_angle)-full_reach)<0.001,"Two-ray admission equals full 48-ray interpolation")
	lab.run.field.bodies.clear()
	lab.run.state.ship_pos = Vector2.ZERO
	em.table.pos[a] = Vector2(400,0)
	em.table.facing[a] = PI
	var rock := em.spawn(em.def_of(&"meteor"),Vector2(200,0),{"meteor_index":0,"size":20.0})
	em._behavior_index(&"reticle")
	check(em.behavior(&"reticle")._blocking_rock(a,30.0)==rock,"New rock invalidates shared sight cache")
	em.table.pos[rock] = Vector2(200,250)
	check(em.behavior(&"reticle")._blocking_rock(a,30.0)==-1,"Shared sight cache reads moving rock position")
	em.table.pos[rock] = Vector2(200,0)
	em.table.dead[rock] = 1
	check(em.behavior(&"reticle")._blocking_rock(a,30.0)==-1,"Destroyed rock immediately excluded")
	# からす座の横断・結晶回収は予算0でも、他の攻撃が占有中でも進む。
	em.clear_all()
	pm.clear_hostile()
	var crow_director = load("res://scripts/encounters/attack_director.gd").new()
	crow_director.projectiles = pm
	crow_director.formation_mode = true
	crow_director.configure({"enabled": true, "budget": 0.0, "jitter": 0.0})
	pm.director = crow_director
	var crow := em.spawn(em.def_of(&"crow"), Vector2(0, 100))
	check(not em.behavior(&"crow").admission, "Crow flight bypasses attack admission")
	var crow_before: Vector2 = em.table.pos[crow]
	em.tick(0.1, 0.1)
	check(em.table.pos[crow] != crow_before and crow_director.used_cost() == 0.0
		and crow_director.waiting.is_empty(), "Crow flies at zero attack budget without requesting a slot")
	var pickups: PickupSystem = lab.run.pickups
	var foot := em.table.pos[crow] - Vector2.from_angle(em.table.facing[crow]) * em.table.r[crow] * 0.62
	var gem: int = pickups.drop_crystal(foot, RunIds.GemKind.Mid)
	pickups.gem_pos[gem] = foot
	em.gather_pickups(pickups, 0.1)
	check(em.table.carry[crow] >= lab.run.cfg.xp_crystal_values[RunIds.GemKind.Mid] and pickups.gem_alive[gem] == 0,
		"Crow collects experience with zero attack budget")
	crow_director.settings.budget = 1.0
	var blocker := em.spawn(em.def_of(&"telescope"), Vector2(400, 0))
	check(crow_director.request("other", ["beam"], blocker, em.table.id[blocker], 10.0, 0.0, 1.0),
		"Other attacker occupies the budget")
	crow_before = em.table.pos[crow]
	em.tick(0.1, 0.1)
	check(em.table.pos[crow] != crow_before and crow_director.used_cost() == 1.0,
		"Crow flies without consuming another attacker's slot")
	em.mark_dead(crow)
	em.cleanup()
	crow_director.advance(1.0, em)
	check(crow_director.used_cost() == 1.0 and crow_director.token("other") > 0,
		"Crow removal does not return another attacker's budget")
	crow_director.advance(20.0, em)
	crow_director.advance(21.0, em)
	check(crow_director.used_cost() == 0.0 and crow_director.owners.is_empty(),
		"Budget returns once when its actual attack ends")
	# float valueの反復加算は数ULPだけずれる。予算0と微小な正値は区別する。
	var precision = load("res://scripts/encounters/attack_director.gd").new()
	precision.projectiles = pm
	precision.formation_mode = true
	precision.configure({"enabled": true, "budget": 0.3, "jitter": 0.0})
	for n in 3:
		check(precision.request("decimal_%d" % n, ["beam"], blocker, em.table.id[blocker], 10.0, 0.0, 0.1),
			"0.1を3回使って予算0.3に収まる")
	check(absf(precision.used_cost() - 0.3) < 1e-14, "反復加算の予算使用量")
	check(not precision.request("tiny_over", ["beam"], blocker, em.table.id[blocker], 10.0, 0.0, 1e-14),
		"満杯では微小な正valueも追加しない")
	precision.groups.clear()
	precision.owners.clear()
	precision.waiting.clear()
	precision.configure({"enabled": true, "budget": 0.0, "jitter": 0.0})
	check(precision.request("zero", ["beam"], blocker, em.table.id[blocker], 0.1, 0.0, 0.0)
		and precision.groups.is_empty() and precision.waiting.is_empty(),
		"予算0でもvalue0は枠と待機を作らず通す")
	check(not precision.request("tiny", ["beam"], blocker, em.table.id[blocker], 0.1, 0.0, 1e-18),
		"予算0で微小な正valueを無料扱いしない")
	precision.waiting.clear()
	precision.configure({"enabled": true, "budget": 1e-12, "jitter": 0.0})
	check(precision.request("small_1", ["beam"], blocker, em.table.id[blocker], 10.0, 0.0, 5e-13)
		and precision.request("small_2", ["beam"], blocker, em.table.id[blocker], 10.0, 0.0, 5e-13),
		"微小な正予算と正valueはその精度のまま使う")
	check(not precision.request("small_over", ["beam"], blocker, em.table.id[blocker], 10.0, 0.0, 1e-16),
		"微小な正予算でも満杯後の超過を止める")
	precision.groups.clear()
	precision.owners.clear()
	precision.waiting.clear()
	precision.configure({"enabled": true, "budget": 1.0, "jitter": 0.0})
	check(precision.request("free", ["beam"], blocker, em.table.id[blocker], 10.0, 0.0, 0.0)
		and precision.used_cost() == 0.0, "正の予算内ではvalue0は残量を消費しない")
	check(precision.request("positive", ["beam"], blocker, em.table.id[blocker], 10.0, 0.0, 1e-16)
		and precision.used_cost() > 0.0, "微小な正valueを0へ丸めない")
	precision.groups.clear()
	precision.owners.clear()
	precision.waiting.clear()
	precision.configure({"enabled": true, "budget": 0.5, "jitter": 0.0})
	check(not precision.request("negative_default", ["beam"], blocker, em.table.id[blocker], 0.1, 0.0, -1.0),
		"負の省略印は既定value1へ戻す")
	precision.waiting.clear()
	precision.configure({"enabled": true, "budget": 1.0, "jitter": 0.0})
	precision.now = 0.2
	check(precision.request("deadline", ["beam"], blocker, em.table.id[blocker], 0.1, 0.0, 0.2),
		"小数秒の期限を持つ攻撃を開始")
	precision.advance(0.3, em)
	check(precision.token("deadline") == 0 and precision.used_cost() == 0.0,
		"0.2+0.1の丸め残りで攻撃枠を保持しない")
	precision.waiting.clear()
	precision.serial = 10000 # 過去の弾に付いた別Directorのtokenと重ねない。
	precision.configure({"enabled": true, "budget": 0.3, "jitter": 0.0})
	var cycles_ok := true
	for cycle in 20:
		precision.now = float(cycle)
		for n in 3:
			cycles_ok = precision.request("repeat_%d_%d" % [cycle, n], ["beam"], blocker,
				em.table.id[blocker], 0.1, 0.0, 0.1) and cycles_ok
		precision.advance(float(cycle) + 0.1, em)
		cycles_ok = precision.used_cost() == 0.0 and cycles_ok
	check(cycles_ok, "小数valueの反復取得・期限切れで予算残差を残さない")
	precision.configure({"enabled": true, "budget": 1.0, "jitter": 0.0})
	precision.now = 30.0
	var owner_id := em.table.id[blocker]
	check(precision.request("existing", ["beam"], blocker, owner_id, 1.0, 0.0, 1.0),
		"予算縮小前に攻撃を開始")
	precision.settings.budget = 0.0
	check(precision.request("existing", ["beam"], blocker, owner_id, 1.0, 0.0, 1.0),
		"予算0へ縮小しても開始済み個体は継続")
	check(not precision.request("existing", ["beam"], blocker, owner_id + 1, 1.0, 0.0, 1.0),
		"予算0では共有枠への新規個体追加を止める")
	lab.queue_free()
	await get_tree().process_frame
	print("[attack_priority] %d checks, %d failures" % [checks,failed])
	get_tree().quit(1 if failed else 0)

func check_cpp_sniper() -> void:
	var cfg: GameConfig = ContentManager.base.duplicate(true)
	cfg.start_radius = 900.0
	cfg.planet_radius = 0.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage := RuntimeStage.new()
	stage.index = 80
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["telescope"])
	var output := "res://.content/dev/run_sniper"
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"ぼうえんきょう座の遮蔽と照準".sha256_text())
	check(built==OK,"ぼうえんきょう座の編集値と外観を生成する")
	if built!=OK: return
	var path := output.path_join("stage_80.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":981},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"ぼうえんきょう座のランと表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":981,"empty":true,"field":{"terrain":true,"rocks":false,"gimmicks":false},"config":{"start_radius":900.0,"planet_radius":0.0}})
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
	var position := target-Vector2(560,0)
	var row := run.enemies.spawn(run.enemies.def_of(&"telescope"),position)
	var id: int = core.spawn_enemy(&"telescope",position,{})
	var director = run.projectiles.director
	director.formation_mode = true
	core.set_attack_formation_mode(true)
	director.configure({"enabled":true,"budget":0.0,"jitter":0.0})
	core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	var rock_row := -1
	var rock_id := 0
	var pending: Dictionary = {}
	var pending_motion: Array = []
	var next_motion: Array = []
	var fired := false
	for tick in 30:
		if tick==1:
			director.configure({"enabled":true,"budget":1.0,"jitter":0.0})
			core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
		if tick==4:
			var at := run.enemies.table.pos[row].lerp(target,0.5)
			check(bridge.command("dev_add_rock",{"position":at,"kind":0,"manual":true}).ok,"光を遮る岩を生成する")
			bridge.command("dev_stream_rocks",{"center":target,"half":Vector2(640,360),"dt":0.3})
			var rock: Dictionary = {}
			for enemy: Dictionary in core.enemies_snapshot():
				if enemy.type=="meteor": rock = enemy
			rock_id = int(rock.id)
			rock_row = run.enemies.spawn(run.enemies.def_of(&"meteor"),at,{"meteor_index":0})
			run.enemies.table.r[rock_row] = rock.radius
		if tick==6:
			run.enemies.mark_dead(rock_row)
			bridge.command("dev_kill",{"entity_id":rock_id,"cause":"bullet"})
		run.state.world_time += 0.1
		director.advance(run.state.world_time,run.enemies)
		core.advance_attack_budget(run.state.world_time)
		run.enemies.tick(0.1,0.1)
		core.step(0.1)
		for enemy: Dictionary in core.enemies_snapshot():
			if enemy.id==id: check(Vector2(enemy.pos[0],enemy.pos[1]).distance_to(run.enemies.table.pos[row])<0.03 and Vector2(enemy.vel[0],enemy.vel[1]).distance_to(run.enemies.table.vel[row])<0.03 and absf(enemy.facing-run.enemies.table.facing[row])<0.0001,"遮蔽の前後で移動・旋回が一致する: %d" % tick)
		for item: Dictionary in core.enemy_motion_snapshot():
			if item.id!=id: continue
			check(item.mode==run.enemies.table.mode[row] and is_equal_approx(item.charge,run.enemies.table.charge[row]) and is_equal_approx(item.timer,run.enemies.table.timer[row]),"照準・溜め・休みの状態が一致する: %d" % tick)
			var rays: PackedFloat32Array = run.enemies.behavior(&"sniper").telescope_rays(row)
			var same: bool = item.sight_rays.size()==rays.size()
			if same:
				for n in rays.size():
					if absf(rays[n]-item.sight_rays[n])>0.02: same = false
			check(same,"判定と表示で使う48光線が一致する: %d" % tick)
		if tick==0: check(run.enemies.table.charge[row]==0.0 and core.attack_budget_snapshot().groups.is_empty(),"予算0では照準の進行と表示を始めない")
		if tick==4: check(run.enemies.table.charge[row]==0.0 and core.enemy_motion_snapshot()[0].charge==0.0,"岩陰で照準と未発射の予約を取り消す")
		if run.enemies.table.mode[row]==RunIds.EnemyModeId.Windup and pending.is_empty():
			pending = bridge.checkpoint()
			pending_motion = core.enemy_motion_snapshot()
			var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(1100,500),Vector2(1600,1000))).value
			var shown := false
			for batch: Dictionary in frame.batches:
				if batch.has("sniper"): shown = batch.sniper.size()==59
			var presentation: RunPresentation = session.view.get_node("RunPresentation")
			check(shown and presentation.frame_view.apply_frame(frame),"狭まる48光線と溜めの光を通常画面へ表示する")
			presentation._present_cpp(0.0)
			await get_tree().process_frame
		elif not pending.is_empty() and next_motion.is_empty(): next_motion = core.enemy_motion_snapshot()
		if not core.hazards_snapshot().is_empty():
			fired = true
			check(run.projectiles.hazard_slots.live==1 and run.enemies.table.mode[row]==RunIds.EnemyModeId.Recover,"遮蔽が先に消えると再照準しレーザーを撃つ")
			break
	check(fired and not pending.is_empty(),"照準から独立したレーザーの発射まで進む")
	if fired:
		check(bridge.command("dev_kill",{"entity_id":id,"cause":"bullet"}).value.killed and core.hazards_snapshot().size()==1,"発射後に本体を倒しても独立したレーザーは残る")
		core.step_hazards(0.06)
		var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(1100,500),Vector2(1600,1000))).value
		var rounded := false
		for shape: Dictionary in frame.shapes: rounded = rounded or shape.get("rounded",false)
		check(rounded,"レーザーの丸い先端と短い終了フェードを表示する")
		core.step_hazards(0.3)
		check(core.hazards_snapshot().is_empty(),"レーザーを自然寿命で終了する")
		check(bridge.restore(pending.value).ok and core.enemy_motion_snapshot()==pending_motion,"照準の48光線と溜めを値から復帰する")
		core.step(0.1)
		check(core.enemy_motion_snapshot()==next_motion,"復帰後に同じ照準へ進み保持元へ変更を漏らさない")
		bridge.restore(pending.value)
		bridge.command("dev_kill",{"entity_id":id,"cause":"bullet"})
		core.step(0.6)
		check(core.hazards_snapshot().is_empty(),"溜めの途中で倒した本体はレーザーを撃たない")
		core.remove_enemy(id)
		var replacement: int = core.spawn_enemy(&"telescope",position,{})
		var clean := false
		for item: Dictionary in core.enemy_motion_snapshot():
			if item.id==replacement: clean = item.sight_rays.is_empty() and item.charge==0.0 and item.mode==RunIds.EnemyModeId.Move
		check(replacement!=id and clean and not core.set_enemy_motion(id,{"held":true}),"行の再利用で古い照準・ID・光線を引き継がない")
		bridge.release_checkpoint(pending.value)
	lab.free()
	session.free()
