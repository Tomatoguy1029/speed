## スリルと寄り道の受け入れ確認。セーブはメモリだけで扱う。
## Godot --headless --log-file /tmp/speed-acceptance.log --path speed res://tests/integration/thrill_acceptance.tscn
extends Node
const AcceptanceRunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS

class MemorySave:
	extends "res://scripts/managers/save_manager.gd"
	func save() -> void:
		save_changed.emit()
	func _save_settings() -> void:
		pass

var scene: RunSession
var passed := 0
var failed := 0
var shots := ""

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cpp-stage="):
			await _test_cpp_stage(arg.trim_prefix("--cpp-stage=").to_int())
			return
	if "--cpp-entries" in OS.get_cmdline_user_args():
		await _test_cpp_entries()
		return
	await _test_cpp_stage(1)

func _close() -> void:
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("[acceptance] OK ", label)
	else:
		failed += 1
		push_error("[acceptance] FAIL " + label)

func _shot(label: String, redraw: CanvasItem = null) -> void:
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if redraw != null:
		redraw.queue_redraw()
	# 静止画面やフォーカスを外した画面でも、撮影前に描画を完了させる。
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	get_viewport().get_texture().get_image().save_png(shots.path_join(label + ".png"))
	print("[acceptance] CAPTURE ", label)

func _settle_screen() -> void:
	while GameManager.screen_transition_active:
		await get_tree().process_frame
	await get_tree().process_frame

## S1〜S5の表示確認。通常の選択・入力と、時間を飛ばす診断を別のランで記録する。
func _cpp_open(stage: int, check_entry := true) -> RunSession:
	GameManager.run_stage = stage
	GameManager.run_endless = false
	GameManager.run_start_source = "stage_start"
	var owner := RunManager.create_run({"seed":932})
	owner.auto_step = false
	add_child(owner)
	for i in 4000:
		if owner.bridge!=null or owner.cpp_error!=OK: break
		await get_tree().process_frame
	if check_entry: _check(owner.bridge!=null and not _cpp_has_legacy(owner),"C++通常入口で旧シミュレーションを作らない: %d" % stage)
	return owner

func _cpp_choose(owner: RunSession, frame: Dictionary) -> bool:
	if frame.ui.phase==AcceptanceRunIds.Phase.Paused: return owner.bridge.command("pause",{"paused":false}).ok
	var cards: Dictionary = frame.ui.cards
	if cards.offer_id==0 or cards.selected_id!=0: return true
	if cards.candidates.is_empty(): return false
	var candidate: Dictionary = cards.candidates[0]
	# 既存の通常候補から射撃を優先する。候補やレベルは書き換えない。
	for item: Dictionary in cards.candidates:
		if item.id=="W01": candidate = item;break
	if "--cpp-late-only" in OS.get_cmdline_user_args():
		var priorities := {"W05":120,"T10":110,"T07":105,"W23":100,"T11":95,"W08":90,"T05":85,"W01":80,"T31":75,"T04":70,"W17":65,"T12":60}
		for item: Dictionary in cards.candidates:
			if int(priorities.get(item.id,0))>int(priorities.get(candidate.id,0)): candidate = item
	var result: Dictionary = owner.bridge.command("choose_card",{"offer_id":cards.offer_id,"candidate_id":candidate.candidate_id})
	return result.ok

func _test_cpp_stage(stage: int) -> void:
	SaveManager.data = SaveManager.default_data()
	SaveManager.data.intro_seen = true
	var definition: StageDef = load("res://data/stages/stage_%d.tres" % stage)
	print("[S%d 定義] boss_enabled=%s boss_id=%s boss_start=%s time_limit=%s" % [stage,definition.boss_enabled,definition.boss_id,definition.boss_start(ContentManager.cfg),definition.time_limit])
	if "--cpp-diagnostic-only" not in OS.get_cmdline_user_args(): await _test_cpp_natural(stage,definition)
	if "--cpp-natural-only" not in OS.get_cmdline_user_args() and "--cpp-late-only" not in OS.get_cmdline_user_args(): await _test_cpp_diagnostic(stage,definition)
	print("[S%d] passed=%d failed=%d" % [stage,passed,failed])
	get_tree().quit(1 if failed else 0)

