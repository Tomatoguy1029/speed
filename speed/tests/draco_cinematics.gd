extends Node
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _ready() -> void:
	if "--cpp-draco-cycle" in OS.get_cmdline_user_args():
		call_deferred("native_cycle")
		return
	if "--cpp-draco-intro" in OS.get_cmdline_user_args() or "--cpp-draco-intro-position" in OS.get_cmdline_user_args():
		call_deferred("native_intro")
		return
	var stage: RuntimeStage = ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled = false
	var session := RunManager.create_session(self, {"lab":true,"stage":stage,"stage_index":5,"seed":1605}, false)
	session.auto_step = false
	var sim: RunSimulation = session.sim
	sim.field.bodies.clear()
	sim.state.ship_pos = Vector2(180,260)
	sim.state.view_center = Vector2(60,180)
	sim.state.camera_zoom = 0.6
	sim.state.view_half = Vector2(800,450)
	sim.state.ship_heading = Vector2.LEFT
	sim.bosses.spawn(load("res://data/bosses/draco.tres"), Vector2(-500,-100))
	var actor = sim.bosses.actor
	actor.selection_enabled = false
	var initial_pos: Vector2 = actor.table.pos[actor.body]
	var camera: Vector2 = sim.state.view_center
	var view_half: Vector2 = sim.state.view_half
	for angle in [0.0, PI*0.5, PI, -PI*0.5]:
		actor.table.facing[actor.body] = angle
		actor.entrance.begin()
		for frame in 60: actor.entrance.tick(1.0/60.0)
		check(is_equal_approx(actor.table.facing[actor.body],PI*0.5),"登場方向に関係なく自機を背後から映す対面構図に揃える")
		actor.entrance.cancel()
		check(sim.state.view_center.is_equal_approx(camera) and is_equal_approx(sim.state.camera_zoom,0.6),"登場中断はカメラ中心と倍率を復元する")
		check(sim.state.view_half.is_equal_approx(view_half),"登場中断は入力に使う表示範囲も復元する")
		check(actor.table.pos[actor.body].is_equal_approx(initial_pos),"登場中断は戦闘前の本体位置を復元する")
		check(not sim.state.controls_locked and not sim.state.cinematic_camera and sim.state.cinematic_bars==0.0,"登場中断後に操作とHUDを返す")
	check(actor.entrance.has_method("skip"),"登場だけを明示的にスキップできる")
	if actor.entrance.has_method("skip"):
		actor.entrance.begin()
		actor.entrance.skip()
		check(actor.mode==&"idle" and actor.table.guard[actor.body]==0.0,"登場スキップは無敵を残さず戦闘へ渡す")
		actor.entrance.skip()
		check(not sim.state.controls_locked,"二重スキップで操作を再ロックしない")
	var original_ship: Vector2=sim.state.ship_pos
	for ship_at in [Vector2(0,-9900),Vector2(9000,2500),Vector2(1200,1200)]:
		sim.state.ship_pos=ship_at
		var solid:=FieldSystem.Body.new()
		solid.pos=ship_at+Vector2.UP*430.0;solid.r=300.0
		sim.field.bodies.append(solid)
		actor.entrance.begin()
		actor.entrance.skip()
		var head: Vector2=actor.table.pos[actor.body]
		var margin: float=actor.def.radius*actor.head_scale+40.0
		check(head.length()<=sim.cfg.field_radius-margin+0.1,"端の対面でも頭を世界境界内へ置く")
		check(head.distance_to(solid.pos)>=solid.r+margin-0.1,"対面の本体を天体の中へ置かない")
		check(sim.state.ship_pos==ship_at,"安全な対面構図のために自機を瞬間移動しない")
		sim.field.bodies.clear()
	sim.state.ship_pos=original_ship
	actor.entrance.begin()
	for frame in 600: actor.entrance.tick(1.0/60.0)
	check(not actor.entrance.active and actor.mode==&"idle","登場は通常終了できる")
	check(sim.state.ship_heading==Vector2.LEFT,"登場終了時に機体の元の向きを返す")
	actor.phase=2
	actor.cycle.begin_initial()
	for frame in 1000: actor.cycle.tick(1.0/60.0)
	check(actor.cycle.stage==&"" and actor.mode==&"idle","初回生成が全段階を終えて本体戦へ戻る")
	check(not sim.state.controls_locked and not sim.state.cinematic_camera and not sim.state.encounter_protected,"初回生成のロックと保護を全て解放する")
	actor.cycle.begin_deep()
	check(not sim.state.controls_locked and sim.state.cinematic_bars==0.0,"通常の採集では操作を止めない")
	for frame in 90: actor.cycle.tick(1.0/60.0)
	actor.cycle.cancel()
	check(actor._presentation.scale==Vector2.ONE,"採集中断は描画だけの縮小を残さない")
	actor.finale.begin()
	actor.finale.guide.append(Vector2.ONE)
	actor.finale.strokes.append(Vector2.ONE)
	actor.finale.began=true
	actor.finale.completed=true
	actor.finale.dispose()
	actor.finale.begin()
	check(actor.finale.guide.is_empty() and actor.finale.strokes.is_empty() and not actor.finale.began and not actor.finale.completed,"最終決着の再生は前回の描画と完了フラグを引き継がない")
	for frame in 420: actor.finale.advance(1.0/60.0,Intent.new())
	check(actor.finale.stage==&"input" and not sim.state.controls_locked,"最終姿勢から自由描画へ渡す")
	check(sim.state.world_scale==0.0,"最終描画の世界時計は止まる")
	var it := Intent.new()
	it.press=true;it.has_cursor=true;it.pen=Vector2(-100,0)
	actor.finale.advance(1.0/60.0,it)
	it=Intent.new();it.has_cursor=true;it.pen=Vector2(10000,0)
	actor.finale.advance(1.0/60.0,it)
	check(actor.finale.stage==&"input" and actor.finale.strokes[-1]==Vector2(10000,0),"長い自由描画を自動確定や切り詰めしない")
	actor.finale.dispose()
	check(not sim.state.cinematic_camera and not sim.state.controls_locked and sim.state.world_scale>0.0,"最終演出の中断はカメラと操作と世界の速さを返す")
	for target: StringName in [&"release",&"combine",&"pose",&"input",&"strikes",&"last",&"sight",&"split"]:
		var before_camera: Vector2=sim.state.view_center
		var before_zoom: float=sim.state.camera_zoom
		var before_ship: Vector2=sim.state.ship_pos
		sim.state.ship_vel=Vector2(40,-70)
		var before_velocity: Vector2=sim.state.ship_vel
		actor.finale.begin()
		for frame in 1200:
			if actor.finale.stage==target: break
			var action:=Intent.new()
			if actor.finale.stage==&"input":
				action.press=not actor.finale.began;action.has_cursor=true;action.pen=Vector2(200,100);action.pen_release=actor.finale.began
			actor.finale.advance(1.0/60.0,action)
		check(actor.finale.stage==target,"決着の中断地点へ到達する: "+target)
		if target in [&"strikes",&"last"]:
			actor.finale.advance(0.12,Intent.new())
			check(not sim.state.ship_pos.is_equal_approx(before_ship),"連撃の実移動を経てから中断を検証する: "+target)
		actor.finale.dispose()
		check(sim.state.ship_pos.is_equal_approx(before_ship) and sim.state.ship_vel.is_equal_approx(before_velocity),"決着の各段階中断で実際の自機位置と速度を返す: "+target)
		actor.finale.begin()
		actor.finale.dispose()
		check(sim.state.ship_pos.is_equal_approx(before_ship) and sim.state.ship_vel.is_equal_approx(before_velocity),"中断後の再生でも自機の基準位置をずらさない: "+target)
		check(sim.state.view_center.is_equal_approx(before_camera) and is_equal_approx(sim.state.camera_zoom,before_zoom),"決着の各段階中断でカメラを返す: "+target)
		check(not sim.state.controls_locked and not sim.state.cinematic_camera and sim.state.world_scale>0.0,"決着の各段階中断で操作と世界を返す: "+target)
	for aspect in [Vector2(1280,720),Vector2(900,900),Vector2(720,1280)]:
		for angle in [0.0,PI*0.5,PI,-PI*0.5]:
			sim.ctx.options["view_size"]=aspect
			sim.state.ship_pos=Vector2(-300,200)
			sim.state.view_center=sim.state.ship_pos
			sim.state.camera_zoom=minf(aspect.x,aspect.y)/1100.0
			actor.table.pos[actor.body]=Vector2(430,-220)
			actor.table.facing[actor.body]=angle
			actor._update_body()
			var ship_before: Vector2=sim.state.ship_pos
			actor.finale.begin()
			var all_visible:=true
			for frame in 240:
				actor.finale.advance(1.0/60.0,Intent.new())
				if not actor.finale.stage in [&"release",&"combine"]: continue
				var probes:=PackedVector2Array()
				for vertex in [Vector2(-118,-108),Vector2(-118,108),Vector2(110,0),Vector2(24,-91),Vector2(-8,87)]:
					probes.append(actor.table.pos[actor.body]+(vertex*actor.head_scale).rotated(actor.table.facing[actor.body]))
				for corner in [Vector2(-45,-45),Vector2(45,-45),Vector2(-45,45),Vector2(45,45)]: probes.append(sim.state.ship_pos+corner)
				for star in actor.finale.BEAR: probes.append(actor.finale.core+star)
				if actor.finale.stage==&"combine":
					for j in 4:
						var part: Vector2=(actor.finale.core+Vector2.from_angle(j*TAU/4.0)*250.0).lerp(sim.state.ship_pos,clampf(actor.finale.time/2.0,0.0,1.0))
						for corner in [Vector2(-28,-28),Vector2(28,-28),Vector2(-28,28),Vector2(28,28)]: probes.append(part+corner)
				for point in probes:
					var pixel: Vector2=aspect*0.5+(point-sim.state.view_center)*sim.state.camera_zoom
					if not Rect2(aspect*Vector2(0.04,0.12),aspect*Vector2(0.92,0.76)).has_point(pixel): all_visible=false
			check(all_visible,"核解放と合体は頭・自機・星座・部品を黒帯の内側へ映す: %s angle%s" % [aspect,angle])
			check(sim.state.ship_pos==ship_before,"合体の構図を合わせるために自機を移動しない")
			actor.finale.dispose()
	sim.ctx.options.erase("view_size")
	actor.cancel_attack();actor.cycle.cancel();sim.projectiles.clear_hostile()
	actor.phase=3;actor.mode=&"idle"
	actor.start_attack(&"rifts")
	var rifts_open := false
	for frame in 600:
		actor.sim_tick(1.0/60.0,1.0/60.0)
		if actor.technique == &"rifts" and actor._runner != null and actor._runner.walls.size() == 6:
			rifts_open = true
			break
	check(rifts_open,"引っ掻きの退場・再登場後に亀裂を開く")
	actor.finale.begin()
	check(sim.state.cinematic_hide_enemies,"最終演出では残った通常敵を画面から退ける")
	check(not actor.closing_walls.is_empty(),"亀裂を引き裂いた後の決着移行で修復を開始する")
	actor.finale.advance(0.5,Intent.new())
	check(actor.closing_walls.is_empty(),"止まった世界でも取り消した亀裂の修復を実時間で完了する")
	actor.finale.dispose()
	check(not sim.state.cinematic_hide_enemies,"決着を中断すると通常敵の表示方針を復元する")
	actor.finale.begin()
	var observed: Array[StringName]=[]
	var defeats_before: int=sim.state.events.filter(func(event):return event.type==&"boss_defeated").size()
	for frame in 1800:
		if actor.finale.completed: break
		if not actor.finale.stage in observed: observed.append(actor.finale.stage)
		if actor.finale.stage in [&"pose",&"input"]: check(sim.state.final_modules.size()==4,"機体合体の完了時点から四つの部品を武器欄へ渡す")
		var action:=Intent.new()
		if actor.finale.stage==&"input":
			action.press=not actor.finale.began;action.has_cursor=true;action.pen=Vector2(200,100);action.pen_release=actor.finale.began
		actor.finale.advance(1.0/60.0,action)
	check(observed==[&"release",&"combine",&"pose",&"input",&"strikes",&"last",&"sight",&"split",&"explode"],"核解放から爆発まで採用済みの順序を全て通る")
	check(actor.finale.completed and sim.state.draco_finish_done,"決着を完走して通常クリアへ接続する")
	actor.finale.advance(1.0,Intent.new())
	var defeats_after: int=sim.state.events.filter(func(event):return event.type==&"boss_defeated").size()
	check(defeats_after-defeats_before==1,"決着の完了通知は一度だけ出す")
	check(not sim.state.controls_locked and not sim.state.cinematic_camera and sim.state.world_scale>0.0,"完走後に演出のロックを残さない")
	session.free()
	print("[draco_cinematics] failures=",failures)
	get_tree().quit(1 if failures else 0)

