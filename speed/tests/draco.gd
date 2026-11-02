extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	if "--cpp-draco-meteor" in OS.get_cmdline_user_args():
		call_deferred("native_meteor")
		return
	if "--cpp-draco-star-fan" in OS.get_cmdline_user_args():
		call_deferred("native_star_fan")
		return
	if "--cpp-draco-tail-sweep" in OS.get_cmdline_user_args():
		call_deferred("native_tail_sweep")
		return
	if "--cpp-draco-tail-slam" in OS.get_cmdline_user_args():
		call_deferred("native_tail_slam")
		return
	if "--cpp-draco-leap" in OS.get_cmdline_user_args():
		call_deferred("native_leap")
		return
	if "--cpp-draco-charge" in OS.get_cmdline_user_args():
		call_deferred("native_charge")
		return
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
func breath_fixture(move: BossTechnique, flow_enabled := false, moves: Array = []) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg: GameConfig = load("res://data/config.tres").duplicate(true)
	var package: Dictionary = builder.draco_technique_package(load("res://data/bosses/draco.tres"),move,cfg)
	if not moves.is_empty():
		package=builder.boss_body_package(load("res://data/bosses/draco.tres"),cfg)
		var records: Dictionary=builder.draco_set_records(load("res://data/bosses/draco.tres"),moves)
		for record in records:package.records[record]=records[record]
		for part: BossTechnique in moves:
			if part.technique in [&"breath",&"meteor"]:builder.append_draco_breath_rock(package,part,cfg)
			builder.append_draco_style(package,part)
	if flow_enabled:
		var rules=load("res://scripts/data_types/boss_action_rules.gd").new()
		rules.adapter=&"draco";rules.techniques.assign([move]);rules.conditions={"breath":{}}
		var flow=load("res://scripts/data_types/boss_flow_def.gd").new()
		flow.sections=[{"request":"normal","cap":2.0,"next":0,"action_count":1}]
		var compiled: Dictionary=builder.boss_flow_records(rules,flow,package.records.BossTechniqueDefinition)
		for key in compiled: package.records[key]=compiled[key]
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":194,"mode":1,"stage_id":"B_draco_"+str(move.technique),"profile":{},"settings":{"hitstop":false}})
	check(configured.ok,"技の型付き定義と依存する敵を生成して読む")
	if not configured.ok: print(configured);return {}
	bridge.start(105,{"position":Vector2(700,0),"lab_mode":true})
	var captured: Array = []
	bridge.subscribe("確認",func(frame):captured.append_array(frame.events);return true)
	bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true,"level":1,"position":Vector2(700,0),"invincible":false}})
	bridge._core.set_motion_context(Vector2(700,0),Vector2(700,0),Vector2(800,450))
	var boss: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	return {"bridge":bridge,"boss":boss,"package":package,"captured":captured}

## 既存の移動攻撃・中断ケースへ突進の状態と表示を接続する。
func native_charge() -> void:
	await native_draco_move("charge")

func native_leap() -> void:
	await native_draco_move("leap")

func draco_move_stage(attack: Dictionary) -> int:
	return (3 if attack.get("staging_phase",0)==1 else 4) if attack.stage==0 and not attack.staging_ready else int(attack.stage)