## 現在位置から一定だけ先を向き、通常の満充填とタッチ描線の確定を待つ。
func _cpp_route_input(frame: Dictionary, driver: Dictionary, owner: RunSession) -> Intent:
	var intent := Intent.new()
	var ship: Dictionary = frame.ui.ship
	var draw: Dictionary = frame.ui.draw
	var at: Vector2 = ship.ship_pos
	var ahead := at.normalized().rotated(0.5) if at.length()>1.0 else Vector2.RIGHT
	intent.has_cursor = true
	intent.cursor = ahead*2400.0
	intent.hero_press = int(frame.tick)%120==0
	if driver.smart:
		if frame.ui.phase==AcceptanceRunIds.Phase.Play and not draw.drawing and not draw.tracing and int(frame.tick)>=int(driver.scan):
			var path := _cpp_safer_path(owner,frame,(intent.cursor-at).normalized(),450.0,driver)
			driver.cursor = path[-1]
			driver.scan = int(frame.tick)+30
		if driver.has("cursor"): intent.cursor = driver.cursor
		intent.hero_press = not str(frame.ui.hero.power).is_empty() and frame.ui.hero.cooldown<=0 and (frame.ui.hp<frame.ui.max_hp*0.7 or int(driver.blockers)>0)

	var clock := float(frame.tick)/120.0
	if driver.start<0.0 and clock>=driver.next and not draw.drawing and not draw.tracing and draw.fuel>=frame.ui.boost_min_cost:
		var heading: Vector2 = ship.ship_heading
		if heading.length_squared()<0.1: heading = (intent.cursor-at).normalized()
		driver.stroke.clear()
		if driver.smart:
			var length: float = frame.ui.base_draw_length*maxf(draw.fuel/ContentManager.cfg.fuel_capacity,ContentManager.cfg.boost_min_q)*(frame.ui.max_speed/ContentManager.cfg.base_max_speed)*frame.ui.length_mult*0.9
			driver.stroke = Array(_cpp_safer_path(owner,frame,(intent.cursor-at).normalized(),length,driver))
		else:
			for k in 7: driver.stroke.append(at+heading*(60.0+220.0*k)+heading.orthogonal()*(80.0 if k%2 else -80.0))
		driver.start = clock
		driver.next = clock+1.0
	if driver.start>=0.0:
		var elapsed := clock-float(driver.start)
		intent.touch = true
		intent.pen = driver.stroke[mini(6,int(elapsed*120.0))]
		intent.press = elapsed<0.5/120.0
		if elapsed>=7.0/120.0:
			intent.pen_release = true
			driver.start = -1.0
	return intent

## 読取専用の経路判定で候補を比べる。未来の不確実さは安全の保証に数えない。
func _cpp_safer_path(owner: RunSession, frame: Dictionary, direction: Vector2, length: float, driver: Dictionary) -> PackedVector2Array:
	var at: Vector2 = frame.ui.ship.ship_pos
	var best := PackedVector2Array([at,at+direction*length])
	var score := INF
	for angle in [0.0,-0.7,0.7,-1.4,1.4]:
		var path := PackedVector2Array()
		for k in 7: path.append(at+direction.rotated(angle)*(length*k/6.0))
		var answer: Dictionary = owner.bridge.query_route(path,{"margin":16.0,"window":0.2,"draw_seconds":0.06,"exit_clearance":80.0})
		if not answer.ok:
			driver.query_errors += 1
			continue
		if not answer.value.unsupported.is_empty(): driver.uncertain += 1
		var next_score: float = answer.value.blockers.size()*1000.0+absf(angle)-minf(answer.value.fodder.size(),100.0)*0.01
		if next_score<score:
			score = next_score
			best = path
			driver.blockers = answer.value.blockers.size()
	return best

