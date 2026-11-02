## 噛みつきの円形判定・一度だけの被弾・残留する枠と表示状態を比較する。
extends "res://tests/native_attack_budget.gd"
const SHIP := preload("res://tests/native_ship.gd")
var beam_finished := false
var beam_retry := false
var beamer_finished := false
var beamer_fixes := false
func values(object: Object,keys: Array) -> Dictionary:
	var out := {}
	for key in keys: out[key] = object.get(key)
	return out
func _ready() -> void:
	comparison = COMPARE.new()
	if "--cpp-wall" in OS.get_cmdline_user_args():
		await check_cpp_wall()
		print("[cpp_wall] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-beamer" in OS.get_cmdline_user_args() or "--cpp-beamer-fixes" in OS.get_cmdline_user_args():
		beamer_fixes = "--cpp-beamer-fixes" in OS.get_cmdline_user_args()
		await check_cpp_beamer()
		beamer_check(beamer_finished,"ビーム敵の確認が最後まで進んだ")
		print("[cpp_beamer] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-beam" in OS.get_cmdline_user_args() or "--cpp-beam-fixes" in OS.get_cmdline_user_args():
		beam_retry = "--cpp-beam-fixes" in OS.get_cmdline_user_args()
		await check_cpp_beam()
		check(beam_finished,"ビームの確認が最後まで進んだ")
		print("[cpp_beam] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	var probe = comparison.create_native()
	if not probe.has_method("fire_bite_zone"):
		check(false,"噛みつきの判定をネイティブが所有する")
	else:
		for effects in [false,true]: await compare_zones(effects)
	probe.close()
	print("[native_bite_zone] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func hazard_snapshot(ps: ProjectileSystem) -> Array:
	var out := []
	for row in ps.hazard_alive.size():
		if not ps.hazard_alive[row]: continue
		out.append({"row":row,"pos":ps.hazard_pos[row],"radius":ps.hazard_len[row],"time":ps.hazard_t[row],"delay":ps.hazard_delay[row],"active":ps.hazard_active[row],"damage":ps.hazard_dmg[row],"hit":ps.hazard_hit[row]!=0,"color":ps.hazard_color[row],"token":ps.lab_hazard_group.get(row,0)})
	return comparison.plain(out)
func add_zone(run: RunSimulation,core,at: Vector2,radius: float,delay: float,token: int) -> void:
	run.projectiles.lab_context = token
	var row := run.projectiles.fire_zone(at,radius,delay,3.0,ProjectileSystem.HazardStyle.BITE,Color(0.7,0.3,0.1,0.8))
	check(core.fire_bite_zone(at,radius,delay,3.0,Color(0.7,0.3,0.1,0.8),token) == row,"噛みつきの判定を同じ順で生成・再利用する")
func compare_zones(effects: bool) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":422,"empty":true,"invincible":false})
	var run: RunSimulation = lab.run
	var d = run.projectiles.director
	d.formation_mode = true
	run.state.stats.invulnerability = 0.06
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	run.ship.setup(run.ship.ctx)
	var library := load("res://.content/attack_visuals.res").duplicate(true)
	if effects:
		library.set_meta("looks",{"res://scenes/attacks/zone_bite.tscn":{"Hit":Resource.new(),"Fade":Resource.new()}})
	run.projectiles._end_visual_library = library
	run.projectiles._end_visual_phases.clear()
	var definition := run.enemies.def_of(&"drifter").duplicate(true) as EnemyDef
	definition.speed = 0.0
	var core = comparison.create_native()
	core.configure(DATA.compile_enemy(definition,run.cfg,run.state.stage))
	core.configure_ship(values(run.cfg,SHIP.CONFIG_KEYS),values(run.state.stats,SHIP.STAT_KEYS))
	core.set_attack_formation_mode(true)
	configure(d,core,true,1.0)
	check(core.configure_bite_zone(DATA.compile_bite_zone(library)),"判定の寿命と表示終了の条件を準備する")
	core.start(422,run.enemies._next_id)
	run.state.rng.seed = 422
	var at := run.state.ship_pos
	var row := run.enemies.spawn(definition,at+Vector2(1000,0))
	var id: int = core.spawn_enemy(&"drifter",at+Vector2(1000,0))
	run.state.events.clear()
	core.drain_events()
	request(run,core,"噛みつき",row,1.0)
	var token: int = d.token("噛みつき")
	add_zone(run,core,at,20.3,0.0,token)
	add_zone(run,core,at,20.3,0.0,0)
	add_zone(run,core,at+Vector2(1000,0),20.3,0.0,0)
	add_zone(run,core,at,20.3,0.113,0)
	d.cancel_attack("噛みつき",id)
	core.cancel_attack("噛みつき",id)
	var hit_count := 0
	var retained := false
	for tick in 60:
		if tick in [20,40]: add_zone(run,core,run.state.ship_pos,31.7,0.0,0)
		var dt := 0.3 if tick == 40 else 0.02
		run.state.events.clear()
		run.state.time += dt
		run.state.world_time += dt
		d.advance(run.state.world_time,run.enemies)
		core.advance_attack_budget(run.state.world_time)
		retained = retained or (d.groups.has(token) and run.state.world_time > 0.0)
		check(comparison.difference(snapshot(d),core.attack_budget_snapshot()).is_empty(),"範囲判定が消えるまで攻撃枠を保持する")
		run.enemies.tick(dt,dt)
		core.set_motion_context(run.state.ship_pos,run.state.view_center,run.state.view_half)
		core.step(dt)
		run.ship.intent.touch = true
		run.ship.tick(dt,dt)
		core.step_ship(dt,dt,{"touch":true})
		run.projectiles._update_hazards(dt)
		check(core.step_hazards(dt),"噛みつきの判定を世界時間で更新する")
		var diff: String = comparison.difference(hazard_snapshot(run.projectiles),comparison.plain(core.hazards_snapshot()))
		if diff.is_empty(): diff = comparison.difference(comparison.plain(values(run.state,SHIP.STATE_KEYS)),comparison.plain(core.ship_snapshot()))
		if diff.is_empty(): diff = comparison.difference(comparison.plain(run.state.events),comparison.plain(core.drain_events()))
		check(diff.is_empty(),"予告・被弾・寿命・表示終了が一致する tick%d: %s" % [tick,diff])
		for event in run.state.events:
			if event.type == &"hurt": hit_count += 1
		if not diff.is_empty(): break
	check(hit_count == 3,"同時発動は無敵で一回、遅延と再利用は各一回、寿命を飛び越す更新は被弾しない")
	check(retained and not d.groups.has(token),"残留中の枠の保持と最終解放を実際に通る")
	var before: Array = core.hazards_snapshot()
	check(core.fire_bite_zone(at,NAN,0.0,1.0,Color.WHITE,0) == -1 and before == core.hazards_snapshot(),"不正な範囲を追加しない")
	core.close()
	lab.free()

func beam_states(run: RunSimulation, core, label: String) -> void:
	var old := []
	var current := []
	var ps := run.projectiles
	for i in ps.hazard_alive.size():
		if ps.hazard_alive[i]==0: continue
		old.append({"pos":ps.hazard_pos[i],"angle":ps.hazard_angle[i],"length":ps.hazard_len[i],"half_width":ps.hazard_width[i]*0.5,
			"arc":ps.hazard_arc[i],"time":ps.hazard_t[i],"delay":ps.hazard_delay[i],"active":ps.hazard_active[i],
			"damage":ps.hazard_dmg[i],"hit":ps.hazard_hit[i]!=0,"color":ps.hazard_color[i],"attached":ps.hazard_owner[i]>=0})
	for row: Dictionary in core.hazards_snapshot():
		var value := row.duplicate()
		for key in ["row","radius","kind","token","owner_id"]: value.erase(key)
		value.attached = row.owner_id>0
		current.append(value)
	var diff: String = comparison.difference(comparison.plain(old),comparison.plain(current))
	check(diff.is_empty(),label+": "+diff)
	check(is_equal_approx(core.ship_snapshot().ship_hp,run.state.ship_hp),label+"の機体HP")

func beam_pair(run: RunSimulation, bridge, from: Vector2, owner: int, owner_id: int, delay: float, arc := 0.0) -> Dictionary:
	var row := run.projectiles.fire_beam(from,0.0,200.0,32.0,delay,1.0,7.0)
	run.projectiles.hazard_arc[row] = arc
	if owner>=0: run.projectiles.attach_hazard(row,owner)
	var params := {"position":from,"angle":0.0,"length":200.0,"width":32.0,"delay":delay,"active":1.0,"damage":7.0,"arc":arc}
	if owner_id>0: params["owner_id"] = owner_id
	var emitted: Dictionary = bridge.command("dev_fire_beam",params)
	check(emitted.ok,"ビームの形・時刻・発生元を生成する: "+str(emitted))
	return {"row":row,"id":emitted.value.id if emitted.ok else 0}

func check_cpp_beam() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 900.0
	config.planet_radius = 100.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	var stage := RuntimeStage.new()
	stage.index = 86
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/run_beam"
	var builder = load("res://tools/content/build_run_content.gd")
	var built: Error = builder.build(stage,config,output,"ビームの予告・命中・解除".sha256_text())
	if not beam_retry: check(built==OK,"ビームの共通当たり定義を生成する")
	if built!=OK: return
	var path := output.path_join("stage_86.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":286},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	if not beam_retry: check(session.bridge!=null,"ビームを表示する通常のC++ランを準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target := Vector2(-900,0)
	bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2.ZERO})
	core.set_motion_context(target,target,Vector2(640,360))
	var owner_id: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":target+Vector2(-100,100)}).value
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":286,"empty":true,"field":{"terrain":true,"rocks":false,"gimmicks":false},"invincible":false,
		"config":{"start_radius":900.0,"planet_radius":100.0}})
	var run: RunSimulation = lab.run
	run.state.ship_pos = target
	run.state.ship_vel = Vector2.ZERO
	run.state.view_center = target
	run.state.view_half = Vector2(640,360)
	var owner := run.enemies.spawn(run.enemies.def_of(&"drifter"),target+Vector2(-100,100))
	var empty: Dictionary = bridge.checkpoint()
	var shot := beam_pair(run,bridge,target+Vector2(-100,100),owner,owner_id,0.25)
	run.projectiles._update_hazards(0.125)
	core.step_hazards(0.125)
	beam_states(run,core,"予告中は命中しない")
	var warning: Dictionary = bridge.checkpoint()
	var warning_state: Array = core.hazards_snapshot()
	var frame: Dictionary = bridge.read_render(Rect2(-1600,-400,1200,800)).value
	var shapes: Array = frame.shapes
	check(shapes.size()==1 and shapes[0].kind==1 and shapes[0].points[0]==target+Vector2(-100,100),"予告の円を発生位置へ出す")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	presentation._present_cpp(0.0)
	check(presentation.frame_view.apply_frame(frame),"予告の円を通常の表示へ渡す")
	await get_tree().process_frame
	var from := target-Vector2(100,0)
	run.projectiles.move_hazard(shot.row,from,0.0,240.0)
	check(bridge.command("dev_move_beam",{"attack_id":shot.id,"position":from,"angle":0.0,"length":240.0}).ok,"発生元の指示で位置・向き・長さを変える")
	run.projectiles._update_hazards(0.125)
	core.step_hazards(0.125)
	beam_states(run,core,"予告が終わった時点で命中する")
	check(is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp-7.0),"ビームを共通の機体被弾へ通す")
	frame = bridge.read_render(Rect2(-1600,-400,1200,800)).value
	shapes = frame.shapes
	check(shapes.size()==1 and shapes[0].kind==0 and shapes[0].widths.size()==3 and is_equal_approx(shapes[0].widths[1],32.0),"照射は元の全幅で光・本体・芯を出す")
	check(presentation.frame_view.apply_frame(frame),"予告から照射の3本へ通常の表示を切り替える")
	await get_tree().process_frame
	var active: Dictionary = bridge.checkpoint()
	for dt in [0.125,0.875]:
		run.projectiles._update_hazards(dt)
		core.step_hazards(dt)
		beam_states(run,core,"照射済みは再度当たらず寿命で消える")
	var ended: Dictionary = core.ship_snapshot()
	check(core.hazards_snapshot().is_empty(),"有効期間の終端でビームを回収する")
	bridge.restore(active.value)
	core.step_hazards(0.125)
	core.step_hazards(0.875)
	check(core.hazards_snapshot().is_empty() and core.ship_snapshot()==ended,"照射中の保持点から同じ命中済み状態と終了を再現する")
	bridge.restore(warning.value)
	check(core.hazards_snapshot()==warning_state,"予告中の保持点から幅・位置・時刻・所有者を復元する")
	# 先へ広がる形は、外側の不命中のあと内側へ移しても当たる。
	bridge.restore(empty.value)
	run.projectiles.clear_hostile()
	run.state.ship_hp = config.base_hp
	run.state.ship_invuln = 0.0
	var lateral := 16.0+100.0*0.5+config.ship_radius
	shot = beam_pair(run,bridge,target+Vector2(-100,-lateral-2),owner,owner_id,0.0,atan(0.5))
	run.projectiles._update_hazards(0.125)
	core.step_hazards(0.125)
	beam_states(run,core,"広がる幅の外側は不命中のまま残る")
	check(not core.hazards_snapshot()[0].hit,"触れる前に一度だけの判定を消費しない")
	from = target+Vector2(-100,-lateral+2)
	run.projectiles.move_hazard(shot.row,from,0.0)
	bridge.command("dev_move_beam",{"attack_id":shot.id,"position":from,"angle":0.0})
	run.projectiles._update_hazards(0.125)
	core.step_hazards(0.125)
	beam_states(run,core,"広がる幅の内側へ追従すると命中する")
	# 承認済みの接触境界の統一は、元の厳密不等号との例外として確かめる。
	bridge.restore(empty.value)
	bridge.command("dev_fire_beam",{"position":target+Vector2(config.ship_radius,0),"angle":0.0,"length":200.0,"width":32.0,"arc":0.2,"delay":0.0,"active":1.0,"damage":7.0})
	core.step_hazards(0.125)
	check(core.hazards_snapshot()[0].hit,"広がる形の根元の接触境界も設計どおり当たりに含める")
	for ending in ["death","reuse","pump","skip"]:
		bridge.restore(empty.value)
		run.projectiles.clear_hostile()
		run.enemies.table.dead[owner] = 0
		run.enemies.table.pump_owner[owner] = -1
		run.state.ship_hp = config.base_hp
		run.state.ship_invuln = 0.0
		shot = beam_pair(run,bridge,from,owner,owner_id,0.25)
		if ending=="death":
			run.enemies.table.dead[owner] = 1
			bridge.command("dev_kill",{"entity_id":owner_id,"cause":"ram"})
		elif ending=="reuse":
			run.enemies.table.id[owner] += 100
			core.remove_enemy(owner_id)
			bridge.command("dev_spawn",{"definition_id":"drifter","position":from})
		elif ending=="pump":
			var pump := run.enemies.spawn(run.enemies.def_of(&"drifter"),target+Vector2(500,500))
			var pump_id: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":target+Vector2(500,500)}).value
			run.enemies.table.pump_owner[owner] = pump
			core.set_enemy_motion(owner_id,{"pump_owner":pump_id})
		var dt := 1.25 if ending=="skip" else 0.125
		run.projectiles._update_hazards(dt)
		core.step_hazards(dt)
		check(core.hazards_snapshot().is_empty() and run.projectiles.hazard_slots.live==0,"所有者死亡・行再利用・吸引・期間飛び越しで当たる前に解除する: "+ending)
	# 噛みつきの設定がないランでも、通常Runnerからビームの時計を進める。
	bridge.restore(empty.value)
	var emitted: Dictionary = bridge.command("dev_fire_beam",{"position":target+Vector2(0,100),"angle":0.0,"length":200.0,"width":32.0,"delay":0.25,"active":1.0,"damage":7.0})
	var before: float = core.hazards_snapshot()[0].time
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	check(emitted.ok and core.hazards_snapshot()[0].time>before,"通常更新はビーム単独のステージでも動く")
	bridge.release_checkpoint(active.value)
	bridge.release_checkpoint(warning.value)
	bridge.release_checkpoint(empty.value)
	lab.free()
	session.free()
	beam_finished = true