func native_draco_move(move_id: String) -> void:
	var motion_only:= "--cpp-draco-"+move_id+"-motion" in OS.get_cmdline_user_args()
	var move: BossTechnique=load("res://data/bosses/draco_moves/%s.tres"%move_id)
	var label: String=move.display_name
	var fixture:=breath_fixture(move)
	if fixture.is_empty():get_tree().quit(1);return
	var bridge=fixture.bridge
	check(fixture.package.records["DracoChargeDefinition" if move_id=="charge" else "DracoLeapDefinition"].size()==3,label+"の実効値を3形態へ生成する")
	var stage: RuntimeStage=ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled=false
	var session:=RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":105},false)
	session.auto_step=false
	var sim: RunSimulation=session.sim
	sim.field.bodies.clear();sim.state.phase=RunState.Phase.PLAY;sim.ship.invincible=false
	sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
	var a=sim.bosses.actor
	a.selection_enabled=false;a.cycle.cancel();a.cancel_attack();a.clock=0.0;a.table.facing[a.body]=0.0;a.body_trail.clear();a.body_pose.clear();a.body_override.clear();a.reset_pose()
	sim.state.ship_pos=Vector2(700,0);sim.state.enemy_aim=Vector2(700,0);sim.state.ship_vel=Vector2.ZERO
	sim.state.view_center=Vector2(700,0);sim.state.view_half=Vector2(800,450)
	check(a.start_attack(StringName(move_id)) and bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1}).ok,"SourceとC++の移動攻撃を開始する")
	# SourceのGodot RNGとC++ PCGの抽選値は異なるため、選ばれた左右を同じにして動作を照合する。
	a._runner.staging.side=bridge.command("dev_boss_state").value[0].staging_side
	var position_error:=0.0
	var shape_error:=0.0
	var warning_error:=0.0
	var attack_error:=0.0
	var times_equal:=true
	var saved: Array=[]
	var rendered: Array=[]
	for frame in 900:
		a.sim_tick(1.0/120.0,1.0/120.0);bridge._core.step(1.0/120.0)
		var attack: Dictionary=bridge.command("dev_boss_state").value[0]
		var body: Dictionary=bridge.command("dev_boss_body_state").value[-1]
		position_error=maxf(position_error,body.position.distance_to(a.table.pos[a.body]))
		var points: PackedVector2Array=a.body_points()
		for j in points.size():shape_error=maxf(shape_error,points[j].distance_to(body.body_points[j]))
		times_equal=times_equal and attack.stage=={&"windup":0,&"active":1,&"recovery":2,&"idle":5}[a.mode] and is_equal_approx(attack.stage_time,a.elapsed)
		if a._runner!=null:times_equal=times_equal and attack.locked==a._runner.locked
		if attack.attack_points.size()==a.attack_points.size():
			for j in a.attack_points.size():attack_error=maxf(attack_error,attack.attack_points[j].distance_to(a.attack_points[j]))
		else:attack_error=INF
		if not a.telegraph_paths.is_empty():
			if not motion_only:check(attack.warning.size()==2,"予告の線分を出す")
			if attack.warning.size()==2:
				for j in 2:warning_error=maxf(warning_error,attack.warning[j].distance_to(a.telegraph_paths[0][j]))
		var key: int=draco_move_stage(attack)
		if not motion_only and key not in saved and key<5:
			saved.append(key)
			var held: Dictionary=bridge.checkpoint()
			check(held.ok,"退場・予告・実行・回復の値型を保持する")
			bridge._core.step(1.0/120.0)
			var future: Array=bridge.command("dev_boss_state").value
			var future_body: Array=bridge.command("dev_boss_body_state").value
			check(bridge.restore(held.value).ok,label+"の途中へ復帰する")
			bridge._core.step(1.0/120.0)
			check(bridge.command("dev_boss_state").value==future and bridge.command("dev_boss_body_state").value==future_body,"復帰後の段階・固定照準・全身点列が一致する")
			bridge.restore(held.value);bridge.release_checkpoint(held.value)
		if not motion_only and key not in rendered and key in [0,1,2]:
			rendered.append(key)
			var appearance: Dictionary={}
			for visual: Dictionary in fixture.package.visuals:
				if visual.get("boss","")=="draco":appearance=visual.appearance
			var display=load("res://scripts/render/bosses/draco.gd").new()
			add_child(display);display.apply_frame(body,attack,appearance);await get_tree().process_frame
			check(display._parts.visible,"同じ技状態から予告・攻撃軌跡・回復を描画する")
			display.free()
		if attack.stage==5 and a.mode==&"idle":break
	check(times_equal,"Sourceと退場中の時計0・予告・実行・回復の切替tickが一致する")
	check(position_error<0.1 and shape_error<0.1 and warning_error<0.1 and attack_error<0.1,label+"の頭・全身・予告・口線分がSourceと一致する: %s/%s/%s/%s"%[position_error,shape_error,warning_error,attack_error])
	if motion_only:
		bridge.dispose();session.free()
		native_draco_move_flow(move)
		return
	check(saved.size()==(4 if move_id=="charge" else 5) and rendered.size()==3,"退場から自然終了までの各段階を通る")
	var hits: Array=fixture.captured.filter(func(event):return event.type==&"combat_player_damage" and event.payload.accepted and event.payload.cause==StringName(move_id) and event.payload.source==&"draco" and event.payload.technique==StringName(move_id))
	check(hits.size()==1,"無敵を切った静止対象へ原因・出所・技名を持って1回命中する")
	for target in ([4,0,1,2] if move_id=="charge" else [4,3,0,1,2]):
		var started: Dictionary=bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
		for frame in 900:
			bridge._core.step(1.0/120.0)
			var attack: Dictionary=bridge.command("dev_boss_state").value[0]
			if draco_move_stage(attack)==target:break
		var at: Vector2=bridge.command("dev_boss_body_state").value[-1].position
		check(bridge.command("dev_cancel_technique",{"ticket":started.value}).ok,"退場・予告・実行・回復の途中で取り消す")
		check(bridge.command("dev_boss_state").value[0].warning.is_empty() and bridge.command("dev_boss_state").value[0].attack_points.is_empty() and bridge.command("dev_boss_body_state").value[-1].position.is_equal_approx(at),"取消は移動先を保ち予告・攻撃線を消す")
	bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
	bridge.command("dev_cancel_boss",{"entity_id":fixture.boss})
	check(bridge.command("dev_boss_state").value[0].stage==7,"本体消失で移動攻撃を取り消す")
	bridge.dispose();session.free()
	native_draco_move_flow(move)