## 既存の登場方向・中断・二重skip・安全配置・自然終了をC++入口へ接続する。
func native_intro() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	var package: Dictionary = builder.boss_body_package(load("res://data/bosses/draco.tres"),cfg)
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":188,"mode":1,"stage_id":"B_draco_intro","profile":{},"settings":{"hitstop":false}})
	check(configured.ok,"登場の編集値を生成データから読む")
	if not configured.ok: print(configured);get_tree().quit(1);return
	bridge.start(1605,{"position":Vector2(180,260),"lab_mode":true})
	bridge.subscribe("確認",func(_frame):return true)
	bridge._core.set_motion_context(Vector2(180,260),Vector2(60,180),Vector2(800,450))
	bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true,"level":1,"position":Vector2(180,260)}})
	var boss := 0
	var position_only := "--cpp-draco-intro-position" in OS.get_cmdline_user_args()
	if not position_only:
		for angle in [0.0,PI*0.5,PI,-PI*0.5]:
			var initial := Vector2(180,260)-Vector2.from_angle(angle)*700.0
			boss = bridge.command("dev_spawn_boss",{"definition":1,"position":initial,"entrance":false}).value
			bridge.command("dev_edit",{"kind":"camera","payload":{"center":Vector2(60,180),"size":Vector2(960,540),"zoom":0.6,"bars":0.0}})
			bridge.command("dev_draco_intro",{"entity_id":boss,"operation":"begin"})
			bridge._core.step(1.0)
			var body: Dictionary = bridge.command("dev_boss_body_state").value[-1]
			check(is_equal_approx(float(body.facing),PI*0.5),"登場方向を四方から同じ対面構図に揃える")
			bridge.command("dev_draco_intro",{"entity_id":boss,"operation":"cancel"})
			var frame: Dictionary = bridge.read_frame().value
			check(frame.camera.center.is_equal_approx(Vector2(60,180)) and is_equal_approx(frame.camera.zoom,0.6),"中断はカメラ中心と倍率を復元する")
			check(frame.camera.half.is_equal_approx(Vector2(800,450)),"中断は入力用の表示範囲を返す")
			check(bridge.command("dev_boss_body_state").value[-1].position.is_equal_approx(initial),"中断は本体位置を戻す")
			check(not frame.ui.controls_locked and not frame.ui.cinematic_camera and frame.ui.cinematic_bars==0.0,"中断は操作とHUDを返す")
			bridge.command("dev_cancel_boss",{"entity_id":boss})
		boss = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2(-500,-100),"entrance":true}).value
		bridge.command("dev_draco_intro",{"entity_id":boss,"operation":"skip"})
		bridge.command("dev_draco_intro",{"entity_id":boss,"operation":"skip"})
		check(bridge.command("dev_boss_body_state").value[-1].mode==1 and bridge.command("dev_boss_body_state").value[-1].guard==0.0 and not bridge.read_frame().value.ui.controls_locked,"二重スキップでも戦闘へ返す")
	if position_only: boss = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2(-500,-100),"entrance":false}).value
	for ship_at in [Vector2(0,-9900),Vector2(9000,2500),Vector2(1200,1200)]:
		check(bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true,"level":1,"position":ship_at}}).ok,"安全配置の自機位置を設定する")
		var planet: Vector2 = ship_at+Vector2.UP*430.0
		check(bridge.command("dev_edit",{"kind":"planet","payload":{"position":planet,"radius":300.0}}).ok,"安全配置の天体を置く")
		bridge.command("dev_draco_intro",{"entity_id":boss,"operation":"begin"})
		bridge.command("dev_draco_intro",{"entity_id":boss,"operation":"skip"})
		var body: Dictionary = bridge.command("dev_boss_body_state").value[-1]
		var head: Vector2 = body.position
		var margin: float = body.radius+40.0
		check(head.length()<=cfg.field_radius-margin+0.1 and head.distance_to(planet)>=300.0+margin-0.1,"頭を境界と天体から離す")
		check(bridge._core.ship_snapshot().ship_pos==ship_at,"対面のために自機を瞬間移動しない")
	if position_only:
		bridge.dispose()
		print("[B_draco_intro_position] failures=",failures)
		get_tree().quit(1 if failures else 0)
		return
	bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true,"level":1,"position":Vector2(180,260)}})
	bridge.command("dev_draco_intro",{"entity_id":boss,"operation":"begin"})
	bridge._core.step(3.4)
	var scope := ContentResourceScope.new()
	for visual: Dictionary in package.visuals:
		if not visual.path.is_empty(): scope.provide(visual.path,load(visual.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	add_child(view)
	var entries: Array[Dictionary] = [];entries.assign(package.visuals)
	view.setup(scope,entries,cfg.character_scale)
	check(view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value),"裂け目と出現を既存の描画経路へ渡す")
	await get_tree().process_frame
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"登場途中の値状態を保持する")
	bridge._core.step(1.0)
	var expected: Dictionary = bridge.command("dev_boss_body_state").value[-1]
	check(bridge.restore(held.value).ok,"登場途中を復帰する")
	bridge._core.step(1.0)
	check(bridge.command("dev_boss_body_state").value[-1]==expected,"復帰後も同じ位置・段階・時刻になる")
	bridge.release_checkpoint(held.value)
	bridge._core.step(10.0)
	check(not bridge.command("dev_boss_body_state").value[-1].intro.active and bridge.command("dev_boss_body_state").value[-1].mode==1,"登場は自然終了で戦闘へ渡す")
	view.free();bridge.dispose()
	print("[B_draco_intro] failures=",failures)
	get_tree().quit(1 if failures else 0)

