extends Node

var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("[lab_core] " + label)

func _ready() -> void:
	if "--cpp-lab-replay" in OS.get_cmdline_user_args() or "--cpp-lab-replay-placement" in OS.get_cmdline_user_args():
		await cpp_lab_replay()
		print("[cpp_lab_replay] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-lab-history" in OS.get_cmdline_user_args():
		await cpp_lab_history()
		print("[cpp_lab_history] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-lab" in OS.get_cmdline_user_args():
		await cpp_lab()
		print("[cpp_lab_core] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-definition-edits" in OS.get_cmdline_user_args():
		check(await cpp_definition_edits(), "型付き定義編集の確認を最後まで行う")
		print("[cpp_definition_edits] passed=%d failed=%d" % [passed, failed])
		get_tree().quit(1 if failed else 0)
		return
	if not FileAccess.file_exists("res://gyms/enemy_lab/lab_session.gd"):
		check(false, "専用の実験セッションが存在する")
		get_tree().quit(1)
		return
	var script := load("res://gyms/enemy_lab/lab_session.gd")
	var lab = script.new()
	add_child(lab)
	check(is_equal_approx(lab.DT, 1.0 / Engine.physics_ticks_per_second), "実験場は本番と同じ物理更新の刻み")
	var data_before := JSON.stringify(SaveManager.data)
	var config_before := ContentManager.cfg.enemy_hp_mult
	await lab.reset({"seed": 932, "empty": true, "stage": 4})
	check(lab.run.state.stage.boss_id == &"hydra", "実験の基準はステージ4のヒュドラ")
	check(lab.run.state.phase == RunState.Phase.PLAY, "カード選択なしで実験できる")
	check(lab.run.cfg != ContentManager.cfg, "設定を実験ごとに複製する")
	lab.perform("spawn", {"type": "gunner", "pos": [200, 0], "count": 3})
	check(lab.run.enemies.count() == 3, "好きな敵を複数出せる")
	for n in 120:
		lab.step()
	check(is_equal_approx(lab.run.state.time, 1.0), "120回の更新で1秒進む")
	var track = load("res://gyms/enemy_lab/lab_timeline.gd").new()
	track.session = lab
	check(is_equal_approx(track.visible_span() * lab.DT, 10.0), "タイムラインの表示幅は10秒を保つ")
	track.free()
	var digest: String = lab.digest()
	check(not digest.is_empty(), "比較用の戦闘状態を取得できる")
	await lab.seek(0)
	check(lab.tick == 0, "開始へ巻き戻す")
	for checkpoint in lab.checkpoints: checkpoint.scene.queue_free()
	lab.checkpoints.clear()
	await lab.seek(120)
	check(lab.digest() == digest, "同じ時刻へ戻ると戦闘状態が一致する")
	check(JSON.stringify(SaveManager.data) == data_before and ContentManager.cfg.enemy_hp_mult == config_before, "実験でセーブと本番設定を変えない")
	await lab.reset({"seed": 932, "empty": true})
	check(lab.run.enemies.count() == 0, "実験を空の状態へ戻せる")
	await lab.reset({"seed": 801, "empty": true, "stage": 4})
	lab.perform("boss", {"type": "hydra", "pos": [400, 0]})
	for n in 150:
		lab.step()
	var boss_digest: String = lab.digest()
	await lab.seek(0)
	for checkpoint in lab.checkpoints: checkpoint.scene.queue_free()
	lab.checkpoints.clear()
	await lab.seek(150)
	check(lab.digest() == boss_digest, "うみへびの首と乱数も巻き戻して再現できる")
	await lab.seek(60)
	lab.perform("spawn", {"type": "rocket", "pos": [-300, 0]})
	check(lab.branches.size() == 1 and lab.furthest == 60, "過去を編集すると元の履歴を残して分岐する")
	lab.queue_free()
	await get_tree().process_frame
	print("[lab_core] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func cpp_definition_edits() -> bool:
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var definition: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
	definition.armor = 0.0
	definition.speed = 0.0
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	var records: Dictionary = builder.chase_records(definition,config)
	var original: PackedByteArray = schema.write_content(records,"定義編集の確認".sha256_text().hex_decode())
	var first = load("res://scripts/runtime/run_bridge.gd").new()
	var second = load("res://scripts/runtime/run_bridge.gd").new()
	for bridge in [first,second]:
		if not bridge.configure(original,{"api_version":1,"run_id":1 if bridge==first else 2,"mode":1,"stage_id":"編集確認","profile":{},"settings":{}}).ok or not bridge.start(832,{}).ok: return false
		bridge.subscribe("編集確認",func(_frame: Dictionary) -> bool: return true)
		if not bridge.command("dev_remove_weapon",{"id":"W01"}).ok: return false
		if not bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(-500,300)}).ok: return false
	var id: int = first._core.enemies_snapshot()[0].id
	if not first.command("dev_damage",{"entity_id":id,"amount":1.0,"cause":"shot","no_crit":true}).ok: return false
	if not first.step(1.0/120.0,first.pack_intent(Intent.new()),{"logical_size":Vector2(1280,720)}).ok: return false
	var before: Dictionary = first._core.enemies_snapshot()[0]
	var tick: int = first.read_frame().value.tick
	var held: Dictionary = first.checkpoint()
	if not held.ok: return false
	definition.stage_hp = definition.base_hp(config)*2.0
	definition.armor = 7.0
	definition.speed = 20.0
	var changed: PackedByteArray = schema.write_content(builder.chase_records(definition,config),"定義編集の確認".sha256_text().hex_decode())
	var edited: Dictionary = first.replace_definition("drifter",changed)
	check(edited.ok,"検証済みの定義を停止境界で原子的に編集する")
	var after: Dictionary = first._core.enemies_snapshot()[0]
	check(after.id==id and after.max_hp>before.max_hp and is_equal_approx(after.hp/after.max_hp,before.hp/before.max_hp),"生存個体のIDとHP割合を保つ")
	check(after.armor>0.0 and after.speed==20.0,"旧値0から装甲と速度を再計算する")
	check(first.read_frame().value.tick==tick and second._core.enemies_snapshot()[0].armor==0.0,"編集は現在tickと別ランを変えない")
	var failed_edit: Dictionary = first.replace_definition("drifter",PackedByteArray([1,2,3]))
	check(not failed_edit.ok and first._core.enemies_snapshot()[0]==after,"不正な定義は個体を部分変更しない")
	check(first.replace_definition("drifter",original).ok and first.read_frame().value.tick==tick,"逆命令も現在tickで適用する")
	check(first.restore(held.value).ok and first._core.enemies_snapshot()[0]==before,"編集後も保持した旧ContentBundleと個体へ戻る")
	first.release_checkpoint(held.value)
	for bridge in [first,second]:
		check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.get("ok",false),"編集後の読取・回収・通知配信が成功する")
		bridge.dispose()
	return true

func cpp_lab() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	var data_before := JSON.stringify(SaveManager.data)
	await lab.reset({"seed":932,"empty":true,"stage":4})
	check(lab.bridge!=null and lab.scene.runtime_kind=="cpp" and lab.run!=null,"実験場は旧RunSimulationを作らずC++Sessionを使う")
	if lab.run==null: lab.queue_free(); return
	check(lab.last_error.get("ok",false),"開始設定が成功する: "+str(lab.last_error))
	if not lab.last_error.get("ok",false): lab.queue_free(); return
	check(lab.run.state.stage.boss_id==&"hydra" and lab.run.state.phase==RunState.Phase.PLAY,"元のステージとカード待ちのない入口を保つ")
	check(lab.perform("spawn",{"type":"gunner","pos":[200,0],"count":3}) and lab.run.enemies.count()==3,"手動配置は通常の生成サービスへ接続する")
	var id: int = lab.run.enemies.table.id[lab.selected]
	check(lab.perform("move",{"id":id,"pos":[300,50],"angle":0.25}) and lab.run.enemies.table.pos[lab.selected]==Vector2(300,50),"論理IDで選択と移動を行う")
	check(lab.perform("pin",{"value":true,"pos":[-600,0]}),"機体固定を正式命令で設定する")
	for n in 120: lab.step()
	check(is_equal_approx(lab.run.state.time,1.0) and lab.run.state.ship_pos==Vector2(-600,0),"120Hzで進めながら機体だけを固定する")
	check(lab.bridge.read_frame().ok and lab.bridge.collect_frame().ok and lab.bridge.delivery_error.get("ok",false),"更新・読取・回収・通知配信が成功する")
	check(lab.perform("delete",{"id":id}) and lab.row_for_id(id)<0,"削除後の選択に再利用した行を混ぜない")
	var digest: String = lab.digest()
	await lab.seek(0)
	for checkpoint in lab.checkpoints: checkpoint.scene.queue_free()
	lab.checkpoints.clear()
	await lab.seek(120)
	check(lab.digest()==digest,"同じ入力と手動配置を固定tickで再現する")
	check(JSON.stringify(SaveManager.data)==data_before,"実験で共有セーブを変えない")
	await lab.reset({"empty":true})
	check(lab.run.enemies.count()==0,"Resetで開始状態へ戻る")
	check(lab.perform("schedule",{"entries":[{"type":"drifter","pos":[500,500],"start":0,"end":0,"interval":1}]}),"予定配置をC++へ渡す")
	lab.step()
	check(lab.run.enemies.count()==1,"予定配置をC++の時計と乱数で実行する")
	print("[cpp_lab_core] 未実施: うみへびの首を含む再生（該当種類の移行待ち）")
	lab.queue_free()
	await get_tree().process_frame

func cpp_lab_history() -> void:
	var script := load("res://gyms/enemy_lab/lab_session.gd")
	var first = script.new()
	var second = script.new()
	add_child(first)
	add_child(second)
	for lab in [first,second]:
		await lab.reset({"empty":true,"overrides":{"drifter":{"armor":0.0,"speed":0.0}}})
		check(lab.perform("spawn",{"type":"drifter","pos":[500,300]}),"編集確認の個体を正式入口で配置する")
	for n in 24: first.step()
	var before: Dictionary = first.bridge.read_lab().value.enemies[0].duplicate(true)
	var id: int = before.id
	var tick: int = first.tick
	check(first.perform("parameter",{"type":"drifter","key":"armor","value":7.0}),"Labの現在tickで旧値0の装甲を編集する")
	check(first.run.enemies.table.armor[first.row_for_id(id)]>0.0 and first.tick==tick,"装甲を再算出しIDと現在tickを維持する")
	await first.undo_edit()
	check(first.run.enemies.table.armor[first.row_for_id(id)]==0.0 and first.tick==tick,"値のundoは同じtickの逆命令で戻す")
	await first.redo_edit()
	check(first.run.enemies.table.armor[first.row_for_id(id)]>0.0 and first.tick==tick,"値のredoも同じtickに適用する")
	check(first.perform("parameter",{"type":"drifter","key":"speed","value":20.0}),"Labの旧値0の速度を編集する")
	var after: Dictionary = first.bridge.read_lab().value.enemies[0].duplicate(true)
	check(after.speed==20.0 and after.id==id and is_equal_approx(after.hp/after.max_hp,before.hp/before.max_hp),"速度編集でもIDとHP割合を維持する")
	var count: int = first.history.size()
	check(not first.perform("parameter",{"type":"unknown","key":"speed","value":1.0}) and first.bridge.read_lab().value.enemies[0]==after and first.history.size()==count,"失敗は状態と履歴を部分変更しない")
	check(second.bridge.read_lab().value.enemies[0].speed==0.0 and second.bridge.read_lab().value.enemies[0].armor==0.0,"別Sessionへ編集値を漏らさない")
	check(first.history.slice(-3).all(func(command): return command.tick==tick),"適用した逆命令を同じtickの履歴へ保存する")
	await first.seek(12)
	check(first.perform("time",{"value":3.0}) and first.branches.size()==1 and first.furthest==12,"過去表示中の値編集は履歴を分岐する")
	for lab in [first,second]:
		check(lab.bridge.read_frame().ok and lab.bridge.collect_frame().ok and lab.bridge.delivery_error.get("ok",false),"履歴編集後の読取・回収・通知配信が成功する")
		lab.queue_free()
	await get_tree().process_frame

func cpp_lab_replay() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true,"overrides":{"gunner":{"speed":0.0}}})
	check(lab.perform("spawn",{"type":"gunner","pos":[500,0]}),"攻撃を持つ敵を配置する")
	for n in 48: lab.step()
	var tick: int = lab.tick
	var firing: String = lab.digest()
	check(lab.perform("spawn",{"type":"drifter","pos":[700,400]}),"攻撃中の現在tickで敵を追加する")
	for n in 12: lab.step()
	await lab.undo_edit()
	check(lab.tick==tick+12 and lab.run.enemies.count()==1,"配置の取消は後続入力を保ち現在tickまで再構築する")
	await lab.redo_edit()
	check(lab.tick==tick+12 and lab.run.enemies.count()==2,"再配置も現在tickまで再構築する")
	await lab.seek(tick)
	check(lab.run.enemies.count()==2,"配置時刻の命令を同じ境界で適用する")
	if "--cpp-lab-replay-placement" in OS.get_cmdline_user_args():
		lab.queue_free()
		await get_tree().process_frame
		return
	await lab.reset({"empty":true,"overrides":{"drifter":{"speed":0.0}}})
	lab.perform("spawn",{"type":"drifter","pos":[500,0]})
	for n in 12: lab.step()
	var old_hash: String = lab.bridge.read_recording(true).value.identity.payload_sha256
	var old_epoch: int = lab.bridge.read_frame().value.epoch
	await lab.seek(0)
	for n in 24: lab.step()
	lab.perform("parameter",{"type":"drifter","key":"speed","value":20.0})
	var new_hash: String = lab.bridge.read_recording(true).value.identity.payload_sha256
	await lab.seek(12)
	check(old_hash!=new_hash and lab.bridge.read_recording(true).value.identity.payload_sha256==old_hash and lab.run.enemies.table.speed[0]==0.0,"seekで保持した旧ContentBundleへ戻る")
	check(lab.bridge.read_frame().value.epoch>old_epoch,"復帰は共通保持の新epochへ切り替える")
	for target in [0,24,6,18,3]: await lab.seek(target)
	check(lab.checkpoints.size()<=3,"保持するSessionとC++保持点の上限を守る")
	lab.perform("command",{"name":"dev_add_xp","args":{"amount":100.0}})
	lab.step()
	check(lab.run.state.phase==RunState.Phase.LEVELUP,"カード待ちを復元対象に含める")
	var card_tick: int = lab.tick
	lab.perform("spawn",{"type":"drifter","pos":[900,500]})
	await lab.undo_edit()
	check(lab.tick==card_tick and lab.run.state.phase==RunState.Phase.LEVELUP,"カード待ちでも配置取消のtickと候補待ちを維持する")
	lab.cancel_seek()
	check(not lab.seeking and not lab.playing,"取消後の古いseekを進めない")
	await lab.reset({"empty":true})
	check(lab.tick==0 and lab.checkpoints.is_empty() and lab.edit_undo.is_empty() and lab.edit_redo.is_empty(),"Resetで開始状態とundo/redoと保持点へ戻る")
	check(lab.bridge.read_frame().ok and lab.bridge.collect_frame().ok and lab.bridge.delivery_error.get("ok",false),"再構築の後の読取・回収・通知配信が成功する")
	var ids: Array = RunManager._sessions.keys().duplicate()
	lab.queue_free()
	await get_tree().process_frame
	check(ids.all(func(id): return RunManager.session(id)==null),"画面破棄で現在と保持中の全Sessionを解放する")
