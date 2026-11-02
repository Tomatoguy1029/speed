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
	if "--cpp-w23" in OS.get_cmdline_user_args():
		await check_cpp_w23()
		print("[cpp_w23] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-w02" in OS.get_cmdline_user_args() or "--cpp-w02-retry" in OS.get_cmdline_user_args():
		await check_cpp_w02()
		print("[cpp_w02] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-t35" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_t35()
		check(finished,"マルチショットの確認を最後まで実施する")
		print("[cpp_t35] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-t34" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_t34()
		check(finished,"大振りの確認を最後まで実施する")
		print("[cpp_t34] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-t31" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_t31()
		check(finished,"慣性航行の確認を最後まで実施する")
		print("[cpp_t31] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-t14" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_t14()
		check(finished,"軌跡延長の確認を最後まで実施する")
		print("[cpp_t14] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-t12" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_t12()
		check(finished,"広域回収の確認を最後まで実施する")
		print("[cpp_t12] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-t11-ram" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_t11_ram()
		check(finished,"攻撃力の体当たり経路を最後まで照合する")
		print("[cpp_t11_ram] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-t11" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_t11()
		check(finished,"攻撃力の確認を最後まで実施する")
		print("[cpp_t11] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-t10-motion" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_t10_motion()
		check(finished,"最高速度の操舵を最後まで照合する")
		print("[cpp_t10_motion] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-t10" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_t10()
		check(finished,"最高速度の確認を最後まで実施する")
		print("[cpp_t10] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-t09" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_t09()
		check(finished,"急所見切りの確認を最後まで実施する")
		print("[cpp_t09] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

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

func check_cpp_w01(weapon_id: StringName = &"W01") -> void:
	var retry := "--cpp-w02-retry" in OS.get_cmdline_user_args()
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
	var output := "res://.content/dev/run_%s" % weapon_id
	var builder = load("res://tools/content/build_run_content.gd")
	check(builder.build(stage,config,output,"射撃の全Lvと特性・解除".sha256_text())==OK,"射撃の全Lvの値を生成する")
	var path := output.path_join("stage_88.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":631},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"射撃の通常の状態・表示を準備する")
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
	if weapon_id!=&"W01":
		check(bridge.command("dev_remove_weapon",{"id":"W01"}).ok,"確認前に初期装備を外す")
		check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":String(weapon_id),"levels":1}).ok,"生成した射撃を取得する")
	var initial: Dictionary = bridge.checkpoint()
	var lab = SESSION.new()
	add_child(lab)
	await lab.reset({"seed":631,"empty":true,"config":{"planet_radius":0.0,"start_radius":900.0}})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	var definition: WeaponDef = ContentManager.definition(&"weapons",weapon_id)
	for level in range(5 if retry else 1,definition.level_steps.size()+1):
		check(bridge.restore(initial.value).ok,"Lv別の確認の初期状態へ戻す")
		bridge.collect_frame()
		await lab.reset({"seed":631,"empty":true,"config":{"planet_radius":0.0,"start_radius":900.0}})
		run = lab.run
		run.field.bodies.clear()
		run.loadout.reset_loadout()
		check(run.loadout.grant(&"weapon",weapon_id,level),"現行射撃を全Lvで装備する")
		# 通常選択と同じ取得処理を通す。途中の解除で過去のタイマーを残さない。
		check(bridge.command("dev_remove_weapon",{"id":String(weapon_id)}).ok,"射撃を途中で解除する")
		check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":String(weapon_id),"levels":level}).ok,"型付きの定義から射撃を各Lvで取得する")
		for id in ["T34","T35","T36"]:
			var stacks := 5 if id=="T35" else 2
			check(run.loadout.grant(&"trait",StringName(id),stacks),"現行の範囲・弾数・連射特性を取得する")
			check(bridge.command("dev_grant_equipment",{"kind":"trait","id":id,"levels":stacks}).ok,"同じ特性の生成値をC++の実効能力へ畳む")
		var weapon = run.loadout.weapon_behaviors[weapon_id]
		var source_projectiles: ProjectileSystem = run.projectiles
		for row in source_projectiles.friend_alive.size():
			if source_projectiles.friend_alive[row]: source_projectiles.release_friend(row)
		run.state.rng.state = int(core.inspect().rng_state)
		var fires := 0
		for tick in (170 if weapon_id==&"W02" else 110):
			if tick in [20,30]: bridge.command("pause",{"paused":tick==20})
			if tick in [50,56]: core.set_run_guards({"controls_locked":tick==50})
			var random_before: String = core.inspect().rng_state
			var before: float = core.inspect().world_time
			var input: Dictionary = idle.duplicate()
			if tick==65:
				input.touch = true
				input.press = true
				input.pen = core.ship_snapshot().ship_pos
			if weapon_id==&"W23" and tick>80:
				input.has_cursor = true
				input.cursor = core.ship_snapshot().ship_pos+Vector2.from_angle((tick-80)*0.06)*300.0
			if tick==75:
				input.touch = true
				input.pen_release = true
			check(bridge.step(1.0/120.0,input,viewport).ok,"全Lvで通常の固定更新を進める")
			var dt: float = 0.0 if core.inspect().world_time==before else (1.0/120.0)*bridge._ui.world_scale
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
			check(is_equal_approx(weapon._t,shot_timing(core,weapon_id).elapsed) and is_equal_approx(weapon.recoil,shot_timing(core,weapon_id).recoil),"射撃間隔と反動を停止・操作ロック・描線に合わせる")
			if weapon_id==&"W23":
				var rear: Dictionary = bridge._ui.rear
				check(rear.mount.distance_to(weapon.mount_position())<0.001 and rear.aim.is_equal_approx(weapon.aim_direction()),"旋回中も後方砲台の位置と向きを同じ状態から渡す")
				for event: Dictionary in run.state.events:
					if event.type==&"weapon_fire":
						check(event.pos.distance_to(rear.mount+rear.aim*12.5*config.character_scale)<0.001 and absf(angle_difference(event.angle,rear.aim.angle()))<0.0001,"旋回後の砲口から機首と反対へ発射する")
			var fired := run.state.events.any(func(event): return event.type==&"weapon_fire")
			check((random_before!=core.inspect().rng_state)==fired,"整数の弾数でも発射時に抽選し、停止中は抽選しない Lv%d tick%d" % [level,tick])
			for event: Dictionary in run.state.events:
				if event.type==&"weapon_fire": fires+=1
			if failures: break
		check(fires>0,"全Lvで実際に発射する")
		if failures: break
	if weapon_id==&"W02": await check_cpp_w02_detail(session,idle,viewport)
	if weapon_id==&"W23": await check_cpp_w23_detail(session,idle,viewport)
	if not retry:
		# 発射済みの弾・残り時間・反動を同じ保持点から再現する。
		var mid: Dictionary = bridge.checkpoint()
		var shots: Array = core.projectiles_snapshot()
		var timing: Dictionary = shot_timing(core,weapon_id)
		check(bridge.command("dev_remove_weapon",{"id":String(weapon_id)}).ok,"装備を外して発射を終了する")
		check(core.projectiles_snapshot()==shots,"射撃を外しても発射済みの弾は自然寿命まで残す")
		bridge.collect_frame()
		session.cpp_choices.poll()
		check(not session.cpp_choices.equipped.has("weapon:%s" % weapon_id),"解除した装備の資源保持を解く")
		var render: Dictionary = bridge.read_render(Rect2(-3000,-3000,6000,6000)).value
		check(not bridge._ui.rear.ready if weapon_id==&"W23" else not render.poses[0].visible,"解除した砲身を表示しない")
		check(bridge.restore(mid.value).ok,"途中の射撃状態を復帰する")
		bridge.collect_frame()
		check(core.projectiles_snapshot()==shots and shot_timing(core,weapon_id)==timing,"残った弾とタイマー・反動を一緒に復帰する")
		check(bridge._ui.rear.ready if weapon_id==&"W23" else bridge.read_render(Rect2(-3000,-3000,6000,6000)).value.poses[0].visible,"復帰した射撃の砲身を表示する")
		bridge.release_checkpoint(mid.value)
	bridge.restore(initial.value)
	bridge.collect_frame()
	# 通常のカード選択で射撃を昇格し、資源がそろってからだけ確定する。
	check(bridge.command("dev_add_xp",{"amount":config.xp_base}).ok,"次の通常選択に必要な経験値を取得する")
	bridge.step(1.0/120.0,idle,viewport)
	var cards: Dictionary = bridge.read_frame().value.ui.cards
	var selected := {}
	for attempt in config.reroll_count+1:
		cards = bridge.read_frame().value.ui.cards
		for card: Dictionary in cards.candidates:
			if card.id==weapon_id: selected=card
		print("[射撃の通常候補] 武器=%s 引き直し=%d 候補=%s" % [weapon_id,attempt,cards.candidates.map(func(card): return card.id)])
		if not selected.is_empty() or attempt==config.reroll_count: break
		if not bridge.command("reroll",{"offer_id":cards.offer_id}).ok: break
	check(not selected.is_empty(),"通常の成長候補に射撃の次のLvを出す")
	if not selected.is_empty():
		bridge.command("choose_card",{"offer_id":cards.offer_id,"candidate_id":selected.candidate_id})
		for frame in 120:
			session.cpp_choices.poll()
			bridge.step(1.0/120.0,idle,viewport)
			if bridge.read_frame().value.ui.phase==0: break
			await get_tree().process_frame
		session.cpp_choices.poll()
		var levels: Array = bridge.read_frame().value.ui.weapon_levels
		check(levels.any(func(item): return item.id==weapon_id and item.level>=2),"通常の選択を一度だけ確定し射撃のLvを上げる")
		check(session.cpp_choices.equipped.has("weapon:%s" % weapon_id),"選択資源を装備の寿命へ移す")
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

func t07_bridge(config: GameConfig,profile: Dictionary,enemy_definition: EnemyDef = null):
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var bytes: PackedByteArray = builder.compile_chase(enemy_definition if enemy_definition!=null else ContentManager.enemies[&"drifter"],config,schema.sha256("数値特性の固定場面".to_utf8_buffer()))
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(bytes,{"api_version":1,"run_id":93,"mode":1,"stage_id":"t07","profile":profile,"settings":{}})
	if not configured.ok:
		check(false,"数値特性と最大段後の生成物を読み込む: %s" % configured)
		return null
	check(bridge.start(933,{"position":Vector2(-3000,0)}).ok,"数値特性の固定場面を開始する")
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

func t09_contact_hits(bridge,config: GameConfig,count: int) -> Array:
	var events: Array = []
	bridge.subscribe("t09_contact",func(frame):
		events.append_array(frame.events)
		return true)
	for _i in count:
		var id: int = bridge._core.spawn_enemy(&"drifter",Vector2(-3000,0))
		bridge._core.rebuild_enemy_grid(200.0)
		bridge.command("dev_ship_motion",{"position":Vector2(-2900,0),"velocity":Vector2(config.base_max_speed*2.0,0)})
		bridge._core.collide_ship(Vector2(-3100,0),config.ship_radius)
		bridge.command("dev_remove",{"entity_id":id})
	bridge.unsubscribe("t09_contact")
	return events

func check_cpp_t09() -> bool:
	OS.add_logger(capture)
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	var definition: TraitDef = load("res://data/traits/T09_critRate.tres")
	var enemy: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
	enemy.hp = 1000000.0
	enemy.armor = 0.0
	var bridge = t07_bridge(config,{},enemy)
	if bridge==null: return false
	var cap := float(definition.params.get("max",1.0))
	check(is_equal_approx(bridge._ui.crit_chance,minf(cap,config.base_crit_chance)),"未取得でもtresの上限を含む基礎クリティカル率を使う")
	for level in range(1,config.trait_max_stacks+1):
		check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T09","levels":1}).ok,"T09を共通の取得入口で重ねる")
		check(is_equal_approx(bridge._ui.crit_chance,minf(cap,config.base_crit_chance+definition.stack_bonus(level))),"前半/後半の増分を生成値から一度だけ適用する")
	var trained: float = bridge._ui.crit_chance
	check(not bridge.command("dev_grant_equipment",{"kind":"trait","id":"T09","levels":1}).ok and bridge._ui.crit_chance==trained,"重ね数上限を越えて率を増やさない")
	var reserve := maxf(0.0,minf(1.0,cap)-minf(minf(1.0,cap),config.base_crit_chance+definition.stack_bonus(config.trait_max_stacks)))
	bridge.command("dev_post_crit",{"stacks":2})
	check(is_equal_approx(bridge._ui.crit_chance,trained+minf(reserve,config.post_max.amount(&"crit_chance",{&"crit_chance":2}))),"最大段後はT09を最大にしても残る余地だけを加算する")
	bridge.command("dev_post_crit",{"stacks":10000})
	var maximum: float = bridge._ui.crit_chance
	check(is_equal_approx(maximum,trained+reserve),"最大段後の積み増しも予約した上限で止める")
	var saved: Dictionary = bridge.checkpoint()
	bridge.command("dev_remove_trait",{"id":"T09"})
	check(is_equal_approx(bridge._ui.crit_chance,minf(cap,config.base_crit_chance)+reserve),"解除で通常の特性分だけを外す")
	bridge.command("dev_post_crit",{"stacks":0})
	check(is_equal_approx(bridge._ui.crit_chance,minf(cap,config.base_crit_chance)),"最大段後の加算も外すと基礎値へ戻る")
	check(bridge.restore(saved.value).ok,"所持段と最大段後の積み増しを保持して復帰する")
	bridge.collect_frame()
	check(is_equal_approx(bridge._ui.crit_chance,maximum),"復帰後も同じ実効クリティカル率を公開する")
	bridge.release_checkpoint(saved.value)
	var events: Array = t09_contact_hits(bridge,config,32)
	var hits: Array = events.filter(func(event): return event.type==&"hit")
	var criticals: Array = hits.filter(func(event): return event.payload.crit)
	check(hits.size()==32 and not criticals.is_empty() and criticals.size()<32,"実際の体当たり入口が同じRunRandomでクリティカルを抽選する")
	var attack := config.base_attack*config.atk_scale
	check(hits.all(func(event): return is_equal_approx(event.payload.dmg,attack*(config.crit_mult if event.payload.crit else 1.0))),"抽選結果が実際のダメージ倍率へ一度だけ効く")
	check(events.filter(func(event): return event.type==&"critical_hit").size()==criticals.size(),"クリティカルの見た目へ命中ごとに1つ通知する")
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.bridge = bridge
	hud.size = Vector2(640,480)
	add_child(hud)
	bridge.collect_frame()
	for _frame in range(3): await get_tree().process_frame
	check(is_equal_approx(hud._cpp_ui.crit_chance,maximum) and hud._cpp_ui.trait_levels.any(func(item): return item.id=="T09" and item.level==config.trait_max_stacks),"HUDへ実効値と所持段を同じ状態から渡す")
	hud.free()
	bridge.dispose()
	# 基礎値だけでT09の上限へ届く調整でも、最大段後の余地を作らない。
	config.base_crit_chance = cap
	bridge = t07_bridge(config,{},enemy)
	if bridge==null: return false
	bridge.command("dev_grant_equipment",{"kind":"trait","id":"T09","levels":config.trait_max_stacks})
	bridge.command("dev_post_crit",{"stacks":10000})
	check(is_equal_approx(bridge._ui.crit_chance,cap),"基礎値と特性が上限へ届いた場合は加算を止める")
	bridge.dispose()
	config.base_crit_chance = 0.0
	bridge = t07_bridge(config,{},enemy)
	if bridge==null: return false
	events = t09_contact_hits(bridge,config,1)
	check(events.any(func(event): return event.type==&"hit") and not events.any(func(event): return event.type==&"critical_hit"),"確率0では弱点のない相手へクリティカルを出さない")
	bridge.dispose()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"急所見切りの状態・利用側・HUDに実行エラーがない: %s" % [capture.messages()])
	return true

func check_cpp_t10() -> bool:
	OS.add_logger(capture)
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	var definition: TraitDef = load("res://data/traits/T10_speed.tres")
	var factor := 1.2
	var profile := {"mult":{"max_speed":factor},"reduce":{"charge_time":0.9}}
	var bridge = t07_bridge(config,profile)
	if bridge==null: return false
	var core = bridge._core
	check(is_equal_approx(bridge._ui.max_speed,config.base_max_speed*factor),"未取得時は永続強化を掛けた最高速度を使う")
	check(is_equal_approx(bridge._ui.charge_time,config.dash_charge_time*0.9),"速度の永続値を読んでも充填の永続値を保つ")
	var velocity: Vector2 = core.ship_snapshot().ship_vel
	for level in range(1,config.trait_max_stacks+1):
		check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T10","levels":1}).ok,"T10を共通の取得入口で重ねる")
		check(is_equal_approx(bridge._ui.max_speed,config.base_max_speed*factor*(1.0+definition.stack_bonus(level))),"tresの各段を永続強化の後に一度適用する")
		check(core.ship_snapshot().ship_vel==velocity,"取得時に今の速度を勝手に書き換えない")
	var trained: float = bridge._ui.max_speed
	check(not bridge.command("dev_grant_equipment",{"kind":"trait","id":"T10","levels":1}).ok and bridge._ui.max_speed==trained,"上限を越えて最高速度を増やさない")
	bridge.command("dev_post_speed",{"stacks":2})
	var expected := trained*config.post_max.factor(&"max_speed",{&"max_speed":2})
	check(is_equal_approx(bridge._ui.max_speed,expected),"最大段後の速度倍率を通常の育成後に掛ける")
	var saved: Dictionary = bridge.checkpoint()
	# 同じ最高速度を使う操舵と自然減速を、既存の利用側で1回進める。
	bridge.command("dev_ship_motion",{"position":Vector2.ZERO,"velocity":Vector2.ZERO})
	check(core.step_ship(1.0,1.0,{"touch":true,"stick_active":true,"stick":Vector2.RIGHT*(config.stick_dead_zone+1.0)}),"機体の操舵と移動を進める")
	var cruise := minf(config.steer_accel,expected*config.steer_cruise)
	var floor_speed := expected*config.cruise_floor
	var result := floor_speed+(cruise-floor_speed)*exp(-config.cruise_drag) if cruise>floor_speed else cruise
	check(absf(core.ship_snapshot().ship_vel.length()-result)<0.0001,"操舵と減速は同じ実効最高速度を使う")
	var position: Vector2 = core.ship_snapshot().ship_pos
	core.handle_draw({"press":true,"touch":true,"has_cursor":true,"pen":position},0,1.0)
	check(is_equal_approx(core.draw_snapshot().draw_limit,config.draw_length*expected/config.base_max_speed),"描線の距離にも実効最高速度の比率が効く")
	core.handle_draw({"touch":true,"pen_release":true},100,1.0)
	velocity = core.ship_snapshot().ship_vel
	bridge.command("dev_remove_trait",{"id":"T10"})
	check(is_equal_approx(bridge._ui.max_speed,config.base_max_speed*factor*config.post_max.factor(&"max_speed",{&"max_speed":2})) and core.ship_snapshot().ship_vel==velocity,"解除で特性分だけを外し、現在の慣性速度を保つ")
	bridge.command("dev_post_speed",{"stacks":0})
	check(is_equal_approx(bridge._ui.max_speed,config.base_max_speed*factor),"最大段後の倍率も外すと永続強化までの速度へ戻る")
	check(bridge.restore(saved.value).ok,"取得段・永続値・最大段後の速度を保持して復帰する")
	bridge.collect_frame()
	check(is_equal_approx(bridge._ui.max_speed,expected),"復帰後も同じ実効最高速度を渡す")
	bridge.release_checkpoint(saved.value)
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.bridge = bridge
	hud.size = Vector2(640,480)
	add_child(hud)
	bridge.collect_frame()
	for _frame in range(3): await get_tree().process_frame
	check(is_equal_approx(hud._cpp_ui.max_speed,expected) and hud._speed_indicator_mode()==hud.SPEED_INDICATOR.NORMAL,"HUDの通常の速度判定も実効最高速度を使う")
	bridge.command("dev_ship_motion",{"position":Vector2.ZERO,"velocity":Vector2(expected*config.steer_cruise+2.0,0)})
	check(hud._speed_indicator_mode()==hud.SPEED_INDICATOR.FAST,"巡航より速い状態も同じ境界で速度計へ渡す")
	hud.free()
	bridge.dispose()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"最高速度の状態・利用側・HUDに実行エラーがない: %s" % [capture.messages()])
	return true

func check_cpp_t10_motion() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	var bridge = t07_bridge(config,{"mult":{"max_speed":1.2}})
	if bridge==null: return false
	bridge.command("dev_grant_equipment",{"kind":"trait","id":"T10","levels":config.trait_max_stacks})
	bridge.command("dev_post_speed",{"stacks":2})
	var expected: float = bridge._ui.max_speed
	bridge.command("dev_ship_motion",{"position":Vector2.ZERO,"velocity":Vector2.ZERO})
	bridge._core.step_ship(1.0,1.0,{"touch":true,"stick_active":true,"stick":Vector2.RIGHT*(config.stick_dead_zone+1.0)})
	var cruise := minf(config.steer_accel,expected*config.steer_cruise)
	var floor_speed := expected*config.cruise_floor
	var result := floor_speed+(cruise-floor_speed)*exp(-config.cruise_drag) if cruise>floor_speed else cruise
	var actual: float = bridge._core.ship_snapshot().ship_vel.length()
	check(absf(actual-result)<0.0001,"操舵と減速は同じ実効最高速度を使う: expected=%.12f actual=%.12f max=%.12f" % [result,actual,expected])
	bridge.dispose()
	return true

func check_cpp_t11() -> bool:
	OS.add_logger(capture)
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	config.base_crit_chance = 0.0
	var definition: TraitDef = load("res://data/traits/T11_attack.tres")
	var weapon: WeaponDef = load("res://data/weapons/W01_forward.tres")
	var enemy: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
	enemy.hp = 1000000.0
	enemy.armor = 0.0
	var factor := 1.3
	var bridge = t07_bridge(config,{"mult":{"attack":factor,"max_speed":1.1}},enemy)
	if bridge==null: return false
	var core = bridge._core
	check(is_equal_approx(bridge._ui.attack_mult,factor),"未取得では永続強化の攻撃倍率を使う")
	for level in range(1,config.trait_max_stacks+1):
		check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T11","levels":1}).ok,"T11を共通の取得入口で重ねる")
		check(is_equal_approx(bridge._ui.attack_mult,factor*(1.0+definition.stack_bonus(level))),"生成した各段の増分を永続倍率へ一度だけ適用する")
	var trained: float = bridge._ui.attack_mult
	check(not bridge.command("dev_grant_equipment",{"kind":"trait","id":"T11","levels":1}).ok and bridge._ui.attack_mult==trained,"上限を越えて攻撃倍率を増やさない")
	var attack := config.base_attack*trained*config.atk_scale
	check(is_equal_approx(bridge._ui.attack_power,attack),"基礎攻撃力・特性・永続倍率から共通の攻撃力を求める")
	check(bridge.command("dev_post_weapon_power",{"damage":2,"followup":3}).ok,"最大段後の武器強化を別の加算へ渡す")
	check(bridge._ui.attack_mult==trained and is_equal_approx(bridge._ui.attack_power,attack),"武器限定の強化を体当たりの攻撃倍率へ混ぜない")
	var saved: Dictionary = bridge.checkpoint()
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	for _tick in range(240):
		bridge.step(1.0/120.0,idle,{"logical_size":Vector2(640,480)})
		if not core.projectiles_snapshot().is_empty(): break
	var shots: Array = core.projectiles_snapshot()
	check(shots.size()==1,"実際のW01更新から弾を1つ発射する")
	if shots.is_empty(): return false
	var post := 1.0+config.post_max.amount(&"weapon_damage",{&"weapon_damage":2})
	if config.post_max.target(weapon.id).has("followup"): post+=config.post_max.amount(&"followup",{&"followup":3})
	var expected := attack*float(weapon.params.damage_by_level[0])*post
	check(is_equal_approx(shots[0].damage,expected),"W01は共通攻撃力の後に武器の威力と最大段後の加算を一度だけ掛ける")
	var target: int = core.spawn_enemy(&"drifter",shots[0].pos+shots[0].vel.normalized()*80.0)
	core.rebuild_enemy_grid(200.0)
	var before: float = core.enemies_snapshot().filter(func(item): return item.id==target)[0].hp
	check(core.step_projectiles(0.1),"実際の味方弾を命中まで更新する")
	var after: float = core.enemies_snapshot().filter(func(item): return item.id==target)[0].hp
	check(is_equal_approx(before-after,expected),"弾の設定値が実際のHP減少へそのまま届く")
	bridge.command("dev_remove",{"entity_id":target})
	var contacts: Array = t09_contact_hits(bridge,config,1).filter(func(event): return event.type==&"hit" and event.payload.cause==&"ram")
	check(contacts.size()==1 and is_equal_approx(contacts[0].payload.dmg,attack),"体当たりはT11を含む共通攻撃力を使い、武器限定の加算を掛けない")
	bridge.command("dev_remove_trait",{"id":"T11"})
	check(is_equal_approx(bridge._ui.attack_mult,factor),"解除で特性分だけを外し、永続強化を保つ")
	bridge.command("dev_post_weapon_power",{"damage":0,"followup":0})
	check(bridge.restore(saved.value).ok,"取得段と共通攻撃力・武器強化を保持して復帰する")
	bridge.collect_frame()
	check(bridge._ui.attack_mult==trained and is_equal_approx(bridge._ui.attack_power,attack),"復帰後も同じ実効攻撃力を公開する")
	bridge.release_checkpoint(saved.value)
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.bridge = bridge
	hud.size = Vector2(640,480)
	add_child(hud)
	bridge.collect_frame()
	for _frame in range(3): await get_tree().process_frame
	check(hud._cpp_ui.attack_mult==trained and hud._cpp_ui.trait_levels.any(func(item): return item.id=="T11" and item.level==config.trait_max_stacks),"HUDへ実効攻撃倍率と所持段を同じ状態から渡す")
	hud.free()
	bridge.dispose()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"攻撃力の状態・利用側・HUDに実行エラーがない: %s" % [capture.messages()])
	return true

func check_cpp_t11_ram() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	config.base_crit_chance = 0.0
	var definition: TraitDef = load("res://data/traits/T11_attack.tres")
	var enemy: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
	enemy.hp = 1000000.0
	enemy.armor = 0.0
	var bridge = t07_bridge(config,{"mult":{"attack":1.3,"max_speed":1.1}},enemy)
	if bridge==null: return false
	bridge.command("dev_grant_equipment",{"kind":"trait","id":"T11","levels":config.trait_max_stacks})
	bridge.command("dev_post_weapon_power",{"damage":2,"followup":3})
	var attack := config.base_attack*1.3*(1.0+definition.stack_bonus(config.trait_max_stacks))*config.atk_scale
	var contacts: Array = t09_contact_hits(bridge,config,1).filter(func(event): return event.type==&"hit" and event.payload.cause==&"ram")
	check(contacts.size()==1 and is_equal_approx(contacts[0].payload.dmg,attack),"体当たりへ武器限定の倍率を混ぜない: expected=%s actual=%s" % [attack,contacts])
	bridge.dispose()
	return true

func check_cpp_t12() -> bool:
	OS.add_logger(capture)
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	var definition: TraitDef = load("res://data/traits/T12_pickup.tres")
	var factor := 1.1
	var bridge = t07_bridge(config,{"mult":{"pickup":factor}})
	if bridge==null: return false
	var core = bridge._core
	var base := config.pickup_radius*factor
	check(is_equal_approx(bridge._ui.pickup_radius,base) and bridge._ui.xp_pickup_radius==bridge._ui.pickup_radius,"未取得時は永続強化までの回収半径を使う")
	var position := Vector2(-3000,0)
	var trained := base*(1.0+definition.stack_bonus(config.trait_max_stacks))
	var placed: Dictionary = bridge.command("dev_drop_crystal",{"kind":0,"position":position+Vector2((base+trained)*0.5,0)})
	check(placed.ok,"通常と強化後の半径の間へ結晶を置く")
	core.step_pickups(0.001)
	check(not core.pickups_snapshot().gems[0].pulled,"取得前は半径の外の結晶を吸い寄せない")
	for level in range(1,config.trait_max_stacks+1):
		check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T12","levels":1}).ok,"T12を共通の取得入口で重ねる")
		check(is_equal_approx(bridge._ui.pickup_radius,base*(1.0+definition.stack_bonus(level))) and bridge._ui.xp_pickup_radius==bridge._ui.pickup_radius,"各段の増分を通常回収と結晶の半径へ一度適用する")
	check(not bridge.command("dev_grant_equipment",{"kind":"trait","id":"T12","levels":1}).ok and is_equal_approx(bridge._ui.pickup_radius,trained),"上限を越えて回収範囲を広げない")
	core.step_pickups(0.001)
	check(core.pickups_snapshot().gems[0].pulled,"取得後は同じ結晶を実際の共通回収で吸い寄せる")
	var retained: Dictionary = core.pickups_snapshot()
	var saved: Dictionary = bridge.checkpoint()
	var increment: float = config.post_max.increments.get("pickup_radius",0.0)
	var stacks: int = ceili(1.0/increment)
	bridge.command("dev_post_pickup",{"stacks":stacks})
	var xp_radius := trained*config.post_max.factor(&"pickup_radius",{&"pickup_radius":stacks})
	check(is_equal_approx(bridge._ui.pickup_radius,trained) and is_equal_approx(bridge._ui.xp_pickup_radius,xp_radius),"最大段後は結晶の半径だけを広げる")
	var far := position+Vector2((xp_radius+trained*1.6)*0.5,0)
	var extra: Dictionary = bridge.command("dev_drop_crystal",{"kind":0,"position":far})
	bridge.command("dev_spawn_pickup",{"kind":"coin","position":far})
	bridge.command("dev_spawn_pickup",{"kind":"magnet","position":far})
	core.step_pickups(0.001)
	var snapshot: Dictionary = core.pickups_snapshot()
	var gem: Dictionary = snapshot.gems.filter(func(item): return item.id==extra.value)[0]
	check(gem.pulled and not snapshot.coins[0].pulled and snapshot.capsules[0].pos==far,"結晶だけの追加範囲ではコイン・カプセルを吸い寄せない")
	bridge.command("dev_remove_trait",{"id":"T12"})
	check(is_equal_approx(bridge._ui.pickup_radius,base) and is_equal_approx(bridge._ui.xp_pickup_radius,base*config.post_max.factor(&"pickup_radius",{&"pickup_radius":stacks})),"解除で特性分だけを外し、永続倍率と結晶の追加範囲を保つ")
	bridge.command("dev_post_pickup",{"stacks":0})
	check(is_equal_approx(bridge._ui.xp_pickup_radius,base),"最大段後の追加も外すと元の結晶半径へ戻る")
	check(bridge.restore(saved.value).ok,"取得段と半径・吸引中の結晶を保持して復帰する")
	bridge.collect_frame()
	check(core.pickups_snapshot()==retained and is_equal_approx(bridge._ui.pickup_radius,trained) and bridge._ui.xp_pickup_radius==bridge._ui.pickup_radius,"復帰後も同じ回収範囲と吸引状態へ戻る")
	bridge.release_checkpoint(saved.value)
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.bridge = bridge
	hud.size = Vector2(640,480)
	add_child(hud)
	bridge.collect_frame()
	for _frame in range(3): await get_tree().process_frame
	check(is_equal_approx(hud._cpp_ui.pickup_radius,trained) and hud._cpp_ui.trait_levels.any(func(item): return item.id=="T12" and item.level==config.trait_max_stacks),"HUDへ回収範囲と所持段を同じ状態から渡す")
	hud.free()
	bridge.dispose()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"広域回収の状態・利用側・HUDに実行エラーがない: %s" % [capture.messages()])
	return true

func check_cpp_t14() -> bool:
	OS.add_logger(capture)
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	var definition: TraitDef = load("res://data/traits/T14_length.tres")
	var factor := 1.1
	var speed_factor := 1.2
	var bridge = t07_bridge(config,{"mult":{"length":factor,"max_speed":speed_factor}})
	if bridge==null: return false
	var core = bridge._core
	check(is_equal_approx(bridge._ui.length_mult,factor),"未取得時は永続強化の描線倍率を使う")
	for level in range(1,config.trait_max_stacks+1):
		check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T14","levels":1}).ok,"T14を共通の取得入口で重ねる")
		check(is_equal_approx(bridge._ui.length_mult,factor*(1.0+definition.stack_bonus(level))),"tresの各段を永続強化へ一度掛ける")
	var trained: float = bridge._ui.length_mult
	check(not bridge.command("dev_grant_equipment",{"kind":"trait","id":"T14","levels":1}).ok and bridge._ui.length_mult==trained,"上限を越えて描線倍率を増やさない")
	bridge.command("dev_post_length",{"stacks":3})
	var expected := trained*config.post_max.factor(&"line_length",{&"line_length":3})
	check(is_equal_approx(bridge._ui.length_mult,expected),"最大段後の延長は通常の育成後へ掛ける")
	var start := Vector2(-3000,0)
	check(core.handle_draw({"press":true,"touch":true,"has_cursor":true,"pen":start},0,1.0),"実際の描線入力を開始する")
	var limit := config.draw_length*expected*speed_factor
	check(is_equal_approx(core.draw_snapshot().draw_limit,limit),"速度の倍率・充填量・延長倍率を含む距離上限を開始時に決める")
	check(core.handle_draw({"touch":true,"has_cursor":true,"pen":start+Vector2(limit*0.25,0)},10,1.0),"延長された距離の途中まで描く")
	var partial: Dictionary = core.draw_snapshot()
	check(partial.drawing and is_equal_approx(partial.draw_length,limit*0.25),"途中の長さを同じ距離単位で保持する")
	bridge.command("set_ui_overlay",{"active":false})
	var saved: Dictionary = bridge.checkpoint()
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.bridge = bridge
	hud.size = Vector2(640,480)
	add_child(hud)
	bridge.collect_frame()
	for _frame in range(3): await get_tree().process_frame
	check(is_equal_approx(hud._cpp_ui.length_mult,expected) and is_equal_approx(hud._cpp_ui.draw.draw_limit,limit) and is_equal_approx(hud._cpp_ui.draw.draw_length/limit,0.25),"HUDへ同じ延長倍率と描き途中のゲージ消費率を渡す")
	check(core.handle_draw({"touch":true,"has_cursor":true,"pen":start+Vector2(limit*2.0,0)},20,1.0),"上限を越える入力も実際の描線へ通す")
	var committed: Dictionary = core.draw_snapshot()
	check(committed.tracing and not committed.drawing and is_equal_approx(committed.trace_total,limit) and committed.gauge<0.00001,"上限で線を止めて発進し、上限相当のゲージを消費する")
	bridge.command("dev_remove_trait",{"id":"T14"})
	check(is_equal_approx(bridge._ui.length_mult,factor*config.post_max.factor(&"line_length",{&"line_length":3})) and core.draw_snapshot().trace_total==committed.trace_total,"解除で特性分だけを外し、開始済みの線を縮めない")
	bridge.command("dev_post_length",{"stacks":0})
	check(is_equal_approx(bridge._ui.length_mult,factor),"最大段後の延長も外すと永続強化までの倍率へ戻る")
	check(bridge.restore(saved.value).ok,"所持段・倍率・描き途中の点列と距離上限を保持して復帰する")
	bridge.collect_frame()
	check(core.draw_snapshot()==partial and is_equal_approx(bridge._ui.length_mult,expected),"復帰後も同じ点列と実効距離へ戻る")
	bridge.release_checkpoint(saved.value)
	core.handle_draw({"touch":true,"pen_release":true},30,1.0)
	check(core.draw_snapshot().tracing and is_equal_approx(core.draw_snapshot().gauge,0.75),"復帰した途中の線を発進すると実際に描いた分だけ消費する")
	hud.free()
	bridge.dispose()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"軌跡延長の状態・利用側・HUDに実行エラーがない: %s" % [capture.messages()])
	return true

func check_cpp_t31() -> bool:
	OS.add_logger(capture)
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	config.world_tick_div = 1
	var definition: TraitDef = load("res://data/traits/T31_glideDuration.tres")
	var bridge = t07_bridge(config,{"mult":{"length":2.0}})
	if bridge==null: return false
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(640,480)}
	bridge.step(1.0/120.0,idle,viewport)
	check(bridge._ui.glide_duration_mult==1.0,"取得前は勢いの時間倍率1を使う")
	for level in range(1,config.trait_max_stacks+1):
		check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T31","levels":1}).ok,"T31を共通の取得入口で重ねる")
		check(is_equal_approx(bridge._ui.glide_duration_mult,1.0+definition.stack_bonus(level)),"tresの各段を勢いの時間倍率へ一度適用する")
	var multiplier: float = bridge._ui.glide_duration_mult
	check(not bridge.command("dev_grant_equipment",{"kind":"trait","id":"T31","levels":1}).ok and bridge._ui.glide_duration_mult==multiplier,"上限を越えて勢いの時間を延ばさない")
	var start: Vector2 = core.ship_snapshot().ship_pos
	core.handle_draw({"press":true,"touch":true,"has_cursor":true,"pen":start},0,1.0)
	core.handle_draw({"touch":true,"has_cursor":true,"pen_release":true,"pen":start+Vector2(config.draw_length*0.5,0)},100,1.0)
	var target: int = core.spawn_enemy(&"drifter",start+Vector2(200,100),{"facing":0.0})
	bridge.step(1.0/120.0,idle,viewport)
	var locked: float = core.enemies_snapshot().filter(func(item): return item.id==target)[0].facing
	check(is_equal_approx(locked,0.0),"なぞり中は自律操舵を止める")
	core.step_draw(10.0)
	check(core.ship_snapshot().glide and is_equal_approx(core.draw_snapshot().trace_total,config.draw_length*0.5),"実際の短いなぞりを完走して勢いへ入る")
	var tracking_saved: Dictionary = bridge.checkpoint()
	bridge.step(1.0/120.0,idle,viewport)
	var unlocked: float = core.enemies_snapshot().filter(func(item): return item.id==target)[0].facing
	check(absf(unlocked-locked)>0.001 and core.ship_snapshot().glide,"勢いの間はTrackingPolicyの抑制を続けない")
	bridge.restore(tracking_saved.value)
	bridge.collect_frame()
	bridge.release_checkpoint(tracking_saved.value)
	bridge.command("dev_remove",{"entity_id":target})
	var beginning: Dictionary = bridge.checkpoint()
	var initial: Dictionary = core.ship_snapshot()
	var hold := config.glide_hold*0.5*multiplier
	var fade := config.glide_fade*0.5*multiplier
	var first_dt := hold*0.5
	check(core.step_ship(first_dt,first_dt,{"touch":true,"stick_active":true,"stick":Vector2.UP*(config.stick_dead_zone+1.0)}),"勢いの保持中も機体を操舵する")
	var held: Dictionary = core.ship_snapshot()
	check(held.glide and is_equal_approx(held.ship_vel.length(),initial.glide_speed) and absf(held.ship_vel.angle()-initial.ship_vel.angle())>0.01,"保持速度を保ちながら向きを変えられる")
	var mid_time := hold+fade*0.5
	core.step_ship(mid_time-first_dt,mid_time-first_dt,{})
	var mid: Dictionary = core.ship_snapshot()
	var cruise := config.base_max_speed*config.steer_cruise
	check(mid.glide and is_equal_approx(mid.glide_t,mid_time) and is_equal_approx(mid.ship_vel.length(),lerpf(initial.glide_speed,cruise,0.5)),"実走距離比と特性の倍率を使った時間で減速する")
	var saved: Dictionary = bridge.checkpoint()
	bridge.command("dev_remove_trait",{"id":"T31"})
	check(bridge._ui.glide_duration_mult==1.0 and core.ship_snapshot().glide_t==mid.glide_t,"解除で倍率だけを戻し、進行中の時間を巻き戻さない")
	check(bridge.restore(saved.value).ok,"所持段と減速中の進行・倍率を保持して復帰する")
	bridge.collect_frame()
	check(core.ship_snapshot()==mid and bridge._ui.glide_duration_mult==multiplier,"復帰後も同じ勢いの進行へ戻る")
	bridge.release_checkpoint(saved.value)
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.bridge = bridge
	hud.size = Vector2(640,480)
	add_child(hud)
	bridge.collect_frame()
	for _frame in range(3): await get_tree().process_frame
	check(hud._cpp_ui.glide_duration_mult==multiplier and hud._cpp_ui.glide,"HUDへ同じ倍率と勢いの状態を渡す")
	hud.free()
	core.step_ship(fade*0.5+0.01,fade*0.5+0.01,{})
	check(not core.ship_snapshot().glide and is_equal_approx(core.ship_snapshot().ship_vel.length(),cruise),"短いなぞりの保持と減速が終わると巡航へ戻る")
	bridge.restore(beginning.value)
	bridge.collect_frame()
	bridge.command("dev_remove_trait",{"id":"T31"})
	var ordinary_time := (config.glide_hold+config.glide_fade)*0.5+0.01
	core.step_ship(ordinary_time,ordinary_time,{})
	check(not core.ship_snapshot().glide,"未取得では同じ距離の勢いが元の時間で終わる")
	bridge.restore(beginning.value)
	bridge.collect_frame()
	bridge.release_checkpoint(beginning.value)
	# 延長した線でも距離比は1まで。倍の長さで時間まで倍にしない。
	core.step_draw(config.dash_charge_time*2.0)
	bridge.command("dev_ship_motion",{"position":Vector2(-3000,0),"velocity":Vector2.ZERO})
	start = core.ship_snapshot().ship_pos
	core.handle_draw({"press":true,"touch":true,"has_cursor":true,"pen":start},200,1.0)
	core.handle_draw({"touch":true,"has_cursor":true,"pen":start+Vector2(config.draw_length*4.0,0)},300,1.0)
	core.step_draw(10.0)
	check(core.ship_snapshot().glide and core.draw_snapshot().trace_total>config.draw_length,"基礎距離を越える延長した線を完走する")
	var maximum_time := (config.glide_hold+config.glide_fade)*multiplier+0.01
	core.step_ship(maximum_time,maximum_time,{})
	check(not core.ship_snapshot().glide,"長いなぞりでも距離比を1で止めた時間で終了する")
	bridge.dispose()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"慣性航行の状態・利用側・HUDに実行エラーがない: %s" % [capture.messages()])
	return true

func t34_sweep(bridge,config: GameConfig,offset: float) -> float:
	var core = bridge._core
	var start: Vector2 = core.ship_snapshot().ship_pos
	var target: int = core.spawn_enemy(&"drifter",start+Vector2(config.draw_length*0.25,offset))
	var before: float = core.enemies_snapshot().filter(func(item): return item.id==target)[0].hp
	core.rebuild_enemy_grid(200.0)
	core.handle_draw({"press":true,"touch":true,"has_cursor":true,"pen":start},0,1.0)
	core.handle_draw({"touch":true,"has_cursor":true,"pen_release":true,"pen":start+Vector2(config.draw_length*0.5,0)},100,1.0)
	core.step_draw(10.0)
	var after: float = core.enemies_snapshot().filter(func(item): return item.id==target)[0].hp
	bridge.command("dev_remove",{"entity_id":target})
	return before-after

func check_cpp_t34() -> bool:
	OS.add_logger(capture)
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	config.base_crit_chance = 0.0
	var definition: TraitDef = load("res://data/traits/T34_bigSwing.tres")
	var enemy: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
	enemy.hp = 1000000.0
	enemy.armor = 0.0
	var bridge = t07_bridge(config,{},enemy)
	if bridge==null: return false
	var core = bridge._core
	check(bridge._ui.area_multiplier==1.0 and is_equal_approx(bridge._ui.trace_radius,config.trace_radius),"未取得でもtresの基礎突進半径を使う")
	var probe: int = core.spawn_enemy(&"drifter",Vector2(-3000,1000))
	var radius: float = core.enemies_snapshot().filter(func(item): return item.id==probe)[0].radius
	bridge.command("dev_remove",{"entity_id":probe})
	var initial: Dictionary = bridge.checkpoint()
	var trained := 1.0+definition.stack_bonus(config.trait_max_stacks)
	var offset := radius+config.trace_radius*(1.0+trained)*0.5
	check(t34_sweep(bridge,config,offset)==0.0,"取得前は通常の突進半径の外の相手に当たらない")
	bridge.restore(initial.value)
	bridge.collect_frame()
	bridge.release_checkpoint(initial.value)
	for level in range(1,config.trait_max_stacks+1):
		check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T34","levels":1}).ok,"T34を共通の取得入口で重ねる")
		var area := 1.0+definition.stack_bonus(level)
		check(is_equal_approx(bridge._ui.area_multiplier,area) and is_equal_approx(bridge._ui.trace_radius,config.trace_radius*area),"各段を共通範囲と突進半径へ一度だけ適用する")
	check(not bridge.command("dev_grant_equipment",{"kind":"trait","id":"T34","levels":1}).ok and is_equal_approx(bridge._ui.area_multiplier,trained),"上限を越えて範囲を増やさない")
	bridge.command("dev_post_weapon_power",{"damage":2,"followup":3})
	check(is_equal_approx(bridge._ui.area_multiplier,trained) and is_equal_approx(bridge._ui.trace_radius,config.trace_radius*trained),"別の最大段後の再計算でT34を二重に掛けない")
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	for _tick in range(240):
		bridge.step(1.0/120.0,idle,{"logical_size":Vector2(640,480)})
		if not core.projectiles_snapshot().is_empty(): break
	var shots: Array = core.projectiles_snapshot()
	check(shots.size()==1 and is_equal_approx(shots[0].radius,5.0*trained),"実際のW01の弾の半径へ同じ共通範囲が効く")
	var saved: Dictionary = bridge.checkpoint()
	var damage := t34_sweep(bridge,config,offset)
	check(is_equal_approx(damage,config.base_attack*config.atk_scale),"取得後は同じ外側の相手へ実際の突進が届く")
	bridge.command("dev_remove_trait",{"id":"T34"})
	check(bridge._ui.area_multiplier==1.0 and is_equal_approx(bridge._ui.trace_radius,config.trace_radius),"解除で共通範囲と突進半径を基礎値へ戻す")
	check(is_equal_approx(core.projectiles_snapshot()[0].radius,5.0*trained),"解除しても発射済みの弾の半径を変えない")
	check(bridge.restore(saved.value).ok,"取得段と実効半径・発射済みの弾を保持して復帰する")
	bridge.collect_frame()
	check(is_equal_approx(bridge._ui.area_multiplier,trained) and is_equal_approx(bridge._ui.trace_radius,config.trace_radius*trained) and core.projectiles_snapshot()==shots,"復帰後も同じ範囲と弾の半径へ戻る")
	bridge.release_checkpoint(saved.value)
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.bridge = bridge
	hud.size = Vector2(640,480)
	add_child(hud)
	bridge.collect_frame()
	for _frame in range(3): await get_tree().process_frame
	check(is_equal_approx(hud._cpp_ui.area_multiplier,trained) and hud._cpp_ui.trait_levels.any(func(item): return item.id=="T34" and item.level==config.trait_max_stacks),"HUDへ共通範囲と所持段を同じ状態から渡す")
	hud.free()
	bridge.dispose()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"大振りの状態・利用側・HUDに実行エラーがない: %s" % [capture.messages()])
	return true

func t35_volley(bridge) -> Dictionary:
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	for tick in range(240):
		var before: String = core.inspect().rng_state
		bridge.step(1.0/120.0,idle,{"logical_size":Vector2(640,480)})
		var fresh: Array = core.projectiles_snapshot().filter(func(shot): return shot.age<0.009)
		if not fresh.is_empty(): return {"count":fresh.size(),"ticks":tick+1,"rng_before":before,"rng":core.inspect().rng_state}
	check(false,"実際のW01更新で次の発射へ進む")
	return {"count":0,"ticks":240,"rng_before":"","rng":core.inspect().rng_state}

func check_cpp_t35() -> bool:
	OS.add_logger(capture)
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	var definition: TraitDef = load("res://data/traits/T35_multiShot.tres")
	var bridge = t07_bridge(config,{})
	if bridge==null: return false
	var core = bridge._core
	check(bridge._ui.shot_multiplier==1.0,"取得前は弾数倍率1を使う")
	var initial: Dictionary = bridge.checkpoint()
	var ordinary: Dictionary = t35_volley(bridge)
	check(ordinary.count==1 and ordinary.rng_before!=ordinary.rng,"未取得の整数1発でも抽選を消費して実際に発射する")
	bridge.restore(initial.value)
	bridge.collect_frame()
	for level in range(1,config.trait_max_stacks+1):
		check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T35","levels":1}).ok,"T35を共通の取得入口で重ねる")
		check(is_equal_approx(bridge._ui.shot_multiplier,1.0+definition.stack_bonus(level)),"各段のtresの増分を弾数倍率へ一度適用する")
	var trained: float = bridge._ui.shot_multiplier
	check(not bridge.command("dev_grant_equipment",{"kind":"trait","id":"T35","levels":1}).ok and bridge._ui.shot_multiplier==trained,"上限を越えて弾数を増やさない")
	bridge.command("dev_post_weapon_power",{"damage":2,"followup":3})
	check(bridge._ui.shot_multiplier==trained,"最大段後の再計算で弾数を二重に掛けない")
	var integers: Array = []
	for volley in range(16):
		var fired: Dictionary = t35_volley(bridge)
		integers.append(fired)
		check(fired.count==int(trained) and fired.rng_before!=fired.rng,"整数の追加弾も抽選を1回使って発射する")
	check(integers[0].rng==ordinary.rng and integers[0].ticks==ordinary.ticks,"1発と整数の増加後で発射時刻と乱数の進み方を変えない")
	bridge.restore(initial.value)
	bridge.collect_frame()
	bridge.release_checkpoint(initial.value)
	var fractional_level := 2
	bridge.command("dev_grant_equipment",{"kind":"trait","id":"T35","levels":fractional_level})
	var amount := 1.0+definition.stack_bonus(fractional_level)
	var low := floori(amount)
	var counts: Array[int] = []
	for volley in range(16):
		var fired: Dictionary = t35_volley(bridge)
		counts.append(fired.count)
		check(fired.count in [low,low+1] and fired.rng==integers[volley].rng and fired.ticks==integers[volley].ticks,"端数は追加1発を抽選し、整数時と同じ乱数消費と周期を保つ")
	check(counts.has(low) and counts.has(low+1),"固定seedの実発射で端数の追加あり・なしを確認する")
	var shots: Array = core.projectiles_snapshot()
	var random: String = core.inspect().rng_state
	var saved: Dictionary = bridge.checkpoint()
	bridge.command("dev_remove_trait",{"id":"T35"})
	check(bridge._ui.shot_multiplier==1.0 and core.projectiles_snapshot()==shots,"解除は今後の弾数だけを戻し、発射済みの弾を消さない")
	check(t35_volley(bridge).count==1,"解除後の次の発射は元の1発へ戻る")
	check(bridge.restore(saved.value).ok,"取得段と弾数倍率・発射済みの弾・乱数を保持して復帰する")
	bridge.collect_frame()
	check(is_equal_approx(bridge._ui.shot_multiplier,amount) and core.projectiles_snapshot()==shots and core.inspect().rng_state==random,"復帰後も同じ弾数倍率と抽選位置へ戻る")
	bridge.release_checkpoint(saved.value)
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.bridge = bridge
	hud.size = Vector2(640,480)
	add_child(hud)
	bridge.collect_frame()
	for _frame in range(3): await get_tree().process_frame
	check(is_equal_approx(hud._cpp_ui.shot_multiplier,amount) and hud._cpp_ui.trait_levels.any(func(item): return item.id=="T35" and item.level==fractional_level),"HUDへ端数を含む弾数倍率と所持段を同じ状態から渡す")
	hud.free()
	bridge.dispose()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"マルチショットの状態・利用側・HUDに実行エラーがない: %s" % [capture.messages()])
	return true

func shot_timing(core, id: StringName) -> Dictionary:
	return core.rear_snapshot() if id==&"W23" else (core.scatter_snapshot() if id==&"W02" else core.forward_snapshot())

func check_cpp_w02() -> void:
	await check_cpp_w01(&"W02")

func check_cpp_w02_detail(session: RunSession,idle: Dictionary,viewport: Dictionary) -> void:
	var retry := "--cpp-w02-retry" in OS.get_cmdline_user_args()
	var bridge = session.bridge
	var core = bridge._core
	var definition: WeaponDef = ContentManager.definition(&"weapons",&"W02")
	bridge.command("dev_remove_trait",{"id":"T35"})
	bridge.command("dev_remove_trait",{"id":"T36"})
	check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T35","levels":2}).ok,"端数を含む散弾数の特性を取得する")
	var saved: Dictionary = bridge.checkpoint()
	var volleys: Array = []
	bridge.subscribe("w02_detail",func(frame: Dictionary):
		for event: Dictionary in frame.events:
			if event.type==&"weapon_fire" and event.payload.id==&"W02": volleys.append(event.payload)
		return true)
	for tick in 165:
		var count := volleys.size()
		bridge.step(1.0/120.0,idle,viewport)
		if volleys.size()==count: continue
		var fresh: Array = core.projectiles_snapshot().filter(func(shot): return shot.age<0.009)
		if not retry: check(fresh.size() in [12,13],"9発の1.4倍を12発か13発へ抽選する")
		var offsets: Array = fresh.map(func(shot): return angle_difference(float(volleys[-1].angle),shot.vel.angle()))
		offsets.sort()
		for i in offsets.size():
			check(absf(offsets[i]-(i-(offsets.size()-1)/2.0)*float(definition.params.spread_step))<0.0001,"端数の抽選後も左右対称の扇へ広げる")
	check(not volleys.is_empty(),"散弾の端数抽選で実際に発射する")
	if retry:
		bridge.release_checkpoint(saved.value)
		bridge.unsubscribe("w02_detail")
		return
	var expected: Array = core.projectiles_snapshot()
	var timing: Dictionary = core.scatter_snapshot()
	var random: String = core.inspect().rng_state
	check(bridge.restore(saved.value).ok,"散弾の発射途中へ戻る")
	bridge.collect_frame()
	for tick in 165: bridge.step(1.0/120.0,idle,viewport)
	check(expected==core.projectiles_snapshot() and timing==core.scatter_snapshot() and random==core.inspect().rng_state,"復帰後の散弾の弾数・位置・反動・乱数を再現する")
	bridge.release_checkpoint(saved.value)
	bridge.command("dev_post_weapon_power",{"damage":2,"followup":3})
	check(bridge.command("dev_post_scatter",{"interval":2,"projectile":3,"duration":4,"knockback":5}).ok,"散弾の対象に指定された最大段後の値を適用する")
	var post_count := volleys.size()
	for tick in 90:
		bridge.step(1.0/120.0,idle,viewport)
		if volleys.size()>post_count: break
	var first_post_time: float = core.inspect().world_time
	post_count = volleys.size()
	for tick in 90:
		bridge.step(1.0/120.0,idle,viewport)
		if volleys.size()>post_count: break
	var reduced: float = ContentManager.base.post_max.reduced(float(definition.params.interval_by_level[-1]),&"weapon_interval",{&"weapon_interval":2},ContentManager.base.post_max.minimum_interval)
	check(volleys.size()>post_count and absf(core.inspect().world_time-first_post_time-reduced)<=1.0/120.0,"最大段後の発射間隔を基準値から短縮する")
	var shots: Array = core.projectiles_snapshot().filter(func(shot): return shot.age<0.009)
	check(not shots.is_empty(),"最大段後の散弾を新しく発射する")
	if not shots.is_empty():
		var post: PostMaxConfig = ContentManager.base.post_max
		var shot: Dictionary = shots[0]
		check(is_equal_approx(shot.vel.length(),1300.0*post.factor(&"projectile_speed",{&"projectile_speed":3})) and is_equal_approx(shot.life+1.0/120.0,float(definition.params.life)*post.factor(&"duration",{&"duration":4})),"最大段後の弾速と寿命を発射時に適用する")
		check(is_equal_approx(shot.knock,float(definition.params.knock)*post.factor(&"knockback",{&"knockback":5})),"最大段後の押し出しを適用する")
		check(is_equal_approx(shot.damage,ContentManager.base.base_attack*float(definition.params.damage_by_level[-1])*(1.0+post.amount(&"weapon_damage",{&"weapon_damage":2})+post.amount(&"followup",{&"followup":3}))),"最大段後の威力と追撃を共通倍率から適用する")
		var created: Dictionary = bridge.command("dev_spawn",{"definition_id":"drifter","position":shot.pos+shot.vel*0.04})
		check(created.ok,"散弾の命中対象を発射先へ置く")
		var before: float = core.enemies_snapshot().filter(func(enemy): return enemy.id==created.value)[0].hp
		core.step_projectiles(0.05)
		var enemies: Array = core.enemies_snapshot().filter(func(enemy): return enemy.id==created.value)
		check(enemies.is_empty() or enemies[0].hp<before,"散弾が通常の命中処理でダメージを与える")
	bridge.command("set_ui_overlay",{"active":false})
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	presentation._present_cpp(0.01)
	check(not presentation.frame_view._scatter_flashes.hits.is_empty(),"散弾の命中を十字・輪・火花の表示へ渡す")
	var frame: Dictionary = bridge.read_frame().value
	var muzzle: float = presentation.frame_view._scatter_flashes.muzzle_time
	presentation.frame_view.update_effects(frame,0.1)
	check(muzzle==presentation.frame_view._scatter_flashes.muzzle_time,"停止中の世界時計では扇の閃光を進めない")
	var render: Dictionary = bridge.read_render(Rect2(-3000,-3000,6000,6000)).value
	var visible := false
	for batch: Dictionary in render.batches:
		if batch.visual_id==2 and batch.flags.has(1): visible = true
	check(visible,"散弾の細い光弾を通常の表示用の値へ渡す")
	bridge.unsubscribe("w02_detail")
	await get_tree().process_frame

func check_cpp_w23() -> void:
	OS.add_logger(capture)
	await check_cpp_w01(&"W23")
	OS.remove_logger(capture)
	check(capture.count()==0,"後方射撃の状態・命中・表示に実行エラーがない: %s" % [capture.messages()])

func check_cpp_w23_detail(session: RunSession,idle: Dictionary,viewport: Dictionary) -> void:
	var bridge = session.bridge
	var core = bridge._core
	var definition: WeaponDef = ContentManager.definition(&"weapons",&"W23")
	bridge.command("dev_remove_trait",{"id":"T35"})
	bridge.command("dev_remove_trait",{"id":"T36"})
	check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T35","levels":2}).ok,"端数を含む後方射撃数の特性を取得する")
	var saved: Dictionary = bridge.checkpoint()
	var volleys: Array = []
	bridge.subscribe("w23_detail",func(frame: Dictionary):
		for event: Dictionary in frame.events:
			if event.type==&"weapon_fire" and event.payload.id==&"W23": volleys.append(event.payload)
		return true)
	for tick in 165:
		var count := volleys.size()
		bridge.step(1.0/120.0,idle,viewport)
		if volleys.size()==count: continue
		var fresh: Array = core.projectiles_snapshot().filter(func(shot): return shot.age<0.009)
		check(fresh.size() in [1,2],"1発の1.4倍を1発か2発へ抽選する")
		var offsets: Array = fresh.map(func(shot): return angle_difference(float(volleys[-1].angle),shot.vel.angle()))
		offsets.sort()
		for i in offsets.size():
			check(absf(offsets[i]-(i-(offsets.size()-1)/2.0)*float(definition.params.spread_step))<0.0001,"端数の抽選後も左右対称の扇へ広げる")
	check(not volleys.is_empty(),"後方射撃の端数抽選で実際に発射する")
	var expected: Array = core.projectiles_snapshot()
	var timing: Dictionary = core.rear_snapshot()
	var random: String = core.inspect().rng_state
	check(bridge.restore(saved.value).ok,"後方射撃の発射途中へ戻る")
	bridge.collect_frame()
	for tick in 165: bridge.step(1.0/120.0,idle,viewport)
	check(expected==core.projectiles_snapshot() and timing==core.rear_snapshot() and random==core.inspect().rng_state,"復帰後の後方射撃の弾数・位置・反動・乱数を再現する")
	bridge.release_checkpoint(saved.value)
	bridge.command("dev_post_weapon_power",{"damage":2,"followup":3})
	check(bridge.command("dev_post_scatter",{"interval":2,"projectile":3,"duration":4,"knockback":5}).ok,"後方射撃の対象に指定された最大段後の値を適用する")
	var post_count := volleys.size()
	for tick in 90:
		bridge.step(1.0/120.0,idle,viewport)
		if volleys.size()>post_count: break
	var first_post_time: float = core.inspect().world_time
	post_count = volleys.size()
	for tick in 90:
		bridge.step(1.0/120.0,idle,viewport)
		if volleys.size()>post_count: break
	var reduced: float = ContentManager.base.post_max.reduced(float(definition.params.interval_by_level[-1]),&"weapon_interval",{&"weapon_interval":2},ContentManager.base.post_max.minimum_interval)
	check(volleys.size()>post_count and absf(core.inspect().world_time-first_post_time-reduced)<=1.0/120.0,"最大段後の発射間隔を基準値から短縮する")
	var shots: Array = core.projectiles_snapshot().filter(func(shot): return shot.age<0.009)
	check(not shots.is_empty(),"最大段後の後方射撃を新しく発射する")
	if not shots.is_empty():
		var post: PostMaxConfig = ContentManager.base.post_max
		var shot: Dictionary = shots[0]
		check(is_equal_approx(shot.vel.length(),1300.0*post.factor(&"projectile_speed",{&"projectile_speed":3})) and is_equal_approx(shot.life+1.0/120.0,float(definition.params.life)*post.factor(&"duration",{&"duration":4})),"最大段後の弾速と寿命を発射時に適用する")
		check(is_equal_approx(shot.knock,float(definition.params.knock)*post.factor(&"knockback",{&"knockback":5})),"最大段後の押し出しを適用する")
		check(is_equal_approx(shot.damage,ContentManager.base.base_attack*float(definition.params.damage_by_level[-1])*(1.0+post.amount(&"weapon_damage",{&"weapon_damage":2})+post.amount(&"followup",{&"followup":3}))),"最大段後の威力と追撃を共通倍率から適用する")
		var created: Dictionary = bridge.command("dev_spawn",{"definition_id":"drifter","position":shot.pos+shot.vel*0.04})
		check(created.ok,"後方射撃の命中対象を発射先へ置く")
		var before: float = core.enemies_snapshot().filter(func(enemy): return enemy.id==created.value)[0].hp
		core.step_projectiles(0.05)
		var enemies: Array = core.enemies_snapshot().filter(func(enemy): return enemy.id==created.value)
		check(enemies.is_empty() or enemies[0].hp<before,"後方射撃が通常の命中処理でダメージを与える")
	bridge.command("set_ui_overlay",{"active":false})
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	presentation._present_cpp(0.01)
	check(not presentation.frame_view._rear_flashes.hits.is_empty(),"後方射撃の命中を十字・輪・火花の表示へ渡す")
	var frame: Dictionary = bridge.read_frame().value
	var muzzle: float = presentation.frame_view._rear_flashes.muzzle_time
	presentation.frame_view.update_effects(frame,0.1)
	check(muzzle==presentation.frame_view._rear_flashes.muzzle_time,"停止中の世界時計では扇の閃光を進めない")
	var render: Dictionary = bridge.read_render(Rect2(-3000,-3000,6000,6000)).value
	var visible := false
	for batch: Dictionary in render.batches:
		if batch.visual_id==2 and batch.flags.has(0) and not batch.ids.is_empty(): visible = true
	check(visible,"後方射撃の太い光弾を通常の表示用の値へ渡す")
	check(presentation.frame_view._rear_canvas.visible and presentation.frame_view._rear_frame.rear.ready,"通常の表示で後方の砲台と反動を出す")
	check(presentation.frame_view._scope.resources.has("res://assets/pixel/airship_turret_base.png") and presentation.frame_view._scope.resources.has("res://assets/pixel/airship_turret.png"),"出撃時の資源準備で後方の砲台画像を保持する")
	var shells: int = presentation.frame_view._rear_shells.size()
	presentation.frame_view._rear_flashes.fire(float(frame.ui.rear.aim.angle()))
	presentation.frame_view._rear_shells.append({"pos":frame.ui.rear.mount,"vel":Vector2(30,0),"age":0.0})
	presentation.frame_view.update_effects(frame,0.1)
	check(presentation.frame_view._rear_shells.size()==shells+1 and presentation.frame_view._rear_shells[-1].age==0.0,"世界時計が止まる間は薬莢の寿命と位置も止める")
	bridge.unsubscribe("w23_detail")
	await get_tree().process_frame
