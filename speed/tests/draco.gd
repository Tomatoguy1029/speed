extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	if "--cpp-draco-breath" in OS.get_cmdline_user_args() or "--cpp-draco-breath-rays" in OS.get_cmdline_user_args():
		call_deferred("native_breath")
		return
	check(ResourceLoader.exists("res://data/bosses/draco.tres"), "竜のボス定義を登録する")
	if failed:
		get_tree().quit(1)
		return
	var stage: RuntimeStage = ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled = false
	var session := RunManager.create_session(self, {"lab": true, "stage": stage, "stage_index": 5, "seed": 105}, false)
	session.auto_step = false
	var sim: RunSimulation = session.sim
	sim.field.bodies.clear()
	sim.state.phase = RunState.Phase.PLAY
	sim.state.ship_pos = Vector2(300,0)
	sim.state.enemy_aim = sim.state.ship_pos
	sim.bosses.spawn(load("res://data/bosses/draco.tres"), Vector2.ZERO)
	var actor = sim.bosses.actor
	check(actor != null and actor.def.id == &"draco", "実験場に本番用の竜を生成できる")
	check(actor.get("entrance") != null, "静かな星空から対面までを所有する")
	if actor.get("entrance") != null:
		actor.entrance.begin()
		check(not actor.start_attack(&"bite") and sim.state.controls_locked, "登場中は攻撃と操作を止める")
		for frame in 1100: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(actor.mode==&"idle" and not sim.state.controls_locked and sim.state.cinematic_bars==0.0, "対面後に戦闘へ引き渡す")
	# The entrance now stages an authored world-space confrontation. The
	# independent collision/attack fixtures below explicitly use their own origin.
	sim.enemies.table.pos[actor.body] = Vector2.ZERO
	sim.enemies.table.facing[actor.body] = 0.0
	actor.reset_pose()
	check(actor.get("body_rows") != null, "全身の命中形状を持つ")
	if actor.get("body_rows") != null:
		var rows: Array = actor.body_rows
		check(rows.size() > 3, "長い胴体に沿って判定を置く")
		var before: float = sim.enemies.table.hp[actor.body]
		sim.combat.damage_enemy(rows[-1],50.0,{"cause": &"shot"})
		check(is_equal_approx(sim.enemies.table.hp[actor.body],before-50.0), "尾への命中が本体HPを削る")
		sim.combat.rebuild_grid()
		var trace := TraceRun.new()
		before = sim.enemies.table.hp[actor.body]
		for row: int in rows:
			var at: Vector2 = sim.enemies.table.pos[row]
			sim.combat.twin_sweep(trace,at-Vector2(20,0),at+Vector2(20,0))
		check(is_equal_approx(before-sim.enemies.table.hp[actor.body],sim.combat.attack_power()), "同じ突進で複数の部位に触れても一体分だけ命中する")
	var trace_hp: float = sim.enemies.table.hp[actor.body]
	sim.state.ship_pos = Vector2(140,0)
	sim.state.ship_vel = Vector2.RIGHT * sim.state.stats.max_speed * 2.0
	sim.state.stats.crit_chance = 0.0
	sim.combat.collide_ship(Vector2(-750,0),sim.cfg.trace_radius,TraceRun.new())
	check(is_equal_approx(trace_hp-sim.enemies.table.hp[actor.body],sim.combat.attack_power()), "実際の一筆でも胴体の重複命中を防ぐ")
	check(actor.get("flow_adapter") != null, "竜は共通フローのadapterを持つ")
	if actor.get("flow_adapter") != null:
		check(not actor.flow_adapter.candidates({"request":"any"}).candidates.is_empty(), "距離条件から噛みつきを候補にできる")
	check(actor.start_attack(&"bite"), "噛みつきを開始する")
	for frame in 600: actor.sim_tick(1.0/120.0,1.0/120.0)
	check(not actor.attack_playing(), "噛みつきの予告・実行・隙が終わる")
	actor.cancel_attack()
	check(actor.start_attack(&"tail_sweep"), "尾の薙ぎ払いをフロー登録から開始できる")
	for frame in 480: actor.sim_tick(1.0/120.0,1.0/120.0)
	check(actor.mode == &"idle", "尾の攻撃は隙を終えて戻る")
	actor.cancel_attack()
	var bullets_before := sim.projectiles.hostile_count()
	check(actor.start_attack(&"star_fan"), "頭部の星弾を開始できる")
	for frame in 240: actor.sim_tick(1.0/120.0,1.0/120.0)
	check(sim.projectiles.hostile_count() - bullets_before == 9, "扇に並んだ星弾を一斉発射する")
	actor.cancel_attack()
	var hazards_before := sim.projectiles.hazard_count()
	check(actor.start_attack(&"tail_slam"), "尾を叩きつける攻撃を開始する")
	for frame in 300: actor.sim_tick(1.0/120.0,1.0/120.0)
	check(sim.projectiles.hazard_count() > hazards_before, "尾の着地点に小さな衝撃波を出す")
	actor.cancel_attack()
	check(actor.start_attack(&"breath"), "隕石投射からブレスを開始する")
	if actor.technique == &"breath":
		var breath = actor._runner
		check(breath.rocks.size() == 3, "口から遮蔽用の隕石を出す")
		for frame in 150: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(breath.rays.size() > 12, "炎の表示と命中に使う遮蔽光線を計算する")
		actor.elapsed = float(actor.rule().active) * 0.5
		sim.state.ship_pos = Vector2(700,0)
		sim.ship.invincible = false
		sim.state.ship_invuln = 0.0
		var before_hp := sim.state.ship_hp
		breath.tick(actor,1.0/120.0)
		check(sim.state.ship_hp == before_hp, "隕石の裏にはブレスが当たらない")
		sim.enemies.mark_dead(breath.rocks[1].row)
		breath.tick(actor,1.0/120.0)
		check(sim.state.ship_hp < before_hp, "遮蔽が破壊されたら見える炎と同時に被弾する")
		actor.cancel_attack()
		check(breath.rocks.all(func(r): return sim.enemies.table.dead[r.row] != 0), "中断時に配置済みの隕石を崩す")
	for id in [&"charge",&"leap"]:
		actor.cancel_attack()
		check(actor.start_attack(id), "移動攻撃を開始する: "+id)
		var origin: Vector2 = sim.enemies.table.pos[actor.body]
		for frame in 1200:
			actor.sim_tick(1.0/120.0,1.0/120.0)
			if actor.mode == &"idle": break
		check(sim.enemies.table.pos[actor.body].distance_to(origin)>100.0, "移動攻撃で本体が移動する: "+id)
		check(actor.mode == &"idle", "移動攻撃後に隙を終える: "+id)
	actor.cancel_attack()
	check(actor.start_attack(&"rifts"), "三本爪の亀裂を開始する")
	if actor.technique == &"rifts":
		var rifts_complete := false
		for frame in 1200:
			actor.sim_tick(1.0/120.0,1.0/120.0)
			if actor._runner == null: break
			if actor._runner.walls.size() == 6:
				rifts_complete = true
				break
		check(rifts_complete, "左右それぞれ三本の亀裂を残す")
		actor.cancel_attack()
		for frame in 60: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(actor.closing_walls.is_empty(), "亀裂を修復してから次へ進む")
	sim.projectiles.clear_hostile()
	var wall := sim.projectiles.fire_wall(Vector2(0,900),-PI*0.5,200.0,20.0,0.0,5.0,0.0)
	sim.projectiles.hazard_block[wall] = 1
	sim.projectiles.fire_bolt(Vector2(-200,800),0.0,400.0,10.0)
	sim.projectiles._update_hostile(1.0)
	check(sim.projectiles.hostile_count() == 0, "通行を止める壁は敵弾も遮る")
	sim.projectiles.release_hazard(wall)
	check(actor.get("picaro") != null, "ピカロの生成と所有者を持つ")
	if actor.get("picaro") != null:
		for id in [&"biter",&"pump"]:
			var row: int = actor.picaro.spawn_picaro(id,Vector2(500,300))
			check(sim.enemies.table.def[row].behavior == sim.enemies.def_of(id).behavior, "ピカロは元の敵の行動を使う")
			check(sim.enemies.table.def[row].params.get("picaro",false), "共通コズミック描画を指定する")
			check(not sim.enemies.def_of(id).params.get("picaro",false), "元の敵定義を変更しない")
		for frame in 150: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(actor.picaro.alive().size() == 2, "異なる既存敵のピカロを保持する")
	actor.cancel_attack()
	check(actor.start_attack(&"picaro_wall"), "隊列と口からの光の矢を開始する")
	if actor.technique == &"picaro_wall":
		var driver = actor._runner
		for frame in 240: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(driver.shots>1, "口から上向きに複数発を連射する")
		check(not driver.impacts.is_empty(), "画面外へ消えた後に固定地点を予告する")
		if not driver.impacts.is_empty():
			var target: Vector2 = driver.impacts[0].pos
			sim.state.enemy_aim += Vector2(200,0)
			actor.sim_tick(0.01,0.01)
			check(driver.impacts[0].pos == target, "予告後は自機を追わない")
		actor.cancel_attack()
	actor.cancel_attack()
	check(actor.start_attack(&"clones"), "全身複製を開始できる")
	if actor.technique == &"clones":
		var clones = actor._runner
		check(clones.units.size()==3, "本体を含め合計三体を編成する")
		var hp: float = sim.enemies.table.hp[actor.body]
		var row: int = clones.units[1].row
		sim.combat.damage_enemy(row,10.0,{"cause":&"shot"})
		check(sim.enemies.table.hp[actor.body]==hp, "複製のHPは本体と独立する")
		for frame in 1400: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(actor.mode==&"idle", "複製の共同攻撃から回収を終える")
		check(sim.enemies.table.dead[row]!=0, "残った複製は吸収だけで回収する")
	actor.cancel_attack()
	check(actor.start_attack(&"inhale"), "吸引と吐き出しを開始する")
	if actor.technique == &"inhale":
		var inhale = actor._runner
		var member: int = actor.picaro.spawn_picaro(&"pump",sim.enemies.table.pos[actor.body]+Vector2(70,0))
		for frame in 600: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(sim.enemies.table.dead[member]!=0, "口元に来たピカロを吸収する")
		check(inhale.spent and inhale.stars==0, "吸収星数は直後の吐き出し一回で使い切る")
		actor.cancel_attack()
	actor.cancel_attack()
	check(actor.start_attack(&"spiral"), "螺旋収縮を開始する")
	if actor.technique == &"spiral":
		var spiral = actor._runner
		var center: Vector2 = spiral.center
		sim.state.enemy_aim += Vector2(500,0)
		for frame in 540: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(spiral.center==center, "螺旋の中心は開始時の位置に固定する")
		check(not spiral.walls.is_empty(), "青紫の胴体オーラは弾と機体を遮る")
		actor.cancel_attack()
		check(spiral.walls.all(func(h): return sim.projectiles.hazard_alive[h]==0), "中断した螺旋壁を残さない")
	for expected_phase in [2,3]:
		var threshold := 0.7 if expected_phase == 2 else 0.4
		sim.combat.damage_enemy(actor.body,1.0e6,{"cause": &"shot"})
		check(actor.phase == expected_phase, "大きな一撃でもHP段階を一つずつ進める")
		check(is_equal_approx(sim.enemies.table.hp[actor.body],sim.enemies.table.max_hp[actor.body] * threshold), "超過分を切り捨てて閾値でHPを止める")
		if expected_phase == 2: check(sim.state.controls_locked, "初回ピカロ生成だけ操作を止める")
		else: check(not sim.state.controls_locked, "終盤移行では操作を維持する")
		check(not sim.state.boss_dead, "段階移行は最終勝利を通知しない")
		for frame in 1200: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(actor.mode == &"idle" and sim.enemies.table.guard[actor.body] <= 0.0, "移行後に攻撃と被弾を再開できる")
	check(actor.get("finale") != null, "HP0を専用の最終決着へ接続する")
	if actor.get("finale") != null:
		sim.combat.damage_enemy(actor.body,1.0e6,{"cause":&"shot"})
		check(actor.mode==&"finale" and not sim.state.boss_dead, "核解放前に勝利を通知しない")
		for frame in 720: actor.advance_finale(1.0/120.0,Intent.new())
		check(actor.finale.stage==&"input", "解放と合体から自由描画へ進む")
		check(sim.state.final_modules.size()==4, "四つの伝説モジュールを武器欄へ渡す")
		var intent := Intent.new()
		intent.press=true;intent.has_cursor=true;intent.pen=Vector2.ZERO
		actor.advance_finale(0.01,intent)
		intent.press=false;intent.pen=Vector2(10000,10000)
		actor.advance_finale(0.01,intent)
		check(actor.finale.strokes.size()>=2 and actor.finale.stage==&"input", "無制限の自由描画中も自動確定しない")
		check(sim.state.world_scale==0.0, "最終描画中の世界速度はゼロ")
		intent.pen_release=true
		actor.advance_finale(0.01,intent)
		check(actor.finale.stage==&"strikes", "離すと入力経路に関係なく固定フィニッシュを始める")
		sim.state.lab_mode=false
		for frame in 1500: actor.advance_finale(1.0/120.0,Intent.new())
		check(sim.state.boss_dead and actor.finale.completed, "固定連撃と切断・爆発を終えて勝利を通知する")
		var wins := sim.state.events.filter(func(e): return e.type==&"boss_defeated").size()
		actor.advance_finale(1.0,Intent.new())
		check(sim.state.events.filter(func(e): return e.type==&"boss_defeated").size()==wins and wins==1, "最終勝利を一度だけ通知する")
		sim.state.lab_mode=true
	session.free()
	print("[draco] failures=",failed)
	get_tree().quit(1 if failed else 0)

