## 味方弾の命中順・寿命・貫通と行再利用を確認する。
extends Node
var failed := 0
var friend_finished := false
var friend_retry := false
var t37_retry := false
var t37_state_only := false
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	if "--cpp-t37-kind-merge" in OS.get_cmdline_user_args():
		var completed := check_cpp_t37_kind_merge()
		check(completed,"複製と種類別生成の統合確認を最後まで実施する")
		print("[cpp_t37_kind_merge] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-t37" in OS.get_cmdline_user_args() or "--cpp-t37-fixes" in OS.get_cmdline_user_args() or "--cpp-t37-state-format" in OS.get_cmdline_user_args():
		t37_state_only = "--cpp-t37-state-format" in OS.get_cmdline_user_args()
		t37_retry = t37_state_only or "--cpp-t37-fixes" in OS.get_cmdline_user_args()
		await check_cpp_t37()
		print("[cpp_t37] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return

	if "--cpp-friend-shot" in OS.get_cmdline_user_args() or "--cpp-friend-shot-fixes" in OS.get_cmdline_user_args():
		friend_retry = "--cpp-friend-shot-fixes" in OS.get_cmdline_user_args()
		await check_cpp_friend_shot()
		check(friend_finished,"味方弾の確認が最後まで進んだ")
		print("[cpp_friend_shot] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	check_cpp_t37_kind_merge()
	print("[run_projectiles] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func check_cpp_friend_shot() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 900.0
	config.planet_radius = 100.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	var stage := RuntimeStage.new()
	stage.index = 85
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter","shield"])
	var output := "res://.content/dev/run_friend_shot"
	var builder = load("res://tools/content/build_run_content.gd")
	var built: Error = builder.build(stage,config,output,"味方弾の地形・貫通・盾".sha256_text())
	check(built==OK,"味方弾の型と当たり定義を生成する")
	if built!=OK: return
	var path := output.path_join("stage_85.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":763},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"味方弾の通常の状態・表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	bridge.command("dev_ship_motion",{"position":Vector2(-900,0),"velocity":Vector2.ZERO})
	var initial: Dictionary = bridge.checkpoint()
	for kind in ["pierce","history","expiry","terrain","shield"]:
		bridge.restore(initial.value)
		var from := Vector2(-900,400)
		var angle := 0.0
		var positions := [from+Vector2(60,0),from+Vector2(100,0),from+Vector2(160,0),from+Vector2(200,0)]
		var definition := "drifter"
		var opts := {"speed":720.0,"life":0.7,"pierce_left":2,"knock":0.0,"visual_key":"weapon/forward","weapon_id":&"W01"}
		var steps := [0.05,0.05,0.05,0.05,0.05]
		if kind=="history":
			positions = [from+Vector2(5,0)]
			opts.speed = 100.0
			steps = [0.01,0.01]
		elif kind=="expiry":
			positions = [from+Vector2(20,0)]
			opts.life = 0.05
			steps = [0.1]
		elif kind=="terrain":
			from = Vector2(-200,0)
			positions = [Vector2(-150,0),Vector2(150,0)]
			opts.speed = 800.0
			steps = [0.5]
		elif kind=="shield":
			from = Vector2(-400,300)
			positions = [Vector2(-600,300)]
			definition = "shield"
			angle = PI
			opts.speed = 800.0
			steps = [0.25]
		for at: Vector2 in positions:
			check(bridge.command("dev_spawn",{"definition_id":definition,"position":at}).ok,"味方弾の命中対象を配置する: "+kind)
		var full_hp: Array = core.enemies_snapshot().map(func(row): return row.hp)
		check(core.fire_shot(from,angle,1.0,opts),"W01の武器IDと編集値から味方弾を生成する: "+kind)
		if kind=="pierce" and not friend_retry:
			var presentation: RunPresentation = session.view.get_node("RunPresentation")
			presentation._present_cpp(0.0)
			var frame: Dictionary = bridge.read_render(Rect2(-1600,-100,1500,1000)).value
			check(presentation.frame_view.apply_frame(frame),"味方弾の位置と向きを通常の表示へ渡す")
			var shown := false
			for visual: Dictionary in session.cpp_resources.visuals:
				if visual.role==2:
					var batch: InstanceBatch = presentation.frame_view.batches.get(visual.id)
					shown = batch!=null and batch.multimesh.visible_instance_count>0
			check(shown,"通常のドットの味方弾を表示する")
			await get_tree().process_frame
		for dt: float in steps:
			core.step_projectiles(dt)
		if kind=="pierce":
			var enemies: Array = core.enemies_snapshot()
			check(enemies[0].hp<full_hp[0] and enemies[1].hp<full_hp[1] and enemies[2].hp<full_hp[2] and enemies[3].hp==full_hp[3],"貫通回数を使い切った弾は次の敵へ届かない")
		elif kind=="terrain":
			var enemies: Array = core.enemies_snapshot()
			check(enemies[0].hp<full_hp[0] and enemies[1].hp==full_hp[1] and core.projectiles_snapshot().is_empty(),"地形の手前だけ命中し奥の敵へ届かない")
		elif kind=="shield":
			check(core.projectiles_snapshot().is_empty() and core.hostiles_snapshot().size()==1,"盾の正面で貫通弾も止まり危険な反射弾へ変わる")
		elif kind=="history" and not friend_retry:
			var held: Dictionary = bridge.checkpoint()
			var before: Array = core.projectiles_snapshot()
			core.step_projectiles(0.1)
			var after: Array = core.projectiles_snapshot()
			bridge.restore(held.value)
			check(core.projectiles_snapshot()==before,"貫通弾の命中済みIDと残り回数を復元する")
			core.step_projectiles(0.1)
			check(core.projectiles_snapshot()==after,"保持点から同じ飛行と一度だけの命中を再現する")
			bridge.release_checkpoint(held.value)
	if friend_retry:
		bridge.release_checkpoint(initial.value)
		session.free()
		friend_finished = true
		return
	# 同じ本体の複数部位を通っても、ダメージと命中履歴は本体IDで一度だけ。
	bridge.restore(initial.value)
	var parent: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(-650,400)}).value
	var part: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(-750,400)}).value
	bridge.command("dev_enemy_combat",{"entity_id":part,"damage_target":parent})
	var full_hp: Array = core.enemies_snapshot().map(func(row): return row.hp)
	core.fire_shot(Vector2(-900,400),0.0,1.0,{"speed":1000.0,"life":1.0,"pierce_left":3,"weapon_id":&"W01"})
	core.step_projectiles(0.3)
	var enemies: Array = core.enemies_snapshot()
	var live: Array = core.projectiles_snapshot()
	check(is_equal_approx(enemies[0].hp,full_hp[0]-1.0) and enemies[1].hp==full_hp[1] and live.size()==1 and live[0].hit_ids==[parent],"部位と本体への重複命中を本体IDで避ける")
	var weapon_seen := false
	for event: Dictionary in core.drain_events():
		if event.type==&"combat_damage" and event.get("weapon_id")==1: weapon_seen = true
	check(weapon_seen,"味方弾の武器IDを共通のダメージ記録へ渡す")
	bridge.release_checkpoint(initial.value)
	session.free()
	friend_finished = true

