## たて座の生成・追跡・旋回を、本番の編集値と更新へ照合する。
extends Node
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
	await check_cpp_shield()
	print("[run_shield] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func reflected_shot(core, target: Vector2, radius: float) -> void:
	var options := {"speed":1200.0,"r":radius,"life":4.0}
	check(core.fire_shot(target,PI,10.0,options),"盾の前面へ味方弾を作る")
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
	var definition: EnemyDef = ContentManager.enemies[&"shield"]
	var empty: Dictionary = bridge.checkpoint()
	var pending: Dictionary = {}
	if not reflected_lifetime:
		for radius in [1.0,7.0,17.0]:
			check(bridge.restore(empty.value).ok,"半径ごとの反射の場面を初期化する")
			reflected_shot(core,target,radius)
			var shots: Array = core.hostiles_snapshot()
			check(shots.size()==1 and shots[0].kind==2 and is_equal_approx(shots[0].life,float(definition.params.reflect_life)),"盾の寿命の値で危険な反射弾を1つ作る")
			var record: Dictionary = core.attack_snapshot()[0]
			check(record.source_id==source_id and record.source_alive,"反射元の敵IDと生存参照を分けて保持する")
			check(core.projectiles_snapshot().is_empty(),"盾に当たった味方弾を同じ更新で消す")
		# この弾を、同じ更新順と保持点から先へ進める。
		pending = bridge.checkpoint()
		var saved_hp: float = core.enemies_snapshot()[0].hp
		core.fire_shot(target,PI,10.0,{"speed":1200.0,"r":7.0,"life":4.0})
		core.step_projectiles(0.5)
		check(core.hostiles_snapshot().size()==1 and core.enemies_snapshot()[0].hp==saved_hp,"反射の待機中も味方弾を止め、反射弾とダメージを重ねない")
		core.step_hostiles(0.1)
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
		core.step_hostiles(0.5)
		var hit: Dictionary = core.ship_snapshot()
		check(is_equal_approx(hit.ship_hp,config.base_hp-float(definition.params.reflect_dmg)),"反射弾を共通の機体被弾へ通す")
		bridge.restore(pending.value)
		core.step_hostiles(0.1)
		core.step_hostiles(0.5)
		check(core.hostiles_snapshot().is_empty() and core.ship_snapshot()==hit,"保持点から反射弾と同じ命中・消滅を再現する")
		bridge.restore(pending.value)
		reflected_shot(core,target,17.0)
		# C++には保持点の弾があるため、上で新規に追加された分を残さない。
		# 盾は保持点のクールダウン中なので、新しい反射弾は生成されない。
		bridge.command("dev_stone_hostiles",{"duration":0.1,"view":Rect2(-1800,-500,1500,1000)})
		core.step_hostiles(0.05)
		frame = bridge.read_render(Rect2(-1800,-500,1500,1000)).value
		var stone_shown := false
		for batch: Dictionary in frame.batches:
			if batch.visual_id==stone_visual: stone_shown = batch.ids.size()==1
		check(stone_shown,"石化した反射弾にも同じ灰色の表示を重ねる")
		var at := Vector2(core.hostiles_snapshot()[0].pos[0],core.hostiles_snapshot()[0].pos[1])
		bridge.command("dev_ship_motion",{"position":at,"velocity":Vector2.ZERO})
		core.step_hostiles(0.02)
		check(core.hostiles_snapshot().is_empty() and is_equal_approx(core.ship_snapshot().ship_hp,config.base_hp),"石化した反射弾は触れると被弾せずに消える")
	# 十分に広い表示範囲で、地形と機体を避け、反射弾自体の寿命で終了させる。
	bridge.restore(empty.value)
	var far_source_position := Vector2(1500,1500)
	bridge.command("dev_spawn",{"definition_id":"shield","position":far_source_position})
	reflected_shot(core,Vector2(1800,1500),7.0)
	var outside := Vector2(-3000,3000)
	bridge.command("dev_ship_motion",{"position":outside,"velocity":Vector2.ZERO})
	core.set_motion_context(outside,Vector2(2000,1500),Vector2(10000,10000))
	core.step_hostiles(float(definition.params.reflect_life)+0.01)
	var lifetime := 0
	# 個別Systemを直接進める確認では、通常Runnerの末尾に相当する通知の確定も行う。
	for event: Dictionary in core.drain_events():
		if event.type==&"attack_retired" and event.reason=="lifetime": lifetime += 1
	check(core.hostiles_snapshot().is_empty() and lifetime==1,"盾の寿命の値を使い切った反射弾を一度だけ回収する")
	if not pending.is_empty(): bridge.release_checkpoint(pending.value)
	bridge.release_checkpoint(empty.value)
	await get_tree().process_frame
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
	stage.boss_enabled = false
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
	for mode in ["front_ram","rear_ram","front_shots","back_shots","movement"]:
		bridge.restore(initial.value)
		notices.clear()
		var definition: EnemyDef = ContentManager.enemies[&"shield"]
		var position := target+Vector2(25,0) if mode=="rear_ram" else target-Vector2(25,0) if mode=="front_ram" else target+Vector2(480,200)
		var id: int = bridge.command("dev_spawn",{"definition_id":"shield","position":position}).value
		core.set_motion_context(target,target,Vector2(640,360))
		if mode.ends_with("ram"):
			var velocity := Vector2(1000,0) if mode=="rear_ram" else Vector2(-1000,0)
			bridge.command("dev_ship_motion",{"position":target,"velocity":velocity})
			var from := target-velocity.normalized()*100.0
			check(core.collide_ship(from,config.ship_radius)==(mode=="front_ram"),"盾への体当たりの前後判定: "+mode)
		elif mode.ends_with("shots"):
			var from := position+Vector2(200,0) if mode=="front_shots" else position-Vector2(200,0)
			var angle := PI if mode=="front_shots" else 0.0
			for repeat in 2:
				var options := {"speed":1200.0,"life":1.0,"pierce_left":5,"knock":0.0,"weapon_id":&"W01"}
				core.fire_shot(from,angle,2.0,options)
				core.step_projectiles(0.2)
			check(core.hostiles_snapshot().size()==(1 if mode=="front_shots" else 0),"前面だけ反射し待ち時間中の反射を重ねない: "+mode)
		else:
			for step in 4:
				core.step(0.125)
			var relocated := target+Vector2(500,-100)
			check(bridge.command("dev_relocate",{"entity_id":id,"position":relocated}).ok and core.enemies_snapshot()[0].id==id,"再配置で盾の個体IDを保つ")
			bridge.command("dev_kill",{"entity_id":id,"cause":"ram"})
			check(core.enemies_snapshot()[0].dead==1,"再配置した盾も通常の撃破へ通る")
			continue
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
				core.step_ship(elapsed,elapsed,{"touch":true})
				var at: Vector2 = core.ship_snapshot().ship_pos
				core.set_motion_context(at,at,Vector2(640,360))
				core.spawn_hostile({"kind":0,"pos":at,"vel":Vector2.ZERO,"speed":0.0,"r":7.0,"life":1.0,"dmg":7.0,"slow":0.2,"turn":0.0})
				core.step_hostiles(0.01)
			bridge.command("set_ui_overlay",{"active":false})
			presentation._present_cpp(0.0)
			check(core.ship_snapshot().ship_hp<config.base_hp and not holder.get_node("ScutumGuardLighting").visible,"失効した盾は表示を消して被弾する")
			bridge.restore(held.value)
			bridge.collect_frame()
			presentation._present_cpp(0.0)
			check(bridge.read_frame().value.ui.get("ship_shield_visual",0)>0 and holder.get_node("ScutumGuardLighting").visible,"盾を奪った保持点から外観と防御を復元する")
			bridge.release_checkpoint(held.value)
	bridge.release_checkpoint(initial.value)
	session.free()
	shield_finished = true
