## 噛みつきの円形判定・一度だけの被弾・残留する枠と表示状態を比較する。
extends "res://tests/native_attack_budget.gd"
const SHIP := preload("res://tests/native_ship.gd")
var beam_finished := false
var beam_retry := false
func values(object: Object,keys: Array) -> Dictionary:
	var out := {}
	for key in keys: out[key] = object.get(key)
	return out
func _ready() -> void:
	comparison = COMPARE.new()
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