func native_draco_move_flow(move: BossTechnique) -> void:
	var label: String=move.display_name
	# 既存の候補選択→自然終了→次技ケースへ接続する。
	var rules=load("res://scripts/data_types/boss_action_rules.gd").new()
	rules.adapter=&"draco";rules.techniques.assign([move]);rules.conditions={str(move.technique):{}}
	var flow=load("res://scripts/data_types/boss_flow_def.gd").new()
	flow.sections=[{"request":"major" if move.category==&"major" else "normal","cap":2.0,"weights":{"major":100.0} if move.category==&"major" else {"single":100.0},"next":0,"action_count":1}]
	var builder=load("res://tools/content/build_run_content.gd")
	var fixture:=breath_fixture(move)
	var bridge=fixture.bridge
	var package: Dictionary=fixture.package
	bridge.dispose()
	var compiled: Dictionary=builder.boss_flow_records(rules,flow,package.records.BossTechniqueDefinition)
	for k in compiled:package.records[k]=compiled[k]
	bridge=load("res://scripts/runtime/run_bridge.gd").new()
	check(bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":195,"mode":1,"stage_id":"B_draco_"+str(move.technique),"profile":{},"settings":{"hitstop":false}}).ok,label+"の候補フローを読む")
	bridge.start(105,{"position":Vector2(700,0),"lab_mode":true})
	bridge.subscribe("確認",func(_frame):return true)
	bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true,"position":Vector2(700,0),"invincible":false}})
	bridge._core.set_motion_context(Vector2(700,0),Vector2(700,0),Vector2(800,450))
	bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false})
	var first: int=-1
	var second:=false
	for frame in 1200:
		bridge._core.step(1.0/120.0)
		var active: Array=bridge.command("dev_boss_state").value
		if not active.is_empty():
			if first<0:first=active[0].id
			elif active.any(func(t):return t.id!=first and t.stage==0):second=true;break
	check(first>0 and second,label+"を選択して自然終了後に次の行動へ進む")
	bridge.dispose()
	print("[cpp_draco_%s] failures="%move.technique,failed)
	get_tree().quit(1 if failed else 0)