func _test_cpp_natural(stage: int, definition: StageDef) -> void:
	var late_only := "--cpp-late-only" in OS.get_cmdline_user_args()
	var owner := await _cpp_open(stage,not late_only)
	if owner.bridge==null:
		owner.free()
		return
	var saw := {"early":false,"growth":false,"late":false,"boss":false,"fired":false,"ended":false}
	var event_counts := {}
	var observed := {"frame":{}}
	owner.bridge.subscribe("S進行記録",func(frame: Dictionary):
		observed.frame = frame
		for event: Dictionary in frame.events:
			var kind := str(event.type)
			event_counts[kind] = int(event_counts.get(kind,0))+1
			if kind=="boss_spawn": saw.boss = true
			if kind in ["weapon_fire","barrier_hit","barrier_restore","anchor_fire","bipolar_charge","escort_deploy","escort_slash","sonic_push","sonic_impact","bolt"]: saw.fired = true
		return true)
	var initial: Dictionary = owner.bridge.read_frame().value
	if not late_only: _check(initial.ui.cards.initial and initial.ui.run_time==0.0,"通常出撃は0秒の武器選択から始まる")
	var frame: Dictionary = initial
	var driver := {"stroke":[],"start":-1.0,"next":0.0,"smart":late_only,"scan":0,"blockers":0,"query_errors":0,"uncertain":0}
	var limit := int((definition.time_limit+15.0)*120.0*2.0) if definition.time_limit>0 else 120*1920
	for tick in limit:
		if not _cpp_choose(owner,frame):
			_check(false,"通常カードを確定する")
			break
		owner.cpp_choices.poll()
		var intent := _cpp_route_input(frame,driver,owner)
		var step: Dictionary = owner.bridge.step(1.0/120.0,owner.bridge.pack_intent(intent),{"logical_size":Vector2(1280,720)})
		if not step.ok:
			_check(false,"通常固定更新に未対応処理や通知エラーがない: "+str(step))
			break
		if not owner.bridge.delivery_error.is_empty() and not owner.bridge.delivery_error.ok:
			_check(false,"表示通知の配信を完了する: "+str(owner.bridge.delivery_error))
			break
		frame = observed.frame
		saw.early = saw.early or frame.ui.run_time>=10.0
		saw.growth = saw.growth or frame.ui.level>1
		saw.late = saw.late or frame.ui.run_time>=definition.boss_start(ContentManager.cfg)-1.0
		saw.fired = saw.fired or owner.bridge.read_metrics().value.friendly_shots>0 or not frame.ui.mines.items.is_empty() or not frame.ui.afterimage.echoes.is_empty()
		if frame.result is Dictionary:
			saw.ended = true
			break
		if tick%(120*60)==0: print("[S%d 自然進行] time=%s level=%s hp=%s" % [stage,frame.ui.run_time,frame.ui.level,frame.ui.hp])
		if tick%120==0: await get_tree().process_frame
	print("[S%d 自然通し] 無敵なし・時間飛ばしなし・強制撃破なし time=%s level=%s gear=%s traits=%s result=%s events=%s criteria=%s" % [stage,frame.ui.run_time,frame.ui.level,frame.ui.weapon_levels,frame.ui.trait_levels,frame.result,event_counts,saw])
	if late_only:
		print("[S%d 後半入力] query_errors=%s future_uncertain=%s" % [stage,driver.query_errors,driver.uncertain])
		_check(driver.query_errors==0,"後半の入力補正は読取専用の経路判定を通す")
		_check(saw.late and (saw.boss or not definition.boss_enabled) and saw.ended,"S%d 未成立だった自然な後半→ボス/終了" % stage)
	else:
		_check(saw.early and saw.growth and saw.late and (saw.boss or not definition.boss_enabled) and saw.ended,"S%d 自然な序盤→成長→終盤→設定済みボス/終了" % stage)
		_check(saw.fired,"S%d 通常取得装備が発動する" % stage)
	owner.free()
	await get_tree().process_frame