func beamer_check(ok: bool, label: String) -> void:
	if beamer_fixes and label not in ["当たりの大きさに合わせる新しい外観を使う","保持点からチャージ音の所有も復元する","発生元の撃破・行再利用・吸引で付随ビームを回収する: pull","ビーム敵の確認が最後まで進んだ"]: return
	check(ok,label)

func beamer_state(run: RunSimulation, core, row: int, id: int, label: String) -> void:
	if beamer_fixes: return
	for enemy: Dictionary in core.enemies_snapshot():
		if enemy.id!=id: continue
		beamer_check(Vector2(enemy.pos[0],enemy.pos[1]).distance_to(run.enemies.table.pos[row])<0.02 and Vector2(enemy.vel[0],enemy.vel[1]).distance_to(run.enemies.table.vel[row])<0.02 and absf(enemy.facing-run.enemies.table.facing[row])<0.0001,label+"の距離保持・照準・停止")
	for motion: Dictionary in core.enemy_motion_snapshot():
		if motion.id!=id: continue
		# 負の余りを読まない残り時間は、承認済みの時計の決まりで0にそろえる。
		beamer_check(motion.mode==run.enemies.table.mode[row] and is_equal_approx(motion.timer,maxf(0.0,run.enemies.table.timer[row])) and is_equal_approx(motion.fire_t,maxf(0.0,run.enemies.table.fire_t[row])) and is_equal_approx(motion.charge,run.enemies.table.charge[row]),label+"の予告・照射・再装填")
	beam_states(run,core,label+"の付随ビーム")