## 既存の尾の着弾・小さな波・中断を同じSourceへ照合する。
func native_tail_slam() -> void:
	var move: BossTechnique=load("res://data/bosses/draco_moves/tail_slam.tres")
	var fixture:=breath_fixture(move)
	if fixture.is_empty():get_tree().quit(1);return
	var bridge=fixture.bridge
	check(fixture.package.records.DracoTailSlamDefinition.size()==3,"尾の叩きつけの実効値を3形態へ生成する")
	var stage: RuntimeStage=ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled=false
	var session:=RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":105},false)
	session.auto_step=false
	var sim: RunSimulation=session.sim
	sim.field.bodies.clear();sim.state.phase=RunState.Phase.PLAY;sim.ship.invincible=false
	sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
	var a=sim.bosses.actor
	a.selection_enabled=false;a.cycle.cancel();a.cancel_attack();a.clock=0.0;a.table.facing[a.body]=0.0;a.body_trail.clear();a.body_pose.clear();a.body_override.clear();a.reset_pose()
	sim.state.ship_pos=Vector2(700,0);sim.state.enemy_aim=Vector2(700,0);sim.state.ship_vel=Vector2.ZERO;sim.state.ship_invuln=0.0
	check(a.start_attack(&"tail_slam") and bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1}).ok,"SourceとC++で尾の叩きつけを開始する")
	var shape_error:=0.0
	var ring_error:=0.0
	var times_equal:=true
	var hazard_equal:=true
	var saved: Array=[]
	var shown: Array=[]
	var landed:=false
	for frame in 300:
		a.sim_tick(1.0/120.0,1.0/120.0);sim.projectiles._update_hazards(1.0/120.0)
		bridge._core.step(1.0/120.0);bridge._core.step_hazards(1.0/120.0)
		var attack: Dictionary=bridge.command("dev_boss_state").value[0]
		var body: Dictionary=bridge.command("dev_boss_body_state").value[-1]
		times_equal=times_equal and attack.stage=={&"windup":0,&"active":1,&"recovery":2,&"idle":5}[a.mode] and is_equal_approx(attack.stage_time,a.elapsed)
		if a._runner!=null:times_equal=times_equal and attack.locked==a._runner.locked and attack.fired==a._runner.fired
		var points: PackedVector2Array=a.body_points()
		for j in points.size():shape_error=maxf(shape_error,points[j].distance_to(body.body_points[j]))
		if a.telegraph_paths.size()==attack.telegraph_paths.size():
			for path in a.telegraph_paths.size():
				if a.telegraph_paths[path].size()!=attack.telegraph_paths[path].size():ring_error=INF
				else:
					for j in a.telegraph_paths[path].size():ring_error=maxf(ring_error,a.telegraph_paths[path][j].distance_to(attack.telegraph_paths[path][j]))
		else:ring_error=INF
		var hazards: Array=bridge._core.hazards_snapshot()
		var source_hazards: Array=[]
		for j in sim.projectiles.hazard_alive.size():
			if sim.projectiles.hazard_alive[j]!=0:source_hazards.append(j)
		hazard_equal=hazard_equal and hazards.size()==source_hazards.size()
		for h: Dictionary in hazards:
			var found:=false
			for j: int in source_hazards:
				if h.kind!=int(sim.projectiles.hazard_kind[j]):continue
				found=h.pos.distance_to(sim.projectiles.hazard_pos[j])<0.01 and is_equal_approx(h.damage,sim.projectiles.hazard_dmg[j]) and is_equal_approx(h.delay,sim.projectiles.hazard_delay[j]) and is_equal_approx(h.active,sim.projectiles.hazard_active[j])
				if h.kind==1:found=found and is_equal_approx(h.radius,sim.projectiles.hazard_len[j])
				if h.kind==2:found=found and is_equal_approx(h.length,sim.projectiles.hazard_len[j]) and is_equal_approx(h.radius,sim.projectiles.wave_radius(j)) and is_equal_approx(h.half_width*2,sim.projectiles.hazard_width[j])
				hazard_equal=hazard_equal and found
		if attack.stage not in saved and attack.stage<3:
			saved.append(attack.stage)
			var held: Dictionary=bridge.checkpoint()
			check(held.ok,"尾の予告・実行・回復の途中を値型で保持する")
			bridge._core.step(1.0/120.0);bridge._core.step_hazards(1.0/120.0)
			var future: Array=bridge.command("dev_boss_state").value
			var future_body: Array=bridge.command("dev_boss_body_state").value
			var future_hazards: Array=bridge._core.hazards_snapshot()
			check(bridge.restore(held.value).ok,"尾の叩きつけの途中へ復帰する")
			bridge._core.step(1.0/120.0);bridge._core.step_hazards(1.0/120.0)
			check(bridge.command("dev_boss_state").value==future and bridge.command("dev_boss_body_state").value==future_body and bridge._core.hazards_snapshot()==future_hazards,"復帰後の尾の姿勢・段階・攻撃が同じになる")
			bridge.restore(held.value);bridge.release_checkpoint(held.value)
		var key: int=3 if attack.fired and not landed else attack.stage
		if key in [0,3,2] and key not in shown:
			shown.append(key)
			var appearance: Dictionary={}
			for visual: Dictionary in fixture.package.visuals:
				if visual.get("boss","")=="draco":appearance=visual.appearance
			var display=load("res://scripts/render/bosses/draco.gd").new()
			add_child(display);display.apply_frame(body,attack,appearance);await get_tree().process_frame
			check(display._parts.visible,"尾の予告円・着弾・回復を状態から描く")
			if key==3:
				var rendered: Dictionary=bridge.read_render(Rect2(-500,-500,2200,1000)).value
				check(body.impacts.size()==1 and rendered.shapes.any(func(shape):return shape.kind==2) and rendered.shapes.any(func(shape):return shape.kind==7),"着弾の表示とzone・waveの形を通常の描画出力へ渡す")
				landed=true
			display.free()
		if attack.stage==5 and a.mode==&"idle":break
	check(times_equal,"Sourceと予告・固定・着弾1回・回復・終了のtickが一致する")
	check(shape_error<0.1 and ring_error<0.1,"尾のベジェ・両端固定・49点の予告円がSourceと一致する: %s/%s"%[shape_error,ring_error])
	check(hazard_equal and bridge._core.hazards_snapshot().is_empty(),"zoneとwaveの生成時刻・形・ダメージ・自然寿命がSourceと一致する")
	check(saved.size()==3 and shown.size()==3,"予告から自然終了までの状態と表示を通る")
	check(fixture.captured.any(func(event):return event.type==&"combat_player_damage" and event.payload.accepted and event.payload.cause==&"blast" and event.payload.source==&"draco" and event.payload.technique==&"tail_slam"),"着地円の実HPと原因・出所・技名を記録する")
	for target in [0,1,2]:
		var started: Dictionary=bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
		for frame in 300:
			bridge._core.step(1.0/120.0);bridge._core.step_hazards(1.0/120.0)
			if bridge.command("dev_boss_state").value[0].stage==target:break
		check(bridge.command("dev_cancel_technique",{"ticket":started.value}).ok,"尾の予告・実行・回復で取り消す")
		check(bridge.command("dev_boss_state").value[0].telegraph_paths.is_empty(),"取消は尾の予告を消す")
		bridge._core.step_hazards(1.0)
	bridge.dispose();session.free()
	# 着地円の外に避け、取消・本体消失後にも波だけを受ける既存の残留攻撃ケース。
	for operation in ["dev_cancel_technique","dev_cancel_boss","outside"]:
		fixture=breath_fixture(move);bridge=fixture.bridge
		var started: Dictionary=bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
		for frame in 40:bridge._core.step(1.0/120.0);bridge.command("dev_boss_state")
		bridge.command("dev_ship_motion",{"position":Vector2(860 if operation!="outside" else 940,0),"velocity":Vector2.ZERO})
		for frame in 150:
			bridge._core.step(1.0/120.0);bridge._core.step_hazards(1.0/120.0);bridge.command("dev_boss_state")
			if bridge.command("dev_boss_state").value[0].fired:break
		check(bridge._core.hazards_snapshot().size()==2,"着弾は一度だけzoneとwaveを出す")
		if operation=="dev_cancel_technique":bridge.command(operation,{"ticket":started.value})
		elif operation=="dev_cancel_boss":bridge.command(operation,{"entity_id":fixture.boss})
		if operation!="outside":check(bridge._core.hazards_snapshot().size()==2,"生成済みの着弾と波は技取消・本体消失で消さない")
		for frame in 75:
			bridge._core.step(1.0/120.0);bridge._core.step_hazards(1.0/120.0);bridge.command("dev_boss_state")
		var hits: Array=fixture.captured.filter(func(event):return event.type==&"combat_player_damage" and event.payload.accepted)
		check(hits.is_empty() if operation=="outside" else hits.size()==1 and hits[0].payload.cause==&"wave" and hits[0].payload.source==&"draco" and hits[0].payload.technique==&"tail_slam","着地円の外は波だけに当たり、波の外まで避ければ当たらない")
		check(bridge._core.hazards_snapshot().is_empty(),"残る波も自然寿命で終わる")
		bridge.dispose()
	native_draco_move_flow(move)

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