func _test_cpp_diagnostic(stage: int, definition: StageDef) -> void:
	# 自然通しの失敗で、独立した後半と終了の接続確認を飛ばさない。
	var owner := await _cpp_open(stage)
	if owner.bridge!=null:
		var input: Dictionary = owner.bridge.pack_intent(Intent.new())
		var frame: Dictionary = owner.bridge.read_frame().value
		_cpp_choose(owner,frame)
		for i in 1000:
			owner.cpp_choices.poll()
			owner.bridge.step(1.0/120.0,input, {"logical_size":Vector2(1280,720)})
			frame = owner.bridge.read_frame().value
			if frame.ui.phase==AcceptanceRunIds.Phase.Play: break
			await get_tree().process_frame
		owner.bridge.command("dev_edit",{"kind":"debug_action","payload":{"action":"invincible","args":{}}})
		owner.bridge.command("dev_edit",{"kind":"debug_action","payload":{"action":"time","args":{"seconds":definition.boss_start(ContentManager.cfg)+ContentManager.cfg.boss_time_spread+0.1}}})
		for tick in 120*50:
			var step: Dictionary = owner.bridge.step(1.0/120.0,input, {"logical_size":Vector2(1280,720)})
			if not step.ok:
				_check(false,"時間短縮した後半の更新: "+str(step))
				break
			frame = owner.bridge.read_frame().value
			_cpp_choose(owner,frame)
			owner.cpp_choices.poll()
			if tick==120*15 and definition.boss_enabled:
				_check(owner.bridge.command("dev_edit",{"kind":"debug_action","payload":{"action":"kill_boss","args":{}}}).ok,"時間短縮した診断でボスの終了へ進む")
			if frame.result is Dictionary: break
			if tick%60==0: await get_tree().process_frame
		print("[S%d 時間短縮診断] 無敵・時間飛ばし・強制撃破あり time=%s boss=%s result=%s" % [stage,frame.ui.run_time,frame.ui.boss_bodies,frame.result])
		_check(not definition.boss_enabled or not frame.ui.boss_bodies.is_empty() or frame.result is Dictionary,"設定済みボスの自動出現を維持する")
		_check(frame.result is Dictionary,"時間短縮診断の終了へ接続する")
	owner.free()