func t37_velocity_contract(core, label: String) -> void:
	for shot: Dictionary in core.projectiles_snapshot():
		var velocity: Vector2 = shot.vel
		var angle: float = absf(velocity.angle())
		check(is_zero_approx(angle) or (angle>=deg_to_rad(15.0)-0.0001 and angle<=deg_to_rad(45.0)+0.0001 and velocity.length()>=270.0-0.002 and velocity.length()<=330.0+0.002),label+"の複製が角度と速度の範囲を保つ")

func t37_normal_contract(core, level: int, definition: TraitDef) -> void:
	# 設計17.1のPCG32をseed737から進めた、通常生成16回の期待列。
	var split_at: Array = [[0,3,8],[0,3,8,9],[0,3,8,9,10,14],[0,3,8,9,10,14],[0,3,8,9,10,14]][level-1]
	var final_state: String = ["-3220606506977829253","3273026683270212063","-7467066158754631833","-7467066158754631833","-7467066158754631833"][level-1]
	var shots: Array = core.projectiles_snapshot()
	check(shots.size()==16+split_at.size()*2,"各段でPCG32の確率抽選に従って元と複製を出す")
	var cursor := 0
	for original in 16:
		if cursor>=shots.size(): return
		check(shots[cursor].pos==Vector2(original*20,0) and shots[cursor].damage==10.0,"通常の元を生成順に保持する")
		cursor += 1
		if not original in split_at: continue
		for side in [-1.0,1.0]:
			if cursor>=shots.size(): return
			var shot: Dictionary = shots[cursor]
			var angle: float = shot.vel.angle()*side
			check(shot.pos==Vector2(original*20,0) and is_equal_approx(shot.damage,10.0*float(definition.params.damage_by_level[level-1])),"複製は初期化後の元から位置と各段の威力を引き継ぐ")
			check(angle>=deg_to_rad(float(definition.params.angle_min))-0.0001 and angle<=deg_to_rad(float(definition.params.angle_max))+0.0001 and shot.vel.length()>=450.0-0.002 and shot.vel.length()<=550.0+0.002,"通常生成の左右の角度と速度が定義の範囲に収まる")
			cursor += 1
	check(core.inspect().rng_state==final_state,"各段の出生順と抽選消費がPCG32の期待列に一致する")