## 尾の扇・掃いた線分・正常終了と中断を既存の技検査で照合する。
func native_tail_sweep() -> void:
	var move: BossTechnique=load("res://data/bosses/draco_moves/tail_sweep.tres")
	var fixture:=breath_fixture(move)
	if fixture.is_empty():get_tree().quit(1);return
	var bridge=fixture.bridge
	check(fixture.package.records.DracoTailSweepDefinition.size()==3,"尾の薙ぎ払いの実効値を3形態へ生成する")
	bridge.command("dev_ship_motion",{"position":Vector2(-700,0),"velocity":Vector2.ZERO})
	var stage: RuntimeStage=ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled=false
	var session:=RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":105},false)
	session.auto_step=false
	var sim: RunSimulation=session.sim
	sim.field.bodies.clear();sim.state.phase=RunState.Phase.PLAY;sim.ship.invincible=false
	sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
	var a=sim.bosses.actor
	a.selection_enabled=false;a.cycle.cancel();a.cancel_attack();a.clock=0.0;a.table.facing[a.body]=0.0;a.body_trail.clear();a.body_pose.clear();a.body_override.clear();a.reset_pose()
	sim.state.ship_pos=Vector2(-700,0);sim.state.enemy_aim=Vector2(-700,0);sim.state.ship_vel=Vector2.ZERO;sim.state.ship_invuln=0.0
	check(a.start_attack(&"tail_sweep") and bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1}).ok,"SourceとC++で尾の薙ぎ払いを開始する")
	var shape_error:=0.0
	var area_error:=0.0
	var times_equal:=true
	var saved: Array=[]
	var shown: Array=[]
	for frame in 350:
		a.sim_tick(1.0/120.0,1.0/120.0);bridge._core.step(1.0/120.0)
		var attack: Dictionary=bridge.command("dev_boss_state").value[0]
		var body: Dictionary=bridge.command("dev_boss_body_state").value[-1]
		times_equal=times_equal and attack.stage=={&"windup":0,&"active":1,&"recovery":2,&"idle":5}[a.mode] and is_equal_approx(attack.stage_time,a.elapsed)
		var points: PackedVector2Array=a.body_points()
		for j in points.size():shape_error=maxf(shape_error,points[j].distance_to(body.body_points[j]))
		var area: PackedVector2Array=a.telegraph_areas[0].polygon if not a.telegraph_areas.is_empty() else PackedVector2Array()
		if area.size()!=attack.telegraph_polygon.size():area_error=INF
		else:
			for j in area.size():area_error=maxf(area_error,area[j].distance_to(attack.telegraph_polygon[j]))
		if attack.stage not in saved and attack.stage<3:
			saved.append(attack.stage)
			var held: Dictionary=bridge.checkpoint()
			check(held.ok,"尾の予告・実行・回復の途中を値型で保持する")
			bridge._core.step(1.0/120.0)
			var future: Array=bridge.command("dev_boss_state").value
			var future_body: Array=bridge.command("dev_boss_body_state").value
			check(bridge.restore(held.value).ok,"尾の薙ぎ払いの途中へ復帰する")
			bridge._core.step(1.0/120.0)
			check(bridge.command("dev_boss_state").value==future and bridge.command("dev_boss_body_state").value==future_body,"復帰後の尾の姿勢・段階・前回点列が同じになる")
			bridge.restore(held.value);bridge.release_checkpoint(held.value)
		if attack.stage not in shown and attack.stage<3:
			shown.append(attack.stage)
			var appearance: Dictionary={}
			for visual: Dictionary in fixture.package.visuals:
				if visual.get("boss","")=="draco":appearance=visual.appearance
			var display=load("res://scripts/render/bosses/draco.gd").new()
			add_child(display);display.apply_frame(body,attack,appearance);await get_tree().process_frame
			check(display._parts.visible,"尾の扇の塗り・薙ぎ払い・回復を状態から描く")
			display.free()
		if attack.stage==5 and a.mode==&"idle":break
	check(times_equal,"Sourceと予告・実行・回復・終了のtickが一致する")
	check(shape_error<0.1 and area_error<0.1,"尾の両端固定と96点の予告の扇がSourceと一致する: %s/%s"%[shape_error,area_error])
	check(saved.size()==3 and shown.size()==3,"予告から自然終了までの状態と表示を通る")
	var hits: Array=fixture.captured.filter(func(event):return event.type==&"combat_player_damage" and event.payload.accepted and event.payload.cause==&"tail_sweep" and event.payload.source==&"draco" and event.payload.technique==&"tail_sweep")
	check(hits.size()==1,"尾の根元から先までの掃引は実HPへ1回だけ命中し原因・出所・技名を記録する")
	for target in [0,1,2]:
		var started: Dictionary=bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
		for frame in 350:
			bridge._core.step(1.0/120.0)
			if bridge.command("dev_boss_state").value[0].stage==target:break
		check(bridge.command("dev_cancel_technique",{"ticket":started.value}).ok,"尾の予告・実行・回復で取り消す")
		check(bridge.command("dev_boss_state").value[0].telegraph_polygon.is_empty(),"取消は尾の扇を消す")
	bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
	bridge.command("dev_cancel_boss",{"entity_id":fixture.boss})
	check(bridge.command("dev_boss_state").value[0].stage==7,"本体消失で尾の薙ぎ払いを取り消す")
	bridge.dispose();session.free()
	native_draco_move_flow(move)

