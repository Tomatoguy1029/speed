## 全装備を編集画面と同じ手順で本番描画へ接続し、実行時エラーを失敗として扱う。
extends Node
const SESSION := preload("res://gyms/enemy_lab/lab_session.gd")
const SCENARIO := preload("res://gyms/equipment_effect_scenario.gd")
const MemorySave := preload("res://tests/integration/thrill_acceptance.gd").MemorySave
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
	if "--cpp-w28-boss-visual" in OS.get_cmdline_user_args():
		await check_cpp_w28_boss_visual()
		print("[cpp_w28_boss_visual] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return
	if "--cpp-stats" in OS.get_cmdline_user_args() or "--cpp-stats-boundary" in OS.get_cmdline_user_args():
		var completed = await check_cpp_stats()
		check(completed==true,"全装備への特性接続を最後まで確認する")
		print("[cpp_stats] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return
	if "--cpp-overlap" in OS.get_cmdline_user_args() or "--cpp-overlap-retry" in OS.get_cmdline_user_args():
		var completed = await check_cpp_overlap()
		check(completed==true,"同時作用の指定確認を最後まで完了する")
		print("[cpp_overlap] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return
	if "--cpp-w28" in OS.get_cmdline_user_args() or "--cpp-w28-retry" in OS.get_cmdline_user_args():
		var completed = await check_cpp_w28()
		check(completed==true,"閃光斬の指定確認を最後まで完了する")
		print("[cpp_w28] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return
	if "--cpp-w27" in OS.get_cmdline_user_args() or "--cpp-w27-retry" in OS.get_cmdline_user_args():
		await check_cpp_w27()
		print("[cpp_w27] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return
	if "--cpp-w26" in OS.get_cmdline_user_args() or "--cpp-w26-post" in OS.get_cmdline_user_args():
		await check_cpp_w26()
		print("[cpp_w26] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return
	if "--cpp-weapon-world-clock" in OS.get_cmdline_user_args():
		await check_cpp_weapon_world_clock()
		print("[cpp_weapon_world_clock] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return
	if "--cpp-w25" in OS.get_cmdline_user_args() or "--cpp-w25-fixes" in OS.get_cmdline_user_args():
		await check_cpp_w25()
		print("[cpp_w25] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return
	if "--cpp-w22" in OS.get_cmdline_user_args():
		await check_cpp_w22()
		print("[cpp_w22] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return
	if "--cpp-w21" in OS.get_cmdline_user_args():
		await check_cpp_w21()
		print("[cpp_w21] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return
	if "--cpp-t05" in OS.get_cmdline_user_args():
		await check_cpp_t05()
		print("[cpp_t05] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return
	if "--cpp-w04-clock" in OS.get_cmdline_user_args():
		await check_cpp_w04_clock()
		print("[cpp_w04_clock] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return
	if "--cpp-w17" in OS.get_cmdline_user_args() or "--cpp-w17-fixes" in OS.get_cmdline_user_args():
		await check_cpp_w17()
		print("[cpp_w17] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return
	if "--cpp-w08" in OS.get_cmdline_user_args() or "--cpp-w08-fixes" in OS.get_cmdline_user_args():
		await check_cpp_w08()
		print("[cpp_w08] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return
	if "--cpp-w04" in OS.get_cmdline_user_args() or "--cpp-w04-fixes" in OS.get_cmdline_user_args():
		await check_cpp_w04()
		print("[cpp_w04] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return
	if "--cpp-t06-source-clock" in OS.get_cmdline_user_args():
		var completed: bool = await check_cpp_t06_source_clock()
		check(completed,"槍本体と火花の元の時計を最後まで確認する")
		print("[cpp_t06_source_clock] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-w03" in OS.get_cmdline_user_args() or "--cpp-w03-fixes" in OS.get_cmdline_user_args():
		await check_cpp_w03()
		print("[cpp_w03] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-t06" in OS.get_cmdline_user_args() or "--cpp-t06-fixes" in OS.get_cmdline_user_args():
		await check_cpp_t06()
		print("[cpp_t06] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-t03" in OS.get_cmdline_user_args() or "--cpp-t03-fixes" in OS.get_cmdline_user_args():
		await check_cpp_t03()
		print("[cpp_t03] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-w07" in OS.get_cmdline_user_args() or "--cpp-w07-fixes" in OS.get_cmdline_user_args():
		await check_cpp_w07()
		print("[cpp_w07] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-t32" in OS.get_cmdline_user_args():
		await check_cpp_t32()
		print("[cpp_t32] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-w29" in OS.get_cmdline_user_args() or "--cpp-w29-tail" in OS.get_cmdline_user_args():
		await check_cpp_w29()
		print("[cpp_w29] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-t36" in OS.get_cmdline_user_args() or "--cpp-t36-fixes" in OS.get_cmdline_user_args() or "--cpp-t36-interval" in OS.get_cmdline_user_args():
		await check_cpp_t36()
		print("[cpp_t36] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-t33" in OS.get_cmdline_user_args() or "--cpp-t33-launch" in OS.get_cmdline_user_args():
		await check_cpp_t33()
		print("[cpp_t33] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-t04" in OS.get_cmdline_user_args():
		await check_cpp_t04()
		print("[cpp_t04] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

	if "--cpp-w05" in OS.get_cmdline_user_args() or "--cpp-w05-retry" in OS.get_cmdline_user_args():
		await check_cpp_w05()
		print("[cpp_w05] failed=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return

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
				check(presentation.frame_view.visible,"実験場で敵を表示する: "+key)
				if level==1:
					var before_spawn: int = session.run.enemies.table.alive.count(1)
					preview._add_preview_enemies()
					check(session.run.enemies.table.alive.count(1)==before_spawn+3,"敵を追加ボタンで3体を出す: "+key)
				var observed := false
				for frame in 600:
					session.step()
					if frame%4 == 0:
						presentation._present_cpp(4.0*session.DT)
						if key == "weapon/interceptor": observed = observed or session.bridge._ui.interceptor.drones.any(func(d):return d.flash>0.0)
						if key == "weapon/sonic": observed = observed or (presentation.frame_view._sonic_visual!=null and presentation.frame_view._sonic_visual.impacts.size()+presentation.frame_view._sonic_visual.pushes.size()>0)
						if key == "weapon/afterimage":
							var mirage: Dictionary = session.bridge._ui.afterimage
							observed = observed or not mirage.echoes.is_empty()
							for echo in mirage.echoes: check(echo.copies.size()==level,"ミラージュの本体はLvごとの1〜5機")
							var visual = presentation.frame_view._afterimage_visual
							if visual != null: check(visual._frame_node._body.multimesh.visible_instance_count<=level,"ミラージュの描画で本体を重複させない")
						if key == "trait/fullCharge": observed = observed or (presentation.frame_view._full_charge_visual!=null and presentation.frame_view._full_charge_visual.gear.fire.emitting)
						if key == "trait/rampage": observed = observed or (not session.run.state.tracing and session.bridge._ui.rampage.strength>0.9)
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
		var presentation = session.scene.view.get_node("RunPresentation")
		presentation.set_process(false)
		SCENARIO.play(session,combination.key)
		var mines_seen := {}
		for frame in 420:
			session.step()
			for mine: Dictionary in session.bridge._ui.mines.items: mines_seen[mine.id]=true
			if frame%4 == 0: presentation._present_cpp(4.0*session.DT)
			if gpu and frame%4 == 0: await RenderingServer.frame_post_draw
			elif frame%60 == 0: await get_tree().process_frame
		if combination.key in ["trait/vortex","trait/rampage"]:
			check(mines_seen.size()==24,"特性の試遊でも機雷は終点で1回だけ出す: "+combination.key)
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
	stage.resources.enemy_ids = PackedStringArray(["splitling"])
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
	var fired_events: Array = []
	bridge.subscribe("射撃の発動確認",func(frame):
		fired_events.append_array(frame.events)
		return true)
	var definition: WeaponDef = ContentManager.definition(&"weapons",weapon_id)
	for level in range(5 if retry else 1,definition.level_steps.size()+1):
		check(bridge.restore(initial.value).ok,"Lv別の確認の初期状態へ戻す")
		bridge.collect_frame()
		# 通常選択と同じ取得処理を通す。途中の解除で過去のタイマーを残さない。
		check(bridge.command("dev_remove_weapon",{"id":String(weapon_id)}).ok,"射撃を途中で解除する")
		check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":String(weapon_id),"levels":level}).ok,"型付きの定義から射撃を各Lvで取得する")
		for id in ["T34","T35","T36"]:
			var stacks := 5 if id=="T35" else 2
			check(bridge.command("dev_grant_equipment",{"kind":"trait","id":id,"levels":stacks}).ok,"同じ特性の生成値をC++の実効能力へ畳む")
		var fires := 0
		for tick in (170 if weapon_id==&"W02" else 110):
			if tick in [20,30]: bridge.command("pause",{"paused":tick==20})
			if tick in [50,56]: core.set_run_guards({"controls_locked":tick==50})
			fired_events.clear()
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
			if weapon_id==&"W23":
				var rear: Dictionary = bridge._ui.rear
				for event: Dictionary in fired_events:
					if event.type==&"weapon_fire":
						check(event.payload.pos.distance_to(rear.mount+rear.aim*12.5*config.character_scale)<0.001 and absf(angle_difference(event.payload.angle,rear.aim.angle()))<0.0001,"旋回後の砲口から機首と反対へ発射する")
			var fired := fired_events.any(func(event): return event.type==&"weapon_fire")
			check((random_before!=core.inspect().rng_state)==fired,"整数の弾数でも発射時に抽選し、停止中は抽選しない Lv%d tick%d" % [level,tick])
			for event: Dictionary in fired_events:
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
	var created: Dictionary = bridge.command("dev_spawn",{"definition_id":"splitling","position":shot.pos+shot.vel*0.04})
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
	var bytes: PackedByteArray = builder.compile_chase(enemy_definition if enemy_definition!=null else ContentManager.enemies[&"splitling"],config,schema.sha256("数値特性の固定場面".to_utf8_buffer()))
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
		var id: int = bridge._core.spawn_enemy(&"splitling",Vector2(-3000,0))
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
	var enemy: EnemyDef = ContentManager.enemies[&"splitling"].duplicate(true)
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
	var enemy: EnemyDef = ContentManager.enemies[&"splitling"].duplicate(true)
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
	var target: int = core.spawn_enemy(&"splitling",shots[0].pos+shots[0].vel.normalized()*80.0)
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
	var enemy: EnemyDef = ContentManager.enemies[&"splitling"].duplicate(true)
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
	var target: int = core.spawn_enemy(&"splitling",start+Vector2(200,100),{"facing":0.0})
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
	var target: int = core.spawn_enemy(&"splitling",start+Vector2(config.draw_length*0.25,offset))
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
	var enemy: EnemyDef = ContentManager.enemies[&"splitling"].duplicate(true)
	enemy.hp = 1000000.0
	enemy.armor = 0.0
	var bridge = t07_bridge(config,{},enemy)
	if bridge==null: return false
	var core = bridge._core
	check(bridge._ui.area_multiplier==1.0 and is_equal_approx(bridge._ui.trace_radius,config.trace_radius),"未取得でもtresの基礎突進半径を使う")
	var probe: int = core.spawn_enemy(&"splitling",Vector2(-3000,1000))
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
		var created: Dictionary = bridge.command("dev_spawn",{"definition_id":"splitling","position":shot.pos+shot.vel*0.04})
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
		var created: Dictionary = bridge.command("dev_spawn",{"definition_id":"splitling","position":shot.pos+shot.vel*0.04})
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

func barrier_defense(bridge, shield: float = 0.0, invulnerability: float = 0.0) -> void:
	check(bridge.command("dev_ship_defense",{"shield":shield,"invulnerability":invulnerability}).ok,"機体の防御条件を準備する")

func barrier_damage(bridge, amount: float, cause: String = "bullet") -> Dictionary:
	var result: Dictionary = bridge.command("dev_ship_damage",{"amount":amount,"cause":cause})
	check(result.ok,"機体への攻撃を共通の防御へ通す")
	return result.value if result.ok else {}

func check_cpp_w05() -> void:
	var retry := "--cpp-w05-retry" in OS.get_cmdline_user_args()
	OS.add_logger(capture)
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 900.0
	config.world_tick_div = 1
	config.planet_radius = 0.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	config.base_attack = 1.0
	config.base_crit_chance = 0.0
	var stage := RuntimeStage.new()
	stage.index = 85
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["splitling"])
	var output := "res://.content/dev/run_W05"
	var builder = load("res://tools/content/build_run_content.gd")
	check(builder.build(stage,config,output,"バリアの全Lvと共通防御".sha256_text())==OK,"バリアの全Lvと防御の固定値を生成する")
	var path := output.path_join("stage_85.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":635},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"バリアの通常の状態・表示を準備する")
	if session.bridge==null:
		session.free()
		OS.remove_logger(capture)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(640,480)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("dev_remove_weapon",{"id":"W01"})
	bridge.command("set_settings",{"hitstop":false})
	var initial: Dictionary = bridge.checkpoint()
	var definition: WeaponDef = ContentManager.definition(&"weapons",&"W05")
	var events: Array = []
	bridge.subscribe("w05_check",func(frame: Dictionary):
		events.append_array(frame.events)
		return true)
	for level in (range(1,definition.level_steps.size()+1) if not retry else []):
		bridge.restore(initial.value)
		bridge.collect_frame()
		check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W05","levels":level}).ok,"生成したバリアを各Lvで取得する")
		bridge.command("dev_grant_equipment",{"kind":"trait","id":"T34","levels":2})
		var hp: float = core.ship_snapshot().ship_hp
		var blocked: Dictionary = barrier_damage(bridge,5.0)
		check(blocked.reason=="barrier" and core.ship_snapshot().ship_hp==hp and is_equal_approx(core.barrier_snapshot().durability,float(definition.params.durability_by_level[level-1])-5.0),"全LvでHPを減らさず同じ耐久を消費する")
		var wave: Dictionary = core.barrier_snapshot().waves[0]
		check(is_equal_approx(wave.radius,float(definition.params.radius_by_level[level-1])*bridge._ui.area_multiplier) and is_equal_approx(wave.damage,float(definition.params.damage_by_level[level-1])*bridge._ui.attack_power),"全Lvの威力と範囲倍率を防御時の波へ保存する")
		barrier_defense(bridge)
		blocked = barrier_damage(bridge,1000.0)
		check(blocked.reason=="barrier" and core.ship_snapshot().ship_hp==hp and core.barrier_snapshot().durability<=0.0 and is_equal_approx(core.barrier_snapshot().restore,float(definition.params.revive_by_level[level-1])),"全Lvで耐久を超える一撃も全量防ぎ同じ復旧時間を使う")
		var broken: Dictionary = core.barrier_snapshot()
		bridge.command("pause",{"paused":true})
		for tick in 3: bridge.step(1.0/120.0,idle,viewport)
		check(core.barrier_snapshot()==broken,"停止中は復旧時間と波を進めない")
		bridge.command("pause",{"paused":false})
		core.set_run_guards({"controls_locked":true})
		for tick in 3: bridge.step(1.0/120.0,idle,viewport)
		check(core.barrier_snapshot()==broken,"操作ロック中は復旧時間と波を進めない")
		core.set_run_guards({"controls_locked":false})
		for tick in ceili(float(definition.params.revive_by_level[level-1])*120.0)+1:
			bridge.step(1.0/120.0,idle,viewport)
		check(core.barrier_snapshot().restore==0.0 and is_equal_approx(core.barrier_snapshot().durability,float(definition.params.durability_by_level[level-1])),"全Lvで世界時計に従って耐久を全回復する")
		check(core.barrier_snapshot().waves.is_empty(),"波は同じ寿命の式で終了する")
		if failures: break
	bridge.restore(initial.value)
	bridge.collect_frame()
	bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W05","levels":5})
	var pristine: Dictionary = bridge.checkpoint()
	if not retry:
		for condition in [[1.0,1.0,"shield"],[0.0,1.0,"invulnerability"]]:
			barrier_defense(bridge,condition[0],condition[1])
			var guarded: Dictionary = barrier_damage(bridge,7.0)
			check(guarded.reason==condition[2] and core.barrier_snapshot().durability==-1.0 and core.barrier_snapshot().waves.is_empty(),"盾と無敵を先に判定してバリアを消費しない")
		for guard in ["controls_locked","encounter_protected","invincible"]:
			barrier_defense(bridge)
			core.set_run_guards({guard:true})
			var guarded: Dictionary = barrier_damage(bridge,7.0)
			check(not guarded.accepted and core.barrier_snapshot().durability==-1.0,"保護中はバリアを消費しない: "+guard)
			core.set_run_guards({guard:false})
		for cause in ["debug","final_strike"]:
			barrier_defense(bridge)
			var bypass: Dictionary = barrier_damage(bridge,2.0,cause)
			check(bypass.accepted and bypass.hp_after==bypass.hp_before-2.0 and core.barrier_snapshot().durability==-1.0,"デバッグと時間切れの一撃はバリアの対象外にする")
	for kind in [0,1]:
		bridge.restore(pristine.value)
		bridge.collect_frame()
		events.clear()
		var pos: Vector2 = core.ship_snapshot().ship_pos
		var hp: float = core.ship_snapshot().ship_hp
		check(core.spawn_hostile({"kind":kind,"pos":pos+Vector2(100,0),"vel":Vector2(-1000,0),"speed":1000.0,"r":5.0,"life":1.0,"dmg":10.0,"slow":0.3,"turn":0.0})>=0,"通常弾とミサイルを実際に生成する")
		check(core.step_hostiles(0.2),"敵弾を殻へ向けて進める")
		bridge.step(1.0/120.0,idle,viewport)
		check(core.hostiles_snapshot().is_empty() and core.ship_snapshot().ship_hp==hp and core.barrier_snapshot().durability==25.0,"通常弾とミサイルを殻で受け止めて一度だけ回収する")
		check(events.filter(func(event): return event.type==&"attack_retired" and event.payload.reason=="barrier").size()==1 and events.filter(func(event): return event.type==&"combat_player_damage").size()==1 and not events.any(func(event): return event.type==&"hurt"),"遮断の終了理由を残し通常命中と二重に防御しない")
	bridge.restore(pristine.value)
	bridge.collect_frame()
	bridge.command("dev_grant_equipment",{"kind":"trait","id":"T34","levels":2})
	bridge.command("dev_post_weapon_power",{"damage":2,"followup":3})
	bridge.command("dev_post_scatter",{"interval":2,"projectile":0,"duration":0,"knockback":3})
	barrier_damage(bridge,1000.0)
	var post: PostMaxConfig = config.post_max
	check(is_equal_approx(core.barrier_snapshot().restore,post.reduced(float(definition.params.revive_by_level[-1]),&"weapon_interval",{&"weapon_interval":2},post.minimum_interval)),"最大段後の復旧時間を基準から短縮する")
	var wave: Dictionary = core.barrier_snapshot().waves[0]
	check(is_equal_approx(wave.damage,4.0*(1+post.amount(&"weapon_damage",{&"weapon_damage":2})+post.amount(&"followup",{&"followup":3}))),"バリアの波へ威力と追撃の共通倍率を適用する")
	var enemy: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":wave.pos+Vector2(60,0)}).value
	core.set_enemy_motion(enemy,{"held":true,"vel":Vector2.ZERO})
	var hp_before: float = core.enemies_snapshot().filter(func(item): return item.id==enemy)[0].hp
	for tick in 60: bridge.step(1.0/120.0,idle,viewport)
	var target: Dictionary = core.enemies_snapshot().filter(func(item): return item.id==enemy)[0]
	check(is_equal_approx(target.hp,hp_before-wave.damage) and target.vel[0]>0.0 and core.barrier_snapshot().waves[0].hits==[enemy],"段階的に広がる波が敵IDごとに一度だけ命中する")
	var saved: Dictionary = bridge.checkpoint()
	var held_wave: Dictionary = core.barrier_snapshot()
	var held_enemy: Dictionary = target
	for tick in 20: bridge.step(1.0/120.0,idle,viewport)
	var expected: Dictionary = core.barrier_snapshot()
	var expected_enemy: Array = core.enemies_snapshot()
	check(bridge.restore(saved.value).ok,"耐久と復旧時間・波・命中済みIDを保持して復帰する")
	bridge.collect_frame()
	check(core.barrier_snapshot()==held_wave,"復帰直後のバリアの値が一致する")
	for tick in 20: bridge.step(1.0/120.0,idle,viewport)
	check(core.barrier_snapshot()==expected and core.enemies_snapshot()==expected_enemy and core.enemies_snapshot().filter(func(item): return item.id==enemy)[0].hp==held_enemy.hp,"復帰後も波が同じ敵へ二重命中しない")
	bridge.release_checkpoint(saved.value)
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	presentation._present_cpp(0.01)
	check(presentation.frame_view._barrier_visual!=null and presentation.frame_view._barrier_armor.visible,"バリアの殻と波を通常の表示へ渡す")
	check(presentation.frame_view._barrier_visual._hexes.multimesh.visible_instance_count>0,"波動の六角形を共通表示で描く")
	var display_age: float = presentation.frame_view._barrier_visual.hits[0].age if not presentation.frame_view._barrier_visual.hits.is_empty() else -1.0
	presentation.frame_view.update_effects(bridge.read_frame().value,0.2)
	if display_age>=0.0: check(presentation.frame_view._barrier_visual.hits[0].age==display_age,"世界時計が止まる間はバリアの表示も止める")
	check(bridge.command("dev_remove_weapon",{"id":"W05"}).ok and not core.barrier_snapshot().equipped and core.barrier_snapshot().waves.is_empty(),"途中解除でバリアと波を終了する")
	presentation._present_cpp(0.01)
	check(presentation.frame_view._barrier_visual==null and not presentation.frame_view._barrier_armor.visible,"解除したバリアの表示を片付ける")
	bridge.release_checkpoint(pristine.value)
	bridge.release_checkpoint(initial.value)
	bridge.unsubscribe("w05_check")
	session.free()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"バリアの状態・防御・命中・表示に実行エラーがない: %s" % [capture.messages()])

func trait_test_session(id: String, config: GameConfig, seed_value: int):
	var stage := RuntimeStage.new()
	stage.index = 84
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["splitling","shield"] if id in ["T03","T06"] else ["splitling"])
	if id=="C_overlap":
		stage.resources.enemy_ids = PackedStringArray(["splitling","corona","biter"])
		stage.enemy_tuning = {"splitling":{"hp":1000.0,"armor":0.0,"speed":0.0},"corona":{"speed":0.0,"params.spin":0.0,"params.pull":0.0,"params.telegraph":100.0,"params.fire_interval":100.0},"biter":{"hp":1.0,"armor":0.0,"speed":0.0}}
	if id=="T_stats": stage.enemy_tuning = {"splitling":{"hp":100000.0,"armor":0.0,"speed":0.0}}
	if id=="W28": stage.enemy_tuning = {"splitling":{"hp":1000.0,"armor":0.0}}
	if id=="T06": stage.enemy_tuning = {"shield":{"hp":200.0}}
	var output := "res://.content/dev/run_"+id
	var builder = load("res://tools/content/build_run_content.gd")
	check(builder.build(stage,config,output,(id+"の状態と表示").sha256_text())==OK,"行動特性の段ごとの値と資源を生成する")
	var path := output.path_join("stage_84.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":seed_value},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"行動特性の通常の状態と表示を準備する")
	if session.bridge==null:
		session.free()
		return null
	return session

func trait_test_config() -> GameConfig:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 900.0
	config.world_tick_div = 1
	config.planet_radius = 0.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	config.base_crit_chance = 0.0
	return config

func trait_start_trace(bridge, length: float, direction: Vector2 = Vector2.RIGHT) -> Vector2:
	var pos: Vector2 = bridge._core.ship_snapshot().ship_pos
	var input: Dictionary = bridge.pack_intent(Intent.new())
	input.press = true
	input.touch = true
	input.pen = pos
	check(bridge._core.handle_draw(input,1000,1.0),"実際の描線入力で開始する")
	input.press = false
	input.has_cursor = true
	input.pen = pos+direction*length
	input.pen_release = true
	check(bridge._core.handle_draw(input,1010,1.0),"実際の描線を確定して発進する")
	# 個別の既存入口を通した状態も公開の更新番号へ反映する。
	bridge.command("set_ui_overlay",{"active":false})
	return pos

func trait_select_upgrade(session, id: String, config: GameConfig, idle: Dictionary, viewport: Dictionary) -> void:
	var bridge = session.bridge
	check(bridge.command("dev_add_xp",{"amount":bridge._ui.next_xp}).ok,"通常の特性選択に必要な経験値を得る")
	bridge.step(1.0/120.0,idle,viewport)
	var cards: Dictionary = bridge._ui.cards
	var selected := {}
	for attempt in config.reroll_count+1:
		cards = bridge._ui.cards
		print("[装備の通常候補] 装備=%s 引き直し=%d 候補=%s" % [id,attempt,cards.candidates.map(func(card): return card.id)])
		for card: Dictionary in cards.candidates:
			if card.id==id: selected = card
		if not selected.is_empty() or attempt==config.reroll_count: break
		if not bridge.command("reroll",{"offer_id":cards.offer_id}).ok: break
	check(not selected.is_empty(),"通常の候補に対象の装備を出す")
	if selected.is_empty(): return
	bridge.command("choose_card",{"offer_id":cards.offer_id,"candidate_id":selected.candidate_id})
	for tick in 120:
		session.cpp_choices.poll()
		bridge.step(1.0/120.0,idle,viewport)
		if bridge._ui.phase==0: break
		await get_tree().process_frame
	session.cpp_choices.poll()
	var kind := "weapon" if id.begins_with("W") else "trait"
	check(bridge._ui[kind+"_levels"].any(func(item): return item.id==id and item.level>=2) and session.cpp_choices.equipped.has(kind+":"+id),"カードの資源準備後に取得段を一度だけ確定する")

func check_cpp_t04() -> void:
	OS.add_logger(capture)
	var config := trait_test_config()
	var session = await trait_test_session("T04",config,634)
	if session==null:
		OS.remove_logger(capture)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(640,480)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("dev_remove_weapon",{"id":"W01"})
	bridge.command("set_settings",{"hitstop":false})
	var initial: Dictionary = bridge.checkpoint()
	var gear: TraitDef = ContentManager.definition(&"traits",&"T04")
	var gear_level := 1
	for level in range(1,config.trait_max_stacks+1):
		bridge.restore(initial.value)
		bridge.collect_frame()
		gear_level = level
		check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T04","levels":level}).ok,"ギアアップを共通の入口で各段まで取得する")
		bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W05","levels":1})
		check(is_equal_approx(bridge._ui.full_charge.maximum,expected_full_charge(config,gear.params,gear_level,config.draw_length)),"生成した各段の最大倍率が現行と一致する")
		trait_start_trace(bridge,config.draw_length)
		check(bridge._ui.full_charge.distance==0.0 and bridge._ui.full_charge.burst_power==1.0 and not bridge._ui.full_charge.ignore_armor,"発進時に距離・倍率・装甲無視を戻す")
		for tick in 65:
			bridge.step(1.0/120.0,idle,viewport)
			var ui: Dictionary = bridge._ui
			var expected: float = expected_full_charge(config,gear.params,gear_level,ui.full_charge.distance) if ui.draw.tracing else 1.0
			check(is_equal_approx(ui.full_charge.burst_power,expected) and is_equal_approx(ui.attack_power,config.base_attack*expected),"走った距離の指数曲線を全攻撃の攻撃力へ一度だけ掛ける")
			if tick==25 and ui.draw.tracing:
				barrier_damage(bridge,1.0)
				check(is_equal_approx(core.barrier_snapshot().waves[-1].damage,ui.attack_power*2.0),"なぞり中の別装備も同じ時点の攻撃倍率を読む")
		check(not bridge._ui.draw.tracing and bridge._ui.full_charge.burst_power==1.0,"なぞり終了で倍率を戻す")
		if failures: break
	bridge.restore(initial.value)
	bridge.collect_frame()
	bridge.command("dev_grant_equipment",{"kind":"trait","id":"T04","levels":5})
	gear_level = 5
	var origin: Vector2 = core.ship_snapshot().ship_pos
	for distance in [200.0,500.0,800.0]:
		var enemy: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":origin+Vector2(distance,0)}).value
		core.set_enemy_motion(enemy,{"held":true,"vel":Vector2.ZERO})
	var contacts: Array = []
	bridge.subscribe("t04_contacts",func(frame: Dictionary):
		for event: Dictionary in frame.events:
			if event.type==&"combat_damage" and event.payload.cause==&"ram": contacts.append(event.payload)
		return true)
	trait_start_trace(bridge,config.draw_length)
	for tick in 20: bridge.step(1.0/120.0,idle,viewport)
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	presentation._present_cpp(0.01)
	check(presentation.frame_view._full_charge_visual!=null and presentation.frame_view._full_charge_visual.gear.fire.emitting,"なぞり中の炎を通常の表示へ渡す")
	var before: Dictionary = bridge._ui.full_charge.duplicate()
	var clock: float = presentation.frame_view._full_charge_visual.gear.fire._clock
	bridge.command("pause",{"paused":true})
	for tick in 3: bridge.step(1.0/120.0,idle,viewport)
	presentation._present_cpp(0.2)
	check(bridge._ui.full_charge==before and presentation.frame_view._full_charge_visual.gear.fire._clock==clock,"停止中は距離・倍率・炎の時計を進めない")
	bridge.command("pause",{"paused":false})
	var saved: Dictionary = bridge.checkpoint()
	for tick in 10: bridge.step(1.0/120.0,idle,viewport)
	var expected_draw: Dictionary = core.draw_snapshot()
	var expected_power: Dictionary = bridge._ui.full_charge.duplicate()
	var expected_enemies: Array = core.enemies_snapshot()
	check(bridge.restore(saved.value).ok,"距離・倍率・なぞり途中の状態へ戻る")
	bridge.collect_frame()
	for tick in 10: bridge.step(1.0/120.0,idle,viewport)
	check(core.draw_snapshot()==expected_draw and bridge._ui.full_charge==expected_power and core.enemies_snapshot()==expected_enemies,"復帰後も距離・同期した倍率・命中結果を再現する")
	bridge.release_checkpoint(saved.value)
	for tick in 40: bridge.step(1.0/120.0,idle,viewport)
	check(bridge._ui.kills==3,"一つのなぞりで連続する敵を実際に撃破する")
	for hit: Dictionary in contacts:
		check(is_equal_approx(hit.requested,config.base_attack*expected_full_charge(config,gear.params,gear_level,origin.distance_to(hit.impact))),"命中位置までの距離を撃破より先に反映する")
	check(not contacts.is_empty(),"命中直前の距離係数を実際のダメージで確認する")
	bridge.unsubscribe("t04_contacts")
	bridge.restore(initial.value)
	bridge.collect_frame()
	bridge.command("dev_grant_equipment",{"kind":"trait","id":"T04","levels":5})
	origin = core.ship_snapshot().ship_pos
	var iron: int = bridge.command("dev_spawn",{"definition_id":"iron","position":origin+Vector2(250,0)}).value
	core.set_enemy_motion(iron,{"held":true,"vel":Vector2.ZERO})
	trait_start_trace(bridge,config.draw_length)
	for tick in 25: bridge.step(1.0/120.0,idle,viewport)
	check(not bridge._ui.draw.tracing and bridge._ui.full_charge.distance<config.draw_length and not bridge._ui.full_charge.ignore_armor and bridge._ui.full_charge.burst_power==1.0,"倍率が足りない装甲では弾かれ、装甲無視を有効にしない")
	check(bridge.command("dev_remove_trait",{"id":"T04"}).ok and bridge._ui.full_charge.maximum==1.0 and bridge._ui.full_charge.burst_power==1.0,"解除時に蓄積した倍率を終了する")
	presentation._present_cpp(0.01)
	check(presentation.frame_view._full_charge_visual==null,"解除した炎の表示を片付ける")
	bridge.restore(initial.value)
	bridge.collect_frame()
	bridge.command("dev_grant_equipment",{"kind":"trait","id":"T04","levels":1})
	await trait_select_upgrade(session,"T04",config,idle,viewport)
	bridge.release_checkpoint(initial.value)
	session.free()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"ギアアップの発動・同期・表示に実行エラーがない: %s" % [capture.messages()])

func trait_kill_fixture(bridge, cause: String = "shot") -> void:
	var pos: Vector2 = bridge._core.ship_snapshot().ship_pos+Vector2(0,3000)
	var created: Dictionary = bridge.command("dev_spawn",{"definition_id":"splitling","position":pos})
	check(created.ok,"撃破の対象を通常の生成入口から配置する")
	if created.ok:
		var killed: Dictionary = bridge.command("dev_kill",{"entity_id":created.value,"cause":cause})
		check(killed.ok and killed.value.killed,"撃破を共通の同期処理へ通す")

func check_cpp_t33() -> void:
	var retry_launch := "--cpp-t33-launch" in OS.get_cmdline_user_args()
	OS.add_logger(capture)
	var config := trait_test_config()
	config.xp_base = 100000.0
	var session = await trait_test_session("T33",config,633)
	if session==null:
		OS.remove_logger(capture)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(640,480)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("set_settings",{"hitstop":false})
	var initial: Dictionary = bridge.checkpoint()
	var rampage: TraitDef = ContentManager.definition(&"traits",&"T33")
	var gear: TraitDef = ContentManager.definition(&"traits",&"T04")
	for level in (range(1,config.trait_max_stacks+1) if not retry_launch else []):
		bridge.restore(initial.value)
		bridge.collect_frame()
		check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T33","levels":level}).ok,"快進撃を各段まで取得する")
		bridge.command("dev_grant_equipment",{"kind":"trait","id":"T04","levels":5})
		trait_kill_fixture(bridge)
		check(bridge._ui.rampage.kills==0 and bridge._ui.rampage.strength==0.0,"なぞりの外で倒しても撃破数を蓄積しない")
		trait_start_trace(bridge,config.draw_length)
		var expected_strength := 0.0
		var expected_pop := 0.0
		for killed in 13:
			trait_kill_fixture(bridge)
			expected_pop = 1.0
		check(bridge._ui.rampage.kills==13 and bridge._ui.rampage.strength==0.0 and bridge._ui.rampage.multiplier==1.0 and bridge._ui.rampage.pop==1.0,"なぞり中は撃破数と光だけを更新して攻撃倍率を1に保つ")
		var was_tracing := true
		for tick in 80:
			bridge.step(1.0/120.0,idle,viewport)
			var tracing: bool = bridge._ui.draw.tracing
			if was_tracing and not tracing: expected_strength = minf(1.0,13.0/float(rampage.params.kills))
			was_tracing = tracing
			var dt: float = (1.0/120.0)*bridge._ui.world_scale
			if not tracing: expected_strength *= pow(0.5,dt/float(rampage.params.half_life))
			expected_pop = maxf(0.0,expected_pop-dt*5.0)
			var expected_multiplier: float = 1.0+(float(rampage.params.bonus_base)+float(rampage.params.bonus_per)*level)*expected_strength
			var expected_gear: float = expected_full_charge(config,gear.params,5,bridge._ui.full_charge.distance) if tracing else 1.0
			check(is_equal_approx(bridge._ui.rampage.strength,expected_strength) and is_equal_approx(bridge._ui.rampage.pop,expected_pop) and is_equal_approx(bridge._ui.rampage.multiplier,expected_multiplier),"各段の終了時の上限・半減曲線・光の減衰が現行と一致する")
			check(is_equal_approx(bridge._ui.full_charge.burst_power,expected_gear) and is_equal_approx(bridge._ui.attack_power,config.base_attack*expected_gear*expected_multiplier),"ギアアップと快進撃が別々の係数を保って全攻撃力で合成される")
		check(not bridge._ui.draw.tracing and bridge._ui.rampage.strength>0.0,"終了後にだけ撃破数から攻撃倍率を有効にする")
		if failures: break
	if not retry_launch:
		var saved: Dictionary = bridge.checkpoint()
		var before: Dictionary = bridge._ui.rampage.duplicate()
		var presentation: RunPresentation = session.view.get_node("RunPresentation")
		presentation._present_cpp(0.01)
		check(presentation.frame_view._rampage_visual!=null and presentation.frame_view._rampage_visual._aura.visible and presentation.frame_view._rampage_visual._level>0.0,"終了後の強さを通常のオーラ表示へ渡す")
		var clock: float = presentation.frame_view._rampage_visual._aura.material.get_shader_parameter("clock")
		bridge.command("pause",{"paused":true})
		for tick in 4: bridge.step(1.0/120.0,idle,viewport)
		presentation._present_cpp(0.1)
		check(bridge._ui.rampage==before and presentation.frame_view._rampage_visual._aura.material.get_shader_parameter("clock")==clock,"停止中は強さ・光・オーラの時計を進めない")
		bridge.command("pause",{"paused":false})
		for tick in roundi(float(bridge._ui.rampage.half_life)*120.0): bridge.step(1.0/120.0,idle,viewport)
		check(is_equal_approx(bridge._ui.rampage.strength,before.strength*0.5),"半減期を世界時計で一度だけ掛ける")
		var expected: Dictionary = bridge._ui.rampage.duplicate()
		var expected_shots: Array = core.projectiles_snapshot()
		check(bridge.restore(saved.value).ok,"撃破数・強さ・光と同期倍率へ復帰する")
		bridge.collect_frame()
		for tick in roundi(float(bridge._ui.rampage.half_life)*120.0): bridge.step(1.0/120.0,idle,viewport)
		check(bridge._ui.rampage==expected and core.projectiles_snapshot()==expected_shots,"復帰後も弱まる速度と武器の発射・命中状態を再現する")
		bridge.release_checkpoint(saved.value)
		var fresh: Array = []
		for tick in 70:
			bridge.step(1.0/120.0,idle,viewport)
			fresh = core.projectiles_snapshot().filter(func(shot): return shot.age<0.009)
			if not fresh.is_empty(): break
		check(not fresh.is_empty(),"快進撃中に実際のW01を発射する")
		if not fresh.is_empty():
			var definition: WeaponDef = ContentManager.definition(&"weapons",&"W01")
			var prior: float = bridge._ui.rampage.strength/pow(0.5,(1.0/120.0)/bridge._ui.rampage.half_life)
			check(is_equal_approx(fresh[0].damage,config.base_attack*float(definition.params.damage_by_level[0])*(1.0+bridge._ui.rampage.bonus*prior)),"武器の発射後に同じ更新の強さを減らす現行の順を保つ")
		check(bridge.command("dev_remove_trait",{"id":"T33"}).ok and bridge._ui.rampage.multiplier==1.0,"解除で快進撃の倍率だけを戻す")
		presentation._present_cpp(0.01)
		check(presentation.frame_view._rampage_visual==null,"解除したオーラ表示を片付ける")
	bridge.restore(initial.value)
	bridge.collect_frame()
	bridge.command("dev_grant_equipment",{"kind":"trait","id":"T33","levels":5})
	bridge.command("dev_grant_equipment",{"kind":"trait","id":"T04","levels":5})
	var origin: Vector2 = core.ship_snapshot().ship_pos
	for distance in [200.0,500.0,800.0]:
		var enemy: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":origin+Vector2(distance,0)}).value
		core.set_enemy_motion(enemy,{"held":true,"vel":Vector2.ZERO})
	trait_start_trace(bridge,config.draw_length)
	trait_kill_fixture(bridge,"afterimage")
	if not retry_launch: check(bridge._ui.rampage.kills==0,"残像による撃破は共通の除外順に従って数えない")
	for tick in 70: bridge.step(1.0/120.0,idle,viewport)
	if not retry_launch: check(bridge._ui.rampage.kills==3 and bridge._ui.rampage.strength>0.0 and bridge._ui.rampage.strength<0.25,"実際の連続した体当たり撃破を終了後の強さへ反映する")
	for tick in ceili(config.dash_charge_time*config.draw_min_charge*120.0)+2: bridge.step(1.0/120.0,idle,viewport)
	trait_start_trace(bridge,config.draw_length*0.5)
	check(bridge._ui.rampage.kills==0 and bridge._ui.rampage.strength==0.0 and bridge._ui.rampage.multiplier==1.0,"次の発進で撃破数と強さを戻す")
	bridge.restore(initial.value)
	bridge.collect_frame()
	bridge.command("dev_grant_equipment",{"kind":"trait","id":"T33","levels":1})
	if not retry_launch: await trait_select_upgrade(session,"T33",config,idle,viewport)
	bridge.release_checkpoint(initial.value)
	session.free()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"快進撃の同期・倍率・表示に実行エラーがない: %s" % [capture.messages()])

func check_cpp_t36() -> void:
	var interval_only: bool = "--cpp-t36-interval" in OS.get_cmdline_user_args()
	var retry: bool = interval_only or "--cpp-t36-fixes" in OS.get_cmdline_user_args()
	var capture := ErrorCapture.new()
	OS.add_logger(capture)
	var config := trait_test_config()
	config.base_attack = 100.0
	config.xp_base = 100000.0
	# 通常候補は固定seed 637の2回目の引き直しでT36を含む。
	var seed_value := 637
	var session = await trait_test_session("T36",config,seed_value)
	if session==null:
		OS.remove_logger(capture)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(640,480)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("set_settings",{"hitstop":false})
	var initial: Dictionary = bridge.checkpoint()
	var events: Array = []
	bridge.subscribe("t36",func(frame: Dictionary):
		events.append_array(frame.events)
		return true)
	var definition: TraitDef = ContentManager.definition(&"traits",&"T36")
	for level in range(1,config.trait_max_stacks+1):
		bridge.restore(initial.value)
		bridge.collect_frame()
		check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T36","levels":level}).ok,"フルバーストを全段取得する")
		bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W02","levels":1})
		events.clear()
		bridge.step(1.0/120.0,idle,viewport)
		var rate: float = 1.0+definition.params.rate_base+definition.params.rate_per*level
		if not retry or level>1: check(is_equal_approx(bridge._ui.shooting_rate,rate) and bridge._ui.full_burst_active,"全段で満充填時の射撃倍率を生成値から適用する")
		if not retry or level>1: check(events.filter(func(event): return event.type==&"full_burst_ready").size()==1,"満充填への移行を一度通知する")
		var fired: Array = events.filter(func(event): return event.type==&"weapon_fire" and event.payload.id==&"W02")
		var ticks := 0
		var first_tick := -1
		while fired.size()<2 and ticks<240:
			bridge.step(1.0/120.0,idle,viewport)
			ticks += 1
			fired = events.filter(func(event): return event.type==&"weapon_fire" and event.payload.id==&"W02")
			if first_tick<0 and not fired.is_empty(): first_tick = ticks
		check(fired.size()>=2 and absf(float(ticks-first_tick)/120.0-0.9/rate)<=1.0/120.0,"実際の散弾の連射間隔へ全段の倍率を適用する")
		if not retry or level>1: check(events.filter(func(event): return event.type==&"full_burst_ready").size()==1,"満充填中に通知を繰り返さない")
		if failures: break
	if not retry:
		var presentation: RunPresentation = session.view.get_node("RunPresentation")
		presentation._present_cpp(0.01)
		check(presentation.frame_view._full_burst_visual!=null,"通常の表示へ満充填の光を接続する")
		var saved: Dictionary = bridge.checkpoint()
		bridge.restore(saved.value)
		bridge.collect_frame()
		events.clear()
		bridge.step(1.0/120.0,idle,viewport)
		presentation._present_cpp(0.01)
		check(bridge._ui.full_burst_active and events.all(func(event): return event.type!=&"full_burst_ready") and presentation.frame_view._full_burst_visual!=null,"値型復帰で満充填表示を作り直し通知を重複しない")
		trait_start_trace(bridge,16.0)
		bridge.step(1.0/120.0,idle,viewport)
		check(not bridge._ui.full_burst_active and bridge._ui.shooting_rate==1.0,"発進で1未満になった瞬間に通常連射へ戻す")
		var before: Dictionary = bridge._ui.duplicate(true)
		bridge.command("pause",{"paused":true})
		for tick in 3: bridge.step(1.0/120.0,idle,viewport)
		check(bridge._ui.draw.gauge==before.draw.gauge and bridge._ui.full_burst_active==before.full_burst_active,"停止中は充填と移行を進めない")
		bridge.command("pause",{"paused":false})
		events.clear()
		for tick in 100:
			bridge.step(1.0/120.0,idle,viewport)
			if bridge._ui.full_burst_active: break
		check(bridge._ui.full_burst_active and events.filter(func(event): return event.type==&"full_burst_ready").size()==1,"復帰後の再充填で光と連射を一度有効にする")
		var origin: Vector2 = core.ship_snapshot().ship_pos
		for distance in [80.0,180.0]:
			var enemy: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":origin+Vector2(distance,0)}).value
			core.set_enemy_motion(enemy,{"held":true,"vel":Vector2.ZERO})
		var kills := 0
		for tick in 160: bridge.step(1.0/120.0,idle,viewport)
		for event: Dictionary in events:
			if event.type==&"kill": kills += 1
		check(kills>=2 and bridge._ui.full_burst_active,"実際の連続撃破後も満充填の効果を維持する")
		bridge.command("dev_remove_trait",{"id":"T36"})
		presentation._present_cpp(0.01)
		check(not bridge._ui.full_burst and not bridge._ui.full_burst_active and bridge._ui.shooting_rate==1.0 and presentation.frame_view._full_burst_visual==null,"解除で倍率・状態・光を片付ける")
		bridge.release_checkpoint(saved.value)
	bridge.restore(initial.value)
	bridge.collect_frame()
	bridge.command("dev_grant_equipment",{"kind":"trait","id":"T36","levels":1})
	if not interval_only: await trait_select_upgrade(session,"T36",config,idle,viewport)
	bridge.release_checkpoint(initial.value)
	session.free()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"フルバーストの状態と表示に実行エラーがない: %s" % [capture.messages()])

func check_cpp_w29() -> void:
	var capture := ErrorCapture.new()
	OS.add_logger(capture)
	var config := trait_test_config()
	config.xp_base = 100000.0
	# 通常候補は固定seed 630の1回目の引き直しでW29を含む。
	var seed_value := 630
	var session = await trait_test_session("W29",config,seed_value)
	if session==null:
		OS.remove_logger(capture)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(640,480)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("set_settings",{"hitstop":false})
	var initial: Dictionary = bridge.checkpoint()
	var events: Array = []
	bridge.subscribe("w29",func(frame: Dictionary):
		events.append_array(frame.events)
		return true)
	var definition: WeaponDef = ContentManager.definition(&"weapons",&"W29")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	for level in ([] if "--cpp-w29-tail" in OS.get_cmdline_user_args() else range(1,definition.level_steps.size()+1)):
		bridge.restore(initial.value)
		bridge.collect_frame()
		check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W29","levels":level}).ok,"終端爆発を全段取得する")
		bridge.command("dev_grant_equipment",{"kind":"trait","id":"T04","levels":5})
		bridge.command("dev_post_weapon_power",{"damage":2,"followup":0})
		var target: Vector2 = core.ship_snapshot().ship_pos+Vector2(120,75)
		var enemy: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":target}).value
		core.set_enemy_motion(enemy,{"held":true,"vel":Vector2.ZERO})
		events.clear()
		trait_start_trace(bridge,120.0)
		for tick in 80:
			bridge.step(1.0/120.0,idle,viewport)
			if not bridge._ui.draw.tracing: break
		var booms: Array = events.filter(func(event): return event.type==&"explode" and event.payload.cause==&"endBlast")
		check(booms.size()==1 and is_equal_approx(booms[0].payload.radius,definition.params.radius_by_level[level-1]),"終了時に全段の主爆発を一度発動する")
		var pending: Array = bridge._ui.end_blast.pending
		var count: int = definition.params.secondary_by_level[level-1]
		check(pending.size()==count,"全段の外周爆発数を生成値どおり予約する")
		var hits: Array = events.filter(func(event): return event.type==&"combat_damage" and event.payload.cause==&"endBlast")
		var gear: TraitDef = ContentManager.definition(&"traits",&"T04")
		var gear_power: float = 1.0+(gear.params.mult_base+gear.params.mult_per*5.0-1.0)*(exp(3.0*120.0/config.draw_length)-1.0)/(exp(3.0)-1.0)
		var expected: float = config.base_attack*gear_power*(1.0+2.0*config.post_max.increments.weapon_damage)*definition.params.damage_by_level[level-1]
		check(not hits.is_empty() and is_equal_approx(hits[0].payload.requested,expected) and bridge._ui.full_charge.burst_power==1.0,"終了時のギア倍率と最大段後倍率を命中へ固定してからリセットする")
		for i in pending.size():
			check(is_equal_approx(pending[i].radius,float(definition.params.radius_by_level[level-1])*definition.params.secondary_radius) and is_equal_approx(pending[i].damage,expected*definition.params.secondary_damage),"予約に半径と威力を値で保持する")
			var distance: float = pending[i].pos.distance_to(booms[0].payload.pos)
			check(distance>=definition.params.radius_by_level[level-1]*0.8999 and distance<=definition.params.radius_by_level[level-1]*1.1001,"外周位置の乱数を共通列で範囲内に使う")
		presentation._present_cpp(0.01)
		check(presentation.frame_view._end_blast_visual!=null and presentation.frame_view._end_blast_visual.booms.size()==1 and presentation.frame_view._end_blast_visual._plasmas!=null,"主爆発を本番の紫のプラズマ表示へ渡す")
		var saved: Dictionary = bridge.checkpoint()
		var before: Dictionary = bridge._ui.end_blast.duplicate(true)
		bridge.command("pause",{"paused":true})
		for tick in 3: bridge.step(1.0/120.0,idle,viewport)
		presentation._present_cpp(0.1)
		check(bridge._ui.end_blast==before,"停止中は予約と残留表示の時計を進めない")
		bridge.command("pause",{"paused":false})
		for tick in 60: bridge.step(1.0/120.0,idle,viewport)
		var after: Dictionary = bridge._ui.end_blast.duplicate(true)
		var enemies: Array = core.enemies_snapshot()
		check(events.filter(func(event): return event.type==&"explode" and event.payload.cause==&"endBlast").size()==count+1 and bridge._ui.end_blast.pending.is_empty(),"予約順で外周爆発を一度ずつ命中させる")
		bridge.restore(saved.value)
		bridge.collect_frame()
		presentation._present_cpp(0.01)
		check(presentation.frame_view._end_blast_visual.booms.size()==1,"復帰した主爆発の残留表示を状態から再構成する")
		for tick in 60: bridge.step(1.0/120.0,idle,viewport)
		check(bridge._ui.end_blast==after and core.enemies_snapshot()==enemies,"復帰後の予約順・命中・残留寿命を再現する")
		bridge.restore(saved.value)
		bridge.collect_frame()
		bridge.command("dev_remove_weapon",{"id":"W29"})
		presentation._present_cpp(0.01)
		events.clear()
		for tick in 130: bridge.step(1.0/120.0,idle,viewport)
		check(not bridge._ui.end_blast.ready and bridge._ui.end_blast.pending.is_empty() and presentation.frame_view._end_blast_visual==null and events.all(func(event): return event.type!=&"explode" or event.payload.cause!=&"endBlast"),"途中解除で残りの予約と専用表示を片付ける")
		bridge.release_checkpoint(saved.value)
		if failures: break
	bridge.restore(initial.value)
	bridge.collect_frame()
	bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W29","levels":5})
	trait_start_trace(bridge,120.0)
	for tick in 210: bridge.step(1.0/120.0,idle,viewport)
	presentation._present_cpp(0.01)
	check(bridge._ui.end_blast.pending.is_empty() and bridge._ui.end_blast.visuals.is_empty() and presentation.frame_view._end_blast_visual.booms.is_empty(),"最終爆発の残留時間後に予約と表示を自然消滅する")
	bridge.restore(initial.value)
	bridge.collect_frame()
	bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W29","levels":1})
	await trait_select_upgrade(session,"W29",config,idle,viewport)
	bridge.release_checkpoint(initial.value)
	session.free()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"終端爆発の状態と表示に実行エラーがない: %s" % [capture.messages()])

func check_cpp_t32() -> void:
	var capture := ErrorCapture.new()
	OS.add_logger(capture)
	var config := trait_test_config()
	config.base_attack = 100.0
	config.xp_base = 100000.0
	# 通常候補は固定seed 632の3回目の引き直しでT32を含む。
	var seed_value := 632
	var session = await trait_test_session("T32",config,seed_value)
	if session==null:
		OS.remove_logger(capture)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(640,480)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("set_settings",{"hitstop":false})
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var initial: Dictionary = bridge.checkpoint()
	var events: Array = []
	bridge.subscribe("t32",func(frame: Dictionary):
		events.append_array(frame.events)
		return true)
	var definition: TraitDef = ContentManager.definition(&"traits",&"T32")
	var gear: TraitDef = ContentManager.definition(&"traits",&"T04")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	for level in range(1,config.trait_max_stacks+1):
		bridge.restore(initial.value)
		bridge.collect_frame()
		check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T32","levels":level}).ok,"助走を全段取得する")
		bridge.command("dev_grant_equipment",{"kind":"trait","id":"T04","levels":5})
		var origin: Vector2 = core.ship_snapshot().ship_pos
		for offset in [Vector2(400,0),Vector2(400,70),Vector2(750,0)]:
			var enemy: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":origin+offset}).value
			core.set_enemy_motion(enemy,{"held":true,"vel":Vector2.ZERO})
			if offset.y>0: bridge.command("dev_damage",{"entity_id":enemy,"amount":3.0,"knock":0.0,"no_crit":true})
		events.clear()
		trait_start_trace(bridge,850.0)
		bridge.step(1.0/120.0,idle,viewport)
		presentation._present_cpp(0.01)
		check(bridge._ui.run_up.first and bridge._ui.run_up.strength==0.0 and presentation.frame_view._run_up_visual!=null,"発進で最初の接触を待ち距離から尾を表示する")
		var before: Dictionary = bridge._ui.run_up.duplicate(true)
		bridge.command("pause",{"paused":true})
		for tick in 3: bridge.step(1.0/120.0,idle,viewport)
		check(bridge._ui.run_up==before,"停止中は最初の接触と助走距離を進めない")
		bridge.command("pause",{"paused":false})
		var saved: Dictionary = bridge.checkpoint()
		var shown := false
		for tick in 70:
			bridge.step(1.0/120.0,idle,viewport)
			if not shown and not bridge._ui.run_up.first:
				presentation._present_cpp(0.01)
				check(presentation.frame_view._run_up_visual.hits.size()==1,"最初の接触だけを光と衝撃線として表示する")
				shown = true
		var expected: Dictionary = bridge._ui.run_up.duplicate(true)
		var expected_enemies: Array = core.enemies_snapshot()
		var hits: Array = events.filter(func(event): return event.type==&"combat_damage" and event.payload.cause==&"ram")
		var area_hits: Array = events.filter(func(event): return event.type==&"combat_damage" and event.payload.cause==&"runUp")
		var flashes: Array = events.filter(func(event): return event.type==&"run_up_hit")
		check(hits.size()==2 and flashes.size()==1 and not bridge._ui.run_up.first,"一回のなぞりで最初だけ助走を使い連続した敵を撃破する")
		if not hits.is_empty():
			var distance: float = origin.distance_to(hits[0].payload.impact)
			var strength: float = (exp(3.0*clampf(distance/definition.params.distance,0.0,1.0))-1.0)/(exp(3.0)-1.0)
			var gear_strength: float = (exp(3.0*clampf(distance/config.draw_length,0.0,1.0))-1.0)/(exp(3.0)-1.0)
			var expected_attack: float = config.base_attack*(1.0+(gear.params.mult_base+gear.params.mult_per*5.0-1.0)*gear_strength)*(1.0+(definition.params.mult_base+definition.params.mult_per*level-1.0)*strength)
			check(is_equal_approx(hits[0].payload.requested,expected_attack) and is_equal_approx(flashes[0].payload.strength,strength),"全段で命中地点までの指数倍率とギア倍率を合成する")
			check(not area_hits.is_empty() and is_equal_approx(area_hits[0].payload.requested,hits[0].payload.applied*definition.params.area_damage),"範囲攻撃は過剰分を除いた実際の減少HPを基準にする")
		if hits.size()>1:
			var d: float = origin.distance_to(hits[1].payload.impact)
			var factor: float = 1.0+(gear.params.mult_base+gear.params.mult_per*5.0-1.0)*(exp(3.0*clampf(d/config.draw_length,0.0,1.0))-1.0)/(exp(3.0)-1.0)
			check(is_equal_approx(hits[1].payload.requested,config.base_attack*factor),"2体目の体当たりへ助走倍率を持ち越さない")
		check(bridge._ui.kills==3,"最初の範囲攻撃と次の体当たりで実際の連鎖撃破を処理する")
		bridge.restore(saved.value)
		bridge.collect_frame()
		for tick in 70: bridge.step(1.0/120.0,idle,viewport)
		check(bridge._ui.run_up==expected and core.enemies_snapshot()==expected_enemies,"最初の接触・強さと連鎖結果を値型復帰で再現する")
		bridge.release_checkpoint(saved.value)
		bridge.command("dev_remove_trait",{"id":"T32"})
		presentation._present_cpp(0.01)
		check(not bridge._ui.run_up.ready and presentation.frame_view._run_up_visual==null,"解除で助走状態と表示を片付ける")
		if failures: break
	for distance in [0.0,210.0]:
		bridge.restore(initial.value)
		bridge.collect_frame()
		bridge.command("dev_grant_equipment",{"kind":"trait","id":"T32","levels":3})
		var origin: Vector2 = core.ship_snapshot().ship_pos
		var enemy: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":origin+Vector2(distance,0)}).value
		core.set_enemy_motion(enemy,{"held":true,"vel":Vector2.ZERO})
		events.clear()
		trait_start_trace(bridge,400.0)
		for tick in 60:
			bridge.step(1.0/120.0,idle,viewport)
			if not bridge._ui.run_up.first: break
		var flashes: Array = events.filter(func(event): return event.type==&"run_up_hit")
		check(flashes.size()==1 and (bridge._ui.run_up.strength==0.0 if distance==0.0 else bridge._ui.run_up.strength>0.0 and bridge._ui.run_up.strength<1.0),"距離0と上限未満の発動境界を指数曲線で扱う")
		var saved: Dictionary = bridge.checkpoint()
		presentation._present_cpp(0.01)
		bridge.restore(saved.value)
		bridge.collect_frame()
		presentation._present_cpp(0.01)
		check(presentation.frame_view._run_up_visual.hits.size()==1,"接触後の短い衝撃表示も値型復帰から作り直す")
		bridge.release_checkpoint(saved.value)
	bridge.restore(initial.value)
	bridge.collect_frame()
	bridge.command("dev_grant_equipment",{"kind":"trait","id":"T32","levels":1})
	await trait_select_upgrade(session,"T32",config,idle,viewport)
	bridge.release_checkpoint(initial.value)
	session.free()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"助走の状態と表示に実行エラーがない: %s" % [capture.messages()])

func check_cpp_w07() -> void:
	var retry: bool = "--cpp-w07-fixes" in OS.get_cmdline_user_args()
	var capture := ErrorCapture.new()
	OS.add_logger(capture)
	var config := trait_test_config()
	config.xp_base = 100000.0
	var session = await trait_test_session("W07",config,607)
	if session==null:
		OS.remove_logger(capture)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(640,480)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("set_settings",{"hitstop":false})
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var initial: Dictionary = bridge.checkpoint()
	var events: Array = []
	bridge.subscribe("w07",func(frame: Dictionary):
		events.append_array(frame.events)
		return true)
	var definition: WeaponDef = ContentManager.definition(&"weapons",&"W07")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	for level in range(4 if retry else 1,definition.level_steps.size()+1):
		var should_check: bool = not retry or level>4
		bridge.restore(initial.value)
		bridge.collect_frame()
		var granted: Dictionary = bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W07","levels":level})
		if should_check: check(granted.ok,"機雷を全段取得する")
		bridge.command("dev_post_scatter",{"interval":0,"projectile":0,"duration":2,"knockback":2})
		bridge.command("dev_post_weapon_power",{"damage":2,"followup":1})
		trait_start_trace(bridge,120.0)
		for tick in 70:
			bridge.step(1.0/120.0,idle,viewport)
			if not bridge._ui.draw.tracing: break
		print("[W07確認Lv] %d" % level)
		var items: Array = bridge._ui.mines.items.duplicate(true)
		if should_check: check(items.size()==definition.params.count_by_level[level-1],"各段の数だけ終端に機雷を置く")
		for mine: Dictionary in items:
			var delta: Vector2 = mine.to-mine.from
			if should_check: check(delta.length()>=definition.params.range_min-0.001 and delta.length()<=definition.params.range_max+0.001 and absf(delta.angle())<=deg_to_rad(definition.params.spread)+0.0001,"共通乱数で最後の区間を向いた扇形へ飛ばす")
			var ease: float = 1.0-pow(1.0-minf(1.0,mine.age/0.14),3.0)
			if should_check: check(mine.pos.distance_to(mine.from.lerp(mine.to,ease))<0.001 and mine.age<0.14,"起動前の飛び出しを3乗曲線で進める")
			if should_check: check(is_equal_approx(mine.life+mine.age,definition.params.life_by_level[level-1]*(1.0+2.0*config.post_max.increments.duration)) and is_equal_approx(mine.damage,config.base_attack*(1.0+2.0*config.post_max.increments.weapon_damage+config.post_max.increments.followup)*definition.params.damage_by_level[level-1]),"寿命・威力・追撃の最大段後補正を生成時に固定する")
		presentation._present_cpp(0.01)
		if should_check: check(presentation.frame_view._mines_visual!=null and presentation.frame_view._mines_overlay.visible and presentation.frame_view._mines_overlay.texture!=null,"飛び出す機雷と機体の装備を本番表示へ渡す")
		var saved: Dictionary = bridge.checkpoint()
		bridge.command("pause",{"paused":true})
		for tick in 3: bridge.step(1.0/120.0,idle,viewport)
		if should_check: check(bridge._ui.mines.items==items,"停止中は起動待ちと寿命を進めない")
		bridge.command("pause",{"paused":false})
		for tick in 20: bridge.step(1.0/120.0,idle,viewport)
		var armed: Array = bridge._ui.mines.items.duplicate(true)
		if should_check: check(armed.size()==items.size() and armed.all(func(item): return item.age>=0.14 and item.pos==item.to),"0.14秒で着地し敵がいなければ爆発せず待つ")
		bridge.restore(saved.value)
		bridge.collect_frame()
		for tick in 20: bridge.step(1.0/120.0,idle,viewport)
		if should_check: check(bridge._ui.mines.items==armed,"復帰後も飛行・起動・残り寿命を再現する")
		var trigger_at: Vector2 = armed[0].pos
		var far := 0.0
		for item: Dictionary in armed:
			var d: float = item.pos.distance_to(core.ship_snapshot().ship_pos)
			if d>far:
				far = d
				trigger_at = item.pos
		var enemy: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":trigger_at}).value
		core.set_enemy_motion(enemy,{"held":true,"vel":Vector2.ZERO})
		var queue: Array[int] = []
		var queued := {}
		for k in armed.size():
			if armed[k].pos.distance_to(trigger_at)<=definition.params.trigger+float(core.enemies_snapshot().filter(func(item): return item.id==enemy)[0].radius):
				queue.append(k)
				queued[k] = true
		var index := 0
		while index<queue.size():
			var k: int = queue[index]
			index += 1
			if level<3: continue
			for other in armed.size():
				if not queued.has(other) and armed[other].pos.distance_to(armed[k].pos)<=armed[k].radius:
					queued[other] = true
					queue.append(other)
		events.clear()
		bridge.step(1.0/120.0,idle,viewport)
		var explosions: Array = events.filter(func(event): return event.type==&"explode" and event.payload.cause==&"mine")
		if should_check: check(explosions.size()==queue.size(),"接近した機雷とLv3以降の誘爆を待ち列で一度ずつ処理する")
		for k in mini(queue.size(),explosions.size()): check(explosions[k].payload.pos==armed[queue[k]].pos,"誘爆の発動順を元の並びに保つ")
		if should_check: check(bridge._ui.kills>=1 and bridge._ui.mines.items.size()==armed.size()-queue.size(),"実際に命中して撃破し爆発済みの機雷を除く")
		presentation._present_cpp(0.01)
		if should_check: check(not presentation.frame_view._mines_visual.booms.is_empty(),"起爆を制作済みの炎と白い破片へ渡す")
		var exploded: Dictionary = bridge.checkpoint()
		bridge.restore(exploded.value)
		bridge.collect_frame()
		presentation._present_cpp(0.01)
		if should_check: check(not presentation.frame_view._mines_visual.booms.is_empty(),"起爆後の残留表示を値型復帰から作り直す")
		bridge.command("dev_remove_weapon",{"id":"W07"})
		presentation._present_cpp(0.01)
		if should_check: check(not bridge._ui.mines.ready and bridge._ui.mines.items.is_empty() and presentation.frame_view._mines_visual==null and not presentation.frame_view._mines_overlay.visible,"途中解除で残る機雷と装備表示を片付ける")
		bridge.release_checkpoint(exploded.value)
		bridge.release_checkpoint(saved.value)
		if failures: break
	bridge.restore(initial.value)
	bridge.collect_frame()
	bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W07","levels":5})
	for volley in 4:
		trait_start_trace(bridge,16.0)
		for tick in 23: bridge.step(1.0/120.0,idle,viewport)
	var capped: Array = bridge._ui.mines.items
	check(capped.size()==definition.params.max and capped.front().id==37 and capped.back().id==96,"上限を超えた古い機雷だけを消して連番を保つ")
	events.clear()
	for tick in 800: bridge.step(1.0/120.0,idle,viewport)
	presentation._present_cpp(0.01)
	check(bridge._ui.mines.items.is_empty() and events.all(func(event): return event.type!=&"explode" or event.payload.cause!=&"mine"),"寿命切れの機雷は爆発せず自然消滅する")
	bridge.restore(initial.value)
	bridge.collect_frame()
	bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W07","levels":1})
	await trait_select_upgrade(session,"W07",config,idle,viewport)
	bridge.release_checkpoint(initial.value)
	session.free()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"機雷の状態と表示に実行エラーがない: %s" % [capture.messages()])

func check_cpp_t03() -> void:
	var retry: bool = "--cpp-t03-fixes" in OS.get_cmdline_user_args()
	var capture := ErrorCapture.new()
	OS.add_logger(capture)
	var config := trait_test_config()
	config.xp_base = 100000.0
	# 通常候補は固定seed 604の初回にT03を含む。
	var seed_value := 604
	var session = await trait_test_session("T03",config,seed_value)
	if session==null:
		OS.remove_logger(capture)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(640,480)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("set_settings",{"hitstop":false})
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var initial: Dictionary = bridge.checkpoint()
	var events: Array = []
	bridge.subscribe("t03",func(frame: Dictionary):
		events.append_array(frame.events)
		return true)
	var definition: TraitDef = ContentManager.definition(&"traits",&"T03")
	var gear: TraitDef = ContentManager.definition(&"traits",&"T04")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	for level in range(1,config.trait_max_stacks+1):
		var should_check: bool = not retry or level>1
		bridge.restore(initial.value)
		bridge.collect_frame()
		var granted: Dictionary = bridge.command("dev_grant_equipment",{"kind":"trait","id":"T03","levels":level})
		if should_check: check(granted.ok,"終端の渦を全段取得する")
		bridge.command("dev_grant_equipment",{"kind":"trait","id":"T04","levels":5})
		events.clear()
		trait_start_trace(bridge,400.0)
		for tick in 70:
			bridge.step(1.0/120.0,idle,viewport)
			if not bridge._ui.draw.tracing: break
		var items: Array = bridge._ui.vortex.items
		if should_check: check(items.size()==1 and events.filter(func(event): return event.type==&"end_hole").size()==1,"なぞりの終端で渦を一度生成する")
		var expected_damage: float = config.base_attack*(1.0+(gear.params.mult_base+gear.params.mult_per*5.0-1.0)*(exp(3.0*400.0/config.draw_length)-1.0)/(exp(3.0)-1.0))*(definition.params.damage_base+definition.params.damage_per*level)
		if should_check: check(is_equal_approx(items[0].radius,definition.params.radius_by_level[level-1]) and is_equal_approx(items[0].damage,expected_damage) and is_equal_approx(items[0].duration,definition.params.charge+definition.params.hold+definition.params.collapse),"全段の半径と終了時のギア倍率・寿命を渦へ固定する")
		presentation._present_cpp(0.01)
		if should_check: check(presentation.frame_view._vortex_visual!=null and presentation.frame_view._vortex_visual.holes.size()==1 and is_instance_valid(presentation.frame_view._vortex_visual.holes[0].lens),"溜めの粒と機体の下のレンズを本番表示へ渡す")
		var before: Dictionary = bridge._ui.vortex.duplicate(true)
		bridge.command("pause",{"paused":true})
		for tick in 3: bridge.step(1.0/120.0,idle,viewport)
		presentation._present_cpp(0.1)
		if should_check: check(bridge._ui.vortex==before,"停止中は渦・捕捉・回復の時計を進めない")
		bridge.command("pause",{"paused":false})
		while bridge._ui.vortex.items[0].age+1.0/120.0<definition.params.charge: bridge.step(1.0/120.0,idle,viewport)
		var center: Vector2 = core.ship_snapshot().ship_pos
		for offset in [Vector2(0,100),Vector2(35,120),Vector2(70,130)]:
			var enemy: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":center+offset}).value
			core.set_enemy_motion(enemy,{"held":true,"vel":Vector2.ZERO})
		var guarded: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":center+Vector2(-40,-100)}).value
		core.set_enemy_motion(guarded,{"held":true,"vel":Vector2.ZERO})
		bridge.command("dev_enemy_combat",{"entity_id":guarded,"guard":1.0})
		var tough: int = bridge.command("dev_spawn",{"definition_id":"shield","position":center+Vector2(60,-120)}).value
		core.set_enemy_motion(tough,{"held":true,"vel":Vector2.ZERO})
		var saved: Dictionary = bridge.checkpoint()
		if should_check: check(events.all(func(event): return event.type!=&"hole_capture"),"溜めの境界より前は捕捉しない")
		bridge.step(1.0/120.0,idle,viewport)
		bridge.step(1.0/120.0,idle,viewport)
		var captures: Array = events.filter(func(event): return event.type==&"hole_capture")
		if should_check: check(captures.size()==3 and bridge._ui.vortex.items[0].kills==3 and bridge._ui.kills==3,"溜めを終えた渦が倒しきれる通常敵を連続して捕捉する")
		if should_check: check(bridge._ui.vortex.items[0].pos==core.ship_snapshot().ship_pos and bridge._ui.vortex.items[0].pos!=center,"渦が飛行中の機体に追従する")
		var survivors: Array = core.enemies_snapshot()
		var guarded_state: Dictionary = survivors.filter(func(enemy): return enemy.id==guarded)[0]
		var tough_state: Dictionary = survivors.filter(func(enemy): return enemy.id==tough)[0]
		if should_check: check(not guarded_state.hull_scattered and not tough_state.hull_scattered and tough_state.hp<ContentManager.enemies[&"shield"].hp and tough_state.dead==0,"拒否した捕捉の船体印を戻し倒しきれない敵にはダメージだけを与える")
		presentation._present_cpp(0.01)
		if should_check: check(presentation.frame_view._vortex_visual.captures.size()==3,"捕捉した敵だけを細かい粒で引き込む表示へ渡す")
		for tick in 10: bridge.step(1.0/120.0,idle,viewport)
		if should_check: check(events.filter(func(event): return event.type==&"combat_damage" and event.payload.cause==&"vortex").size()==5,"同じ渦が一度命中した敵を重ねて攻撃しない")
		var after: Dictionary = bridge._ui.vortex.duplicate(true)
		var expected_enemies: Array = core.enemies_snapshot()
		bridge.restore(saved.value)
		bridge.collect_frame()
		for tick in 12: bridge.step(1.0/120.0,idle,viewport)
		if bridge._ui.vortex!=after: print("[T03復帰差 渦] 期待=%s 実際=%s" % [after,bridge._ui.vortex])
		if core.enemies_snapshot()!=expected_enemies: print("[T03復帰差 敵] 期待=%s 実際=%s" % [expected_enemies,core.enemies_snapshot()])
		check(bridge._ui.vortex==after and core.enemies_snapshot()==expected_enemies,"命中ID・捕捉数・残留表示と敵の結果を復帰で再現する")
		presentation._present_cpp(0.01)
		if should_check: check(presentation.frame_view._vortex_visual.captures.size()==3,"復帰した捕捉の粒も状態から作り直す")
		var recovered := false
		for tick in 70:
			var gauge: float = bridge._ui.draw.gauge
			bridge.step(1.0/120.0,idle,viewport)
			if bridge._ui.vortex.items.is_empty():
				var amount: float = 3.0/definition.params.kills_by_level[level-1]
				if should_check: check(is_equal_approx(bridge._ui.draw.gauge,minf(bridge._ui.capacity,minf(1.0,gauge+1.0/120.0/bridge._ui.charge_time)+amount)),"渦が消える瞬間に段ごとの撃破数からゲージを一度戻す")
				recovered = true
				break
		if should_check: check(recovered,"渦の溜め・保持・崩壊を終えて終了する")
		presentation._present_cpp(0.01)
		if should_check: check(presentation.frame_view._vortex_visual.heals.size()==1,"終了のゲージ回復を通常のゲージ色の光へ渡す")
		bridge.command("dev_remove_trait",{"id":"T03"})
		presentation._present_cpp(0.01)
		if should_check: check(not bridge._ui.vortex.ready and bridge._ui.vortex.items.is_empty() and presentation.frame_view._vortex_visual==null,"解除で残る渦とレンズ・捕捉・回復表示を片付ける")
		bridge.release_checkpoint(saved.value)
		if failures: break
	bridge.restore(initial.value)
	bridge.collect_frame()
	bridge.command("dev_grant_equipment",{"kind":"trait","id":"T03","levels":1})
	await trait_select_upgrade(session,"T03",config,idle,viewport)
	bridge.release_checkpoint(initial.value)
	session.free()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"終端の渦の状態と表示に実行エラーがない: %s" % [capture.messages()])

func check_cpp_t06() -> void:
	var retry: bool = "--cpp-t06-fixes" in OS.get_cmdline_user_args()
	var capture := ErrorCapture.new()
	OS.add_logger(capture)
	var config := trait_test_config()
	config.base_crit_chance = 1.0
	config.xp_base = 100000.0
	# 通常候補は固定seed 606の3回目の引き直しでT06を含む。
	var seed_value := 606
	var session = await trait_test_session("T06",config,seed_value)
	if session==null:
		OS.remove_logger(capture)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(640,480)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var initial: Dictionary = bridge.checkpoint()
	var events: Array = []
	bridge.subscribe("t06",func(frame: Dictionary):
		events.append_array(frame.events)
		return true)
	var definition: TraitDef = ContentManager.definition(&"traits",&"T06")
	var area: TraitDef = ContentManager.definition(&"traits",&"T34")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	for level in range(1,config.trait_max_stacks+1):
		var should_check: bool = not retry or level>1
		bridge.restore(initial.value)
		bridge.collect_frame()
		var granted: Dictionary = bridge.command("dev_grant_equipment",{"kind":"trait","id":"T06","levels":level})
		if should_check: check(granted.ok,"会心の槍を全段取得する")
		bridge.command("dev_grant_equipment",{"kind":"trait","id":"T34","levels":2})
		bridge.command("set_settings",{"hitstop":true})
		var origin: Vector2 = core.ship_snapshot().ship_pos
		for offset in [Vector2(180,0),Vector2(400,0),Vector2(650,0)]:
			var enemy: int = bridge.command("dev_spawn",{"definition_id":"shield" if offset.x==180.0 else "splitling","position":origin+offset}).value
			core.set_enemy_motion(enemy,{"held":true,"vel":Vector2.ZERO,"facing":0.0})
		var tough: int = bridge.command("dev_spawn",{"definition_id":"shield","position":origin+Vector2(500,50)}).value
		core.set_enemy_motion(tough,{"held":true,"vel":Vector2.ZERO,"facing":0.0})
		events.clear()
		trait_start_trace(bridge,800.0)
		for tick in 70:
			bridge.step(1.0/120.0,idle,viewport)
			if not bridge._ui.light_lances.is_empty(): break
		var lances: Dictionary = bridge.command("dev_light_lances_state",{}).value
		if should_check: check(lances.items.size()==1,"実際のクリティカルから槍を一度発動する")
		if lances.items.is_empty(): break
		var lance: Dictionary = lances.items[0]
		if should_check: check(is_equal_approx(lance.length,definition.params.length_base+definition.params.length_per*level) and is_equal_approx(lance.width,(definition.params.width_base+definition.params.width_per*level)*(1.0+area.stack_bonus(2))) and is_equal_approx(lance.damage,config.base_attack*(definition.params.damage_base+definition.params.damage_per*level)) and lance.knock==definition.params.knock,"全段の長さ・幅と範囲補正・威力・ノックバックを共通の槍へ渡す")
		if should_check: check(lance.velocity.normalized().distance_to(Vector2.RIGHT)<0.001 and events.filter(func(event): return event.type==&"kill" and event.payload.cause==&"critBeam").size()>=2,"進む向きへ即時に貫通し連続した敵を撃破する")
		if should_check: check(events.filter(func(event): return event.type==&"critical_lance").size()==1 and is_equal_approx(bridge._ui.crit_beam.next_time,bridge._ui.run_time-1.0/120.0+definition.params.cooldown),"槍から再発動せずラン秒を基準に次の時刻を保持する")
		presentation._present_cpp(0.01)
		check(presentation.frame_view._critical_lances.shots.size()==1 and not presentation.frame_view._lance_flashes.is_empty() and not presentation.frame_view._lance_hits.is_empty(),"槍・発射の光・生存した命中対象の火花を既存描画へ渡す")
		bridge.command("dev_relocate",{"entity_id":tough,"position":origin+Vector2(0,3000)})
		var life_before: float = lance.life
		var display_age: float = bridge._ui.light_lances[0].age
		if bridge._ui.hitstop>1.0/120.0:
			bridge.step(1.0/120.0,idle,viewport)
			check(bridge.command("dev_light_lances_state",{}).value.items[0].life==life_before and bridge._ui.light_lances[0].age==display_age,"ヒットストップは元の槍表示と世界時計を止める")
		bridge.command("set_settings",{"hitstop":false})
		core.set_run_guards({"controls_locked":true})
		life_before = bridge.command("dev_light_lances_state",{}).value.items[0].life
		display_age = bridge._ui.light_lances[0].age
		bridge.step(1.0/120.0,idle,viewport)
		if should_check: check(bridge.command("dev_light_lances_state",{}).value.items[0].life==life_before and is_equal_approx(bridge._ui.light_lances[0].age,display_age+1.0/120.0),"操作ロックでは判定寿命を止め表示の実秒だけを進める")
		core.set_run_guards({"controls_locked":false})
		var before: Dictionary = bridge._ui.duplicate(true)
		bridge.command("pause",{"paused":true})
		for tick in 3: bridge.step(1.0/120.0,idle,viewport)
		presentation._present_cpp(0.2)
		presentation._present_cpp(0.2)
		if should_check: check(bridge._ui.light_lances==before.light_lances and bridge._ui.lance_effects==before.lance_effects and presentation.frame_view._critical_lances.shots[0].age==before.light_lances[0].age,"停止中は表示値を保ち表示側でも二重に時間を加算しない")
		bridge.command("pause",{"paused":false})
		var saved: Dictionary = bridge.checkpoint()
		for tick in 5: bridge.step(1.0/120.0,idle,viewport)
		var expected: Array = bridge._ui.light_lances.duplicate(true)
		var expected_effects: Array = bridge._ui.lance_effects.duplicate(true)
		var expected_lances: Dictionary = bridge.command("dev_light_lances_state",{}).value
		bridge.restore(saved.value)
		bridge.collect_frame()
		presentation._present_cpp(0.01)
		if should_check: check(presentation.frame_view._critical_lances.shots.size()==1 and not presentation.frame_view._lance_flashes.is_empty(),"値型復帰から槍と短い光を通知の再発行なしで作り直す")
		for tick in 5: bridge.step(1.0/120.0,idle,viewport)
		if should_check: check(bridge._ui.light_lances==expected and bridge._ui.lance_effects==expected_effects and bridge.command("dev_light_lances_state",{}).value==expected_lances,"復帰後も世界秒の判定寿命と実秒の表示を別々に再現する")
		var trigger: int = bridge.command("dev_spawn",{"definition_id":"shield","position":origin+Vector2(0,2000)}).value
		core.set_enemy_motion(trigger,{"held":true,"vel":Vector2.ZERO})
		events.clear()
		bridge.command("dev_damage",{"entity_id":trigger,"amount":0.1,"crit":true,"knock":0.0,"cause":"bump"})
		if should_check: check(events.all(func(event): return event.type!=&"critical_lance"),"クールダウン前のクリティカルでは発動しない")
		while bridge._ui.run_time<bridge._ui.crit_beam.next_time: bridge.step(1.0/120.0,idle,viewport)
		events.clear()
		bridge.command("dev_damage",{"entity_id":trigger,"amount":0.1,"crit":true,"no_crit":true,"knock":0.0})
		if should_check: check(events.all(func(event): return event.type!=&"critical_lance"),"no_critの命中は時刻が満ちても再発動しない")
		bridge.command("dev_damage",{"entity_id":trigger,"amount":0.1,"crit":true,"knock":0.0,"cause":"bump"})
		if should_check: check(events.filter(func(event): return event.type==&"critical_lance").size()==1,"クールダウン境界後は弾かれのクリティカルでも発動する")
		bridge.command("dev_remove_trait",{"id":"T06"})
		if should_check: check(not bridge._ui.crit_beam.ready and not bridge._ui.light_lances.is_empty(),"解除は次の発動を止め発射済みの槍を自然寿命まで残す")
		for tick in 70: bridge.step(1.0/120.0,idle,viewport)
		presentation._present_cpp(0.01)
		if should_check: check(bridge._ui.light_lances.is_empty() and presentation.frame_view._critical_lances.shots.is_empty(),"短い表示の実秒の寿命で槍を片付ける")
		bridge.release_checkpoint(saved.value)
		if failures: break
	if not retry:
		bridge.restore(initial.value)
		bridge.collect_frame()
		bridge.command("dev_grant_equipment",{"kind":"trait","id":"T06","levels":5})
		bridge.command("dev_grant_equipment",{"kind":"trait","id":"T37","levels":5})
		var split := false
		for attempt in 12:
			var enemy: int = bridge.command("dev_spawn",{"definition_id":"shield","position":core.ship_snapshot().ship_pos+Vector2(0,2000)}).value
			core.set_enemy_motion(enemy,{"held":true,"vel":Vector2.ZERO})
			events.clear()
			bridge.command("dev_damage",{"entity_id":enemy,"amount":0.1,"crit":true,"knock":0.0})
			if events.any(func(event): return event.type==&"duplicate"):
				var lances: Array = bridge.command("dev_light_lances_state",{}).value.items
				check(lances.filter(func(item): return item.duplicate).size()>=2 and events.filter(func(event): return event.type==&"critical_lance").size()==3,"会心の元の槍から既存の複製2本を同じ入口で発生させる")
				split = true
				break
			for tick in 19: bridge.step(1.0/120.0,idle,viewport)
		check(split,"会心からの槍で分裂が実際に起きる")
	bridge.restore(initial.value)
	bridge.collect_frame()
	bridge.command("dev_grant_equipment",{"kind":"trait","id":"T06","levels":1})
	if not retry: await trait_select_upgrade(session,"T06",config,idle,viewport)
	bridge.release_checkpoint(initial.value)
	session.free()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"会心の槍の状態と表示に実行エラーがない: %s" % [capture.messages()])

func check_cpp_t06_source_clock() -> bool:
	var session = await trait_test_session("T06",trait_test_config(),606)
	if session==null: return false
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(1280,720)}
	bridge.command("dev_remove_weapon",{"id":"W01"})
	bridge.command("set_settings",{"hitstop":true})
	trait_start_trace(bridge,1200.0)
	var origin: Vector2 = core.ship_snapshot().ship_pos
	bridge.command("dev_spawn",{"definition_id":"splitling","position":origin+Vector2(200,0)})
	var shield: int = bridge.command("dev_spawn",{"definition_id":"shield","position":origin+Vector2(400,0)}).value
	core.set_enemy_motion(shield,{"held":true,"facing":0.0,"vel":Vector2.ZERO})
	check(bridge.command("dev_fire_light_lances",{"position":origin,"direction":Vector2.RIGHT,"length":700.0,"width":20.0,"damage":10.0,"knock":0.0}).ok,"元の時計を比べる槍と発射光・命中火花を生成する")
	check(bridge.command("dev_damage",{"entity_id":shield,"amount":1.0,"cause":"ram","crit":true}).ok,"体当たり会心で元のヒットストップ条件を作る")
	bridge.collect_frame()
	check(bridge._ui.hitstop>1.0/120.0 and bridge._ui.tracing and not bridge._ui.lance_effects.is_empty(),"ヒットストップとなぞり中の時計条件を準備できる")
	var before: Dictionary = bridge._ui.duplicate(true)
	bridge.step(1.0/120.0,idle,viewport)
	check(bridge._ui.light_lances[0].age==before.light_lances[0].age and bridge._ui.lance_effects==before.lance_effects,"元の槍本体と世界秒の光・火花はヒットストップ中に止まる")
	if "--cpp-t06-hitstop-fix" in OS.get_cmdline_user_args():
		session.free()
		return true
	bridge.command("set_settings",{"hitstop":false})
	core.set_run_guards({"controls_locked":true})
	bridge.collect_frame()
	before = bridge._ui.duplicate(true)
	bridge.step(1.0/120.0,idle,viewport)
	var world_dt: float = bridge._ui.world_time-before.world_time
	check(world_dt>0.0 and world_dt<1.0/120.0,"なぞり中の世界時計が実秒より遅い条件を維持する")
	check(is_equal_approx(bridge._ui.light_lances[0].age,before.light_lances[0].age+1.0/120.0),"操作ロック中も槍本体は元の実秒で進む")
	check(is_equal_approx(bridge._ui.lance_effects[0].age,before.lance_effects[0].age+world_dt),"発射光・命中火花は元の世界秒で進む")
	session.free()
	return true

func w03_bridge(bytes: PackedByteArray, seed_value: int):
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	check(bridge.configure(bytes,{"api_version":1,"run_id":93,"mode":1,"stage_id":"84","profile":{},"settings":{}}).ok,"星砕きの固定入力を共通の生成物から準備する")
	bridge.start(seed_value)
	bridge.collect_frame()
	bridge.command("dev_remove_weapon",{"id":"W01"})
	return bridge

func w03_kill(bridge, depth: int = 0, cause: String = "shot", preset: float = 0.0, capture: bool = false, boss: bool = false) -> int:
	var core = bridge._core
	var position: Vector2 = core.ship_snapshot().ship_pos+Vector2(100,100)
	var id: int = core.spawn_enemy(&"splitling",position,{"is_boss":true}) if boss else bridge.command("dev_spawn",{"definition_id":"splitling","position":position}).value
	core.set_enemy_motion(id,{"held":true,"vel":Vector2.ZERO})
	var hp: float = core.enemies_snapshot().filter(func(enemy): return enemy.id==id)[0].hp
	if capture: bridge.command("dev_enemy_combat",{"entity_id":id,"capture_on_death":true})
	if preset>0.0: bridge.command("dev_damage",{"entity_id":id,"amount":hp*preset,"knock":0.0,"no_crit":true})
	check(bridge.command("dev_damage",{"entity_id":id,"amount":hp*(1.0-preset),"cause":cause,"direction":Vector2.RIGHT,"knock":0.0,"no_crit":true,"shatter_depth":depth}).ok,"最後の一撃を共通の撃破へ通す")
	return id

func check_cpp_w03() -> void:
	var retry: bool = "--cpp-w03-fixes" in OS.get_cmdline_user_args()
	var capture := ErrorCapture.new()
	OS.add_logger(capture)
	var config := trait_test_config()
	config.xp_base = 100000.0
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var bytes: PackedByteArray = builder.compile_chase(ContentManager.enemies[&"splitling"],config,schema.sha256("星砕きの固定入力".to_utf8_buffer()))
	# PCG32の固定seed3490で実連鎖を確認し、通常候補も初回にW03を含む。
	var seed_value := 3490
	var session = await trait_test_session("W03",config,seed_value)
	if session==null:
		OS.remove_logger(capture)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(640,480)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("set_settings",{"hitstop":false})
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var initial: Dictionary = bridge.checkpoint()
	var events: Array = []
	bridge.subscribe("w03",func(frame: Dictionary):
		events.append_array(frame.events)
		return true)
	var definition: WeaponDef = ContentManager.definition(&"weapons",&"W03")
	var area: TraitDef = ContentManager.definition(&"traits",&"T34")
	var attack: TraitDef = ContentManager.definition(&"traits",&"T11")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	for level in range(1,definition.level_steps.size()+1):
		var should_check: bool = not retry or level>2
		bridge.restore(initial.value)
		bridge.collect_frame()
		var granted: Dictionary = bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W03","levels":level})
		if should_check: check(granted.ok,"星砕きを全段取得する")
		bridge.command("dev_grant_equipment",{"kind":"trait","id":"T34","levels":2})
		bridge.command("dev_grant_equipment",{"kind":"trait","id":"T11","levels":2})
		bridge.command("dev_post_scatter",{"interval":0,"projectile":2,"duration":2,"knockback":2,"area":2})
		bridge.command("dev_post_weapon_power",{"damage":2,"followup":0})
		events.clear()
		var parent: int = w03_kill(bridge)
		var dust: Array = core.projectiles_snapshot()
		if should_check: check(dust.size()==2 and dust.all(func(piece): return piece.shatter_depth==1 and piece.hit_ids==[parent]),"全段の発動抽選から初回深さ1の破片を生成する")
		if should_check: check(is_equal_approx(bridge._ui.knockback.chance,definition.params.chance_by_level[level-1]) and bridge._ui.knockback.chain_limit==definition.params.chain_limit_by_level[level-1],"全段の発動率と連鎖上限を生成値から取得する")
		for piece: Dictionary in dust:
			var speed: float = definition.params.speed*(1.0+2.0*config.post_max.increments.projectile_speed)
			if should_check: check(piece.vel.length()>=speed*0.6999 and piece.vel.length()<=speed*1.3001 and is_equal_approx(piece.life,definition.params.life*(1.0+2.0*config.post_max.increments.duration)),"速度と寿命の最大段後補正を元の破片へ渡す")
			if should_check: check(is_equal_approx(piece.damage,config.hull_debris_damage*(1.0+attack.stack_bonus(2))*(1.0+2.0*config.post_max.increments.weapon_damage)) and is_equal_approx(piece.knock,config.hull_debris_knock*(1.0+2.0*config.post_max.increments.knockback)) and is_equal_approx(piece.radius,4.0*1.82*config.character_scale*(1.0+area.stack_bonus(2))*(1.0+2.0*config.post_max.increments.area)),"攻撃力と武器威力・ノックバック・範囲を一度ずつ合成する")
		var types: Array = events.map(func(event): return event.type)
		if should_check: check(types.find(&"kill")>=0 and types.find(&"kill")<types.find(&"hull_scatter"),"撃破通知のあとに船体破片を同期生成する")
		presentation._present_cpp(0.01)
		if should_check: check(presentation.frame_view._knockback_visual!=null and presentation.frame_view._knockback_visual.breaks.size()==1 and presentation.frame_view._barrier_armor.visible,"砕けた輪ときらめき・機体装備を本番表示へ渡す")
		var shapes: Array = bridge.read_render(Rect2(core.ship_snapshot().ship_pos-Vector2(1000,1000),Vector2(2000,2000))).value.shapes
		if should_check: check(shapes.filter(func(shape): return shape.get("debris_style",-1)==1).size()==2,"星屑2個を共通の破片描画へ渡す")
		bridge.command("pause",{"paused":true})
		for tick in 3: bridge.step(1.0/120.0,idle,viewport)
		if should_check: check(core.projectiles_snapshot()==dust,"停止中は破片の位置・寿命・深さを進めない")
		bridge.command("pause",{"paused":false})
		var target_position: Vector2 = dust[0].pos+dust[0].vel.normalized()*40.0
		var target: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":target_position}).value
		core.set_enemy_motion(target,{"held":true,"vel":Vector2.ZERO})
		var saved: Dictionary = bridge.checkpoint()
		events.clear()
		for tick in 12: bridge.step(1.0/120.0,idle,viewport)
		var hit_events: Array = events.filter(func(event): return event.type==&"combat_damage" and event.payload.cause==&"hullDebris" and event.payload.weapon_id>0)
		check(hit_events.any(func(event): return event.payload.shatter_depth==1) and core.projectiles_snapshot().any(func(piece): return piece.shatter_depth==2),"実際の破片の命中から深さを増やした連鎖を同期生成する")
		if retry and level<=2:
			bridge.release_checkpoint(saved.value)
			continue
		presentation._present_cpp(0.01)
		if should_check: check(not presentation.frame_view._knockback_visual.hits.is_empty(),"星屑の命中を小さな光として表示する")
		var expected: Array = core.projectiles_snapshot()
		var expected_visuals: Array = bridge._ui.knockback.visuals.duplicate(true)
		bridge.restore(saved.value)
		bridge.collect_frame()
		presentation._present_cpp(0.01)
		if should_check: check(presentation.frame_view._knockback_visual.breaks.size()==1,"復帰した砕けの残留表示を状態から作り直す")
		for tick in 12: bridge.step(1.0/120.0,idle,viewport)
		if should_check: check(core.projectiles_snapshot()==expected and bridge._ui.knockback.visuals==expected_visuals,"復帰後も抽選・深さ・命中済みID・位置・表示を再現する")
		bridge.command("dev_remove_weapon",{"id":"W03"})
		presentation._present_cpp(0.01)
		if should_check: check(not bridge._ui.knockback.ready and presentation.frame_view._knockback_visual==null and not presentation.frame_view._barrier_armor.visible and core.projectiles_snapshot()==expected,"解除は次の発動と専用表示を止め生成済み破片は残す")
		var remaining := 0.0
		for piece: Dictionary in expected: remaining = maxf(remaining,piece.life)
		for tick in ceili(remaining*120.0)+2: bridge.step(1.0/120.0,idle,viewport)
		if should_check: check(core.projectiles_snapshot().is_empty(),"残る破片を自然寿命で回収する")
		bridge.release_checkpoint(saved.value)
		if failures: break
	if not retry:
		# 深さの上限と半減抽選。通常のRunRandom入力を固定し、率は変えない。
		for level in range(1,definition.level_steps.size()+1):
			var valid = w03_bridge(bytes,446)
			valid.command("dev_grant_equipment",{"kind":"weapon","id":"W03","levels":level})
			w03_kill(valid,definition.params.chain_limit_by_level[level-1])
			check(valid._core.projectiles_snapshot().size()==2 and valid._core.projectiles_snapshot().all(func(piece): return piece.shatter_depth==definition.params.chain_limit_by_level[level-1]+1),"上限ちょうどの親は次の深さの破片を生成する")
			valid.dispose()
			var control = w03_bridge(bytes,446)
			w03_kill(control)
			var control_rng: String = control._core.inspect().rng_state
			control.dispose()
			var over = w03_bridge(bytes,446)
			over.command("dev_grant_equipment",{"kind":"weapon","id":"W03","levels":level})
			w03_kill(over,definition.params.chain_limit_by_level[level-1]+1)
			check(over._core.projectiles_snapshot().is_empty() and over._core.inspect().rng_state==control_rng,"上限を超える親では生成せず抽選も消費しない")
			over.dispose()
			var decay_seed: int = [303,313,314,306,306][level-1]
			for depth in [0,1]:
				var decay = w03_bridge(bytes,decay_seed)
				decay.command("dev_grant_equipment",{"kind":"weapon","id":"W03","levels":level})
				w03_kill(decay,depth)
				check(decay._core.projectiles_snapshot().size()==(2 if depth==0 else 0),"同じ抽選値が初回では発動し深さ1の半減後は発動しない")
				decay.dispose()
		for reason in ["afterimage","capture","small","boss"]:
			var guarded = w03_bridge(bytes,446)
			guarded.command("dev_grant_equipment",{"kind":"weapon","id":"W03","levels":5})
			w03_kill(guarded,0,"afterimage" if reason=="afterimage" else "shot",0.25 if reason=="small" else 0.0,reason=="capture",reason=="boss")
			check(guarded._core.projectiles_snapshot().is_empty(),"分身・船体の取得・小さいとどめ・ボスでは発動しない: %s" % reason)
			guarded.dispose()
		bridge.restore(initial.value)
		bridge.collect_frame()
		bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W03","levels":5})
		bridge.command("dev_grant_equipment",{"kind":"trait","id":"T37","levels":5})
		var source: int = w03_kill(bridge)
		var duplicated: Array = core.projectiles_snapshot()
		check(duplicated.size()>2 and duplicated.all(func(piece): return piece.shatter_depth==1 and piece.hit_ids==[source]),"複製でも元の星砕き深さと命中済みIDを引き継ぐ")
	bridge.restore(initial.value)
	bridge.collect_frame()
	bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W03","levels":1})
	await trait_select_upgrade(session,"W03",config,idle,viewport)
	bridge.release_checkpoint(initial.value)
	session.free()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"星砕きの状態と表示に実行エラーがない: %s" % [capture.messages()])

func check_cpp_w04() -> void:
	var errors := ErrorCapture.new()
	OS.add_logger(errors)
	var config := trait_test_config()
	config.xp_base = 100000.0
	var session = await trait_test_session("W04",config,604)
	if session==null:
		OS.remove_logger(errors)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(1280,720)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("set_settings",{"hitstop":false})
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var initial: Dictionary = bridge.checkpoint()
	var definition: WeaponDef = ContentManager.definition(&"weapons",&"W04")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	var retry: bool = "--cpp-w04-fixes" in OS.get_cmdline_user_args()
	for level in range(5 if retry else 1,definition.level_steps.size()+1):
		bridge.restore(initial.value)
		bridge.collect_frame()
		var grant: Dictionary = bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W04","levels":level})
		if not retry or level>1: check(grant.ok,"震空を全段取得する")
		bridge.command("dev_grant_equipment",{"kind":"trait","id":"T34","levels":2})
		bridge.command("dev_post_scatter",{"interval":0,"projectile":0,"duration":0,"knockback":2,"area":2})
		bridge.command("dev_post_weapon_power",{"damage":2,"followup":0})
		var origin: Vector2 = core.ship_snapshot().ship_pos
		var struck: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":origin+Vector2(100,0)}).value
		core.set_enemy_motion(struck,{"held":true,"vel":Vector2.ZERO})
		trait_start_trace(bridge,1000.0)
		for tick in 30:
			var step: Dictionary = bridge.step(1.0/120.0,idle,viewport)
			if not retry or level>1: check(step.ok and bridge.read_frame().ok and bridge.delivery_error.ok,"接触から波の発動まで通知を配信する")
			if not bridge._ui.contact_wave.waves.is_empty(): break
		check(not bridge._ui.contact_wave.waves.is_empty(),"実際の体当たりから接触波を発動する")
		if bridge._ui.contact_wave.waves.is_empty(): break
		var wave: Dictionary = bridge._ui.contact_wave.waves[0]
		var tier: int = definition.level_steps[level-1]
		var area: TraitDef = ContentManager.definition(&"traits",&"T34")
		var expected_radius: float = definition.params.radius*(1.0+0.1*(tier-1))*(1.0+area.stack_bonus(2))*(1.0+2.0*config.post_max.increments.area)
		if not retry or level>1: check(is_equal_approx(wave.radius,expected_radius) and is_equal_approx(wave.damage,bridge._ui.attack_power*definition.params.damage*(1.0+0.3*(tier-1))*(1.0+2.0*config.post_max.increments.weapon_damage)),"全段の半径と発動時威力・最大段後倍率を一度だけ合成する")
		core.step_draw(1.0)
		var target: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":wave.pos+Vector2(0,60)}).value
		core.set_enemy_motion(target,{"held":true,"vel":Vector2.ZERO})
		var hp: float = core.enemies_snapshot().filter(func(e): return e.id==target)[0].hp
		for tick in 240:
			bridge.step(1.0/120.0,idle,viewport)
			if bridge._ui.contact_wave.waves.is_empty(): break
			if bridge._ui.contact_wave.waves[0].caught.any(func(h): return h.id==target and h.age>0.05): break
		if bridge._ui.contact_wave.waves.is_empty():
			check(false,"波が消えるまでに対象を捕捉する")
			break
		wave = bridge._ui.contact_wave.waves[0]
		check(wave.caught.any(func(h): return h.id==target) and core.enemies_snapshot().filter(func(e): return e.id==target)[0].pos[1]>wave.pos.y+60.0,"IDと経過時間を保存し別のheld状態の敵も押し運ぶ")
		presentation._present_cpp(0.01)
		check(presentation.frame_view._contact_wave_visual!=null and not presentation.frame_view._contact_wave_visual.quakes.is_empty() and not presentation.pipeline._ripples.is_empty(),"閃光・火花と画面の歪みを通常表示へ渡す")
		var render: Dictionary = bridge.read_render(Rect2(wave.pos-Vector2(1000,1000),Vector2(2000,2000))).value
		var distorted := false
		for batch: Dictionary in render.batches:
			var at: int = batch.ids.find(target)
			if at>=0:
				var x := Vector2(batch.transforms[at*6],batch.transforms[at*6+1])
				var y := Vector2(batch.transforms[at*6+2],batch.transforms[at*6+3])
				distorted = absf(x.length()-y.length())>0.01
		check(distorted,"捕捉中の敵本体と装甲へ同じ変形を渡す")
		var saved: Dictionary = bridge.checkpoint()
		var held_state: Dictionary = bridge._ui.contact_wave.duplicate(true)
		bridge.command("pause",{"paused":true})
		bridge.step(1.0/120.0,idle,viewport)
		check(bridge._ui.contact_wave==held_state,"停止中は捕捉と波の時計を止める")
		bridge.command("pause",{"paused":false})
		var steps := 0
		for tick in 240:
			bridge.step(1.0/120.0,idle,viewport)
			steps += 1
			if bridge._ui.contact_wave.waves[0].done.has(target): break
		var after: Dictionary = bridge._ui.contact_wave.duplicate(true)
		var enemies: Array = core.enemies_snapshot()
		var victims: Array = enemies.filter(func(e): return e.id==target)
		var damaged_once: bool = hp<=wave.damage if victims.is_empty() else is_equal_approx(victims[0].hp,hp-wave.damage)
		check(damaged_once and after.waves[0].done.has(target) and not after.waves[0].caught.any(func(h): return h.id==target),"捕捉時間の後に一度だけ命中し捕捉を解く")
		bridge.restore(saved.value)
		bridge.collect_frame()
		check(bridge._ui.contact_wave==held_state,"途中復帰で捕捉IDと経過・未命中状態を戻す")
		for tick in steps: bridge.step(1.0/120.0,idle,viewport)
		check(bridge._ui.contact_wave==after and core.enemies_snapshot()==enemies,"復帰後も押し運びと命中済み集合・HPを再現する")
		bridge.command("dev_remove_weapon",{"id":"W04"})
		presentation._present_cpp(0.01)
		check(not bridge._ui.contact_wave.ready and bridge._ui.contact_wave.waves.is_empty() and presentation.frame_view._contact_wave_visual==null and not presentation.pipeline._ripples.is_empty(),"途中解除で捕捉・波・変形を片付け、画面の歪みは独立して残す")
		bridge.release_checkpoint(saved.value)
		if failures: break
	bridge.release_checkpoint(initial.value)
	session.free()
	await get_tree().process_frame
	OS.remove_logger(errors)
	check(errors.count()==0,"震空の状態と表示に実行エラーがない: %s" % [errors.messages()])

func check_cpp_w08() -> void:
	var errors := ErrorCapture.new()
	OS.add_logger(errors)
	var config := trait_test_config()
	config.xp_base = 100000.0
	var session = await trait_test_session("W08",config,608)
	if session==null:
		OS.remove_logger(errors)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(1280,720)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("set_settings",{"hitstop":false})
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var initial: Dictionary = bridge.checkpoint()
	var definition: WeaponDef = ContentManager.definition(&"weapons",&"W08")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	var retry: bool = "--cpp-w08-fixes" in OS.get_cmdline_user_args()
	for level in range(1,definition.level_steps.size()+1):
		bridge.restore(initial.value)
		bridge.collect_frame()
		check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W08","levels":level}).ok,"発進波を全段取得する")
		var origin: Vector2 = core.ship_snapshot().ship_pos
		trait_start_trace(bridge,1200.0)
		var target_pos := Vector2.INF
		var enemy_definition: EnemyDef = ContentManager.definition(&"enemies",&"splitling")
		for tick in 240:
			var step: Dictionary = bridge.step(1.0/120.0,idle,viewport)
			if not retry or level>1: check(step.ok and bridge.read_frame().ok and bridge.delivery_error.ok,"発進波の固定更新と通知が成功する")
			var sonic: Dictionary = bridge._ui.sonic
			if sonic.pulse<=0.05: continue
			for frame: Dictionary in sonic.frames:
				if frame.age<0.4: continue
				var candidate: Vector2 = frame.pos+Vector2(0,sonic.wave_speed*frame.age)
				var ship_distance: float = candidate.distance_to(core.ship_snapshot().ship_pos)
				if ship_distance<150.0 or ship_distance>sonic.wave_speed*sonic.life+core.ship_snapshot().ship_vel.length()*sonic.life-50.0: continue
				var overlaps := 0
				for ring: Dictionary in sonic.frames:
					if sonic.wave_speed*ring.age>2.0*1.82*config.character_scale and absf(candidate.distance_to(ring.pos)-sonic.wave_speed*ring.age)<4.0*1.82*config.character_scale+enemy_definition.radius: overlaps += 1
				if overlaps>=3: target_pos = candidate; break
			if target_pos.is_finite(): break
		check(target_pos.is_finite(),"実際に残した輪の後方の重なり位置を取得する")
		if not target_pos.is_finite(): break
		var target: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":target_pos}).value
		core.set_enemy_motion(target,{"held":true,"vel":Vector2.ZERO})
		var hp: float = core.enemies_snapshot().filter(func(e): return e.id==target)[0].hp
		for tick in 10:
			bridge.step(1.0/120.0,idle,viewport)
			if not bridge._ui.sonic.pending.is_empty(): break
		check(bridge._ui.sonic.hits.has(target) and not bridge._ui.sonic.pending.is_empty(),"距離で残した3つ以上の輪が後方の敵へ重なる")
		if bridge._ui.sonic.pending.is_empty(): break
		var before: Dictionary = bridge._ui.sonic.duplicate(true)
		check(is_equal_approx(before.wave_speed,definition.params.speed_by_level[level-1]*1.82*config.character_scale) and before.pending[0].age<before.pending[0].delay and is_equal_approx(before.pending[0].damage,bridge._ui.attack_power*definition.params.damage_by_level[level-1]),"全段の生成値を輪の速さと遅延威力へ使う")
		presentation._present_cpp(0.01)
		check(presentation.frame_view._sonic_visual!=null and presentation.frame_view._sonic_visual._rings.multimesh.visible_instance_count>0 and not presentation.frame_view._sonic_visual.pushes.is_empty(),"発進波の輪・蒸気・衝撃の弧を本番表示へ渡す")
		var saved: Dictionary = bridge.checkpoint()
		bridge.command("pause",{"paused":true})
		bridge.step(1.0/120.0,idle,viewport)
		check(bridge._ui.sonic==before,"停止中は輪・押し運びと遅延時間を進めない")
		bridge.command("pause",{"paused":false})
		for tick in 18: bridge.step(1.0/120.0,idle,viewport)
		var after: Dictionary = bridge._ui.sonic.duplicate(true)
		var enemies: Array = core.enemies_snapshot()
		var victim: Dictionary = enemies.filter(func(e): return e.id==target)[0]
		check(after.pending[0].hit and is_equal_approx(victim.hp,hp-before.pending[0].damage) and victim.pos[1]>target_pos.y,"減衰して横後方へ押し運び遅延後に一度だけ命中する")
		bridge.restore(saved.value)
		bridge.collect_frame()
		for tick in 18: bridge.step(1.0/120.0,idle,viewport)
		check(bridge._ui.sonic==after and core.enemies_snapshot()==enemies,"途中復帰後も輪・命中ID・減衰速度と遅延威力を再現する")
		bridge.command("dev_grant_equipment",{"kind":"trait","id":"T34","levels":2})
		bridge.command("dev_post_scatter",{"interval":0,"projectile":0,"duration":2,"knockback":0,"area":2})
		var area: TraitDef = ContentManager.definition(&"traits",&"T34")
		check(is_equal_approx(bridge._ui.sonic.wave_speed,definition.params.speed_by_level[level-1]*1.82*config.character_scale*(1.0+area.stack_bonus(2))*(1.0+2.0*config.post_max.increments.area)) and is_equal_approx(bridge._ui.sonic.life,definition.params.life*(1.0+2.0*config.post_max.increments.duration)) and bridge._ui.sonic.frames==after.frames,"範囲特性と最大段後強化で既存輪の速さと寿命だけを再計算する")
		bridge.command("dev_remove_weapon",{"id":"W08"})
		presentation._present_cpp(0.01)
		check(not bridge._ui.sonic.ready and bridge._ui.sonic.frames.is_empty() and bridge._ui.sonic.pending.is_empty() and presentation.frame_view._sonic_visual==null,"途中解除で輪・押し運びと専用表示を片付ける")
		bridge.release_checkpoint(saved.value)
		if failures: break
	bridge.release_checkpoint(initial.value)
	session.free()
	await get_tree().process_frame
	OS.remove_logger(errors)
	check(errors.count()==0,"発進波の状態と表示に実行エラーがない: %s" % [errors.messages()])

func check_cpp_w17() -> void:
	var errors := ErrorCapture.new()
	OS.add_logger(errors)
	var config := trait_test_config()
	config.xp_base = 100000.0
	var session = await trait_test_session("W17",config,617)
	if session==null:
		OS.remove_logger(errors)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(1280,720)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("set_settings",{"hitstop":false})
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var initial: Dictionary = bridge.checkpoint()
	var definition: WeaponDef = ContentManager.definition(&"weapons",&"W17")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	for level in range(1,definition.level_steps.size()+1):
		bridge.restore(initial.value)
		bridge.collect_frame()
		check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W17","levels":level}).ok,"接触電撃を全段取得する")
		var origin: Vector2 = core.ship_snapshot().ship_pos
		var roots: Array[int] = []
		for j in 13:
			var pos: Vector2 = origin if j==0 else origin+Vector2.from_angle((j-1)*TAU/12.0)*100.0
			var id: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":pos}).value
			core.set_enemy_motion(id,{"held":true,"vel":Vector2.ZERO})
			roots.append(id)
		core.collide_ship(origin,1.0)
		bridge.command("set_ui_overlay",{"active":false})
		check(bridge.read_frame().ok and bridge.delivery_error.ok and bridge._ui.contact_arc.visuals.size()==1,"同期命中と電撃通知を配信する")
		var arc: Dictionary = bridge._ui.contact_arc.duplicate(true)
		var visual: Dictionary = arc.visuals[0]
		check(visual.segments.size()==2*(1+level*int(definition.params.chains_per_level)) and is_equal_approx(arc.ready_at,bridge._ui.world_time+definition.params.cooldown),"全段の追加対象枠と世界時刻の待ちを使う")
		var hp: float = ContentManager.definition(&"enemies",&"splitling").hp
		var damage: float = bridge._ui.attack_power*definition.params.damage*(1.0+0.3*(definition.level_steps[level-1]-1))
		var hit: Array = core.enemies_snapshot().filter(func(v): return v.id!=roots[0] and is_equal_approx(v.hp,hp-damage))
		check(hit.size()==level*int(definition.params.chains_per_level),"枝分けして同じ敵を重複せず即時命中する")
		presentation._present_cpp(0.01)
		check(presentation.frame_view._contact_arc_visual!=null and presentation.frame_view._contact_arc_visual._frame.size()==1 and presentation.frame_view._contact_arc_visual._probe.visible,"電撃の全線分と機体の装備を本番表示へ渡す")
		var saved: Dictionary = bridge.checkpoint()
		if level==1:
			bridge.command("set_settings",{"hitstop":true})
			trait_start_trace(bridge,1200.0)
			bridge.command("dev_damage",{"entity_id":roots[0],"amount":0.01,"cause":"ram","crit":true})
			var visual_age: float = bridge._ui.contact_arc.visuals[0].age
			check(bridge._ui.hitstop>0.0,"表示時計を比べるヒットストップを作る")
			bridge.step(1.0/120.0,idle,viewport)
			check(is_equal_approx(bridge._ui.contact_arc.visuals[0].age,visual_age+1.0/120.0),"電撃表示は元の実秒に従いヒットストップ中も進む")
			bridge.restore(saved.value)
			bridge.collect_frame()
		bridge.command("pause",{"paused":true})
		bridge.step(1.0/120.0,idle,viewport)
		check(bridge._ui.contact_arc==arc,"停止中は待ちと電撃表示を止める")
		bridge.command("pause",{"paused":false})
		for tick in 5: bridge.step(1.0/120.0,idle,viewport)
		var after: Dictionary = bridge._ui.contact_arc.duplicate(true)
		var enemies: Array = core.enemies_snapshot()
		bridge.restore(saved.value)
		bridge.collect_frame()
		for tick in 5: bridge.step(1.0/120.0,idle,viewport)
		check(bridge._ui.contact_arc==after and core.enemies_snapshot()==enemies,"途中復帰で待ち時刻と電撃の表示・命中結果を再現する")
		var another: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":core.ship_snapshot().ship_pos}).value
		core.set_enemy_motion(another,{"held":true,"vel":Vector2.ZERO})
		core.collide_ship(core.ship_snapshot().ship_pos,1.0)
		bridge.command("set_ui_overlay",{"active":false})
		check(bridge._ui.contact_arc.ready_at==arc.ready_at and bridge._ui.contact_arc.visuals.size()==1,"待ちの途中の別の接触では再発動しない")
		if level<definition.level_steps.size():
			bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W17","levels":1})
			check(bridge._ui.contact_arc.ready_at==arc.ready_at,"段が変わってもクールダウンを戻さない")
		bridge.command("dev_remove_weapon",{"id":"W17"})
		presentation._present_cpp(0.01)
		check(not bridge._ui.contact_arc.ready and bridge._ui.contact_arc.visuals.is_empty() and presentation.frame_view._contact_arc_visual==null,"途中解除で電撃の待ちと専用表示を片付ける")
		bridge.release_checkpoint(saved.value)
		if failures: break
	bridge.release_checkpoint(initial.value)
	session.free()
	await get_tree().process_frame
	OS.remove_logger(errors)
	check(errors.count()==0,"接触電撃の状態と表示に実行エラーがない: %s" % [errors.messages()])

func check_cpp_w04_clock() -> void:
	var errors := ErrorCapture.new()
	OS.add_logger(errors)
	var session = await trait_test_session("W04",trait_test_config(),604)
	if session==null:
		OS.remove_logger(errors)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(1280,720)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("set_settings",{"hitstop":false})
	bridge.command("dev_remove_weapon",{"id":"W01"})
	bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W04","levels":1})
	var origin: Vector2 = core.ship_snapshot().ship_pos
	var target: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":origin+Vector2(100,0)}).value
	core.set_enemy_motion(target,{"held":true,"vel":Vector2.ZERO})
	trait_start_trace(bridge,1200.0)
	for tick in 30:
		bridge.step(1.0/120.0,idle,viewport)
		if not bridge._ui.contact_wave.waves.is_empty(): break
	check(not bridge._ui.contact_wave.waves.is_empty() and not bridge._ui.contact_wave.ripples.is_empty(),"波と独立した実秒の歪みを同じ接触から発生させる")
	if bridge._ui.contact_wave.waves.is_empty() or bridge._ui.contact_wave.ripples.is_empty():
		session.free()
		OS.remove_logger(errors)
		return
	var before: Dictionary = bridge._ui.contact_wave.duplicate(true)
	var step: Dictionary = bridge.step(1.0/120.0,idle,viewport)
	check(step.ok and bridge.read_frame().ok and bridge.delivery_error.ok,"独立表示時計の固定更新と通知を配信する")
	var wave_dt: float = bridge._ui.contact_wave.waves[0].age-before.waves[0].age
	var ripple_dt: float = bridge._ui.contact_wave.ripples[0].age-before.ripples[0].age
	check(wave_dt>0.0 and wave_dt<1.0/120.0 and is_equal_approx(ripple_dt,1.0/120.0),"なぞり中は波・閃光の世界秒と画面の歪みの実秒を分ける")
	bridge.command("set_settings",{"hitstop":true})
	var hit_target: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":core.ship_snapshot().ship_pos+Vector2(0,200)}).value
	bridge.command("dev_damage",{"entity_id":hit_target,"amount":0.01,"cause":"ram","crit":true})
	before = bridge._ui.contact_wave.duplicate(true)
	check(bridge._ui.hitstop>1.0/120.0,"歪みの実秒を確認するヒットストップを作る")
	bridge.step(1.0/120.0,idle,viewport)
	check(bridge._ui.contact_wave.waves==before.waves and is_equal_approx(bridge._ui.contact_wave.ripples[0].age,before.ripples[0].age+1.0/120.0),"ヒットストップ中は波・閃光を止め画面の歪みだけ進める")
	bridge.command("set_ui_overlay",{"active":true})
	before = bridge._ui.contact_wave.duplicate(true)
	bridge.step(1.0/120.0,idle,viewport)
	check(bridge._ui.contact_wave==before,"UI停止中は世界秒と実秒の両方を止める")
	bridge.command("set_ui_overlay",{"active":false})
	before = bridge._ui.contact_wave.duplicate(true)
	var world_before: float = bridge._ui.world_time
	core.set_run_guards({"controls_locked":true})
	bridge.step(1.0/120.0,idle,viewport)
	check(bridge._ui.contact_wave.waves[0].age==before.waves[0].age and is_equal_approx(bridge._ui.contact_wave.waves[0].visual_age,before.waves[0].visual_age+bridge._ui.world_time-world_before),"操作ロック中も閃光は元の世界秒で進み物理の波を待たない")
	core.set_run_guards({"controls_locked":false})
	var saved: Dictionary = bridge.checkpoint()
	for tick in 120:
		bridge.step(1.0/120.0,idle,viewport)
		if bridge._ui.contact_wave.ripples.is_empty(): break
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	presentation._present_cpp(0.01)
	check(bridge._ui.contact_wave.ripples.is_empty() and not bridge._ui.contact_wave.waves.is_empty() and presentation.pipeline._ripples.is_empty() and not presentation.frame_view._contact_wave_visual.quakes.is_empty(),"画面の歪みが先に終わっても物理の波と世界秒の閃光状態を残す")
	bridge.restore(saved.value)
	bridge.collect_frame()
	var held_ripples: Array = bridge._ui.contact_wave.ripples.duplicate(true)
	bridge.command("dev_remove_weapon",{"id":"W04"})
	presentation._present_cpp(0.01)
	check(not bridge._ui.contact_wave.ready and bridge._ui.contact_wave.waves.is_empty() and bridge._ui.contact_wave.ripples==held_ripples and presentation.frame_view._contact_wave_visual==null and not presentation.pipeline._ripples.is_empty(),"装備の解除で物理の波と閃光を終えても画面の歪みは元の寿命まで残す")
	var unowned: Dictionary = bridge.checkpoint()
	bridge.step(1.0/120.0,idle,viewport)
	check(is_equal_approx(bridge._ui.contact_wave.ripples[0].age,held_ripples[0].age+1.0/120.0),"装備の解除後も画面の歪みの時計だけ進める")
	bridge.restore(unowned.value)
	bridge.collect_frame()
	presentation._present_cpp(0.01)
	check(not bridge._ui.contact_wave.ready and bridge._ui.contact_wave.ripples==held_ripples and not presentation.pipeline._ripples.is_empty(),"途中復帰で装備から独立した残留表示と経過時間を戻す")
	for tick in 120:
		bridge.step(1.0/120.0,idle,viewport)
		if bridge._ui.contact_wave.ripples.is_empty(): break
	presentation._present_cpp(0.01)
	check(bridge._ui.contact_wave.ripples.is_empty() and presentation.pipeline._ripples.is_empty(),"装備の解除後の歪みも0.58実秒で終了する")
	bridge.release_checkpoint(unowned.value)
	bridge.release_checkpoint(saved.value)
	session.free()
	await get_tree().process_frame
	OS.remove_logger(errors)
	check(errors.count()==0,"独立した歪み表示の確認に実行エラーがない: %s" % [errors.messages()])

func check_cpp_t05() -> void:
	OS.add_logger(capture)
	var config := trait_test_config()
	config.xp_base = 100000.0
	var session = await trait_test_session("T05",config,605)
	if session==null:
		OS.remove_logger(capture)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(640,480)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("set_settings",{"hitstop":false})
	bridge.command("dev_remove_weapon",{"id":"W01"})
	check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T05","levels":1}).ok,"チェインショックをカードと同じ取得入口で得る")
	check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T33","levels":1}).ok,"同時に撃破を読む特性を取得する")
	var definition: TraitDef = ContentManager.definition(&"traits",&"T05")
	var every: int = int(definition.params.kills_base+definition.params.kills_per)
	var cues: Array = []
	bridge.subscribe("t05",func(frame: Dictionary):
		for event: Dictionary in frame.events:
			if event.type==&"chain_shock": cues.append(event.payload)
		return true)
	trait_kill_fixture(bridge)
	check(bridge._ui.kill_sonic.kills==0 and cues.is_empty(),"発進する前の撃破を連鎖へ数えない")
	trait_start_trace(bridge,400.0)
	for i in every-1: trait_kill_fixture(bridge)
	check(bridge._ui.kill_sonic.kills==every-1 and bridge._ui.kill_sonic.waves.is_empty(),"必要な撃破数の直前では波を出さない")
	trait_kill_fixture(bridge)
	check(bridge._ui.kill_sonic.chains==1 and cues.size()==1,"境界の撃破で一度だけ最初の波を出す")
	var wave: Dictionary = bridge._ui.kill_sonic.waves[0]
	check(is_equal_approx(wave.radius,definition.params.radius_base+definition.params.radius_per) and wave.generation==0 and wave.age==0.0,"生成値の半径と最初の世代・未更新の時計を保持する")
	var before: Dictionary = bridge._ui.kill_sonic.duplicate(true)
	bridge.command("pause",{"paused":true})
	bridge.step(0.05,idle,viewport)
	check(bridge._ui.kill_sonic==before,"ポーズでは波と連鎖の時計を止める")
	bridge.command("pause",{"paused":false})
	# 同じ波の命中が次の波を追加する場面。次の波を同じ回で進めない。
	for i in every*3:
		var spawned: Dictionary = bridge.command("dev_spawn",{"definition_id":"splitling","position":wave.pos+Vector2(5.0,0.0)})
		check(spawned.ok,"連鎖の相手を同じ生成入口で配置する")
	var saved: Dictionary = bridge.checkpoint()
	check(saved.ok,"波の命中前を保持する")
	bridge.step(1.0/120.0,idle,viewport)
	var after: Dictionary = bridge._ui.kill_sonic.duplicate(true)
	check(after.chains==definition.params.limit_by_level[0] and cues.size()==after.chains,"波の撃破から連鎖し、同じ発進の上限で止める")
	check(after.waves.size()>1 and after.waves[1].age==0.0 and after.waves[0].age>0.0,"命中中に追加した波は次の更新から進める")
	if after.waves.size()>1:
		check(is_equal_approx(after.waves[1].radius,wave.radius*definition.params.radius_decay) and is_equal_approx(after.waves[1].damage,wave.damage*definition.params.damage_decay),"連鎖する半径と威力を元の割合で減らす")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	presentation._present_cpp(0.01)
	check(presentation.frame_view._kill_sonic_visual!=null and not presentation.frame_view._kill_sonic_visual.waves.is_empty() and presentation.frame_view._kill_sonic_visual._rings.multimesh.visible_instance_count>0,"連鎖した波の世代と輪の形を通常表示へ渡す")
	check(bridge.read_frame().ok and bridge.delivery_error.ok,"波の通知を公開契約と購読へ正常に届ける")
	var expected_enemies: Array = core.enemies_snapshot()
	check(bridge.restore(saved.value).ok,"命中前へ復帰する")
	bridge.collect_frame()
	cues.clear()
	bridge.step(1.0/120.0,idle,viewport)
	check(bridge._ui.kill_sonic==after and core.enemies_snapshot()==expected_enemies,"復帰後の命中履歴と波の追加順を再現する")
	bridge.release_checkpoint(saved.value)
	for tick in 120:
		bridge.step(1.0/120.0,idle,viewport)
		if not bridge._ui.draw.tracing: break
	check(not bridge._ui.kill_sonic.active,"なぞり終了で新しい連鎖の受付を止める")
	var chains: int = bridge._ui.kill_sonic.chains
	trait_kill_fixture(bridge)
	check(bridge._ui.kill_sonic.chains==chains,"終了後の撃破で連鎖を追加しない")
	trait_start_trace(bridge,400.0)
	check(bridge._ui.kill_sonic.active and bridge._ui.kill_sonic.kills==0 and bridge._ui.kill_sonic.chains==0,"次の発進で撃破数と上限を初期化する")
	check(bridge.command("dev_remove_trait",{"id":"T05"}).ok and not bridge._ui.kill_sonic.ready and bridge._ui.kill_sonic.waves.is_empty(),"解除で波と受付を終了する")
	presentation._present_cpp(0.01)
	check(presentation.frame_view._kill_sonic_visual==null,"解除した連鎖の表示を回収する")
	bridge.unsubscribe("t05")
	session.free()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"チェインショックの状態・命中・表示に実行エラーがない: %s" % [capture.messages()])

func check_cpp_w21() -> void:
	var errors := ErrorCapture.new()
	OS.add_logger(errors)
	var config := trait_test_config()
	config.xp_base = 1000000.0
	var session = await trait_test_session("W21",config,621)
	if session==null:
		OS.remove_logger(errors)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(1280,720)}
	check(bridge.step(1.0/120.0,idle,viewport).ok,"初期更新を通す")
	bridge.command("set_settings",{"hitstop":false})
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var initial: Dictionary = bridge.checkpoint()
	var definition: WeaponDef = ContentManager.definition(&"weapons",&"W21")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	for level in range(1,definition.level_steps.size()+1):
		check(bridge.restore(initial.value).ok and bridge.collect_frame().ok,"全段の基準を復元する")
		check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W21","levels":level}).ok,"牽引船体を全段取得する")
		check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W03","levels":5}).ok,"星砕きより先に捕獲する条件を用意する")
		var start: Vector2 = trait_start_trace(bridge,1200.0)
		var sources: Array[int] = []
		for j in 6:
			var id: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":start+Vector2(0,15.0*j)}).value
			check(bridge.command("dev_damage",{"entity_id":id,"amount":100000.0,"cause":"ram"}).ok,"撃破入口から船体を回収する")
			sources.append(id)
		check(bridge._ui.mass_tow.cargo.size()==6 and core.projectiles_snapshot().is_empty(),"死亡した船体を値コピーし星砕きを抑える")
		check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"捕獲通知を表示と記録へ配信する")
		check(bridge.step(1.0/120.0,idle,viewport).ok,"元の敵の行を回収する更新を通す")
		check(core.enemies_snapshot().is_empty() and bridge._ui.mass_tow.cargo.size()==6,"元の敵が消えても牽引する")
		var replacement: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":start+Vector2(0,900)}).value
		core.set_enemy_motion(replacement,{"held":true,"vel":Vector2.ZERO})
		check(bridge._ui.mass_tow.cargo[0].source_id==sources[0],"再利用した敵の行と船体を混同しない")
		presentation._present_cpp(0.01)
		check(presentation.frame_view._mass_tow_visual!=null and not presentation.frame_view._hull_displays.is_empty(),"船体の絵・房の光と鎖を本番表示へ渡す")
		var towing: Dictionary = bridge.checkpoint()
		bridge.command("pause",{"paused":true})
		var paused: Dictionary = bridge._ui.mass_tow.duplicate(true)
		bridge.step(1.0/120.0,idle,viewport)
		check(bridge._ui.mass_tow==paused,"停止中は牽引と発射時計を止める")
		bridge.command("pause",{"paused":false})
		for tick in 5: bridge.step(1.0/120.0,idle,viewport)
		var expected: Dictionary = bridge._ui.mass_tow.duplicate(true)
		check(bridge.restore(towing.value).ok and bridge.collect_frame().ok,"牽引途中の値を復元する")
		for tick in 5: bridge.step(1.0/120.0,idle,viewport)
		check(bridge._ui.mass_tow==expected,"揺れ・相対位置・角度と発射時計を再現する")
		check(bridge.restore(towing.value).ok and bridge.collect_frame().ok,"解除条件の牽引値を復元する")
		bridge.command("dev_remove_weapon",{"id":"W21"})
		presentation._present_cpp(0.01)
		check(bridge._ui.mass_tow.cargo.is_empty() and presentation.frame_view._mass_tow_visual==null,"途中解除で未発射船体と専用表示を片付ける")
		check(bridge.restore(towing.value).ok and bridge.collect_frame().ok,"解除前の牽引状態へ戻せる")
		for tick in 120:
			bridge.step(1.0/120.0,idle,viewport)
			if not bridge._ui.tracing: break
		check(not bridge._ui.tracing and bridge._ui.mass_tow.cargo.all(func(c): return c.ready),"描線の終了で船体を発射可能にする")
		var held: Dictionary = bridge.checkpoint()
		var emitted := 0
		var interval: float = definition.params.interval/(1.0+0.12*(definition.level_steps[level-1]-1))
		var previous: float = bridge._ui.mass_tow.fire_t
		for tick in 100:
			var steer := idle.duplicate()
			steer.stick_active = true
			steer.stick = Vector2.DOWN if tick%2==0 else Vector2.UP
			check(bridge.step(1.0/120.0,steer,viewport).ok and bridge.read_frame().ok and bridge.delivery_error.ok,"船体の発射と通知を更新する")
			var value: Dictionary = bridge._ui.mass_tow
			var delta: int = 6-value.cargo.size()-emitted
			if delta>0:
				var shots: Array = core.projectiles_snapshot().filter(func(v): return v.get("source_id",-1) in sources)
				check(shots.size()==emitted+delta,"船体を共通の貫通弾へ渡す")
				var shot: Dictionary = shots[-1]
				check(is_equal_approx(shot.damage,bridge._ui.attack_power*definition.params.damage*(1.0+0.3*(definition.level_steps[level-1]-1))*maxf(1.0,shot.radius/definition.params.size_ref)) and absf((shot.vel as Vector2).length()-definition.params.shot_speed)<0.001,"全段の威力と勢いを足さない発射速度を保つ")
				check((shot.vel as Vector2).normalized().is_equal_approx(bridge._ui.ship.ship_heading),"発射するごとに現在の機首を読む")
				if not value.cargo.is_empty(): check(absf(value.fire_t-(previous-1.0/120.0+interval*delta))<0.0001,"発射時計の負の余りへ間隔を足す")
				emitted += delta
			previous = value.fire_t
			if value.cargo.is_empty(): break
		check(emitted==6 and bridge._ui.mass_tow.fire_t==0.0,"全船体を撃ち出すと発射時計を戻す")
		var fired: Array = core.projectiles_snapshot()
		var after: Dictionary = bridge._ui.mass_tow.duplicate(true)
		check(bridge.restore(held.value).ok and bridge.collect_frame().ok,"発射待ちへ途中復帰する")
		# 発射中の結果は牽引中と別に、同じ入力列で保持と復帰を比べる。
		for tick in 100:
			var steer := idle.duplicate()
			steer.stick_active = true
			steer.stick = Vector2.DOWN if tick%2==0 else Vector2.UP
			bridge.step(1.0/120.0,steer,viewport)
			if bridge._ui.mass_tow.cargo.is_empty(): break
		check(bridge._ui.mass_tow==after and core.projectiles_snapshot()==fired,"発射待ち復帰で船体の位置・向き・寿命を再現する")
		presentation._present_cpp(0.01)
		check(bridge.delivery_error.ok,"船体の発射演出を配信する")
		bridge.command("dev_remove_weapon",{"id":"W21"})
		check(core.projectiles_snapshot()==fired,"解除後も発射済み船体の自然寿命を保つ")
		bridge.release_checkpoint(held.value)
		bridge.release_checkpoint(towing.value)
		if failures: break
	bridge.release_checkpoint(initial.value)
	session.free()
	await get_tree().process_frame
	OS.remove_logger(errors)
	check(errors.count()==0,"牽引船体の状態と表示に実行エラーがない: %s" % [errors.messages()])

func check_cpp_w22() -> void:
	var errors := ErrorCapture.new()
	OS.add_logger(errors)
	var config := trait_test_config()
	config.xp_base = 1000000.0
	config.base_attack = 1.0
	var session = await trait_test_session("W22",config,622)
	if session==null:
		OS.remove_logger(errors)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(1280,720)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("set_settings",{"hitstop":false})
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var initial: Dictionary = bridge.checkpoint()
	var definition: WeaponDef = ContentManager.definition(&"weapons",&"W22")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	for level in range(1,definition.level_steps.size()+1):
		check(bridge.restore(initial.value).ok and bridge.collect_frame().ok,"双極ビームの全段の基準を復元する")
		check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W22","levels":level}).ok,"双極ビームを全段取得する")
		var from: Vector2 = trait_start_trace(bridge,600.0)
		check(bridge._ui.bipolar.active and bridge._ui.bipolar.origin==from,"発進した位置へ発射器を置く")
		var active: Dictionary = bridge.checkpoint()
		check(core.step_draw(0.01),"なぞり中の距離を進める")
		bridge.command("set_ui_overlay",{"active":false})
		presentation._present_cpp(0.01)
		check(presentation.frame_view._bipolar_visual!=null and presentation.frame_view._bipolar_visual._frame.active,"なぞり中の結晶とねじれた糸を表示する")
		check(core.step_draw(10.0),"描線を最後まで走って終了する")
		bridge.command("set_ui_overlay",{"active":false})
		var to: Vector2 = core.ship_snapshot().ship_pos
		var pending: Dictionary = bridge._ui.bipolar.pending[0]
		check(not bridge._ui.bipolar.active and pending.from==from and pending.to==to and is_equal_approx(pending.delay,0.18),"実際の終了位置まで0.18世界秒の予告を作る")
		var midpoint: Vector2 = from.lerp(to,0.5)
		var hit: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":midpoint}).value
		var outside: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":midpoint+Vector2(0,300)}).value
		for id in [hit,outside]: core.set_enemy_motion(id,{"held":true,"vel":Vector2.ZERO})
		var hp: float = core.enemies_snapshot().filter(func(e): return e.id==hit)[0].hp
		bridge.command("dev_grant_equipment",{"kind":"trait","id":"T11","levels":1})
		var power: float = bridge._ui.attack_power
		var saved: Dictionary = bridge.checkpoint()
		presentation._present_cpp(0.01)
		check(presentation.frame_view._bipolar_visual.charges.size()==1,"両端へ吸い込む予告の光を表示する")
		bridge.command("pause",{"paused":true})
		var stopped: Dictionary = bridge._ui.bipolar.duplicate(true)
		bridge.step(1.0/120.0,idle,viewport)
		check(bridge._ui.bipolar==stopped,"停止中は予告の世界秒を進めない")
		bridge.command("pause",{"paused":false})
		for tick in 22: check(bridge.step(1.0/120.0,idle,viewport).ok,"予告からビームの更新を通す")
		check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"発射・命中・両端の輪を表示と記録へ配信する")
		check(bridge._ui.bipolar.pending.is_empty() and bridge._ui.bipolar.beams.size()==1,"予告が終わると一度だけ発射する")
		var enemies: Array = core.enemies_snapshot()
		var struck: Array = enemies.filter(func(e): return e.id==hit)
		var damage: float = power*definition.params.damage*(1.0+0.3*(definition.level_steps[level-1]-1))
		check((struck.is_empty() if hp<=damage else is_equal_approx(struck[0].hp,hp-damage)) and is_equal_approx(enemies.filter(func(e): return e.id==outside)[0].hp,hp),"発射時の攻撃力と全段の威力で線分内だけに当てる")
		presentation._present_cpp(0.01)
		var visual = presentation.frame_view._bipolar_visual
		check(visual.beams.size()==1 and visual.beams[0].node.visible and visual.beams[0].material.shader==preload("res://shaders/bipolar_beam.gdshader"),"専用shader・ピクセル炎・両端の輪を本番表示へ渡す")
		check(is_equal_approx(bridge._ui.bipolar.beams[0].width_scale,1.0+0.1*(definition.level_steps[level-1]-1)),"全段のビーム幅倍率を表示へ渡す")
		var fired: Dictionary = bridge._ui.bipolar.duplicate(true)
		check(bridge.restore(saved.value).ok and bridge.collect_frame().ok,"予告途中へ復帰する")
		for tick in 22: bridge.step(1.0/120.0,idle,viewport)
		check(core.enemies_snapshot()==enemies and bridge._ui.bipolar==fired,"予告の残り秒と命中・表示の状態を再現する")
		var visible: Dictionary = bridge.checkpoint()
		bridge.command("dev_remove_weapon",{"id":"W22"})
		presentation._present_cpp(0.01)
		check(not bridge._ui.bipolar.ready and bridge._ui.bipolar.beams.is_empty() and presentation.frame_view._bipolar_visual==null,"発射後の途中解除で表示を片付ける")
		check(bridge.restore(visible.value).ok and bridge.collect_frame().ok,"発射したビームの途中へ復帰する")
		presentation._present_cpp(0.01)
		check(presentation.frame_view._bipolar_visual.beams.size()==1 and is_equal_approx(presentation.frame_view._bipolar_visual.beams[0].age,fired.beams[0].age),"復帰したビームを保持した経過秒で表示する")
		check(bridge.restore(saved.value).ok and bridge.collect_frame().ok,"発射前の解除条件へ復帰する")
		bridge.command("dev_remove_weapon",{"id":"W22"})
		for tick in 22: bridge.step(1.0/120.0,idle,viewport)
		check(core.enemies_snapshot().filter(func(e): return e.id==hit)[0].hp==hp and bridge._ui.bipolar.beams.is_empty(),"予告中の解除では発射しない")
		check(bridge.restore(active.value).ok and bridge.collect_frame().ok and bridge._ui.bipolar.active and bridge._ui.bipolar.origin==from,"発進中の復帰で始点を失わない")
		bridge.release_checkpoint(visible.value)
		bridge.release_checkpoint(saved.value)
		bridge.release_checkpoint(active.value)
		if failures: break
	bridge.release_checkpoint(initial.value)
	session.free()
	await get_tree().process_frame
	OS.remove_logger(errors)
	check(errors.count()==0,"双極ビームの状態と表示に実行エラーがない: %s" % [errors.messages()])

func check_cpp_w25() -> void:
	var errors := ErrorCapture.new()
	OS.add_logger(errors)
	var config := trait_test_config()
	config.xp_base = 1000000.0
	var session = await trait_test_session("W25",config,625)
	if session==null:
		OS.remove_logger(errors)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(1280,720)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("set_settings",{"hitstop":false})
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var initial: Dictionary = bridge.checkpoint()
	var definition: WeaponDef = ContentManager.definition(&"weapons",&"W25")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	for level in range(1,definition.level_steps.size()+1):
		var verify := func(condition: bool, message: String):
			if level!=1 or "--cpp-w25-fixes" not in OS.get_cmdline_user_args() or message=="ウィングの実弾が共通衝突から敵へ同期命中する": check(condition,message)
		verify.call(bridge.restore(initial.value).ok and bridge.collect_frame().ok,"ウィングの全段の基準を復元する")
		verify.call(bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W25","levels":level}).ok,"ウィングを全段取得する")
		var center: Vector2 = core.ship_snapshot().ship_pos
		for j in 16:
			var id: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":center+Vector2.from_angle(TAU*j/16.0)*230.0}).value
			core.set_enemy_motion(id,{"held":true,"vel":Vector2.ZERO})
		verify.call(bridge.step(1.0/120.0,idle,viewport).ok,"編隊を配置して最初の射撃を行う")
		var wing: Dictionary = bridge._ui.interceptor
		verify.call(wing.drones.size()==definition.params.drones_by_level[level-1] and wing.drones[0].left==definition.params.burst_by_level[level-1]-1,"全段の機数と連射数を読み取る")
		var original: Dictionary = wing.drones[0].duplicate(true)
		var first: Array = core.projectiles_snapshot()
		verify.call(first.size()==1 and is_equal_approx(first[0].damage,bridge._ui.attack_power*definition.params.damage_by_level[level-1]) and first[0].callback=="interceptor" and first[0].callback_no_crit,"全段の実弾威力と同期命中hookを使う")
		verify.call(core.remove_enemy(original.target_id),"連射の途中で標的を消す")
		bridge.command("set_ui_overlay",{"active":false})
		var prior: Dictionary = bridge._ui.interceptor.drones[0].duplicate(true)
		for tick in 12:
			prior = bridge._ui.interceptor.drones[0].duplicate(true)
			verify.call(bridge.step(1.0/120.0,idle,viewport).ok,"標的消失後の連射を更新する")
			if bridge._ui.interceptor.drones[0].left==0: break
		var current: Dictionary = bridge._ui.interceptor.drones[0]
		var target: Array = core.enemies_snapshot().filter(func(e): return e.id==current.target_id)
		verify.call(current.target_id!=original.target_id and not target.is_empty(),"消えた標的の行を使わず再捕捉する")
		if target.is_empty(): break
		verify.call(absf(angle_difference(current.angle,(Vector2(target[0].pos[0],target[0].pos[1])-current.pos).angle()))<0.0001,"再捕捉と同じ更新で砲口を新しい相手へ向ける")
		var radial: Vector2 = Vector2.from_angle(bridge._ui.interceptor.clock*definition.params.orbit_speed)
		var expected: Vector2 = bridge._ui.ship.ship_pos+radial*definition.params.orbit-Vector2.from_angle(prior.angle)*prior.kick
		verify.call(current.pos.distance_to(expected)<0.001,"前の射撃の反動を次の機体位置へ反映する")
		var muzzle: Vector2 = current.pos+Vector2.from_angle(current.angle)*15.0*config.character_scale
		var fresh: Array = core.projectiles_snapshot().filter(func(shot): return (shot.pos-shot.vel*(1.0/120.0)).distance_to(muzzle)<0.01)
		verify.call(fresh.size()==1 and (fresh[0].vel as Vector2).normalized().is_equal_approx(Vector2.from_angle(current.angle)),"更新した砲口から現在の標的へ実弾を出す")
		presentation._present_cpp(0.01)
		verify.call(presentation.frame_view._interceptor_visual!=null and presentation.frame_view._interceptor_visual._frame.size()==definition.params.drones_by_level[level-1],"全機の位置・向き・反動・砲口の光を本番表示へ渡す")
		var saved: Dictionary = bridge.checkpoint()
		bridge.command("pause",{"paused":true})
		var paused: Dictionary = bridge._ui.interceptor.duplicate(true)
		bridge.step(1.0/120.0,idle,viewport)
		verify.call(bridge._ui.interceptor==paused,"停止中は編隊・連射・再捕捉期限を止める")
		bridge.command("pause",{"paused":false})
		for tick in 35: bridge.step(1.0/120.0,idle,viewport)
		verify.call(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"実弾の命中と表示を配信する")
		var enemies: Array = core.enemies_snapshot()
		var shots: Array = core.projectiles_snapshot()
		var after: Dictionary = bridge._ui.interceptor.duplicate(true)
		verify.call(enemies.any(func(e): return e.hp<ContentManager.definition(&"enemies",&"splitling").hp),"ウィングの実弾が共通衝突から敵へ同期命中する")
		verify.call(bridge.restore(saved.value).ok and bridge.collect_frame().ok,"編隊と連射の途中へ復帰する")
		for tick in 35: bridge.step(1.0/120.0,idle,viewport)
		verify.call(bridge._ui.interceptor==after and core.projectiles_snapshot()==shots and core.enemies_snapshot()==enemies,"機体・標的/期限・連射・発射済みの弾と命中を再現する")
		bridge.command("dev_remove_weapon",{"id":"W25"})
		presentation._present_cpp(0.01)
		verify.call(not bridge._ui.interceptor.ready and bridge._ui.interceptor.drones.is_empty() and presentation.frame_view._interceptor_visual==null,"途中解除で編隊と専用表示を回収する")
		verify.call(core.projectiles_snapshot()==shots,"解除後も発射済みの弾を自然寿命まで残す")
		bridge.release_checkpoint(saved.value)
		if failures: break
	bridge.release_checkpoint(initial.value)
	session.free()
	await get_tree().process_frame
	OS.remove_logger(errors)
	check(errors.count()==0,"ウィングの状態と表示に実行エラーがない: %s" % [errors.messages()])

func check_cpp_weapon_world_clock() -> void:
	var errors := ErrorCapture.new()
	OS.add_logger(errors)
	for id: String in ["W21","W22","W25"]:
		var session = await trait_test_session(id,trait_test_config(),625)
		if session==null: continue
		var bridge = session.bridge
		var idle: Dictionary = bridge.pack_intent(Intent.new())
		var viewport := {"logical_size":Vector2(1280,720)}
		bridge.step(1.0/120.0,idle,viewport)
		bridge.command("dev_remove_weapon",{"id":"W01"})
		check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":id,"levels":1}).ok,"世界時計確認の対象だけを取得する")
		var presentation: RunPresentation = session.view.get_node("RunPresentation")
		presentation._present_cpp(0.01)
		var key: String = {"W21":"mass_tow","W22":"bipolar","W25":"interceptor"}[id]
		var visual = presentation.frame_view.get("_"+key+"_visual")
		var position: Vector2 = bridge._ui.ship.ship_pos
		visual.sparks.add(position,1,0.0,0.0,1.0,1.0,2.0,[Color.WHITE])
		if id!="W25": visual._fires.add(position,2.0,0.45)
		check(bridge.step(1.0/120.0,idle,viewport).ok and bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"W01なしで対象の世界更新と表示配信を進める")
		presentation._present_cpp(0.01)
		check(visual.sparks._items[0].age>0.008,"W01なしでも%sの火花が自身の世界秒で進む" % id)
		if id!="W25": check(visual._fires._items[0].age>0.008,"W01なしでも%sの炎が自身の世界秒で進む" % id)
		var age: float = visual.sparks._items[0].age
		bridge.command("pause",{"paused":true})
		bridge.step(1.0/120.0,idle,viewport)
		presentation._present_cpp(0.01)
		check(visual.sparks._items[0].age==age,"停止中は%sの火花時計を止める" % id)
		session.free()
		await get_tree().process_frame
	OS.remove_logger(errors)
	check(errors.count()==0,"W01なしの専用表示時計に実行エラーがない: %s" % [errors.messages()])

func check_cpp_w26() -> void:
	var errors := ErrorCapture.new()
	OS.add_logger(errors)
	var config := trait_test_config()
	config.xp_base = 1000000.0
	config.trace_radius = 1.0
	var session = await trait_test_session("W26",config,626)
	if session==null:
		OS.remove_logger(errors)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(1280,720)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("set_settings",{"hitstop":false})
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var initial: Dictionary = bridge.checkpoint()
	var definition: WeaponDef = ContentManager.definition(&"weapons",&"W26")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	var events: Array = []
	bridge.subscribe("w26_check",func(frame: Dictionary):
		events.append_array(frame.events)
		return true)
	for level in ([] if "--cpp-w26-post" in OS.get_cmdline_user_args() else range(1,definition.level_steps.size()+1)):
		check(bridge.restore(initial.value).ok and bridge.collect_frame().ok,"編隊の全段の基準を復元する")
		check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W26","levels":level}).ok,"編隊を全段取得する")
		var center: Vector2 = core.ship_snapshot().ship_pos
		var hit: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":center+Vector2(200.0,30.758*config.character_scale)}).value
		core.set_enemy_motion(hit,{"held":true,"vel":Vector2.ZERO})
		var hp: float = core.enemies_snapshot().filter(func(e): return e.id==hit)[0].hp
		events.clear()
		trait_start_trace(bridge,600.0)
		check(bridge._ui.escort.active and bridge._ui.escort.drones.size()==definition.params.drones_per_side_by_level[level-1]*2,"全段の機数で発進する")
		check(events.any(func(e):return e.type==&"escort_deploy" and e.payload.targets.size()==definition.params.drones_per_side_by_level[level-1]*2),"全機の展開通知を配信する")
		for tick in 8: check(bridge.step(1.0/120.0,idle,viewport).ok,"実秒のなぞり区間で編隊を進める")
		check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"展開と通過命中の通知を表示へ配信する")
		var wing: Dictionary = bridge._ui.escort
		var drone: Dictionary = wing.drones[0]
		var deploy: float = smoothstep(0.0,1.0,clampf(wing.distance/(float(definition.params.deploy_distance)*config.character_scale),0.0,1.0))
		var expected: Vector2 = bridge._ui.ship.ship_pos+Vector2(-31.0,13.0).lerp(Vector2(-9.0*1.82,13.0*1.82),deploy)*config.character_scale
		check(drone.pos.distance_to(expected)<0.001 and drone.dir==Vector2.RIGHT and drone.trail.size()>0 and drone.trail.size()<=96,"なぞりの距離で編隊を滑らかに展開し光跡を保持する")
		presentation._present_cpp(0.01)
		check(presentation.frame_view._escort_visual!=null and presentation.frame_view._escort_visual._frame_node._frame==wing and not presentation.frame_view._flame.visible,"全機と光跡を既存の画像で表示して突進の炎を光跡へ替える")
		var saved: Dictionary = bridge.checkpoint()
		bridge.command("pause",{"paused":true})
		var paused: Dictionary = bridge._ui.escort.duplicate(true)
		bridge.step(1.0/120.0,idle,viewport)
		presentation._present_cpp(0.1)
		check(bridge._ui.escort==paused,"停止中は編隊と光跡の寿命を止める")
		bridge.command("pause",{"paused":false})
		for tick in 40: bridge.step(1.0/120.0,idle,viewport)
		var after: Dictionary = bridge._ui.escort.duplicate(true)
		var enemies: Array = core.enemies_snapshot()
		var struck: Array = enemies.filter(func(e): return e.id==hit)
		var damage: float = config.base_attack*float(definition.params.damage_by_level[level-1])
		check((struck.is_empty() if hp<=damage else is_equal_approx(struck[0].hp,hp-damage)) and events.filter(func(e):return e.type==&"escort_slash").size()==1,"全機で敵IDを共有し同じ突進の通過命中を一度だけ与える")
		check(bridge.restore(saved.value).ok and bridge.collect_frame().ok,"編隊となぞりと光跡の途中へ復帰する")
		for tick in 40: bridge.step(1.0/120.0,idle,viewport)
		check(bridge._ui.escort==after and core.enemies_snapshot()==enemies,"途中復帰後の編隊・命中済みID・経路距離・光跡寿命を再現する")
		for tick in 80: bridge.step(1.0/120.0,idle,viewport)
		check(not bridge._ui.escort.active and bridge._ui.escort.drones.all(func(d):return d.trail.is_empty()),"突進後は攻撃を止めて光跡を自然消滅させる")
		check(bridge.restore(saved.value).ok and bridge.collect_frame().ok,"途中解除の基準へ復帰する")
		bridge.command("dev_remove_weapon",{"id":"W26"})
		presentation._present_cpp(0.01)
		check(not bridge._ui.escort.ready and bridge._ui.escort.drones.is_empty() and presentation.frame_view._escort_visual==null,"途中解除で編隊・光跡・専用表示を回収する")
		bridge.release_checkpoint(saved.value)
		if failures: break
	if "--cpp-w26-post" in OS.get_cmdline_user_args():
		check(bridge.restore(initial.value).ok and bridge.collect_frame().ok,"編隊の範囲境界へ復帰する")
		bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W26","levels":1})
		bridge.command("dev_grant_equipment",{"kind":"trait","id":"T34","levels":2})
		bridge.command("dev_post_scatter",{"interval":0,"projectile":0,"duration":0,"knockback":0,"area":2})
		var center: Vector2 = core.ship_snapshot().ship_pos
		var probe: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":center+Vector2(999,999)}).value
		var enemy_radius: float = core.enemies_snapshot().filter(func(e):return e.id==probe)[0].radius
		core.remove_enemy(probe)
		var area: TraitDef = ContentManager.definition(&"traits",&"T34")
		var radius: float = float(definition.params.drone_hit_radius)*config.character_scale*(1.0+area.stack_bonus(2))*(1.0+2.0*config.post_max.increments.area)
		var inside: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":center+Vector2(240.0,13.0*1.82*config.character_scale+enemy_radius+radius-0.01)}).value
		var outside: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":center+Vector2(240.0,13.0*1.82*config.character_scale+enemy_radius+radius+0.01)}).value
		for id: int in [inside,outside]: core.set_enemy_motion(id,{"held":true,"vel":Vector2.ZERO})
		trait_start_trace(bridge,600.0)
		for tick in 45: bridge.step(1.0/120.0,idle,viewport)
		check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"範囲補正後の命中通知を配信する")
		var enemies: Array = core.enemies_snapshot()
		check(enemies.all(func(e):return e.id!=inside) and enemies.any(func(e):return e.id==outside and e.hp==ContentManager.definition(&"enemies",&"splitling").hp),"範囲特性と最大段後補正を一度ずつ掛けて通過半径の内外を分ける")
	bridge.release_checkpoint(initial.value)
	bridge.unsubscribe("w26_check")
	session.free()
	await get_tree().process_frame
	OS.remove_logger(errors)
	check(errors.count()==0,"編隊の状態と表示に実行エラーがない: %s" % [errors.messages()])

func check_cpp_w27() -> void:
	var errors := ErrorCapture.new()
	OS.add_logger(errors)
	var config := trait_test_config()
	config.xp_base = 1000000.0
	var session = await trait_test_session("W27",config,627)
	if session==null:
		OS.remove_logger(errors)
		return
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(1280,720)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("set_settings",{"hitstop":false})
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var initial: Dictionary = bridge.checkpoint()
	var definition: WeaponDef = ContentManager.definition(&"weapons",&"W27")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	var events: Array = []
	bridge.subscribe("w27_check",func(frame: Dictionary):
		events.append_array(frame.events)
		return true)
	for level in range(1,definition.level_steps.size()+1):
		var retry: bool = level==1 and "--cpp-w27-retry" in OS.get_cmdline_user_args()
		check(bridge.restore(initial.value).ok and bridge.collect_frame().ok,"ミラージュの全段の基準を復元する")
		check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W27","levels":level}).ok,"ミラージュを全段取得する")
		var center: Vector2 = trait_start_trace(bridge,600.0)
		check(bridge._ui.afterimage.echoes.size()==1 and bridge._ui.afterimage.echoes[0].copies.size()==level,"全段の機数で経路の記録を始める")
		for tick in 8: check(bridge.step(1.0/120.0,idle,viewport).ok,"実秒で軌跡を記録する")
		var echoes: Dictionary = bridge._ui.afterimage
		check(echoes.echoes[0].legs>0 and is_equal_approx(echoes.echoes[0].share,float(definition.params.echo_total_by_level[level-1])/level),"各段の通常突進の合計予算を機数へ分配する")
		var hit: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":center+Vector2(10,0)}).value
		core.set_enemy_motion(hit,{"held":true,"vel":Vector2.ZERO})
		events.clear()
		for tick in 12: check(bridge.step(1.0/120.0,idle,viewport).ok,"世界の減速中も分身を実秒で再生する")
		check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"分身の状態と命中通知を表示へ配信する")
		var frame: Dictionary = bridge._ui.afterimage
		var copy: Dictionary = frame.echoes[0].copies[0]
		check(copy.alpha>0.0 and copy.pos.x>center.x+10.0 and frame.clock>bridge._ui.world_time,"遅延した分身が実秒で記録区間を通過する")
		check(events.any(func(e):return e.type==&"combat_damage" and e.payload.cause=="afterimage"),"分身が専用の原因で通常突進の分配ダメージを与える")
		if retry: continue
		presentation._present_cpp(0.01)
		check(presentation.frame_view._afterimage_visual!=null and presentation.frame_view._afterimage_visual._frame_node._body.multimesh.visible_instance_count>0,"既存の機体画像と市松の残光で分身を表示する")
		var saved: Dictionary = bridge.checkpoint()
		for command in ["pause","set_ui_overlay"]:
			bridge.command(command,{"paused":true} if command=="pause" else {"active":true})
			var before: Dictionary = bridge._ui.afterimage.duplicate(true)
			bridge.step(1.0/120.0,idle,viewport)
			presentation._present_cpp(0.1)
			check(bridge._ui.afterimage==before,"停止中は記録と分身の実秒を止める")
			bridge.command(command,{"paused":false} if command=="pause" else {"active":false})
		for tick in 30: bridge.step(1.0/120.0,idle,viewport)
		var after: Dictionary = bridge._ui.afterimage.duplicate(true)
		var enemies: Array = core.enemies_snapshot()
		check(bridge.restore(saved.value).ok and bridge.collect_frame().ok,"保存した経路と分身の途中へ復帰する")
		for tick in 30: bridge.step(1.0/120.0,idle,viewport)
		check(bridge._ui.afterimage==after and core.enemies_snapshot()==enemies,"途中復帰で経路・進み・命中済みID・固定予算を再現する")
		bridge.command("dev_remove_weapon",{"id":"W27"})
		presentation._present_cpp(0.01)
		check(bridge._ui.afterimage.echoes.is_empty() and presentation.frame_view._afterimage_visual==null,"途中解除で保存軌跡と分身と専用表示を回収する")
		check(bridge.restore(saved.value).ok and bridge.collect_frame().ok,"終了時の回収の基準へ復帰する")
		bridge.command("dev_finish",{"cleared":false})
		check(bridge._ui.afterimage.echoes.is_empty(),"ラン終了で残像の攻撃を終了する")
		bridge.release_checkpoint(saved.value)
		if failures: break
	bridge.release_checkpoint(initial.value)
	bridge.unsubscribe("w27_check")
	session.free()
	await get_tree().process_frame
	OS.remove_logger(errors)
	check(errors.count()==0,"ミラージュの状態と表示に実行エラーがない: %s" % [errors.messages()])

func check_cpp_w28() -> bool:
	var errors := ErrorCapture.new()
	OS.add_logger(errors)
	var config := trait_test_config()
	config.xp_base = 1000000.0
	var session = await trait_test_session("W28",config,628)
	if session==null:
		OS.remove_logger(errors)
		return false
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(1280,720)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("set_settings",{"hitstop":false})
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var initial: Dictionary = bridge.checkpoint()
	var definition: WeaponDef = ContentManager.definition(&"weapons",&"W28")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	var events: Array = []
	bridge.subscribe("w28_check",func(frame: Dictionary):
		events.append_array(frame.events)
		return true)
	for level in range(1,definition.level_steps.size()+1):
		check(bridge.restore(initial.value).ok and bridge.collect_frame().ok,"閃光斬の全段の基準へ復帰する")
		check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W28","levels":level}).ok,"閃光斬を全段取得する")
		var center: Vector2 = core.ship_snapshot().ship_pos
		var target: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":center+Vector2(100,0)}).value
		core.set_enemy_motion(target,{"held":true,"vel":Vector2.ZERO})
		events.clear()
		trait_start_trace(bridge,600.0)
		for tick in 40:
			check(bridge.step(1.0/120.0,idle,viewport).ok,"通常の体当たりから閃光斬の印を付ける")
			if not bridge._ui.flash_slash.marks.is_empty(): break
		check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"印の通知と保持状態を表示へ配信する")
		var marks: Array = bridge._ui.flash_slash.marks
		check(marks.size()==1,"敵IDと突進IDを索引して同じ突進の印を一度だけ付ける")
		if marks.is_empty(): break
		var mark: Dictionary = marks[0]
		var ram: Array = events.filter(func(e):return e.type==&"combat_damage" and e.payload.cause=="ram")
		check(mark.total==int(definition.params.cuts_by_level[level-1]) and mark.left==mark.total and mark.time<0 and is_equal_approx(mark.damage,float(ram[0].payload.applied)*float(definition.params.mult_by_level[level-1])),"全段の斬撃回数と実体当たりダメージを印へ固定する")
		check(core.enemy_motion_snapshot().filter(func(e):return e.id==target)[0].slash_hold==1,"通常の敵は独立した閃光斬の保持で止まる")
		presentation._present_cpp(0.01)
		check(presentation.frame_view._slash_visual!=null and presentation.frame_view._slash_visual.needles.has(target),"保持した敵の現在位置に既存の光の針を表示する")
		var saved: Dictionary = bridge.checkpoint()
		bridge.command("pause",{"paused":true})
		var paused: Dictionary = bridge._ui.flash_slash.duplicate(true)
		bridge.step(1.0/120.0,idle,viewport)
		presentation._present_cpp(0.1)
		check(bridge._ui.flash_slash==paused,"停止中は印の時間と表示を止める")
		bridge.command("pause",{"paused":false})
		for tick in 150: check(bridge.step(1.0/120.0,idle,viewport).ok,"突進の終了後に順番に斬る")
		check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"発進後の斬撃と解放を表示へ配信する")
		check(events.filter(func(e):return e.type==&"flash_slash").size()==mark.total and bridge._ui.flash_slash.marks.is_empty() and bridge._ui.flash_slash.dash_count==0,"指定回数だけ斬って印と索引を寿命と同時に回収する")
		var enemies: Array = core.enemies_snapshot()
		check(core.enemy_motion_snapshot().filter(func(e):return e.id==target)[0].slash_hold==0,"斬り終えた印が保持を解除する")
		var after: Dictionary = bridge._ui.flash_slash.duplicate(true)
		check(bridge.restore(saved.value).ok and bridge.collect_frame().ok,"印・残り回数・取得順と索引を途中復帰する")
		for tick in 150: bridge.step(1.0/120.0,idle,viewport)
		check(bridge._ui.flash_slash==after and core.enemies_snapshot()==enemies,"途中復帰で同じ順番とダメージを再現する")
		check(bridge.restore(saved.value).ok and bridge.collect_frame().ok,"印の途中解除の基準へ復帰する")
		bridge.command("dev_remove_weapon",{"id":"W28"})
		presentation._present_cpp(0.01)
		check(bridge._ui.flash_slash.marks.is_empty() and bridge._ui.flash_slash.dash_count==0 and core.enemy_motion_snapshot().filter(func(e):return e.id==target)[0].slash_hold==0 and presentation.frame_view._slash_visual==null,"途中解除で保持・印・索引・光の針を回収する")
		bridge.release_checkpoint(saved.value)
		if failures: break
	bridge.release_checkpoint(initial.value)
	bridge.unsubscribe("w28_check")
	session.free()
	await get_tree().process_frame
	OS.remove_logger(errors)
	check(errors.count()==0,"閃光斬の状態と表示に実行エラーがない: %s" % [errors.messages()])
	return true

func check_cpp_w28_boss_visual() -> void:
	OS.add_logger(capture)
	var boss = preload("res://scripts/bosses/monoceros/sword_flash_visual.gd").new()
	add_child(boss)
	var weapon = preload("res://scripts/render/equipment/flashSlash.gd").new()
	var parent := Node2D.new()
	add_child(parent)
	weapon.setup_frame(parent,1.0)
	var release := {"type":&"slash_release","path":PackedVector2Array([Vector2.ZERO,Vector2(100,0)]),"count":3,"sweep":0.1,"pause":0.1}
	boss.frame_event(release)
	weapon.frame_event(release)
	check(boss.effects.is_empty() and weapon.streaks.size()==3,"武器の解放通知を一角獣の斬撃として読まない")
	var slash := {"type":&"monoceros_slash_release","line":PackedVector2Array([Vector2.ZERO,Vector2(100,0)]),"width":8.0}
	boss.frame_event(slash)
	weapon.frame_event(slash)
	check(not boss.effects.is_empty() and weapon.streaks.size()==3,"一角獣の斬撃を武器の解放通知として読まない")
	weapon.dispose()
	parent.free()
	boss.free()
	await get_tree().process_frame
	OS.remove_logger(capture)
	check(capture.count()==0,"二つの斬撃表示の通知が混ざらない: %s" % [capture.messages()])

func check_cpp_overlap() -> bool:
	var retry: bool = "--cpp-overlap-retry" in OS.get_cmdline_user_args()
	var errors := ErrorCapture.new()
	OS.add_logger(errors)
	var config := trait_test_config()
	config.xp_base = 1000000.0
	config.trace_radius = 1.0
	var session = await trait_test_session("C_overlap",config,3490)
	if session==null:
		OS.remove_logger(errors)
		return false
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(1280,720)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("set_settings",{"hitstop":false})
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var initial: Dictionary = bridge.checkpoint()
	var center: Vector2 = core.ship_snapshot().ship_pos
	var events: Array = []
	bridge.subscribe("overlap_check",func(frame: Dictionary):
		events.append_array(frame.events)
		return true)
	for id in ["W04","W28","W21","W03"]:
		check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":id,"levels":1}).ok,"同時作用の実際の武器を取得する")
	bridge.command("dev_grant_equipment",{"kind":"trait","id":"T33","levels":1})
	var target: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":center+Vector2(100,0)}).value
	core.set_enemy_motion(target,{"vel":Vector2.ZERO})
	trait_start_trace(bridge,600.0)
	check(core.step_draw(1.0) and core.step_draw(10.0),"世界を進めず最初の突進を終えて次を充填する")
	bridge.command("dev_ship_motion",{"position":center-Vector2(400,0),"velocity":Vector2.ZERO})
	trait_start_trace(bridge,600.0)
	core.step_draw(0.2)
	check(core.step_draw(1.0),"別の突進IDで同じ敵へ2つめの印を付ける")
	bridge.command("set_ui_overlay",{"active":false})
	check(bridge._ui.flash_slash.marks.size()==2 and bridge._ui.flash_slash.dash_count==2,"2つの突進が同じ敵の印を独立して索引する")
	var owner: int = bridge.command("dev_spawn",{"definition_id":"corona","position":center+Vector2(100,100)}).value
	core.set_enemy_motion(owner,{"fire_t":100.0})
	for tick in 12: check(bridge.step(1.0/120.0,idle,viewport).ok, "複数の震空と斬撃待ちの敵を冠で捕捉する")
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"重なった各状態と通知を配信する")
	var motion: Array = core.enemy_motion_snapshot().filter(func(e):return e.id==target)
	check(motion.size()==1 and motion[0].held==1 and motion[0].slash_hold==1 and motion[0].corona_owner==owner,"冠のheldと閃光斬のslash_holdを独立して持つ")
	check(bridge._ui.contact_wave.waves.size()==2 and bridge._ui.contact_wave.waves.all(func(w):return w.caught.any(func(c):return c.id==target)),"同じ敵へ複数の震空が重なり冠と閃光斬を除外しない")
	var triple: Dictionary = bridge.checkpoint()
	bridge.command("dev_remove_weapon",{"id":"W28"})
	motion = core.enemy_motion_snapshot().filter(func(e):return e.id==target)
	check(motion[0].held==1 and motion[0].slash_hold==0 and bridge._ui.contact_wave.waves.size()==2,"閃光斬の交換は冠と震空の状態を消さない")
	bridge.command("dev_remove_weapon",{"id":"W04"})
	check(core.enemy_motion_snapshot().filter(func(e):return e.id==target)[0].held==1,"震空の交換は冠の保持を解除しない")
	check(bridge.restore(triple.value).ok and bridge.collect_frame().ok,"3種類の同時作用と複数印の順番へ復帰する")
	bridge.command("dev_remove_weapon",{"id":"W04"})
	motion = core.enemy_motion_snapshot().filter(func(e):return e.id==target)
	check(motion[0].held==1 and motion[0].slash_hold==1,"先に震空を外しても冠と閃光斬を保つ")
	bridge.command("dev_remove",{"entity_id":owner})
	motion = core.enemy_motion_snapshot().filter(func(e):return e.id==target)
	check(motion[0].held==0 and motion[0].slash_hold==1 and not motion[0].has("corona_owner"),"冠を解放しても閃光斬の保持は残る")
	for tick in 13: bridge.step(1.0/120.0,idle,viewport)
	motion = core.enemy_motion_snapshot().filter(func(e):return e.id==target)
	check(bridge._ui.flash_slash.marks.size()==1 and bridge._ui.flash_slash.marks[0].left>0 and motion[0].slash_hold==0,"先の印の完了は後の印が残っていても元の順でboolを解除する")
	check(bridge.restore(triple.value).ok and bridge.collect_frame().ok,"死亡と船体利用の基準へ復帰する")
	core.step_draw(10.0)
	trait_start_trace(bridge,600.0)
	var hp: float = core.enemies_snapshot().filter(func(e):return e.id==target)[0].hp
	bridge.command("dev_damage",{"entity_id":target,"amount":hp-1.0,"cause":"shot","knock":0.0})
	events.clear()
	core.collide_ship(center-Vector2(200,0),config.trace_radius)
	bridge.command("set_ui_overlay",{"active":false})
	check(bridge._ui.mass_tow.cargo.size()==1 and events.filter(func(e):return e.type==&"anchor_capture").size()==1 and not events.any(func(e):return e.type==&"hull_scatter"),"死亡後はアンカーキャノンが先に船体を取り星砕きを抑える")
	check(bridge._ui.rampage.kills==1,"通常の撃破は特性の撃破hookを一度だけ通す")
	bridge.command("dev_remove",{"entity_id":target})
	var next: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":center+Vector2(500,300)}).value
	for tick in 2: bridge.step(1.0/120.0,idle,viewport)
	motion = core.enemy_motion_snapshot().filter(func(e):return e.id==next)
	check(next!=target and motion[0].held==0 and motion[0].slash_hold==0 and not motion[0].has("corona_owner") and bridge._ui.flash_slash.marks.is_empty() and bridge._ui.flash_slash.dash_count==0,"死亡行を使う別個体へ冠・印・索引・保持を漏らさない")
	check(bridge.restore(initial.value).ok and bridge.collect_frame().ok,"船体を一撃で使う境界へ復帰する")
	for id in ["W03","W21"]: bridge.command("dev_grant_equipment",{"kind":"weapon","id":id,"levels":1})
	trait_start_trace(bridge,600.0)
	var fresh: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":center+Vector2(100,100)}).value
	core.set_enemy_motion(fresh,{"held":true,"vel":Vector2.ZERO})
	events.clear()
	bridge.command("dev_damage",{"entity_id":fresh,"amount":1000.0,"cause":"shot","direction":Vector2.RIGHT,"knock":0.0,"no_crit":true})
	check(bridge._ui.mass_tow.cargo.size()==1 and not events.any(func(e):return e.type==&"hull_scatter"),"一撃の船体はW21が先に捕獲し星砕きへ重複して渡さない")
	if not retry:
		check(bridge.restore(initial.value).ok and bridge.collect_frame().ok,"ミラージュの専用撃破の基準へ復帰する")
		for id in ["W21","W03","W27"]: bridge.command("dev_grant_equipment",{"kind":"weapon","id":id,"levels":1})
		bridge.command("dev_grant_equipment",{"kind":"trait","id":"T33","levels":1})
		trait_start_trace(bridge,600.0)
		core.step_draw(0.1)
		var echo_target: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":center+Vector2(10,0)}).value
		core.set_enemy_motion(echo_target,{"held":true,"vel":Vector2.ZERO})
		hp = core.enemies_snapshot().filter(func(e):return e.id==echo_target)[0].hp
		bridge.command("dev_damage",{"entity_id":echo_target,"amount":hp-1.0,"cause":"shot","knock":0.0})
		events.clear()
		for tick in 20: bridge.step(1.0/120.0,idle,viewport)
		check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"ミラージュの実際の撃破通知を配信する")
		check(events.filter(func(e):return e.type==&"kill" and e.payload.id==echo_target and e.payload.cause=="afterimage").size()==1 and bridge._ui.mass_tow.cargo.is_empty() and not events.any(func(e):return e.type in [&"anchor_capture",&"hull_scatter"]) and bridge._ui.rampage.kills==0,"ミラージュ撃破は船体を使用済みにしW21・W03と撃破hookを抑える")
	bridge.release_checkpoint(triple.value)
	bridge.release_checkpoint(initial.value)
	bridge.unsubscribe("overlap_check")
	session.free()
	await get_tree().process_frame
	OS.remove_logger(errors)
	check(errors.count()==0,"同時作用と行再利用に実行エラーがない: %s" % [errors.messages()])
	return true

func check_cpp_stats() -> bool:
	var boundary_only: bool = "--cpp-stats-boundary" in OS.get_cmdline_user_args()
	var errors := ErrorCapture.new()
	OS.add_logger(errors)
	var config := trait_test_config()
	config.xp_base = 1000000.0
	config.trace_radius = 1.0
	config.weapon_slots = 16
	config.trait_slots = 18
	var session = await trait_test_session("T_stats",config,737)
	if session==null:
		OS.remove_logger(errors)
		return false
	var bridge = session.bridge
	var core = bridge._core
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	var viewport := {"logical_size":Vector2(1280,720)}
	bridge.step(1.0/120.0,idle,viewport)
	bridge.command("set_settings",{"hitstop":false})
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var weapons := ["W01","W02","W03","W04","W05","W07","W08","W17","W21","W22","W23","W25","W26","W27","W28","W29"]
	var traits := ["T03","T04","T05","T06","T07","T08","T09","T10","T11","T12","T14","T31","T32","T33","T34","T35","T36","T37"]
	for id in weapons: check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":id,"levels":5 if boundary_only else 1}).ok,"数値特性をつなぐ全16武器を登録する")
	for level in ([5] if boundary_only else range(1,config.trait_max_stacks+1)):
		for id in traits: check(bridge.command("dev_grant_equipment",{"kind":"trait","id":id,"levels":5 if boundary_only else 1}).ok,"全16武器とともに全18特性を各段で取得する")
		if boundary_only: continue
		check(bridge._ui.weapon_levels.size()==16 and bridge._ui.trait_levels.size()==18 and bridge._ui.trait_levels.all(func(t):return t.level==level),"全18特性と全16武器の接続を段ごとに保つ")
		var fields := {"T07":"charge_time","T08":"capacity","T09":"crit_chance","T10":"max_speed","T11":"attack_mult","T12":"pickup_radius","T14":"length_mult","T31":"glide_duration_mult","T34":"area_multiplier","T35":"shot_multiplier"}
		for id in fields:
			var definition: TraitDef = ContentManager.definition(&"traits",StringName(id))
			var amount: float = 1.0+definition.stack_bonus(level)
			var expected: float = amount
			match id:
				"T07": expected = config.dash_charge_time/amount
				"T09": expected = minf(float(definition.params.max),config.base_crit_chance+definition.stack_bonus(level))
				"T10": expected = config.base_max_speed*amount
				"T12": expected = config.pickup_radius*amount
			check(is_equal_approx(float(bridge._ui[fields[id]]),expected),"全武器を持つ各段の実効値を一度だけ合成する: %s" % id)
		check(bridge._ui.vortex.ready and bridge._ui.kill_sonic.ready and bridge._ui.crit_beam.ready and bridge._ui.run_up.ready and bridge._ui.rampage.equipped and bridge._ui.full_burst and bridge._ui.full_charge.maximum>1.0,"行動する特性の実行状態を数値特性と一緒に登録する")
	var stats: Array = [bridge._ui.attack_mult,bridge._ui.area_multiplier,bridge._ui.shot_multiplier,bridge._ui.charge_time,bridge._ui.capacity,bridge._ui.shooting_rate]
	if not boundary_only:
		for id in weapons:
			check(bridge.command("dev_remove_weapon",{"id":id}).ok,"特性を保持したまま各武器を交換する")
			var definition: WeaponDef = ContentManager.definition(&"weapons",StringName(id))
			check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":id,"levels":definition.level_steps.size()}).ok,"交換した武器を最大段で同じ特性へつなぎ直す")
			check(bridge._ui.weapon_levels.size()==16 and bridge._ui.trait_levels.size()==18 and [bridge._ui.attack_mult,bridge._ui.area_multiplier,bridge._ui.shot_multiplier,bridge._ui.charge_time,bridge._ui.capacity,bridge._ui.shooting_rate]==stats,"交換前後で共有倍率を重ねず全特性を維持する")
	var full: Dictionary = bridge.checkpoint()
	var events: Array = []
	bridge.subscribe("stats_check",func(frame: Dictionary):
		events.append_array(frame.events)
		return true)
	var duplicates := 0
	if not boundary_only:
		for weapon_id in ["W01","W02","W23","W25"]:
			check(bridge.restore(full.value).ok and bridge.collect_frame().ok,"混成特性の射撃境界へ復帰する")
			for id in weapons:
				if id!=weapon_id: bridge.command("dev_remove_weapon",{"id":id})
			var definition: WeaponDef = ContentManager.definition(&"weapons",StringName(weapon_id))
			if weapon_id=="W25":
				var target: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":core.ship_snapshot().ship_pos+Vector2(250,0)}).value
				core.set_enemy_motion(target,{"held":true,"vel":Vector2.ZERO})
			var times: Array[float] = []
			for tick in 200:
				events.clear()
				check(bridge.step(1.0/120.0,idle,viewport).ok,"混成特性の通常射撃を短く進める")
				var fresh: Array = core.projectiles_snapshot().filter(func(p):return p.kind==0 and p.age<0.009)
				if fresh.is_empty(): continue
				times.append(bridge._ui.world_time)
				if times.size()==1:
					var power: float = bridge._ui.attack_power*float(definition.params.damage_by_level[-1])
					var parents: Array = fresh.filter(func(p):return is_equal_approx(p.damage,power))
					var count: int = (int(definition.params.shots_by_level[-1]) if weapon_id=="W02" else 1)*2
					var copied: int = events.filter(func(e):return e.type==&"duplicate").size()*2
					duplicates += copied
					var radius: float = (float(definition.params.shot_radius) if weapon_id=="W25" else 5.0)*bridge._ui.area_multiplier
					check(parents.size()==count and fresh.size()==count+copied,"弾数の整数境界へ一度だけ補正し複製を別に追加する: %s" % weapon_id)
					var duplicator: TraitDef = ContentManager.definition(&"traits",&"T37")
					check(fresh.all(func(p):return is_equal_approx(p.radius,radius) and (is_equal_approx(p.damage,power) or is_equal_approx(p.damage,power*float(duplicator.params.damage_by_level[-1])))),"攻撃力・範囲を元の弾へ適用し複製だけへ専用威力を掛ける: %s" % weapon_id)
					if weapon_id=="W25":
						var drone: Dictionary = bridge._ui.interceptor.drones[0]
						check(is_equal_approx(drone.next-bridge._ui.interceptor.clock,float(definition.params.burst_interval)/bridge._ui.shooting_rate),"連射中の次弾にも満タン特性の間隔を適用する")
						break
				if times.size()==2:
					check(absf(times[1]-times[0]-float(definition.params.interval_by_level[-1])/bridge._ui.shooting_rate)<=1.0/120.0+0.000001,"連射特性の間隔で次の発射へ進む: %s" % weapon_id)
					break
			check(not times.is_empty(),"各射撃武器が混成特性から実際の弾を生成する")
		check(duplicates>0,"T37は数値だけでなく実際の射撃生成時に左右2本の複製を作る")
	check(bridge.restore(full.value).ok and bridge.collect_frame().ok,"範囲とミラージュ機数の境界へ復帰する")
	for id in weapons:
		if id!="W27": bridge.command("dev_remove_weapon",{"id":id})
	var center: Vector2 = trait_start_trace(bridge,600.0)
	core.step_draw(0.1)
	var probe: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":center+Vector2(999,999)}).value
	var enemy_radius: float = core.enemies_snapshot().filter(func(e):return e.id==probe)[0].radius
	bridge.command("dev_remove",{"entity_id":probe})
	var inside: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":center+Vector2(10,enemy_radius+config.trace_radius*bridge._ui.area_multiplier-0.01)}).value
	var outside: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":center+Vector2(10,enemy_radius+config.trace_radius*bridge._ui.area_multiplier+0.01)}).value
	for id in [inside,outside]: core.set_enemy_motion(id,{"held":true,"vel":Vector2.ZERO})
	var hp: float = core.enemies_snapshot().filter(func(e):return e.id==inside)[0].hp
	for tick in 20: bridge.step(1.0/120.0,idle,viewport)
	check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"混成特性の射撃と範囲境界を配信する")
	var enemies: Array = core.enemies_snapshot()
	check(enemies.filter(func(e):return e.id==inside)[0].hp<hp and enemies.filter(func(e):return e.id==outside)[0].hp==hp,"ミラージュの保存区間にも共通範囲を一度掛けて内外を分ける")
	check(bridge._ui.afterimage.echoes[0].copies.size()==5,"弾数と複製特性はミラージュの専用機数へ重ねて掛けない")
	for id in ["W22","W26"]:
		check(bridge.restore(full.value).ok and bridge.collect_frame().ok,"候補のセル境界へ復帰する")
		for other in weapons: bridge.command("dev_remove_weapon",{"id":other})
		bridge.command("dev_grant_equipment",{"kind":"weapon","id":id,"levels":1})
		var definition: WeaponDef = ContentManager.definition(&"weapons",StringName(id))
		center = core.ship_snapshot().ship_pos
		probe = bridge.command("dev_spawn",{"definition_id":"splitling","position":center+Vector2(999,999)}).value
		enemy_radius = core.enemies_snapshot().filter(func(e):return e.id==probe)[0].radius
		bridge.command("dev_remove",{"entity_id":probe})
		var y: float = float(definition.params.width)*bridge._ui.area_multiplier*0.5 if id=="W22" else 13.0*1.82*config.character_scale+float(definition.params.drone_hit_radius)*config.character_scale*bridge._ui.area_multiplier
		if id=="W22":
			trait_start_trace(bridge,600.0)
			core.step_draw(1.0)
		inside = bridge.command("dev_spawn",{"definition_id":"splitling","position":center+Vector2(240,y+enemy_radius-0.01)}).value
		outside = bridge.command("dev_spawn",{"definition_id":"splitling","position":center+Vector2(240,y+enemy_radius+0.01)}).value
		for target in [inside,outside]: core.set_enemy_motion(target,{"held":true,"vel":Vector2.ZERO})
		hp = core.enemies_snapshot().filter(func(e):return e.id==inside)[0].hp
		if id=="W26": trait_start_trace(bridge,600.0)
		for tick in 55: bridge.step(1.0/120.0,idle,viewport)
		check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.ok,"セル境界の通過命中を配信する")
		enemies = core.enemies_snapshot()
		check(enemies.filter(func(e):return e.id==inside)[0].hp<hp and enemies.filter(func(e):return e.id==outside)[0].hp==hp,"候補検索は敵半径を含め、判定は武器の半径のまま内外を分ける: %s" % id)
	var rendered: RunPresentation = session.view.get_node("RunPresentation")
	rendered._present_cpp(0.01)
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.bridge = bridge
	hud.size = Vector2(1280,720)
	add_child(hud)
	hud.apply_snapshot(bridge._ui.duplicate(true))
	bridge.collect_frame()
	for frame in 3: await get_tree().process_frame
	check(hud._cpp_ui.weapon_levels.size()==1 and hud._cpp_ui.trait_levels.size()==18 and hud._cpp_ui.attack_mult==bridge._ui.attack_mult and hud._cpp_ui.area_multiplier==bridge._ui.area_multiplier,"交換後の装備と全18特性の同じ実効値をHUDへ表示する")
	hud.free()
	bridge.release_checkpoint(full.value)
	bridge.unsubscribe("stats_check")
	session.free()
	await get_tree().process_frame
	OS.remove_logger(errors)
	check(errors.count()==0,"全装備への特性接続に実行エラーがない: %s" % [errors.messages()])
	return true

## 旧比較で使っていたT04の期待曲線。編集値と距離だけを受け、ラン状態を持たない。
func expected_full_charge(config: GameConfig, params: Dictionary, level: int, distance: float) -> float:
	var x := clampf(distance/config.draw_length,0.0,1.0)
	var maximum := float(params.mult_base)+float(params.mult_per)*level
	return 1.0+(maximum-1.0)*(exp(3.0*x)-1.0)/(exp(3.0)-1.0)