## 既存ブレスの遮蔽・破壊・中断へC++の状態と描画を接続する。
func breath_fixture(move: BossTechnique, flow_enabled := false) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg: GameConfig = load("res://data/config.tres").duplicate(true)
	var package: Dictionary = builder.draco_technique_package(load("res://data/bosses/draco.tres"),move,cfg)
	if flow_enabled:
		var rules=load("res://scripts/data_types/boss_action_rules.gd").new()
		rules.adapter=&"draco";rules.techniques.assign([move]);rules.conditions={"breath":{}}
		var flow=load("res://scripts/data_types/boss_flow_def.gd").new()
		flow.sections=[{"request":"normal","cap":2.0,"next":0,"action_count":1}]
		var compiled: Dictionary=builder.boss_flow_records(rules,flow,package.records.BossTechniqueDefinition)
		for key in compiled: package.records[key]=compiled[key]
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":194,"mode":1,"stage_id":"B_draco_breath","profile":{},"settings":{"hitstop":false}})
	check(configured.ok,"ブレスと報酬ゼロの専用投石定義を生成して読む")
	if not configured.ok: print(configured);return {}
	bridge.start(105,{"position":Vector2(700,0),"lab_mode":true})
	var captured: Array = []
	bridge.subscribe("確認",func(frame):captured.append_array(frame.events);return true)
	bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true,"level":1,"position":Vector2(700,0),"invincible":false}})
	bridge._core.set_motion_context(Vector2(700,0),Vector2(700,0),Vector2(800,450))
	var boss: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	return {"bridge":bridge,"boss":boss,"package":package,"captured":captured}

