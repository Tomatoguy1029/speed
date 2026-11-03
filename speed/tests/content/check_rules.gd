## 設計書 4.4 の決まりを自動で確かめる。違反があれば一覧を出して失敗する。
##   Godot --headless --path speed --script res://tests/content/check_rules.gd
##
## 確かめること：
##   1. Autoload はアプリ全体の窓口と、開発用の起動だけ
##   2. Manager はコンテンツ（ステージ・ボス・フィールドの仕掛け）に依存しない（決まり4）
##   3. 再利用する道具は Godot 本体だけに依存し、content_build はゲーム専用の生成を受け持つ
##   4. UI はランの状態を書き換えない（state.xxx = の代入をしない）（設計書 4.1）
extends SceneTree

const ALLOWED_AUTOLOADS := ["ContentManager", "SaveManager", "AudioManager", "GameManager", "RunManager", "ProfileManager", "DevBootstrap"]
const CONTENT_REFS := ["res://scenes/stages", "res://scenes/bosses", "res://scenes/gimmicks",
	"res://scripts/bosses", "res://scripts/gimmicks"]
const GAME_REFS := ["res://scripts", "res://scenes", "res://data", "ContentManager", "SaveManager",
	"AudioManager", "GameManager"]

var errors: Array[String] = []

func _initialize() -> void:
	if "--package-runtime" in OS.get_cmdline_user_args() or "--package-missing-runtime" in OS.get_cmdline_user_args():
		call_deferred("_package_runtime")
		return
	_check_autoloads()
	for path in _files("res://scripts/managers"):
		_forbid(path, CONTENT_REFS, "Manager がコンテンツを参照している")
	for path in _files("res://addons"):
		if path.begins_with("res://addons/content_build/"):
			continue
		_forbid(path, GAME_REFS, "道具（addons）がゲームを参照している")
	for path in _files("res://scripts/ui"):
		_forbid_regex(path, "\\bstate\\.[a-z_]+\\s*[+\\-*/]?=[^=]", "UI がランの状態を書き換えている")
	for path in _files("res://scripts/encounters"):
		_forbid(path, ["projectiles.director ="], "攻撃予算の所有はC++ランに集約する")
	_forbid("res://scenes/run/run.tscn", ["res://scripts/dev/"], "本番の表示が開発用機能を参照している")
	_forbid("res://scripts/ui/main.gd", ["res://gyms/", "res://addons/"], "画面の入口が開発用機能を参照している")
	if errors.is_empty():
		print("[check_rules] OK")
		quit(0)
	else:
		for e in errors:
			print("[check_rules] ", e)
		quit(1)

func _check_autoloads() -> void:
	var names: Array[String] = []
	for prop in ProjectSettings.get_property_list():
		var n: String = prop.name
		if n.begins_with("autoload/"):
			names.append(n.trim_prefix("autoload/"))
	for n in names:
		if not ALLOWED_AUTOLOADS.has(n):
			errors.append("決められていない Autoload: %s" % n)

