## 全装備を編集画面と同じ手順で本番描画へ接続し、実行時エラーを失敗として扱う。
extends Node
const SESSION := preload("res://gyms/enemy_lab/lab_session.gd")
const SCENARIO := preload("res://gyms/equipment_effect_scenario.gd")
const MemorySave := preload("res://tests/thrill_acceptance.gd").MemorySave
class ErrorCapture extends Logger:
	var errors: Array[String] = []
	var mutex := Mutex.new()
	func _log_message(_message: String, _error: bool) -> void: pass
	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _notify: bool, type: int, _traces: Array[ScriptBacktrace]) -> void:
		if type == ERROR_TYPE_WARNING: return
		mutex.lock()
		errors.append("%s:%d %s %s" % [file,line,code,rationale])
		mutex.unlock()
	func count() -> int:
		mutex.lock()
		var result := errors.size()
		mutex.unlock()
		return result
	func messages() -> Array[String]:
		mutex.lock()
		var result: Array[String] = errors.duplicate()
		mutex.unlock()
		return result
var capture := ErrorCapture.new()
var failures := 0
var cases := 0
var only := PackedStringArray()
var gpu := false
var sonic_white_square := 0
const EVENTS := {
	"weapon/forward":&"weapon_fire", "weapon/scatter":&"weapon_fire", "weapon/rear":&"weapon_fire",
	"weapon/knockback":&"hull_scatter", "weapon/contactWave":&"space_quake", "weapon/contactArc":&"bolt",
	"weapon/barrier":&"barrier_hit", "weapon/mines":&"explode", "weapon/massTow":&"anchor_fire", "weapon/sonic":&"sonic_push",
	"weapon/bipolar":&"beam", "weapon/dashRangeDrone":&"escort_deploy", "weapon/flashSlash":&"flash_slash", "weapon/endBlast":&"explode",
	"trait/vortex":&"hole_recover", "trait/killSonic":&"chain_shock", "trait/critBeam":&"critical_lance",
	"trait/runUp":&"run_up_hit", "trait/fullBurst":&"full_burst_ready", "trait/duplicator":&"duplicate"
}
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

## 装備キー（weapon/〜・trait/〜）の表示。
func _visual(presentation, key: String) -> WeaponVisual:
	for visual in presentation._equipment_visuals.values():
		if visual._effect_key() == key: return visual
	return null

## 大きな白い面が出る再発を、実際の描画画素から検出する。
func measure_white_square(viewport: SubViewport) -> int:
	var image := viewport.get_texture().get_image()
	var columns := image.get_width()/4
	var previous := PackedInt32Array()
	previous.resize(columns+1)
	var largest := 0
	for y in range(0,image.get_height(),4):
		var current := PackedInt32Array()
		current.resize(columns+1)
		for x in columns:
			var color := image.get_pixel(x*4,y)
			if color.a>0.9 and minf(color.r,minf(color.g,color.b))>0.95:
				current[x+1]=1+mini(current[x],mini(previous[x],previous[x+1]))
				largest=maxi(largest,current[x+1])
		previous=current
	return largest*4