func check_cpp_beamer() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 900.0
	config.planet_radius = 100.0
	config.base_hp = 100.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	var stage := RuntimeStage.new()
	stage.index = 83
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["beamer"])
	var output := "res://.content/dev/run_beamer"
	var builder = load("res://tools/content/build_run_content.gd")
	var built: Error = builder.build(stage,config,output,"ビーム敵の予告と付随判定".sha256_text())
	beamer_check(built==OK,"ビーム敵の実効値・新しい本体/装甲/法線を生成する")
	if built!=OK: return
	var path := output.path_join("stage_83.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":983},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	beamer_check(session.bridge!=null,"ビーム敵の通常のランと表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	var initial: Dictionary = bridge.checkpoint()
	var notices := []
	bridge.subscribe("beamer_check",func(frame: Dictionary):
		for event: Dictionary in frame.events:
			if event.type in [&"enemy_laser_charge",&"enemy_laser_fire"]: notices.append(event.type)
		return true)
	for kind in (["normal","pull"] if beamer_fixes else ["normal","death","reuse","pull"]):
		bridge.restore(initial.value)
		notices.clear()
		var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
		add_child(lab)
		await lab.reset({"seed":983,"empty":true,"field":{"terrain":true,"rocks":false,"gimmicks":false},"invincible":false,
			"config":{"start_radius":900.0,"planet_radius":100.0,"base_hp":100.0}})
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
		var definition := run.enemies.def_of(&"beamer")
		var position := target+Vector2(480,120)
		var row := run.enemies.spawn(definition,position)
		var id: int = bridge.command("dev_spawn",{"definition_id":"beamer","position":position}).value
		run.enemies.table.fire_t[row] = 0.125
		core.set_enemy_motion(id,{"fire_t":0.125})
		core.set_motion_context(target,target,Vector2(640,360))
		var warning: Dictionary = {}
		var warning_shapes := []
		for step in 13:
			if step==1:
				director.configure({"enabled":true,"budget":1.0,"jitter":0.0})
				core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
			if step==3 and kind=="death":
				run.combat.kill_enemy(row,{"cause":&"ram"})
				bridge.command("dev_kill",{"entity_id":id,"cause":"ram"})
			elif step==3 and kind=="reuse":
				run.enemies._release_row(row)
				core.remove_enemy(id)
				row = run.enemies.spawn(definition,position)
				var previous_id := id
				id = bridge.command("dev_spawn",{"definition_id":"beamer","position":position}).value
				run.enemies.table.fire_t[row] = 4.0
				core.set_enemy_motion(id,{"fire_t":4.0})
				beamer_check(id!=previous_id and run.enemies.table.id[row]==id,"行を再利用した新しい敵へ古い照射を引き継がない")
			elif step==3 and kind=="pull":
				var puller := run.enemies.spawn(definition,target+Vector2(600,600),{"held":true})
				run.enemies.table.held[puller] = 1
				var puller_id: int = bridge.command("dev_spawn",{"definition_id":"beamer","position":target+Vector2(600,600)}).value
				core.set_enemy_motion(puller_id,{"held":true})
				run.enemies.table.pump_owner[row] = puller
				core.set_enemy_motion(id,{"pump_owner":puller_id})
			if step in [4,5] and kind=="normal":
				run.enemies.table.held[row] = 1 if step==4 else 0
				core.set_enemy_motion(id,{"held":step==4})
			run.state.world_time += 0.125
			run.state.time += 0.125
			director.advance(run.state.world_time,run.enemies)
			core.advance_attack_budget(run.state.world_time)
			run.enemies.tick(0.125,0.125)
			core.step(0.125)
			run.projectiles._update_hazards(0.125)
			core.step_hazards(0.125)
			beamer_state(run,core,row,id,"%s/%d" % [kind,step])
			# 個別Systemを進めた確認では、通常命令と同じ状態公開の区切りも通す。
			var delivered: Dictionary = bridge.command("set_ui_overlay",{"active":false})
			beamer_check(delivered.ok,"ビーム敵の通知と音の状態を公開する: %s/%d" % [kind,step])
			if step==0: beamer_check(core.hazards_snapshot().is_empty(),"枠を待つ間は予告のビームを作らない")
			if step==2 and kind=="normal":
				warning = bridge.checkpoint()
				var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(800,500),Vector2(1600,1000))).value
				warning_shapes = frame.shapes
				beamer_check(frame.shapes.size()==2 and frame.shapes[0].kind==0 and frame.shapes[0].get("behind_parent",false) and frame.shapes[1].kind==1,"予告の線を砲口の光の後ろへ出す")
				var look: EnemyLook
				for entry: Dictionary in session.cpp_resources.visuals:
					if entry.role==6:
						var candidate: EnemyLook = session.resources.resources.get(entry.path)
						if candidate!=null and candidate.source_path=="res://data/visuals/looks/beamer.tres": look = candidate
				beamer_check(look!=null and look.size_from_collision and look.base!=null and look.armor!=null and look.normal!=null,"当たりの大きさに合わせる新しい外観を使う")
				var presentation: RunPresentation = session.view.get_node("RunPresentation")
				presentation._present_cpp(0.0)
				beamer_check(presentation.frame_view.apply_frame(frame) and presentation.frame_view._beamer.size()==10,"本体・装甲・砲口・予告線を通常の表示へ渡す")
				beamer_check(bridge.read_frame().value.ui.laser_voices.size()==1,"チャージ音の所有者を個体IDで返す")
				await get_tree().process_frame
			if step==4 and kind=="normal":
				beamer_check(bridge.read_frame().value.ui.laser_voices[0].paused,"保持中はその敵のチャージ音を止める")
				if AudioManager.sound(&"enemy_laser_charge")!=null:
					beamer_check(session.cpp_laser_audio._voices.has(id) and session.cpp_laser_audio._voices[id].player.stream_paused,"音の再生側も個体の保持に従って一時停止する")
			if step==3 and kind in ["death","reuse","pull"]:
				beamer_check(core.hazards_snapshot().is_empty() and (kind=="pull" or session.cpp_laser_audio._voices.is_empty()),"発生元の撃破・行再利用・吸引で付随ビームを回収する: "+kind)
		if kind=="normal":
			beamer_check(core.hazards_snapshot().is_empty() and core.enemy_motion_snapshot()[0].mode==0,"照射後に判定を回収し次の射撃待ちへ戻る")
			beamer_check(notices.count(&"enemy_laser_charge")==1 and notices.count(&"enemy_laser_fire")==1,"予告と照射の効果音通知を1回ずつ配る")
			var final_enemies: Array = core.enemy_motion_snapshot()
			var final_ship: Dictionary = core.ship_snapshot()
			bridge.restore(warning.value)
			bridge.collect_frame()
			beamer_check(bridge.read_render(Rect2(target-Vector2(800,500),Vector2(1600,1000))).value.shapes==warning_shapes,"保持点から予告線とビームの形も復元する")
			if AudioManager.sound(&"enemy_laser_charge")!=null: beamer_check(session.cpp_laser_audio._voices.has(id),"保持点からチャージ音の所有も復元する")
			for step in range(3,13):
				if step in [4,5]: core.set_enemy_motion(id,{"held":step==4})
				core.advance_attack_budget(core.inspect().world_time+0.125)
				core.step(0.125)
				core.step_hazards(0.125)
			beamer_check(core.hazards_snapshot().is_empty() and core.enemy_motion_snapshot()==final_enemies and core.ship_snapshot()==final_ship,"保持点から同じ照射・被弾・終了を再現する")
			bridge.release_checkpoint(warning.value)
		lab.free()
	bridge.release_checkpoint(initial.value)
	session.free()
	beamer_finished = true