## 同じ論理画面と既存の初回生成・通常採集・中断でSourceと照合する。
func native_cycle() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	var definition: BossDef = load("res://data/bosses/draco.tres").duplicate(true)
	definition.params.picaro_candidates = [&"biter"]
	var package: Dictionary = builder.boss_body_package(definition,cfg)
	var source: Dictionary = builder.chase_package(load("res://data/enemies/biter.tres"),cfg)
	var row: Dictionary = source.records.EnemyRecord[0].duplicate(true)
	row.id=2;row.visual_id=package.records.ResourceKey.size()+1
	package.records.EnemyRecord.append(row)
	package.records.StringEntry.append({"id":2,"value":"biter"})
	package.records.DefinitionIndex.append({"id":2,"enemy":2})
	package.records.PopulationType.append({"id":2,"enemy":2,"rank":1,"maximum":10,"ranged":false})
	for record: Dictionary in builder.Schema.SCHEMA.records:
		if record.fields[0].get("ref","")!="EnemyRecord": continue
		for original: Dictionary in source.records[record.name]:
			var item := original.duplicate(true);item.id=2;package.records[record.name].append(item)
	var hull: Dictionary = source.records.FriendHullLook[0].duplicate(true)
	hull.id=2;hull.enemy=2;package.records.FriendHullLook.append(hull)
	var visual: Dictionary = source.visuals[5].duplicate(true)
	visual.id=row.visual_id
	package.visuals.append(visual);package.records.ResourceKey.append({"id":visual.id,"role":visual.role})
	check(builder.append_draco_cycle(package.records,definition,1)==OK,"通常生成と同じ候補の順序・敵参照を作る")
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":189,"mode":1,"stage_id":"B_draco_cycle","profile":{},"settings":{"hitstop":false}})
	check(configured.ok,"採集・再生成の型付き編集値を読む")
	if not configured.ok: print(configured);get_tree().quit(1);return
	bridge.start(1605,{"position":Vector2(180,260),"lab_mode":true})
	bridge.subscribe("確認",func(_frame):return true)
	bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true,"level":1,"position":Vector2(180,260)}})
	bridge._core.set_motion_context(Vector2(180,260),Vector2(60,180),Vector2(800,450))
	bridge.command("dev_edit",{"kind":"camera","payload":{"center":Vector2(60,180),"size":Vector2(960,540),"zoom":0.6,"bars":0.0}})
	var boss: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2(-500,-100),"entrance":false}).value
	var stage: RuntimeStage = ContentManager.runtime_stage(5).duplicate(true);stage.boss_enabled=false
	var session := RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":1605},false)
	session.auto_step=false
	var sim: RunSimulation = session.sim
	sim.field.bodies.clear();sim.state.ship_pos=Vector2(180,260);sim.state.view_center=Vector2(60,180);sim.state.camera_zoom=0.6;sim.state.view_half=Vector2(800,450)
	sim.ctx.options.view_size=Vector2(960,540)
	sim.bosses.spawn(definition,Vector2(-500,-100))
	var actor = sim.bosses.actor;actor.selection_enabled=false;actor.phase=2
	actor.cycle.begin_initial()
	check(bridge.command("dev_draco_cycle",{"entity_id":boss,"operation":"initial"}).ok,"初回生成を始める")
	var matched := true
	for frame in 1000:
		actor.cycle.tick(1.0/60.0);bridge._core.step(1.0/60.0)
		var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
		var names := ["","roar","collect","wait_beams","return","generate"]
		if String(actor.cycle.stage)!=names[body.cycle.stage] or not body.position.is_equal_approx(actor.table.pos[actor.body]) or absf(body.perspective_scale-actor.perspective_scale)>0.00001 or absf(body.cycle.time-actor.cycle.time)>0.00001: matched=false
		if actor.cycle.stage==&"": break
	check(matched,"初回生成はSourceと同じ段階・時刻・位置・命中半径の遠近で進む")
	var body: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(body.cycle.stage==0 and body.mode==1 and body.guard==0.0 and body.picaro.size()==3,"初回生成で3体を作り本体戦へ戻る")
	var frame: Dictionary = bridge.read_frame().value
	check(not frame.ui.controls_locked and not frame.ui.cinematic_camera and not frame.ui.encounter_protected,"初回のロックと保護を全て解放する")
	actor.cycle.begin_deep();bridge.command("dev_draco_cycle",{"entity_id":boss,"operation":"deep"})
	check(not bridge.read_frame().value.ui.controls_locked and bridge.read_frame().value.ui.cinematic_bars==0.0,"通常採集では操作を止めない")
	for tick in 90: actor.cycle.tick(1.0/60.0);bridge._core.step(1.0/60.0)
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.position.is_equal_approx(actor.table.pos[actor.body]) and absf(body.perspective_scale-actor.perspective_scale)<0.00001,"同じ画面サイズで通常採集の位置と命中半径を保つ")
	var held: Dictionary = bridge.checkpoint();check(held.ok,"採集中の段階・遠近・所有を保持する")
	bridge._core.step(0.4)
	var expected: Dictionary = bridge.command("dev_boss_body_state").value[0]
	check(bridge.restore(held.value).ok,"採集中を復元する")
	bridge._core.step(0.4)
	check(bridge.command("dev_boss_body_state").value[0]==expected,"復元後の位置・判定・時刻を保つ")
	bridge.release_checkpoint(held.value)
	actor.cycle.cancel();bridge.command("dev_draco_cycle",{"entity_id":boss,"operation":"cancel"})
	body=bridge.command("dev_boss_body_state").value[0]
	check(body.perspective_scale==1.0 and body.alpha==1.0 and body.guard==0.0 and body.cycle.stage==0,"採集中断は遠近・透明度・保護を残さない")
	var scope := ContentResourceScope.new()
	for item: Dictionary in package.visuals:
		if not item.path.is_empty(): scope.provide(item.path,load(item.path))
	for path in ["res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png"]: scope.provide(path,load(path))
	var view = load("res://scripts/render/run_frame_view.gd").new();add_child(view)
	var entries: Array[Dictionary]=[];entries.assign(package.visuals);view.setup(scope,entries,cfg.character_scale)
	bridge.command("dev_draco_cycle",{"entity_id":boss,"operation":"deep"});bridge._core.step(0.5)
	check(view.apply_frame(bridge.read_render(Rect2(-3000,-2000,6000,4000)).value),"採集粒と遠近はGodotが状態を読むだけで表示する")
	await get_tree().process_frame
	bridge.command("dev_cancel_boss",{"entity_id":boss})
	check(not bridge.read_frame().value.ui.cinematic_camera and not bridge.read_frame().value.ui.controls_locked,"本体中断は演出の所有状態を返す")
	view.free();bridge.dispose();session.free()
	print("[B_draco_cycle] failures=",failures)
	get_tree().quit(1 if failures else 0)