func native_breath() -> void:
	var rays_only := "--cpp-draco-breath-rays" in OS.get_cmdline_user_args()
	var move: BossTechnique = load("res://data/bosses/draco_moves/breath.tres")
	var fixture := breath_fixture(move)
	if fixture.is_empty(): get_tree().quit(1);return
	var bridge = fixture.bridge
	var stage: RuntimeStage = ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled=false
	var session := RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":105},false)
	session.auto_step=false
	var sim: RunSimulation=session.sim
	sim.field.bodies.clear();sim.state.phase=RunState.Phase.PLAY;sim.ship.invincible=false
	sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
	var actor=sim.bosses.actor
	actor.selection_enabled=false;actor.clock=0.0;actor.cycle.cancel();actor.cancel_attack()
	sim.state.ship_pos=Vector2(700,0);sim.state.enemy_aim=Vector2(700,0);sim.state.ship_vel=Vector2.ZERO;sim.state.ship_invuln=0.0
	check(actor.start_attack(&"breath") and bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1}).ok,"SourceとC++のブレスを開始する")
	var driver=actor._runner
	var max_rock_error := 0.0
	var max_ray_error := 0.0
	var stage_equal := true
	var facing_error := 0.0
	var behind_safe := true
	var damaged_after_break := false
	for frame in 610:
		actor.sim_tick(1.0/120.0,1.0/120.0);bridge._core.step(1.0/120.0)
		var attack: Dictionary=bridge.command("dev_boss_state").value[0]
		var body: Dictionary=bridge.command("dev_boss_body_state").value[-1]
		stage_equal=stage_equal and attack.stage=={&"windup":0,&"active":1,&"recovery":2,&"idle":5}[actor.mode]
		facing_error=maxf(facing_error,absf(angle_difference(body.facing,actor.table.facing[actor.body])))
		for j in attack.rocks.size(): max_rock_error=maxf(max_rock_error,attack.rocks[j].position.distance_to(driver.rocks[j].pos))
		if attack.attack_points.size()==actor.attack_points.size():
			for j in attack.attack_points.size(): max_ray_error=maxf(max_ray_error,attack.attack_points[j].distance_to(actor.attack_points[j]))
		elif attack.stage==1 and actor.mode==&"active": check(false,"遮蔽の光線数がSourceと一致する")
		if frame==275:
			behind_safe=not fixture.captured.any(func(event):return event.type==&"combat_player_damage" and event.payload.accepted)
			sim.enemies.mark_dead(driver.rocks[1].row)
			bridge.command("dev_kill",{"entity_id":attack.rocks[1].actor,"cause":"debug"})
		if frame==280 and not rays_only:
			damaged_after_break=fixture.captured.any(func(event):return event.type==&"combat_player_damage" and event.payload.cause==&"breath" and event.payload.source==&"draco" and event.payload.accepted)
			var held: Dictionary=bridge.checkpoint()
			check(held.ok,"遮蔽破壊後のブレス・岩・光線を保持する")
			bridge._core.step(1.0/120.0)
			var future: Array=bridge.command("dev_boss_state").value
			check(bridge.restore(held.value).ok,"ブレスの途中へ復帰する")
			bridge._core.step(1.0/120.0)
			check(bridge.command("dev_boss_state").value==future,"復帰後も同じ遮蔽光線で進む")
			bridge.restore(held.value);bridge.release_checkpoint(held.value)
		if not rays_only and frame in [120,280,430]:
			var appearance := {}
			for visual: Dictionary in fixture.package.visuals:
				if visual.get("boss","")=="draco":appearance=visual.appearance
			var display=load("res://scripts/render/bosses/draco.gd").new()
			add_child(display);display.apply_frame(body,attack,appearance);display.queue_redraw();await get_tree().process_frame
			check(display._parts.visible,"扇の予告・遮蔽されたブレス・岩の破壊を状態から描画する")
			display.free()
	if rays_only:
		check(max_ray_error<0.1,"Sourceと65光線の遮蔽点列が一致する: %s"%max_ray_error)
		bridge.dispose();session.free()
		print("[cpp_draco_breath_rays] failures=",failed)
		get_tree().quit(1 if failed else 0)
		return
	check(stage_equal and facing_error<0.0001,"Sourceの開始・発動・終了時刻と薙ぐ向きが一致する")
	check(max_rock_error<0.1 and max_ray_error<0.1,"投石の移動と65光線の遮蔽点列が一致する: %s/%s"%[max_rock_error,max_ray_error])
	check(behind_safe and damaged_after_break,"岩の裏は安全で、遮蔽を壊した光線から被弾する")
	check(bridge.command("dev_boss_state").value[0].rocks.all(func(rock):return rock.destroyed and not rock.alive),"自然終了は残る岩をすべて崩す")
	for seconds in [0.3,1.5,3.7]:
		var started: Dictionary=bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
		for frame in int(seconds*120):bridge._core.step(1.0/120.0)
		check(bridge.command("dev_cancel_technique",{"ticket":started.value}).ok,"予告・実行・回復の途中で取消できる")
		check(bridge.command("dev_boss_state").value[0].rocks.all(func(rock):return rock.destroyed and not rock.alive),"途中取消も投石をすべて崩す")
	bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
	bridge.command("dev_cancel_boss",{"entity_id":fixture.boss})
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_state").value[0].rocks.all(func(rock):return rock.destroyed and not rock.alive),"本体消失はブレスと所有する投石を取り消す")
	bridge.dispose();session.free()
	var clear: BossTechnique=move.duplicate(true);clear.rocks=0
	for at in [Vector2(1000,230),Vector2(1000,210)]:
		fixture=breath_fixture(clear);bridge=fixture.bridge
		bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
		bridge._core.step(1.1)
		bridge.command("dev_ship_motion",{"position":at,"velocity":Vector2.ZERO})
		bridge._core.step(1.2);bridge.command("dev_boss_state")
		var hit: bool=fixture.captured.any(func(event):return event.type==&"combat_player_damage" and event.payload.accepted)
		check(hit==(at.y<220.0),"ブレスは機体半径を足さない点判定を保つ")
		bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":0.0})
		bridge._core.step(1.0/120.0);bridge.command("dev_boss_state")
		if at.y<220.0:check(fixture.captured.filter(func(event):return event.type==&"combat_player_damage" and event.payload.accepted).size()==2,"ブレスの直接判定は技全体の1回制限を加えない")
		bridge.dispose()
	fixture=breath_fixture(move);bridge=fixture.bridge
	var positions := PackedVector2Array([Vector2(502,-240),Vector2(502,0),Vector2(502,240)])
	var rock_enemy: int=fixture.package.records.DracoBreathDefinition[0].rock_enemy
	check(bridge.command("dev_draco_pose",{"entity_id":fixture.boss,"operation":"placed_meteors","definition":rock_enemy,"points":positions}).ok,"先行する投石の記録を既存の場面準備へ渡す")
	var started: Dictionary=bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
	var reused: Dictionary=bridge.command("dev_boss_state").value[0]
	check(reused.reused and reused.rocks.size()==3,"前の技が置いた同じ岩をブレスで再利用する")
	bridge._core.step(0.6)
	reused=bridge.command("dev_boss_state").value[0]
	var stable := true
	for j in positions.size():stable=stable and reused.rocks[j].position.is_equal_approx(positions[j])
	check(stable,"再利用した岩を予告中に口から動かし直さない")
	bridge.command("dev_cancel_technique",{"ticket":started.value})
	check(bridge.command("dev_boss_state").value[0].rocks.all(func(rock):return rock.destroyed and not rock.alive),"再利用した岩も取消で崩す")
	bridge.dispose()
	fixture=breath_fixture(clear,true);bridge=fixture.bridge
	var first := -1
	var second := false
	for frame in 700:
		bridge._core.step(1.0/120.0)
		var active: Array=bridge.command("dev_boss_state").value
		if not active.is_empty():
			if first<0:first=active[0].id
			elif active.any(func(t):return t.id!=first and t.stage==0):second=true;break
	check(first>0 and second,"ブレスを候補から選んで自然終了後に次の行動へ進める")
	bridge.dispose()
	print("[cpp_draco_breath] failures=",failed)
	get_tree().quit(1 if failed else 0)