func _test_cpp_entries() -> void:
	SaveManager.data = SaveManager.default_data()
	SaveManager.data.intro_seen = true
	GameManager.boot_request = Callable()
	GameManager.screen = GameManager.Screen.TITLE
	var app: Node = load("res://scenes/app/main.tscn").instantiate()
	add_child(app)
	await _settle_screen()
	_check(GameManager.screen==GameManager.Screen.TITLE,"通常起動でタイトルを表示する")
	app._current.get_node("%StartButton").pressed.emit()
	await _settle_screen()
	_check(GameManager.screen==GameManager.Screen.MAIN_MENU,"タイトルからメニューへ進む")
	for stage in range(1,ContentManager.stage_count()+1):
		GameManager.goto(GameManager.Screen.STAGE_SELECT)
		await _settle_screen()
		app._current._map._select(stage-1)
		app._current._map._launch.pressed.emit()
		await _settle_screen()
		var owner := app._current as RunSession
		if owner!=null:
			for i in 4000:
				if owner.bridge!=null or owner.cpp_error!=OK: break
				await get_tree().process_frame
		_check(owner!=null and owner.bridge!=null and not _cpp_has_legacy(owner),"ステージ%dの通常出撃がC++だけを生成する" % stage)
		if owner!=null and owner.bridge!=null:
			var identity := owner.id
			GameManager.abort_run()
			await _settle_screen()
			_check(GameManager.screen==GameManager.Screen.MAIN_MENU and RunManager.session(identity)==null,"ステージ%dから戻るとセッションを解放する" % stage)
	GameManager.goto(GameManager.Screen.RESULT,false)
	await _settle_screen()
	app._current.get_node("%RetryButton").pressed.emit()
	await _settle_screen()
	var retry := app._current as RunSession
	if retry!=null:
		for i in 4000:
			if retry.bridge!=null or retry.cpp_error!=OK: break
			await get_tree().process_frame
	_check(retry!=null and retry.bridge!=null and not _cpp_has_legacy(retry),"結果画面の再出撃もC++だけを生成する")
	GameManager.abort_run()
	await _settle_screen()
	GameManager.replay_intro()
	await _settle_screen()
	var introduction = app._current
	for i in 4000:
		if introduction.session!=null and introduction.session.bridge!=null: break
		await get_tree().process_frame
	_check(introduction.session!=null and introduction.session.bridge!=null and not _cpp_has_legacy(introduction.session),"導入の画面出撃もC++だけを生成する")
	var intro_id: int = introduction.session.id if introduction.session!=null else -1
	GameManager.reset_to_main_menu()
	await _settle_screen()
	_check(RunManager.session(intro_id)==null,"導入から戻るとセッションを解放する")
	GameManager.goto(GameManager.Screen.ENEMY_LAB)
	await _settle_screen()
	var laboratory = app._current.session
	for i in 4000:
		if laboratory.scene!=null and laboratory.scene.bridge!=null: break
		await get_tree().process_frame
	_check(laboratory.scene!=null and laboratory.scene.bridge!=null and not _cpp_has_legacy(laboratory.scene),"実験場の画面出撃もC++だけを生成する")
	if laboratory.scene!=null and laboratory.scene.bridge!=null:
		var lab_bridge: RefCounted = laboratory.scene.bridge
		var input: Dictionary = lab_bridge.pack_intent(Intent.new())
		var at: float = ContentManager.stage(1).boss_start(ContentManager.cfg)+ContentManager.cfg.boss_time_spread+0.1
		_check(lab_bridge.command("dev_set_scenario",{"kind":"lab","params":{"lab_mode":true,"auto_spawn":false,"auto_boss":false,"invincible":true,"time":at}}).ok,"実験場の明示した自動開始を設定する")
		for i in 3: lab_bridge.step(1.0/120.0,input,{"logical_size":Vector2(1280,720)})
		_check(lab_bridge.read_frame().value.ui.boss_bodies.is_empty(),"実験場の自動ボスなしでは後半時刻でも始めない")
		_check(lab_bridge.command("dev_set_scenario",{"kind":"lab","params":{"lab_mode":true,"auto_spawn":false,"auto_boss":true,"invincible":true,"time":at}}).ok,"実験場の自動ボスを明示して許可する")
		for i in 3: lab_bridge.step(1.0/120.0,input,{"logical_size":Vector2(1280,720)})
		_check(not lab_bridge.read_frame().value.ui.boss_bodies.is_empty(),"実験場の明示した自動ボスは通常の出現へつながる")
	var lab_id: int = laboratory.scene.id if laboratory.scene!=null else -1
	GameManager.reset_to_main_menu()
	await _settle_screen()
	_check(RunManager.session(lab_id)==null,"実験場から戻るとセッションを解放する")
	app.free()
	await get_tree().process_frame
	# タイムラインが保存した索引から途中再生する。
	var path := "res://.content/run/stage_1.json"
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	GameManager.run_start_content = {"index":path,"signature":index.input_sha256}
	GameManager.run_start_source = "timeline"
	GameManager.run_start_time = 30.0
	GameManager.run_stage = 1
	var owner := RunManager.create_run({"seed":932})
	owner.auto_step = false
	add_child(owner)
	for i in 4000:
		if owner.bridge!=null or owner.cpp_error!=OK: break
		await get_tree().process_frame
	_check(owner.bridge!=null and not _cpp_has_legacy(owner) and owner.bridge.read_frame().value.ui.run_time==30.0,"タイムラインの途中開始もC++だけを生成する")
	owner.free()
	_check(RunManager._sessions.is_empty(),"全入口から戻った後にランを残さない")
	print("[P01] passed=%d failed=%d" % [passed,failed])
	get_tree().quit(1 if failed else 0)

func _cpp_has_legacy(owner: Object) -> bool:
	for property: Dictionary in owner.get_property_list():
		if property.name == "_sim": return owner.get("_sim") != null
	return false