func source_draco_fixture(target: Vector2) -> Dictionary:
	var stage: RuntimeStage=ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled=false
	var session:=RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":105},false)
	session.auto_step=false
	var sim: RunSimulation=session.sim
	sim.field.bodies.clear();sim.state.phase=RunState.Phase.PLAY;sim.ship.invincible=false
	sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
	var actor=sim.bosses.actor
	actor.selection_enabled=false;actor.cycle.cancel();actor.cancel_attack();actor.clock=0.0;actor.table.facing[actor.body]=0.0;actor.body_trail.clear();actor.body_pose.clear();actor.body_override.clear();actor.reset_pose()
	sim.state.ship_pos=target;sim.state.enemy_aim=target;sim.state.ship_vel=Vector2.ZERO;sim.state.ship_invuln=0.0
	return {"session":session,"sim":sim,"actor":actor}

func show_native_draco(fixture: Dictionary, body: Dictionary, attack: Dictionary) -> void:
	var appearance: Dictionary={}
	for visual: Dictionary in fixture.package.visuals:
		if visual.get("boss","")=="draco":appearance=visual.appearance
	var display=load("res://scripts/render/bosses/draco.gd").new()
	add_child(display);display.apply_frame(body,attack,appearance);await get_tree().process_frame
	check(display._parts.visible,"技の予告・攻撃・回復を状態から描く")
	display.free()