func t37_fixture_bridge(config: GameConfig):
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var records: Dictionary = builder.chase_records(ContentManager.enemies[&"drifter"],config)
	# 既存split検査と同じく、入れ子と上限は抽選成功を固定して境界だけを見る。
	for row: Dictionary in records.DuplicatorDefinition: row.chance = 1.0
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	check(bridge.configure(schema.write_content(records,schema.sha256("複製の入れ子と上限".to_utf8_buffer())),{"api_version":1,"run_id":937,"mode":1,"stage_id":"T37","profile":{},"settings":{}}).ok,"入れ子と上限の固定場面を生成する")
	check(bridge.start(737,{"position":Vector2(-900,0)}).ok,"複製の固定場面を始める")
	bridge.collect_frame()
	return bridge

func check_cpp_t37() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	for field in ["planet_radius","moon_count","meteor_count","iron_count","saw_count"]: config.set(field,0)
	config.start_radius = 900.0
	config.base_crit_chance = 0.0
	var stage := RuntimeStage.new()
	stage.index = 87
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/run_T37"
	var builder = load("res://tools/content/build_run_content.gd")
	check(builder.build(stage,config,output,"複製の全段と表示".sha256_text())==OK,"複製の全段の実効値と資源を生成する")
	var path := output.path_join("stage_87.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":737},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"複製の通常のランと表示を用意する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	var initial: Dictionary = bridge.checkpoint()
	for level in range(1,config.trait_max_stacks+1):
		if t37_state_only and level==2: continue
		bridge.restore(initial.value)
		bridge.collect_frame()
		check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T37","levels":level}).ok,"生成した複製を各段で取得する")
		for n in 16:
			var pos := Vector2(n*20,0)
			var opts := {"speed":500.0,"life":1.0,"pierce_left":2,"knock":137.0,"weapon_id":"W01","visual_key":"weapon/forward"}
			core.fire_shot(pos,0.0,10.0,opts)
		t37_normal_contract(core,level,ContentManager.definition(&"traits",&"T37"))
		if level==config.trait_max_stacks and not t37_retry:
			bridge.command("set_ui_overlay",{"active":false})
			var presentation: RunPresentation = session.view.get_node("RunPresentation")
			presentation._present_cpp(0.01)
			check(presentation.frame_view._duplicator_visual!=null and not presentation.frame_view._duplicator_visual.splits.is_empty(),"複製の光を実際の生成通知から通常の表示へ渡す")
			var age: float = presentation.frame_view._duplicator_visual.splits[0].age
			presentation.frame_view.update_effects(bridge.read_frame().value,0.2)
			check(presentation.frame_view._duplicator_visual.splits[0].age==age,"世界時計が止まる間は複製の光も止める")
			var before: Array = core.projectiles_snapshot()
			bridge.command("dev_remove_trait",{"id":"T37"})
			check(core.projectiles_snapshot()==before,"特性を外しても生成済みの複製は自然寿命まで残す")
			presentation._present_cpp(0.01)
			check(presentation.frame_view._duplicator_visual==null,"解除した複製の表示を片付ける")
	bridge.release_checkpoint(initial.value)
	session.free()
	var fixture = t37_fixture_bridge(config)
	core = fixture._core
	fixture.command("dev_remove_weapon",{"id":"W01"})
	fixture.command("dev_grant_equipment",{"kind":"trait","id":"T37","levels":5})
	var records := [{"position":Vector2(0,0),"velocity":Vector2(300,0),"damage":1.0,"post_damage":9.0,"life":0.8,"age":0.1,"hit_ids":PackedInt64Array([99]),"shatter_depth":3},
		{"nested":[{"position":Vector2(100,0),"velocity":Vector2(300,0),"post_damage":7.0,"callback":"interceptor","callback_knock":173.0,"callback_no_crit":true},{"position":Vector2(200,0),"velocity":Vector2(300,0),"kind":2,"cause":"saw","pierce":true}]},
		{"position":Vector2(300,0),"velocity":Vector2(300,0),"kind":1,"cause":"hullDebris","post_damage":11.0,"pierce":true}]
	check(fixture.command("dev_friend_births",{"births":records}).ok,"入れ子の生成列を初期化してから完了する")
	t37_velocity_contract(core,"入れ子と初期化完了")
	check(core.inspect().rng_state=="2861193922729689715","入れ子は内側2件→外側2件のPCG32抽選を消費する")
	check(core.projectiles_snapshot().size()==12,"4件の元から各2件を複製し、複製を再び複製しない")
	for shot: Dictionary in core.projectiles_snapshot():
		if shot.callback=="interceptor": check(shot.callback_knock==173.0 and shot.callback_no_crit,"callbackの型と値を複製へ引き継ぐ")
	var held: Dictionary = fixture.checkpoint()
	var state: Array = core.projectiles_snapshot()
	core.step_projectiles(0.1)
	var advanced: Array = core.projectiles_snapshot()
	check(fixture.restore(held.value).ok and core.projectiles_snapshot()==state,"命中集合・残り寿命・経過・深さ・callbackの値へ復帰する")
	core.step_projectiles(0.1)
	check(core.projectiles_snapshot()==advanced,"復帰後も元と複製が同じ飛行を再現する")
	fixture.release_checkpoint(held.value)
	core.step_projectiles(2.0)
	check(core.projectiles_snapshot().is_empty(),"寿命が来た元と複製をすべて回収する")
	fixture.command("dev_friend_births",{"births":records})
	t37_velocity_contract(core,"回収後の行再利用")
	check(core.inspect().rng_state=="-7467066158754631833","回収後も同じ出生順でPCG32の次の20回を消費する")
	core.step_projectiles(2.0)
	fixture.command("dev_remove_trait",{"id":"T37"})
	var filling := []
	for n in 217: filling.append({"position":Vector2(n,0),"velocity":Vector2.ZERO,"life":1.0})
	check(fixture.command("dev_friend_births",{"births":filling}).ok,"通常の元の弾で上限直前まで埋める")
	fixture.command("dev_grant_equipment",{"kind":"trait","id":"T37","levels":5})
	check(fixture.command("dev_friend_reserve",{"count":1,"release":false}).ok,"未処理の飛ぶ攻撃を共通の上限へ予約する")
	var random: String = core.inspect().rng_state
	fixture.command("dev_friend_births",{"births":[{"position":Vector2.ZERO,"velocity":Vector2.RIGHT}]})
	check(core.projectiles_snapshot().size()==218 and core.inspect().rng_state==random,"予約分を含めて残り1枠なら抽選せず複製を出さない")
	check(fixture.command("dev_friend_reserve",{"count":1,"release":true}).ok,"処理済みの予約を一度だけ解放する")
	core.step_projectiles(2.0)
	fixture.command("dev_remove_trait",{"id":"T37"})
	fixture.command("dev_friend_births",{"births":filling})
	fixture.command("dev_grant_equipment",{"kind":"trait","id":"T37","levels":5})
	fixture.command("dev_friend_births",{"births":[{"position":Vector2.ZERO,"velocity":Vector2.RIGHT}]})
	check(core.projectiles_snapshot().size()==220,"残り2枠なら同じ生成で2件を複製する")
	core.step_projectiles(2.0)
	fixture.command("dev_remove_trait",{"id":"T37"})
	var debris := []
	for n in 198: debris.append({"position":Vector2(n,0),"velocity":Vector2.ZERO,"kind":1,"cause":"hullDebris"})
	fixture.command("dev_friend_births",{"births":debris})
	fixture.command("dev_grant_equipment",{"kind":"trait","id":"T37","levels":5})
	fixture.command("dev_friend_births",{"births":[{"position":Vector2.ZERO,"velocity":Vector2.RIGHT,"kind":1,"cause":"hullDebris"}]})
	check(core.projectiles_snapshot().size()==200,"星屑の残り1枠では複製中にも200件の上限を守る")
	random = core.inspect().rng_state
	fixture.command("dev_friend_births",{"births":[{"position":Vector2.ZERO,"velocity":Vector2.RIGHT,"kind":1,"cause":"hullDebris"}]})
	check(core.projectiles_snapshot().size()==201 and core.inspect().rng_state==random,"星屑が満杯なら元の生成後も複製の抽選を使わない")
	fixture.dispose()
	await get_tree().process_frame