func _forbid(path: String, words: Array, message: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var lines := text.split("\n")
	for i in lines.size():
		var line := lines[i].strip_edges()
		if line.begins_with("#"):
			continue
		for w in words:
			if line.contains(w):
				errors.append("%s：%s:%d（%s）" % [message, path, i + 1, w])

func _forbid_regex(path: String, pattern: String, message: String) -> void:
	var re := RegEx.create_from_string(pattern)
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i in lines.size():
		var line := lines[i].strip_edges()
		if line.begins_with("#"):
			continue
		if re.search(line) != null:
			errors.append("%s：%s:%d" % [message, path, i + 1])

func _files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for f in da.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for sub in da.get_directories():
		out.append_array(_files(dir.path_join(sub)))
	return out


## 確認用コピーのMainへ移して、公式配布エンジンの通常起動から呼ぶ。
## 生成器・テスト資源・エディターキャッシュは配布へ加えない。
func _package_runtime() -> void:
	var missing := "--package-missing-runtime" in OS.get_cmdline_user_args()
	var loaded := ClassDB.class_exists(&"SpeedRunCore")
	Engine.max_fps = 60
	if loaded == missing:
		push_error("配布拡張の存在と読込結果が一致しません")
		quit(1)
		return
	var manager = root.get_node_or_null("RunManager")
	if manager==null:
		push_error("配布のラン入口を読み込めません")
		quit(1)
		return
	var session = manager.create_run()
	root.add_child(session)
	session.auto_step = false
	for frame in range(600):
		if session.bridge!=null or session.cpp_error!=OK: break
		await process_frame
	if missing:
		var rejected: bool = session.bridge==null and not _package_has_legacy(session) and session.cpp_error!=OK
		session.free()
		if rejected: print("[package_missing_runtime] OK")
		else: push_error("拡張欠落時にランの準備失敗が必要です")
		quit(0 if rejected else 1)
		return
	if session.bridge==null or _package_has_legacy(session):
		push_error("配布の通常入口がC++ランを開始しません")
		session.free()
		quit(1)
		return
	var bridge = session.bridge
	var before: Dictionary = bridge.read_frame()
	var updated: Dictionary = bridge.step(1.0/120.0,bridge.pack_intent(load("res://scripts/input/intent.gd").new()), {"logical_size":Vector2(1280,720)})
	var after: Dictionary = bridge.read_frame()
	var ok: bool = before.ok and updated.ok and after.ok and after.value.tick==before.value.tick+1
	session.free()
	await process_frame
	if ok: print("[package_runtime] OK cpu="+Engine.get_architecture_name())
	else: push_error("配布ランを最小更新できません")
	quit(0 if ok else 1)

func _package_has_legacy(session: Object) -> bool:
	for property: Dictionary in session.get_property_list():
		if property.name=="_sim": return session.get("_sim")!=null
	return false

## 通常出撃の初回と再出撃を測る。ボスと交換の条件だけは明示した実験場を使う。
func _package_loading() -> void:
	if OS.has_feature("editor") or DisplayServer.get_name()=="headless":
		push_error("P04は描画付きの配布版で確認してください")
		quit(1)
		return
	if not await _package_startup():
		quit(1)
		return
	if "--loading-boss-only" in OS.get_cmdline_user_args():
		var path := "res://.content/run/stage_1.json"
		var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var owner: RunSession = RunManager.create_session(root,{"cpp_index":path,"cpp_signature":index.input_sha256,"seed":42,"cpp_start":{"lab_mode":true}},true)
		var ready := await _package_ready(owner)
		var boss_ok: bool = await _package_boss_preparation(owner) if ready else false
		owner.free()
		await process_frame
		if boss_ok: print("[package_loading_boss] OK")
		quit(0 if boss_ok else 1)
		return
	var stamp := FileAccess.get_sha256("res://.content/stamp.json")
	_package_measure("起動",{"engine_elapsed_ms":Time.get_ticks_msec(),"content":ContentManager.startup_timings})
	var ok := true
	for label in ["通常初回","通常再出撃"]:
		GameManager.start_run(1)
		var session: RunSession = RunManager.current()
		if session==null or not await _package_ready(session):
			push_error("P04の通常出撃を開始できません")
			quit(1)
			return
		_package_measure(label,session.loading_timings)
		ok = await _package_initial_equipment(session,label) and ok
		ok = await _package_release(session,label,true) and ok
	# 通常の時間進行や成長の所要時間とは別に、同じ表示・資源経路の初回費用を測る。
	var path := "res://.content/run/stage_1.json"
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var options := {"cpp_index":path,"cpp_signature":index.input_sha256,"seed":42,"cpp_start":{"lab_mode":true}}
	var fixture: RunSession = RunManager.create_session(root,options,true)
	if await _package_ready(fixture):
		ok = await _package_lab_preparation(fixture) and ok
		ok = await _package_release(fixture,"実験場条件",false) and ok
	else:
		fixture.free()
		ok = false
	# 準備の取消は通常の要求を発行してから破棄し、到着後にも保持が戻らないことを確かめる。
	var cancelled: RunSession = RunManager.create_run()
	root.add_child(cancelled)
	ok = cancelled.bridge==null and not cancelled._pending_cpp.is_empty() and ok
	ok = await _package_release(cancelled,"準備取消",false) and ok
	# 失敗を注入するのは準備窓口だけ。要求した資源は本番のContentManagerが回収する。
	var failed_session := RunSession.new()
	root.add_child(failed_session)
	failed_session.cpp_prepare = func(paths: PackedStringArray) -> ContentResourceScope:
		var scope := ContentManager.prepare_resources(paths,true)
		scope.failed = true
		return scope
	var failure: Error = failed_session.start_cpp_content(path,index.input_sha256,42,true)
	ok = failure!=OK and failed_session.bridge==null and failed_session.cpp_resources==null and failed_session._pending_cpp_bridge==null and ok
	ok = await _package_release(failed_session,"準備失敗を注入",false) and ok
	# 生成器・固定解析用ScriptはPCKから除外し、生成済みの索引をこの起動中に更新しない。
	var generated_unchanged := not stamp.is_empty() and FileAccess.get_sha256("res://.content/stamp.json")==stamp
	for excluded in ["res://tools/content/build_all.gd","res://addons/content_build/builder.gd","res://scripts/render/armor_paint.gd"]:
		generated_unchanged = not ResourceLoader.exists(excluded) and generated_unchanged
	_package_measure("配布生成境界",{"stamp_unchanged":generated_unchanged,"pending_resources":ContentManager.pending_resources()})
	ok = generated_unchanged and ok
	if ok: print("[package_loading] OK")
	else: push_error("P04の準備・回収の確認に失敗しました")
	quit(0 if ok else 1)

func _package_measure(label: String, values: Dictionary) -> void:
	print("[package_loading_measure] "+JSON.stringify({"case":label,"values":values}))

func _package_startup() -> bool:
	var app := root.get_node_or_null("Main")
	if app == null: return false
	while not app.get("startup_complete") and not app.get("startup_failed"):
		await process_frame
	_package_measure("起動時の資源と描画準備",{"complete":app.get("startup_complete"),"failed":app.get("startup_failed"),"timings":ContentManager.startup_timings,"sessions":RunManager.get("_sessions").size()})
	return app.get("startup_complete") and not app.get("startup_failed") and RunManager.get("_sessions").is_empty()

func _package_ready(session: RunSession) -> bool:
	session.auto_step = false
	for frame in range(600):
		if session.bridge!=null or session.cpp_error!=OK: break
		await process_frame
	return session.bridge!=null and session.cpp_error==OK and session.view!=null and not _package_has_legacy(session)

func _package_step(session: RunSession) -> bool:
	return session.bridge.step(1.0/120.0,session.bridge.pack_intent(load("res://scripts/input/intent.gd").new()),{"logical_size":Vector2(1280,720)}).ok

func _package_initial_equipment(session: RunSession, label: String) -> bool:
	var initial: Dictionary = session.bridge.read_frame().value
	var cards: Dictionary = initial.ui.cards
	if not cards.initial or cards.candidates.is_empty() or initial.ui.run_time!=0.0: return false
	var began := Time.get_ticks_usec()
	var candidate: Dictionary = cards.candidates[0]
	if not session.bridge.command("choose_card",{"offer_id":cards.offer_id,"candidate_id":candidate.candidate_id}).ok: return false
	for frame in range(600):
		session.cpp_choices.poll()
		if not _package_step(session): return false
		if not session.bridge.read_frame().value.ui.weapon_levels.is_empty(): break
		await process_frame
	await process_frame
	await process_frame
	var equipped: Dictionary = session.bridge.read_frame().value
	var ok: bool = equipped.ui.weapon_levels.any(func(item): return item.id==candidate.id) and session.cpp_choices.equipped.has("weapon:"+str(candidate.id))
	_package_measure(label+"の初期装備",{"resource_and_present_ms":(Time.get_ticks_usec()-began)/1000.0,"weapon":candidate.id,"equipped":ok})
	return ok

func _package_boss_preparation(session: RunSession) -> bool:
	var bridge: RefCounted = session.bridge
	var ok := true
	for i in ContentManager.cfg.weapon_slots:
		ok = bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W%02d" % (i+1),"levels":1}).ok and ok
	var at: float = ContentManager.stage(1).boss_start(ContentManager.cfg)+ContentManager.cfg.boss_time_spread+0.1
	var began := Time.get_ticks_usec()
	ok = bridge.command("dev_set_scenario",{"kind":"lab","params":{"lab_mode":true,"auto_spawn":false,"auto_boss":true,"invincible":true,"time":at,"level":1}}).ok and ok
	for i in 3: ok = _package_step(session) and ok
	await process_frame
	await process_frame
	var boss: bool = not bridge.read_frame().value.ui.boss_bodies.is_empty()
	_package_measure("実験場条件のボス初登場",{"spawn_and_present_ms":(Time.get_ticks_usec()-began)/1000.0,"boss_bodies_present":boss,"natural_progression":false})
	return boss and ok

func _package_lab_preparation(session: RunSession) -> bool:
	var bridge: RefCounted = session.bridge
	var ok := await _package_boss_preparation(session)
	var began := Time.get_ticks_usec()
	ok = bridge.command("dev_edit",{"kind":"comet_weapon","payload":{"id":"W22"}}).ok and ok
	ok = _package_step(session) and ok
	var cards: Dictionary = bridge.read_frame().value.ui.cards
	if cards.get("swap_pick","")!="W22" or cards.candidates.is_empty(): return false
	var target: Dictionary = cards.candidates[0]
	ok = bridge.command("choose_swap",{"offer_id":cards.offer_id,"candidate_id":target.candidate_id,"replace_weapon_id":str(target.id)}).ok and ok
	# prepareを差し替えず、実際の資源要求→描画準備→装備への保持を待つ。
	for frame in range(600):
		session.cpp_choices.poll()
		ok = _package_step(session) and ok
		if session.cpp_choices.equipped.has("weapon:W22"): break
		await process_frame
	await process_frame
	await process_frame
	var exchanged: bool = bridge.read_frame().value.ui.weapon_levels.any(func(item): return item.id=="W22") and session.cpp_choices.equipped.has("weapon:W22")
	_package_measure("実験場条件の装備交換",{"offer_resources_and_present_ms":(Time.get_ticks_usec()-began)/1000.0,"equipped":exchanged,"natural_progression":false})
	return exchanged and ok

func _package_release(session: RunSession, label: String, normal_return: bool) -> bool:
	var id := session.id
	var scopes: Array[ContentResourceScope] = []
	if session.resources!=null: scopes.append(session.resources)
	if session.cpp_choices!=null:
		for row: Dictionary in session.cpp_choices.candidates.values(): scopes.append(row.scope)
		for scope: ContentResourceScope in session.cpp_choices.equipped.values(): scopes.append(scope)
	var began := Time.get_ticks_usec()
	if normal_return: GameManager.abort_run()
	else: session.free()
	var command_ms := (Time.get_ticks_usec()-began)/1000.0
	for frame in range(600):
		await process_frame
		if RunManager.session(id)==null and ContentManager.pending_resources()==0: break
	var released: bool = RunManager.session(id)==null and ContentManager.pending_resources()==0
	for scope: ContentResourceScope in scopes:
		released = scope.cancelled and scope.resources.is_empty() and scope.pending.is_empty() and scope.warm_materials.is_empty() and released
	_package_measure(label+"から戻る",{"command_ms":command_ms,"cleanup_elapsed_ms":(Time.get_ticks_usec()-began)/1000.0,"scopes":scopes.size(),"released":released,"normal_return":normal_return})
	return released

## 撤去後の既定起動→通常出撃→自然なDeath→結果保存。開発命令・状態上書きは使わない。
func _package_final_runtime() -> void:
	if OS.has_feature("editor") or SaveManager.SAVE_PATH.begins_with("user://") or SaveManager.SETTINGS_PATH.begins_with("user://"):
		push_error("最終配布確認には隔離した保存先と配布エンジンが必要です")
		quit(1)
		return
	if not await _package_startup():
		quit(1)
		return
	var save_path: String = SaveManager.SAVE_PATH
	var before_hash := FileAccess.get_sha256(save_path) if FileAccess.file_exists(save_path) else ""
	var before_runs := int(SaveManager.data.best.runs)
	var observed := {"results":0,"saves":0,"result":{}}
	var on_save := func(): observed.saves += 1
	SaveManager.save_changed.connect(on_save)
	_package_measure("最終配布の既定起動",{"main_in_tree":root.get_node_or_null("Main")!=null,"headless":DisplayServer.get_name()=="headless"})
	GameManager.start_run(1)
	var session: RunSession = RunManager.current()
	if session==null or not await _package_ready(session):
		push_error("最終配布確認の通常出撃を開始できません")
		quit(1)
		return
	_package_measure("最終配布の通常出撃準備",{"loading_timings":session.loading_timings,"ready":session.bridge!=null})
	var id := session.id
	# 通常configureのmode=0を保ち、同じランの本番結果通知だけを観測する。
	var normal_mode: bool = int(session.bridge.recording_origin.options.mode)==0
	session.cpp_finished.connect(func(result: Dictionary):
		observed.results += 1
		observed.result = result.duplicate(true))
	var ok := await _package_initial_equipment(session,"最終通常出撃") and normal_mode
	var began := Time.get_ticks_usec()
	var ticks := 0
	while ticks<120*180 and Time.get_ticks_usec()-began<150000000 and observed.results==0 and ok:
		if not is_instance_valid(session) or session.bridge==null:
			ok = false
			break
		var current: Dictionary = session.bridge.read_frame()
		if not current.ok:
			ok = false
			break
		var cards: Dictionary = current.value.ui.cards
		if int(cards.get("offer_id",0))>0 and int(cards.get("selected_id",0))==0:
			if cards.candidates.is_empty():
				ok = false
				break
			var first: Dictionary = cards.candidates[0]
			var payload := {"offer_id":cards.offer_id,"candidate_id":first.candidate_id}
			var command := "choose_card"
			if not str(cards.get("swap_pick","")).is_empty():
				command = "choose_swap"
				payload.replace_weapon_id = str(first.id)
			ok = session.bridge.command(command,payload).ok
		if not ok: break
		session.cpp_choices.poll()
		ok = _package_step(session)
		ticks += 1
		# 状態だけを早送りせず、本番の資源準備・表示・結果flushにもフレームを渡す。
		if ticks%16==0: await process_frame
	# 自然な結果が出ない場合は、強制終了や時刻の上書きで成立させない。
	var natural_death: bool = observed.results==1 and observed.result.get("kind","")=="Death"
	_package_measure("撤去後の自然な終了",{"ticks":ticks,"step_budget_seconds":180,"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0,"normal_mode":normal_mode,"result_count":observed.results,"kind":observed.result.get("kind","")})
	ok = natural_death and ok
	if not ok:
		push_error("最終配布確認は上限内の自然なDeathと結果通知が未成立です")
		quit(1)
		return
	for frame in range(600):
		await process_frame
		if not GameManager.screen_transition_active and RunManager.session(id)==null: break
	var app := root.get_node_or_null("Main")
	var result_view: Node = app.get("_current") if app!=null else null
	var result_visible: bool = GameManager.screen==GameManager.Screen.RESULT and is_instance_valid(result_view) and result_view.get_script()==load("res://scripts/ui/result_screen.gd")
	var saved_hash := FileAccess.get_sha256(save_path) if FileAccess.file_exists(save_path) else ""
	var saved = JSON.parse_string(FileAccess.get_file_as_string(save_path)) if not saved_hash.is_empty() else null
	var saved_once: bool = observed.saves==1 and int(SaveManager.data.best.runs)==before_runs+1 and not saved_hash.is_empty() and saved_hash!=before_hash
	saved_once = saved is Dictionary and int(saved.best.runs)==before_runs+1 and saved==JSON.parse_string(JSON.stringify(SaveManager.data)) and saved_once
	var last_result: Dictionary = GameManager.last_result.duplicate(true)
	# 実際に受け取った同じ結果の再通知を入口へ渡し、二重保存を拒否する。
	GameManager.finish_cpp_run(observed.result)
	var duplicate_rejected: bool = not SaveManager.record_run(last_result) and observed.saves==1 and FileAccess.get_sha256(save_path)==saved_hash
	GameManager.reset_to_main_menu()
	for frame in range(600):
		await process_frame
		if not GameManager.screen_transition_active and RunManager.get("_sessions").is_empty() and ContentManager.pending_resources()==0: break
	var returned: bool = GameManager.screen==GameManager.Screen.MAIN_MENU and RunManager.get("_sessions").is_empty() and ContentManager.pending_resources()==0
	var unchanged: bool = observed.results==1 and observed.saves==1 and GameManager.last_result==last_result and FileAccess.get_sha256(save_path)==saved_hash
	SaveManager.save_changed.disconnect(on_save)
	_package_measure("撤去後の結果保存と戻る",{"result_screen":result_visible,"saved_once":saved_once,"duplicate_rejected":duplicate_rejected,"save_signals":observed.saves,"returned_without_sessions":returned,"result_and_save_unchanged":unchanged})
	ok = result_visible and saved_once and duplicate_rejected and returned and unchanged
	if ok: print("[package_final_runtime] OK cpu="+Engine.get_architecture_name())
	else: push_error("最終配布確認の結果保存・重複拒否・戻るが未成立です")
	quit(0 if ok else 1)