func _ready() -> void:
	if "--cpp-t08" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_t08()
		check(finished,"大容量チャージの確認を最後まで実施する")
		print("[cpp_t08] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-t07-view" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_t07_view()
		check(finished,"急速充填の表示と下限を最後まで確認する")
		print("[cpp_t07_view] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-t07" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_t07()
		if finished: finished = await check_cpp_t07_view()
		check(finished,"急速充填の確認を最後まで実施する")
		print("[cpp_t07] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-w01" in OS.get_cmdline_user_args() or "--cpp-w01-detail" in OS.get_cmdline_user_args():
		await check_cpp_w01()
		print("[cpp_w01] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return
	for arg in OS.get_cmdline_user_args():
		if arg == "--gpu": gpu = true
		if arg == "--combinations-only": only = PackedStringArray(["__combinations__"])
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=").split(",")
	OS.add_logger(capture)
	# 高速な描画処理の検査では音を再生せず、音声再生の終了待ちを含めない。
	AudioManager._sounds = {}
	var settings: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.data = SaveManager.default_data()
	SaveManager.settings = settings
	var editor_script = load("res://gyms/effect_settings_preview.gd")
	var preview = load("res://gyms/boss_effect_preview.gd").new()
	preview.size = Vector2(1280,720)
	add_child(preview)
	var session = preview.session
	session.set_physics_process(false)
	for category in [&"weapons",&"traits"]:
		for entry in ContentManager.catalog.table(category).values():
			var key := ("weapon/" if category == &"weapons" else "trait/")+String(entry.code_id)
			if not only.is_empty() and key not in only: continue
			check(key in editor_script.DIRECT_EFFECTS,"全装備が再生一覧にある: "+key)
			for level in range(1,6):
				var before_reset := capture.count()
				preview._equipment_key = ""
				preview._weapon_key = ""
				preview._trait_key = ""
				preview._trait_level.select(level-1)
				preview._equipment_level.select(level-1)
				await preview.set_effect(key)
				session.playing = false
				var presentation = session.scene.view.get_node("RunPresentation")
				presentation.set_process(false)
				var error_count := before_reset
				check(presentation._layers.enemies.visible,"実験場で敵を表示する: "+key)
				if level==1:
					var before_spawn: int = session.run.enemies.table.alive.count(1)
					preview._add_preview_enemies()
					check(session.run.enemies.table.alive.count(1)==before_spawn+3,"敵を追加ボタンで3体を出す: "+key)
				var observed := false
				for frame in 600:
					session.step()
					if frame%4 == 0:
						presentation._present(4.0*session.DT)
						if key == "weapon/interceptor": observed = observed or session.run.loadout.weapon_behaviors[entry.id].drones.any(func(d):return d.flash>0.0)
						if key == "weapon/sonic": observed = observed or _visual(presentation, key).impacts.size() + _visual(presentation, key).pushes.size() > 0
						if key == "weapon/afterimage":
							var mirage = session.run.loadout.weapon_behaviors[entry.id]
							observed = observed or not mirage.echoes.is_empty()
							for echo in mirage.echoes: check(echo.copies.size()==level,"ミラージュの本体はLvごとの1〜5機")
							var visual = presentation._equipment_visuals.get(mirage.get_instance_id())
							if visual != null: check(visual.node._body._count<=level,"ミラージュの描画で本体を重複させない")
						if key == "trait/fullCharge": observed = observed or not _visual(presentation, key).gear.fire.particles.is_empty()
						if key == "trait/rampage": observed = observed or (not session.run.state.tracing and session.run.loadout.trait_behaviors[entry.id].strength>0.9)
					if gpu and frame%4 == 0:
						await RenderingServer.frame_post_draw
						if key=="weapon/sonic": sonic_white_square=maxi(sonic_white_square,measure_white_square(preview._viewport))
					elif frame%60 == 0: await get_tree().process_frame
				if EVENTS.has(key): check(session.events.any(func(ev):return ev.type == EVENTS[key]),"対象の演出が実際に発動する: %s Lv%d" % [key,level])
				if key in ["weapon/interceptor","weapon/sonic","weapon/afterimage","trait/fullCharge","trait/rampage"]: check(observed,"連続する演出が実際に動く: %s Lv%d" % [key,level])
				if key == "weapon/barrier": check(session.events.any(func(ev):return ev.type == &"barrier_restore"),"バリアが復活する演出まで再生する")
				if key == "weapon/sonic": check(session.events.any(func(ev):return ev.type == &"sonic_impact"),"ソニックは輪だけでなく押し出し後の破裂まで再生する")
				check(capture.count() == error_count,"装備再生でエラー: %s Lv%d" % [key,level])
				if key == "weapon/knockback":
					check(not session.events.any(func(ev):return ev.type == &"debris_trail"),"星砕きの消滅後に古い航跡を残さない")
				cases += 1
				print("[equipment_effects] %d %s Lv%d errors=%d" % [cases,key,level,capture.count()-error_count])
				if capture.count() > error_count: break
	for combination in [
		{"key":"trait/critBeam","weapons":{},"traits":{&"T06":5,&"T37":5}},
		{"key":"weapon/knockback","weapons":{&"W03":5},"traits":{&"T37":5}},
		{"key":"weapon/interceptor","weapons":{&"W25":5},"traits":{&"T35":5,&"T36":5,&"T37":5}},
		{"key":"weapon/endBlast","weapons":{&"W05":5,&"W07":5,&"W29":5},"traits":{&"T03":5,&"T34":5}},
		{"key":"trait/vortex","weapons":{&"W07":5},"traits":{&"T03":5}},
		{"key":"trait/rampage","weapons":{&"W07":5},"traits":{&"T33":5}}
	]:
		if not only.is_empty() and "__combinations__" not in only: continue
		var error_count := capture.count()
		await session.reset({"empty":true,"invincible":true,"director":{"enabled":false},"weapons":combination.weapons,"traits":combination.traits})
		var duplicator = session.run.loadout.trait_behaviors.get(&"T37")
		if duplicator != null:
			duplicator.def = duplicator.def.duplicate(true)
			duplicator.def.params.chance_by_level = [1.0,1.0,1.0,1.0,1.0]
		var presentation = session.scene.view.get_node("RunPresentation")
		presentation.set_process(false)
		SCENARIO.play(session,combination.key)
		for frame in 420:
			session.step()
			if frame%4 == 0: presentation._present(4.0*session.DT)
			if gpu and frame%4 == 0: await RenderingServer.frame_post_draw
			elif frame%60 == 0: await get_tree().process_frame
		if combination.key in ["trait/vortex","trait/rampage"]:
			check(session.run.loadout.weapon_behaviors[&"W07"]._serial==24,"特性の試遊でも機雷は終点で1回だけ出す: "+combination.key)
		check(capture.count() == error_count,"装備の組み合わせ再生でエラー: "+combination.key)
		cases += 1
		print("[equipment_effects] combination ",combination.key," errors=",capture.count()-error_count)
	if is_instance_valid(session.scene): session.scene.free()
	for checkpoint in session.checkpoints:
		if is_instance_valid(checkpoint.scene): checkpoint.scene.free()
	session.free()
	preview.free()
	await get_tree().process_frame
	await get_tree().process_frame
	OS.remove_logger(capture)
	for error in capture.messages(): printerr("[equipment_effects] "+error)
	if gpu and sonic_white_square>0:
		check(sonic_white_square<64,"ソニックに64px以上の白い面が出ない")
		print("[equipment_effects] ソニックの白い連続面の最大辺=%dpx" % sonic_white_square)
	print("[equipment_effects] cases=%d failures=%d errors=%d" % [cases,failures,capture.count()])
	get_tree().quit(1 if failures or capture.count()>0 else 0)

func check_cpp_w01() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 900.0
	config.world_tick_div = 1
	config.planet_radius = 0.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	var stage := RuntimeStage.new()
	stage.index = 88
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/run_w01"
	var builder = load("res://tools/content/build_run_content.gd")
	check(builder.build(stage,config,output,"W01全Lvと特性・解除".sha256_text())==OK,"W01の全Lvの値を生成する")
	var path := output.path_join("stage_88.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":631},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"W01の通常の状態・表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(640,480)}
	bridge.step(1.0/120.0,idle,viewport)
	if "--cpp-w01-detail" in OS.get_cmdline_user_args():
		await check_cpp_w01_detail(session,idle,viewport)
		session.free()
		return
	var initial: Dictionary = bridge.checkpoint()
	var lab = SESSION.new()
	add_child(lab)
	await lab.reset({"seed":631,"empty":true,"config":{"planet_radius":0.0,"start_radius":900.0}})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	var definition: WeaponDef = ContentManager.definition(&"weapons",&"W01")
	for level in range(1,definition.level_steps.size()+1):
		check(bridge.restore(initial.value).ok,"Lv別の確認の初期状態へ戻す")
		bridge.collect_frame()
		await lab.reset({"seed":631,"empty":true,"config":{"planet_radius":0.0,"start_radius":900.0}})
		run = lab.run
		run.field.bodies.clear()
		run.loadout.reset_loadout()
		check(run.loadout.grant(&"weapon",&"W01",level),"現行W01を全Lvで装備する")
		# 通常選択と同じ取得処理を通す。途中の解除で過去のタイマーを残さない。
		check(bridge.command("dev_remove_weapon",{"id":"W01"}).ok,"W01を途中で解除する")
		check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W01","levels":level}).ok,"型付きの定義からW01を各Lvで取得する")
		for id in ["T34","T35","T36"]:
			var stacks := 5 if id=="T35" else 2
			check(run.loadout.grant(&"trait",StringName(id),stacks),"現行の範囲・弾数・連射特性を取得する")
			check(bridge.command("dev_grant_equipment",{"kind":"trait","id":id,"levels":stacks}).ok,"同じ特性の生成値をC++の実効能力へ畳む")
		var weapon = run.loadout.weapon_behaviors[&"W01"]
		var source_projectiles: ProjectileSystem = run.projectiles
		for row in source_projectiles.friend_alive.size():
			if source_projectiles.friend_alive[row]: source_projectiles.release_friend(row)
		run.state.rng.state = int(core.inspect().rng_state)
		var fires := 0
		for tick in 110:
			if tick in [20,30]: bridge.command("pause",{"paused":tick==20})
			if tick in [50,56]: core.set_run_guards({"controls_locked":tick==50})
			var random_before: String = core.inspect().rng_state
			var before: float = core.inspect().world_time
			var input: Dictionary = idle.duplicate()
			if tick==65:
				input.touch = true
				input.press = true
				input.pen = core.ship_snapshot().ship_pos
			if tick==75:
				input.pen_release = true
			check(bridge.step(1.0/120.0,input,viewport).ok,"全Lvで通常の固定更新を進める")
			var dt: float = core.inspect().world_time-before
			var ship: Dictionary = core.ship_snapshot()
			var draw: Dictionary = core.draw_snapshot()
			run.state.ship_pos = ship.ship_pos
			run.state.ship_heading = ship.ship_heading
			run.state.gauge = draw.gauge
			run.state.events.clear()
			if dt>0.0 and not (tick>=50 and tick<56):
				weapon.tick(dt,draw.drawing or draw.tracing)
			if dt>0.0: source_projectiles.tick(dt,dt)
			var actual: Array = core.projectiles_snapshot()
			var expected := []
			for row in source_projectiles.friend_alive.size():
				if source_projectiles.friend_alive[row]: expected.append(row)
			check(actual.size()==expected.size(),"全Lvで弾数・寿命・解除の挙動が一致する Lv%d tick%d" % [level,tick])
			if actual.size()!=expected.size(): break
			for n in actual.size():
				var row: int = expected[n]
				check(actual[n].pos.distance_to(source_projectiles.friend_pos[row])<0.02 and actual[n].vel.distance_to(source_projectiles.friend_vel[row])<0.02,"砲口・扇状の角度・移動が一致する")
				check(is_equal_approx(actual[n].radius,source_projectiles.friend_r[row]) and is_equal_approx(actual[n].damage,source_projectiles.friend_dmg[row]) and is_equal_approx(actual[n].life,source_projectiles.friend_life[row]) and actual[n].pierce_left==source_projectiles.friend_pierce_left[row],"範囲・攻撃力・寿命・貫通数が実効値と一致する")
			check(is_equal_approx(weapon._t,core.forward_snapshot().elapsed) and is_equal_approx(weapon.recoil,core.forward_snapshot().recoil),"射撃間隔と反動を停止・操作ロック・描線に合わせる")
			var fired := run.state.events.any(func(event): return event.type==&"weapon_fire")
			check((random_before!=core.inspect().rng_state)==fired,"整数の弾数でも発射時に抽選し、停止中は抽選しない Lv%d tick%d" % [level,tick])
			for event: Dictionary in run.state.events:
				if event.type==&"weapon_fire": fires+=1
			if failures: break
		check(fires>0,"全Lvで実際に発射する")
		if failures: break
	# 発射済みの弾・残り時間・反動を同じ保持点から再現する。
	var mid: Dictionary = bridge.checkpoint()
	var shots: Array = core.projectiles_snapshot()
	var timing: Dictionary = core.forward_snapshot()
	check(bridge.command("dev_remove_weapon",{"id":"W01"}).ok,"装備を外して発射を終了する")
	check(core.projectiles_snapshot()==shots,"W01を外しても発射済みの弾は自然寿命まで残す")
	bridge.collect_frame()
	session.cpp_choices.poll()
	check(not session.cpp_choices.equipped.has("weapon:W01"),"解除した装備の資源保持を解く")
	var render: Dictionary = bridge.read_render(Rect2(-3000,-3000,6000,6000)).value
	check(not render.poses[0].visible,"解除した砲身を表示しない")
	check(bridge.restore(mid.value).ok,"途中の射撃状態を復帰する")
	bridge.collect_frame()
	check(core.projectiles_snapshot()==shots and core.forward_snapshot()==timing,"残った弾とタイマー・反動を一緒に復帰する")
	check(bridge.read_render(Rect2(-3000,-3000,6000,6000)).value.poses[0].visible,"復帰したW01の砲身を表示する")
	bridge.release_checkpoint(mid.value)
	bridge.restore(initial.value)
	bridge.collect_frame()
	# 通常のカード選択でW01を昇格し、資源がそろってからだけ確定する。
	check(bridge.command("dev_add_xp",{"amount":config.xp_base}).ok,"次の通常選択に必要な経験値を取得する")
	bridge.step(1.0/120.0,idle,viewport)
	var cards: Dictionary = bridge.read_frame().value.ui.cards
	var selected := {}
	for card: Dictionary in cards.candidates:
		if card.id=="W01": selected=card
	check(not selected.is_empty(),"通常の成長候補にW01の次のLvを出す")
	if not selected.is_empty():
		bridge.command("choose_card",{"offer_id":cards.offer_id,"candidate_id":selected.candidate_id})
		for frame in 120:
			session.cpp_choices.poll()
			bridge.step(1.0/120.0,idle,viewport)
			if bridge.read_frame().value.ui.phase==0: break
			await get_tree().process_frame
		session.cpp_choices.poll()
		var levels: Array = bridge.read_frame().value.ui.weapon_levels
		check(levels.any(func(item): return item.id=="W01" and item.level>=2),"通常の選択を一度だけ確定しW01のLvを上げる")
		check(session.cpp_choices.equipped.has("weapon:W01"),"選択資源を装備の寿命へ移す")
	bridge.release_checkpoint(initial.value)
	lab.free()
	session.free()

func check_cpp_w01_detail(session: RunSession,idle: Dictionary,viewport: Dictionary) -> void:
	var bridge = session.bridge
	var core = bridge._core
	var definition: WeaponDef = ContentManager.definition(&"weapons",&"W01")
	check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T35","levels":2}).ok,"端数を含む弾数特性を取得する")
	var volleys: Array = []
	bridge.subscribe("w01_detail",func(frame: Dictionary):
		for event: Dictionary in frame.events:
			if event.type==&"weapon_fire": volleys.append(event.payload)
		return true)
	for tick in 65:
		var count := volleys.size()
		bridge.step(1.0/120.0,idle,viewport)
		if volleys.size()==count: continue
		var fresh: Array = core.projectiles_snapshot().filter(func(shot): return shot.age<0.009)
		check(fresh.size() in [1,2],"端数の弾数は切り捨てか切り上げの1発群になる")
		for shot: Dictionary in fresh:
			var spread: float = absf(angle_difference(shot.vel.angle(),float(volleys[-1].angle)))
			check(is_equal_approx(spread,0.0 if fresh.size()==1 else float(definition.params.spread_step)*0.5),"追加弾を左右対称に広げる")
	check(not volleys.is_empty(),"端数の弾数で実際に発射する")
	var elapsed: float = core.forward_snapshot().elapsed
	var recoil: float = core.forward_snapshot().recoil
	check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W01","levels":1}).ok,"射撃の途中でW01を昇格する")
	check(is_equal_approx(elapsed,core.forward_snapshot().elapsed) and recoil==core.forward_snapshot().recoil,"Lv変更で射撃の経過時間と反動を初期化しない")
	var saved: Dictionary = bridge.checkpoint()
	for tick in 35: bridge.step(1.0/120.0,idle,viewport)
	var expected: Array = core.projectiles_snapshot()
	var expected_timing: Dictionary = core.forward_snapshot()
	var expected_random: String = core.inspect().rng_state
	check(bridge.restore(saved.value).ok,"端数抽選の途中へ復帰する")
	bridge.collect_frame()
	for tick in 35: bridge.step(1.0/120.0,idle,viewport)
	check(expected==core.projectiles_snapshot() and expected_timing==core.forward_snapshot() and expected_random==core.inspect().rng_state,"復帰後も弾数・位置・タイマー・乱数消費位置を再現する")
	bridge.release_checkpoint(saved.value)
	var shots: Array = core.projectiles_snapshot()
	check(not shots.is_empty(),"命中確認に実際に発射したW01の弾を使う")
	if shots.is_empty(): return
	var shot: Dictionary = shots[-1]
	var created: Dictionary = bridge.command("dev_spawn",{"definition_id":"drifter","position":shot.pos+shot.vel*0.04})
	check(created.ok,"発射済みのW01の弾の前へ敵を置く")
	var before: float = core.enemies_snapshot().filter(func(enemy): return enemy.id==created.value)[0].hp
	core.step_projectiles(0.05)
	var enemies: Array = core.enemies_snapshot().filter(func(enemy): return enemy.id==created.value)
	check(enemies.is_empty() or enemies[0].hp<before,"W01のLv別威力を通常の命中経路へ渡す")
	bridge.command("set_ui_overlay",{"active":false})
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	presentation._present_cpp(0.01)
	check(not presentation.frame_view._flashes.hits.is_empty(),"実際の命中通知を共通の十字・輪・火花の表示へ渡す")
	var shown := false
	for visual: Dictionary in session.cpp_resources.visuals:
		if visual.role==2:
			var batch: InstanceBatch = presentation.frame_view.batches.get(visual.id)
			shown = batch!=null and batch.multimesh.visible_instance_count>0
	check(shown,"発射したW01の光弾を通常の描画へ渡す")
	var muzzle: float = presentation.frame_view._flashes.muzzle_time
	var frame: Dictionary = bridge.read_frame().value
	presentation.frame_view.update_effects(frame,0.1)
	check(muzzle==presentation.frame_view._flashes.muzzle_time,"世界時計が止まっている表示では砲口の光も進めない")
	bridge.unsubscribe("w01_detail")
	await get_tree().process_frame

func t07_bridge(config: GameConfig,profile: Dictionary):
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var bytes: PackedByteArray = builder.compile_chase(ContentManager.enemies[&"drifter"],config,schema.sha256("急速充填の固定場面".to_utf8_buffer()))
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(bytes,{"api_version":1,"run_id":93,"mode":1,"stage_id":"t07","profile":profile,"settings":{}})
	if not configured.ok:
		check(false,"特性と最大段後の生成物を読み込む: %s" % configured)
		return null
	check(bridge.start(933,{"position":Vector2(-3000,0)}).ok,"急速充填の固定場面を開始する")
	bridge.collect_frame()
	return bridge

func check_cpp_t07() -> bool:
	OS.add_logger(capture)
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	var definition: TraitDef = load("res://data/traits/T07_quickCharge.tres")
	var factor := 0.8
	var bridge = t07_bridge(config,{"reduce":{"charge_time":factor}})
	if bridge==null: return false
	check(is_equal_approx(bridge._ui.charge_time,config.dash_charge_time*factor),"未取得時は永続強化までの充填時間を使う")
	for level in range(1,config.trait_max_stacks+1):
		check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T07","levels":1}).ok,"T07を共通取得入口で重ねる")
		check(is_equal_approx(bridge._ui.charge_time,config.dash_charge_time*factor/(1.0+definition.stack_bonus(level))),"各段の生成値から一度だけ実効充填時間を求める")
	var baseline: float = bridge._ui.charge_time
	check(not bridge.command("dev_grant_equipment",{"kind":"trait","id":"T07","levels":1}).ok and bridge._ui.charge_time==baseline,"上限を越えて取得せず実効値も変えない")
	check(bridge.command("dev_post_charge",{"stacks":5}).ok,"最大段後の短縮を同じ再計算へ渡す")
	var expected: float = config.post_max.reduced(baseline,&"charge_time",{&"charge_time":5},config.post_max.minimum_charge_time)
	check(is_equal_approx(bridge._ui.charge_time,expected),"通常特性から最大段後の短縮へ同じ順で適用する")
	var saved: Dictionary = bridge.checkpoint()
	bridge.command("dev_post_charge",{"stacks":10000})
	var floor_time := minf(baseline,maxf(config.post_max.minimum_charge_time,baseline*config.post_max.minimum_time_ratio))
	check(is_equal_approx(bridge._ui.charge_time,floor_time),"最大段後の充填短縮は元と同じ下限で止める")
	check(bridge.command("dev_remove_trait",{"id":"T07"}).ok,"特性を解除して実効値を再計算する")
	bridge.command("dev_post_charge",{"stacks":0})
	check(is_equal_approx(bridge._ui.charge_time,config.dash_charge_time*factor),"解除後も永続強化を保ち、特性の効果を残さない")
	check(bridge.restore(saved.value).ok,"所持段・永続倍率・最大段後の積み増しを保持して復帰する")
	bridge.collect_frame()
	check(is_equal_approx(bridge._ui.charge_time,expected),"復帰後に同じ実効値を表示へ渡す")
	bridge.release_checkpoint(saved.value)
	# 実際の描線でゲージを使い、利用側のstep_drawで充填量を確認する。
	var core = bridge._core
	var start := Vector2(-3000,0)
	check(core.handle_draw({"press":true,"touch":true,"has_cursor":true,"pen":start},0,1.0),"実際の描線入力を開始する")
	check(core.handle_draw({"touch":true,"has_cursor":true,"pen_release":true,"pen":start+Vector2(config.draw_length*0.5,0)},100,1.0),"線を発進してゲージを消費する")
	check(core.step_draw(10.0) and not core.draw_snapshot().tracing,"なぞりを終えて再充填へ戻る")
	var gauge: float = core.draw_snapshot().gauge
	check(gauge<1.0 and core.step_draw(0.01),"利用側の実時間で再充填する")
	check(is_equal_approx(core.draw_snapshot().gauge,minf(1.0,gauge+0.01/expected)),"実効充填時間が戦闘のゲージ増分へ一度だけ効く")
	bridge.dispose()
	OS.remove_logger(capture)
	check(capture.count()==0,"急速充填の状態に実行エラーがない: %s" % [capture.messages()])
	return true

func check_cpp_t07_view() -> bool:
	OS.add_logger(capture)
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	var factor := 0.8
	var bridge = t07_bridge(config,{"reduce":{"charge_time":factor}})
	if bridge==null: return false
	bridge.command("dev_grant_equipment",{"kind":"trait","id":"T07","levels":config.trait_max_stacks})
	bridge.command("dev_post_charge",{"stacks":5})
	var core = bridge._core
	var start := Vector2(-3000,0)
	core.handle_draw({"press":true,"touch":true,"has_cursor":true,"pen":start},0,1.0)
	core.handle_draw({"touch":true,"has_cursor":true,"pen_release":true,"pen":start+Vector2(config.draw_length*0.5,0)},100,1.0)
	core.step_draw(10.0)
	core.step_draw(0.01)
	var baseline := 0.0
	bridge.command("set_ui_overlay",{"active":false})
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.bridge = bridge
	hud.size = Vector2(640,480)
	add_child(hud)
	bridge.collect_frame()
	for _frame in range(3): await get_tree().process_frame
	check(hud._cpp_ui.charge_time==bridge._ui.charge_time and is_equal_approx(hud._ring_amount,core.draw_snapshot().gauge),"HUDのリングへ同じ実効値と充填量を描画する")
	hud.free()
	bridge.dispose()
	# 元の充填時間が表示上の最小秒数より短い場合も、特性を弱めない。
	config.dash_charge_time = 0.1
	bridge = t07_bridge(config,{"reduce":{"charge_time":factor}})
	if bridge==null: return false
	bridge.command("dev_grant_equipment",{"kind":"trait","id":"T07","levels":config.trait_max_stacks})
	baseline = bridge._ui.charge_time
	bridge.command("dev_post_charge",{"stacks":10000})
	check(is_equal_approx(bridge._ui.charge_time,baseline),"元から短い充填を最大段後の下限で長くしない")
	bridge.dispose()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"急速充填の状態・HUDに実行エラーがない: %s" % [capture.messages()])
	return true

func check_cpp_t08() -> bool:
	OS.add_logger(capture)
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	var definition: TraitDef = load("res://data/traits/T08_capacity.tres")
	var bridge = t07_bridge(config,{})
	if bridge==null: return false
	var core = bridge._core
	check(bridge._ui.capacity==1.0,"取得前は容量1で始まる")
	# 元からあるゲージの割合を、容量の変更で勝手に入れ替えない。
	var start := Vector2(-3000,0)
	core.handle_draw({"press":true,"touch":true,"has_cursor":true,"pen":start},0,1.0)
	core.handle_draw({"touch":true,"has_cursor":true,"pen_release":true,"pen":start+Vector2(config.draw_length*0.5,0)},100,1.0)
	core.step_draw(10.0)
	var gauge: float = core.draw_snapshot().gauge
	check(gauge<1.0,"実際の描線でゲージを消費しておく")
	for level in range(1,config.trait_max_stacks+1):
		check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T08","levels":1}).ok,"T08を共通の取得入口で重ねる")
		check(is_equal_approx(bridge._ui.capacity,1.0+definition.stack_bonus(level)) and core.draw_snapshot().gauge==gauge,"tresの各段を一度反映し、充填の割合を保つ")
	var capacity: float = bridge._ui.capacity
	check(not bridge.command("dev_grant_equipment",{"kind":"trait","id":"T08","levels":1}).ok and bridge._ui.capacity==capacity,"上限を越えて容量を増やさない")
	var saved: Dictionary = bridge.checkpoint()
	bridge.command("dev_post_charge",{"stacks":10000})
	check(bridge._ui.capacity==capacity,"最大段後の充填短縮を容量の増分へ混ぜない")
	var position: Vector2 = core.ship_snapshot().ship_pos
	core.handle_draw({"press":true,"touch":true,"has_cursor":true,"pen":position},200,1.0)
	var draw: Dictionary = core.draw_snapshot()
	check(is_equal_approx(draw.draw_gauge,gauge*capacity) and is_equal_approx(draw.draw_limit,config.draw_length*gauge*capacity),"利用側は容量を含む実充填量から描ける長さを求める")
	core.handle_draw({"touch":true,"pen_release":true},210,1.0)
	var charge: float = bridge._ui.charge_time
	core.step_draw(0.01)
	check(is_equal_approx(core.draw_snapshot().gauge,minf(1.0,gauge+0.01/(charge*capacity))),"再充填は実充填量で1単位分の速さを保つ")
	var retained: float = core.draw_snapshot().gauge
	check(bridge.command("dev_remove_trait",{"id":"T08"}).ok and bridge._ui.capacity==1.0 and core.draw_snapshot().gauge==retained,"解除で容量だけを戻し、ゲージの割合を保つ")
	check(bridge.restore(saved.value).ok,"取得段と容量とゲージを保持して復帰する")
	bridge.collect_frame()
	check(bridge._ui.capacity==capacity and core.draw_snapshot().gauge==gauge,"復帰後も容量と充填量が対応する")
	bridge.release_checkpoint(saved.value)
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.bridge = bridge
	hud.size = Vector2(640,480)
	add_child(hud)
	bridge.collect_frame()
	for _frame in range(3): await get_tree().process_frame
	check(hud._cpp_ui.capacity==capacity and is_equal_approx(hud._ring_amount,gauge*capacity),"HUDは容量と実充填量から追加のリングを描く")
	check(hud._lap_filled(0.99,1.01,capacity) and not hud._lap_filled(1.5,1.9,capacity),"容量の途中の1周だけでも満充填の境界を判定する")
	hud.free()
	bridge.dispose()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"大容量チャージの状態・表示に実行エラーがない: %s" % [capture.messages()])
	return true