func native_star_fan() -> void:
	var move: BossTechnique=load("res://data/bosses/draco_moves/star_fan.tres")
	var fixture:=breath_fixture(move)
	if fixture.is_empty():get_tree().quit(1);return
	var bridge=fixture.bridge
	check(fixture.package.records.DracoStarFanDefinition.size()==3,"星弾の扇の実効値を3形態へ生成する")
	var source:=source_draco_fixture(Vector2(700,0))
	var a=source.actor
	var sim: RunSimulation=source.sim
	check(a.start_attack(&"star_fan") and bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1}).ok,"SourceとC++で星弾の扇を開始する")
	var shape_error:=0.0
	var warning_error:=0.0
	var shot_error:=0.0
	var times_equal:=true
	var saved: Array=[]
	var shown: Array=[]
	for frame in 300:
		if frame==10:
			sim.state.ship_pos=Vector2(700,100);sim.state.enemy_aim=sim.state.ship_pos
			bridge.command("dev_ship_motion",{"position":sim.state.ship_pos,"velocity":Vector2.ZERO})
		a.sim_tick(1.0/120.0,1.0/120.0);bridge._core.step(1.0/120.0)
		var attack: Dictionary=bridge.command("dev_boss_state").value[0]
		var body: Dictionary=bridge.command("dev_boss_body_state").value[-1]
		times_equal=times_equal and attack.stage=={&"windup":0,&"active":1,&"recovery":2,&"idle":5}[a.mode] and is_equal_approx(attack.stage_time,a.elapsed)
		if a._runner!=null:times_equal=times_equal and attack.locked==a._runner.locked and attack.fired==a._runner.fired
		var points: PackedVector2Array=a.body_points()
		for j in points.size():shape_error=maxf(shape_error,points[j].distance_to(body.body_points[j]))
		if a.telegraph_paths.size()!=attack.telegraph_paths.size():warning_error=INF
		else:
			for j in a.telegraph_paths.size():
				for k in 2:warning_error=maxf(warning_error,a.telegraph_paths[j][k].distance_to(attack.telegraph_paths[j][k]))
		var shots: Array=bridge._core.hostiles_snapshot()
		var source_shots: Array=[]
		for row in sim.projectiles.hostile_alive.size():
			if sim.projectiles.hostile_alive[row]!=0:source_shots.append(row)
		if shots.size()!=source_shots.size():shot_error=INF
		else:
			for j in shots.size():
				var row: int=source_shots[j]
				shot_error=maxf(shot_error,shots[j].pos.distance_to(sim.projectiles.hostile_pos[row]))
				shot_error=maxf(shot_error,shots[j].vel.distance_to(sim.projectiles.hostile_vel[row]))
		if attack.stage not in saved and attack.stage<3:
			saved.append(attack.stage)
			var held: Dictionary=bridge.checkpoint()
			check(held.ok,"星弾の予告・実行・回復を値型で保持する")
			bridge._core.step(1.0/120.0)
			var future: Array=bridge.command("dev_boss_state").value
			var future_shots: Array=bridge._core.hostiles_snapshot()
			check(bridge.restore(held.value).ok,"星弾の扇の途中へ復帰する")
			bridge._core.step(1.0/120.0)
			check(bridge.command("dev_boss_state").value==future and bridge._core.hostiles_snapshot()==future_shots,"復帰後の照準・発射済み・弾が一致する")
			bridge.restore(held.value);bridge.release_checkpoint(held.value)
		if attack.stage not in shown and attack.stage<3:
			shown.append(attack.stage);await show_native_draco(fixture,body,attack)
		if attack.stage==5 and a.mode==&"idle":break
	check(times_equal and shape_error<0.1 and warning_error<0.1 and shot_error<0.1,"照準・段階・全身・予告線・9弾の位置と速度がSourceと一致する: %s/%s/%s"%[shape_error,warning_error,shot_error])
	check(saved.size()==3 and shown.size()==3 and bridge._core.hostiles_snapshot().size()==9,"星弾は予告後の最初の実行tickで一度だけ9発出る")
	var star_rule: Dictionary=fixture.package.records.StarBoltDefinition[fixture.package.records.DracoStarFanDefinition[0].projectile-1]
	var visual: Dictionary=fixture.package.visuals[star_rule.visual-1]
	var rendered: Dictionary=bridge.read_render(Rect2(-2000,-2000,4000,4000)).value
	var stars: Array=rendered.batches.filter(func(batch):return batch.visual_id==star_rule.visual)
	var batch:=InstanceBatch.new()
	add_child(batch)
	load("res://scripts/render/attacks/star_bolt.gd").setup_batch(batch,load(visual.path),visual.scene)
	check(stars.size()==1 and stars[0].ids.size()==9 and batch.multimesh.mesh!=null,"技専用の星と芯の保存済みメッシュへ9発の描画出力を渡す")
	if not stars.is_empty():batch.apply_frame(stars[0].transforms,stars[0].colors)
	await get_tree().process_frame
	batch.free()
	bridge.dispose();source.session.free()
	for operation in ["before","dev_cancel_technique","dev_cancel_boss","outside"]:
		fixture=breath_fixture(move);bridge=fixture.bridge
		var started: Dictionary=bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
		for frame in 150:
			bridge._core.step(1.0/120.0)
			if bridge.command("dev_boss_state").value[0].fired:break
			if operation=="before" and frame==10:break
		if operation=="dev_cancel_boss":bridge.command(operation,{"entity_id":fixture.boss})
		else:bridge.command("dev_cancel_technique",{"ticket":started.value})
		check(bridge._core.hostiles_snapshot().size()==(0 if operation=="before" else 9),"発射前取消は弾を出さず、発射後は取消・本体消失でも弾を残す")
		if operation=="outside":bridge.command("dev_ship_motion",{"position":Vector2(700,1000),"velocity":Vector2.ZERO})
		for frame in 100:
			bridge._core.step_hostiles(1.0/120.0);bridge.command("dev_boss_state")
		var hits: Array=fixture.captured.filter(func(event):return event.type==&"combat_player_damage" and event.payload.accepted and event.payload.cause==&"star_bolt" and event.payload.source==&"draco" and event.payload.technique==&"star_fan")
		check(hits.is_empty() if operation in ["before","outside"] else hits.size()==1,"発射後の星弾が実HP・原因・出所・技名へ届き、扇の外なら避けられる")
		bridge._core.step_hostiles(6.0)
		check(bridge._core.hostiles_snapshot().is_empty(),"残る星弾も自然寿命で終わる")
		bridge.dispose()
	native_draco_move_flow(move)