func check_cpp_t37_kind_merge() -> bool:
	check(load("res://tests/runtime/run_hostiles.gd").can_instantiate(),"統合した敵攻撃検査の構文を読み込める")
	var config: GameConfig = ContentManager.base.duplicate(true)
	for field in ["planet_radius","moon_count","meteor_count","iron_count","saw_count"]: config.set(field,0)
	config.start_radius = 900.0
	var bridge = t37_fixture_bridge(config)
	var core = bridge._core
	check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T37","levels":5}).ok,"固定抽選の複製を取得する")
	var source: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(-900,0)}).value
	check(bridge.command("dev_scatter_hull",{"source_id":source,"direction":Vector2.RIGHT,"speed":100.0,"damage":2.0,"shatter_depth":3}).ok,"種類別の星屑を出生列の完了時に複製する")
	var dust: Array = core.projectiles_snapshot()
	check(dust.size()==6 and dust.all(func(p): return p.shatter_depth==3 and p.hit_ids==[source]),"星屑の元2件と複製4件が共通の深さと命中済みIDを保持する")
	check(bridge.command("dev_fire_hull",{"position":Vector2(-900,0),"velocity":Vector2.RIGHT*100.0,"definition_id":"drifter","source_id":source,"radius":12.0,"damage":2.0,"life":1.0,"angle":0.0,"knock":10.0}).ok,"種類別の船体弾を完成後に複製する")
	var hulls: Array = core.projectiles_snapshot().filter(func(p): return p.kind==2)
	check(hulls.size()==3 and hulls.all(func(p): return p.source_id==source and p.source_definition==1 and not p.saw),"船体弾の元と複製が元外観と個体IDを保持する")
	var snapshot: Array = core.projectiles_snapshot()
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"種類別の深さと元外観を含む複製を保持できる")
	if not held.ok: bridge.dispose(); return false
	core.step_projectiles(0.05)
	check(bridge.restore(held.value).ok and core.projectiles_snapshot()==snapshot,"統合した種類別の複製を同じ値へ復帰する")
	bridge.release_checkpoint(held.value)
	bridge.dispose()
	return true