func check_cpp_wall() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 900.0
	config.planet_radius = 100.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	config.invuln_time = 0.06
	var stage := RuntimeStage.new()
	stage.index = 87
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/run_wall"
	var builder = load("res://tools/content/build_run_content.gd")
	check(builder.build(stage,config,output,"壁の予告・再接触・終了".sha256_text())==OK,"壁の共通定義を生成する")
	var path := output.path_join("stage_87.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":287},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"壁を表示する通常のC++ランを準備する")
	if session.bridge==null: session.free(); return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target := Vector2(-900,0)
	bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2.ZERO})
	var owner_id: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":target+Vector2(-300,300)}).value
	var emitted: Dictionary = bridge.command("dev_fire_wall",{"position":target-Vector2(100,0),"angle":0.0,"length":200.0,"width":32.0,"delay":0.25,"active":1.0,"damage":7.0,"owner_id":owner_id})
	check(emitted.ok,"発生源から残る壁を生成する")
	if not emitted.ok: session.free(); return
	var checkpoint: Dictionary = bridge.checkpoint()
	check(checkpoint.ok,"予告中の壁を保持する")
	core.step_hazards(0.125)
	check(is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp),"残る線は予告中に被弾しない")
	var frame: Dictionary = bridge.read_render(Rect2(-1600,-400,1200,800)).value
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	presentation._present_cpp(0.0)
	check(frame.shapes.size()==1 and frame.shapes[0].kind==0 and frame.shapes[0].points.size()==2,"壁の予告は始点から終点まで線で表示する")
	check(presentation.frame_view.apply_frame(frame),"壁の予告を通常の表示へ渡す")
	await get_tree().process_frame
	core.step_hazards(0.125)
	check(is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp-7.0),"残る線に触れると被弾する")
	core.step_hazards(0.01)
	check(is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp-7.0),"壁の接触中も無敵時間は被弾を防ぐ")
	core.step_ship(0.08,0.08,{"touch":true})
	bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2.ZERO})
	core.step_hazards(0.01)
	check(is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp-14.0),"無敵が切れたあとの再接触でまた被弾する")
	frame = bridge.read_render(Rect2(-1600,-400,1200,800)).value
	check(frame.shapes.size()==1 and frame.shapes[0].widths.size()==2 and is_equal_approx(frame.shapes[0].widths[1],32.0),"有効な壁は元の全幅で光と本体を表示する")
	check(presentation.frame_view.apply_frame(frame),"有効な壁を通常の表示へ渡す")
	await get_tree().process_frame
	bridge.command("dev_remove",{"entity_id":owner_id})
	var replacement: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":target+Vector2(500,500)}).value
	core.step_hazards(0.01)
	check(core.hazards_snapshot().size()==1 and core.hazards_snapshot()[0].owner_id==owner_id and replacement!=owner_id,"発生元の退場と行再利用でも元の所有者IDで壁が残る")
	var active: Dictionary = bridge.checkpoint()
	var active_state: Array = core.hazards_snapshot()
	check(active.ok,"接触後の残る壁を値で保持する")
	core.step_hazards(1.0)
	check(core.hazards_snapshot().is_empty(),"残る線は時間で消える")
	bridge.restore(active.value)
	check(core.hazards_snapshot()==active_state,"寿命・幅・所有者ID・接触状態を保持点から復元する")
	core.step_hazards(1.0)
	check(core.hazards_snapshot().is_empty(),"復元後も同じ期限で消える")
	bridge.restore(checkpoint.value)
	var before: Array = core.hazards_snapshot()
	check(not bridge.command("dev_fire_wall",{"position":target,"angle":0.0,"length":200.0,"width":-1.0,"delay":0.0,"active":1.0,"damage":7.0}).ok and core.hazards_snapshot()==before,"不正な壁は状態を変えずに拒否する")
	core.step_hazards(1.25)
	check(core.hazards_snapshot().is_empty() and is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp),"期限を飛び越した壁は命中前に終了する")
	var barrier: Dictionary = bridge.command("dev_fire_wall",{"position":target-Vector2(100,0),"angle":0.0,"length":200.0,"width":32.0,"delay":0.0,"active":1.0,"damage":0.0,"blocking":true,"style":2})
	check(barrier.ok,"じょうぎ座用の移動を止める壁を生成する")
	bridge.command("dev_ship_motion",{"position":target+Vector2(0,100),"velocity":Vector2(0,1000)})
	check(core.collide_ship(target+Vector2(0,-100),config.ship_radius) and core.ship_snapshot().ship_pos.y<0 and core.ship_snapshot().ship_vel.y<0,"壁の手前で機体を止めて弾く")
	bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2(0,1000)})
	check(core.collide_ship(target,config.ship_radius) and core.ship_snapshot().ship_pos.y>16.0+config.ship_radius,"壁の中にいた機体を近い側へ押し出す")
	bridge.command("dev_ship_motion",{"position":target+Vector2(0,100),"velocity":Vector2.ZERO})
	bridge.command("dev_emit_attack",{"pool":0,"position":target+Vector2(0,-100),"velocity":Vector2(0,1000),"life":1.0,"radius":5.0,"damage":2.0})
	core.step_projectiles(0.2)
	check(core.projectiles_snapshot().is_empty(),"移動を止める壁は味方弾を止める")
	bridge.command("dev_emit_attack",{"pool":1,"position":target+Vector2(0,-100),"velocity":Vector2(0,1000),"life":1.0,"radius":5.0,"damage":2.0})
	core.set_motion_context(target+Vector2(0,100),target,Vector2(640,360))
	core.step_hostiles(0.2)
	check(core.hostiles_snapshot().is_empty() and is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp),"壁が敵弾を機体より先に止める")
	frame = bridge.read_render(Rect2(-1600,-400,1200,800)).value
	check(frame.shapes.size()==2 and presentation.frame_view.apply_frame(frame),"じょうぎ座の壁は光の柱と根元の光を表示する")
	await get_tree().process_frame
	bridge.command("dev_attack_scope",{"event":"bonus"})
	check(core.hazards_snapshot().is_empty(),"ボーナス切替で残る壁を回収する")
	bridge.release_checkpoint(active.value)
	bridge.release_checkpoint(checkpoint.value)
	session.free()