func native_meteor() -> void:
	var move: BossTechnique=load("res://data/bosses/draco_moves/meteor.tres")
	var fixture:=breath_fixture(move)
	if fixture.is_empty():get_tree().quit(1);return
	var bridge=fixture.bridge
	check(fixture.package.records.DracoMeteorDefinition.size()==3,"隕石投射の実効値を3形態へ生成する")
	var source:=source_draco_fixture(Vector2(700,0))
	var a=source.actor
	check(a.start_attack(&"meteor") and bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1}).ok,"SourceとC++で隕石投射を開始する")
	var error:=0.0
	var times_equal:=true
	var saved: Array=[]
	var shown: Array=[]
	for frame in 240:
		a.sim_tick(1.0/120.0,1.0/120.0);bridge._core.step(1.0/120.0)
		var attack: Dictionary=bridge.command("dev_boss_state").value[0]
		var body: Dictionary=bridge.command("dev_boss_body_state").value[-1]
		times_equal=times_equal and attack.stage=={&"windup":0,&"active":1,&"recovery":2,&"idle":5}[a.mode] and is_equal_approx(attack.stage_time,a.elapsed)
		var rocks: Array=a._runner.rocks if a._runner!=null else a.placed_meteors
		check(attack.rocks.size()==rocks.size() and attack.telegraph_paths.is_empty(),"3個の岩だけを作りブレスの扇は出さない")
		for j in rocks.size():error=maxf(error,rocks[j].pos.distance_to(attack.rocks[j].position))
		if attack.stage not in saved and attack.stage<3:
			saved.append(attack.stage)
			var held: Dictionary=bridge.checkpoint()
			check(held.ok,"隕石投射の予告・実行・回復を値型で保持する")
			bridge._core.step(1.0/120.0)
			var future: Array=bridge.command("dev_boss_state").value
			check(bridge.restore(held.value).ok,"隕石投射の途中へ復帰する")
			bridge._core.step(1.0/120.0)
			check(bridge.command("dev_boss_state").value==future,"復帰後の岩の位置・生存・段階が一致する")
			bridge.restore(held.value);bridge.release_checkpoint(held.value)
		if attack.stage not in shown and attack.stage<3:
			shown.append(attack.stage);await show_native_draco(fixture,body,attack)
		if attack.stage==5 and a.mode==&"idle":break
	check(times_equal and error<0.1,"岩の口元からの補間と予告・実行・回復・終了のtickがSourceと一致する: %s"%error)
	check(saved.size()==3 and shown.size()==3 and a.placed_meteors.size()==3,"通常終了で3個の岩を置いたまま次の技へ渡す")
	var placed: Array=bridge.command("dev_boss_state").value[0].rocks.duplicate(true)
	check(bridge.checkpoint().ok,"置いた岩の所有を終了後にも値型で保持する")
	var reused: Dictionary=bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
	var attack: Dictionary=bridge.command("dev_boss_state").value[0]
	check(reused.ok and attack.reused and attack.rocks==placed,"次の隕石投射は既存の岩を同じ位置・IDのまま引き取る")
	bridge.command("dev_cancel_technique",{"ticket":reused.value})
	check(bridge.command("dev_boss_state").value[0].rocks.all(func(rock):return not rock.alive and rock.destroyed),"取消は引き取った岩も壊す")
	bridge.dispose();source.session.free()
	var breath: BossTechnique=load("res://data/bosses/draco_moves/breath.tres")
	fixture=breath_fixture(move,false,[move,breath]);bridge=fixture.bridge
	bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
	for frame in 200:bridge._core.step(1.0/120.0)
	placed=bridge.command("dev_boss_state").value[0].rocks.duplicate(true)
	check(bridge.command("dev_damage",{"entity_id":placed[0].actor,"amount":1000000.0,"cause":"shot"}).ok,"置いた岩は自機から攻撃して壊せる")
	bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":4})
	attack=bridge.command("dev_boss_state").value[0]
	check(attack.reused and attack.rocks.size()==2 and attack.rocks[0].actor==placed[1].actor and attack.rocks[1].actor==placed[2].actor,"次のブレスは破壊済みを除いた2個の岩だけを同じIDで引き取る")
	bridge.dispose()
	for target in [0,1,2]:
		fixture=breath_fixture(move);bridge=fixture.bridge
		var started: Dictionary=bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
		for frame in 240:
			bridge._core.step(1.0/120.0)
			if bridge.command("dev_boss_state").value[0].stage==target:break
		bridge.command("dev_cancel_technique",{"ticket":started.value})
		check(bridge.command("dev_boss_state").value[0].rocks.all(func(rock):return not rock.alive and rock.destroyed),"予告・実行・回復の取消は岩を壊す")
		bridge.dispose()
	fixture=breath_fixture(move);bridge=fixture.bridge
	bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
	bridge.command("dev_cancel_boss",{"entity_id":fixture.boss})
	check(bridge.command("dev_boss_state").value[0].rocks.all(func(rock):return not rock.alive and rock.destroyed),"本体消失で投射中の岩を壊す")
	bridge.dispose()
	fixture=breath_fixture(move);bridge=fixture.bridge
	bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
	for frame in 200:bridge._core.step(1.0/120.0)
	var changed: Dictionary=bridge.command("dev_damage",{"entity_id":fixture.boss,"amount":1000000.0,"cause":"shot"})
	check(changed.ok and bridge.command("dev_boss_body_state").value[-1].phase==2 and bridge.command("dev_boss_body_state").value[-1].placed_meteors.is_empty() and bridge.command("dev_boss_state").value[0].rocks.all(func(rock):return not rock.alive and rock.destroyed),"形態の境界は置いた岩を破壊して所有を消す")
	bridge.dispose()
	native_draco_move_flow(move)
