## 技ノードから指定したボス・技を一度再生し、別の技を抽選しない。
extends SceneTree
var failed := 0
func _initialize() -> void:
	if "--cpp-hydra-tools-display" in OS.get_cmdline_user_args(): call_deferred("native_hydra_display")
	elif "--cpp-hydra-tools-retry" in OS.get_cmdline_user_args(): call_deferred("native_hydra_retry")
	elif "--cpp-hydra-tools" in OS.get_cmdline_user_args(): call_deferred("native_hydra")
	elif "--cpp-canis-tools-restore" in OS.get_cmdline_user_args(): call_deferred("native_canis_restore")
	elif "--cpp-boss-tools-combo" in OS.get_cmdline_user_args(): call_deferred("native_combo")
	else: call_deferred("native_tools")
func native_check(ok: bool, label: String) -> void:
	if "--cpp-boss-tools-tail" in OS.get_cmdline_user_args() and (label.ends_with("制作画面からC++ボスを配置する") or label.ends_with("本番のボス表示へ接続する")): return
	if not ok: failed += 1; push_error(label)

func native_tools() -> void:
	for boss in (["canis_major"] if "--cpp-canis-tools" in OS.get_cmdline_user_args() else ["monoceros","centaurus"]):
		var selected := "kick" if boss == "monoceros" else "sirius_flame" if boss=="canis_major" else "volley"
		if boss=="canis_major":
			var compiled: Dictionary = load("res://tools/content/build_boss_program.gd").build_boss(boss,"res://.content/boss_%s.tres" % boss)
			native_check(compiled.get("error",FAILED)==OK,"canis_major: 共通変換から制作プログラムを生成する")
		var rules_path := "res://data/bosses/ai/%s_action_rules.tres" % boss
		var source_hash := FileAccess.get_sha256(rules_path)
		var trial = load("res://gyms/boss_flow_trial.tscn").instantiate()
		trial.set_meta("preview_request",{"boss":boss,"technique":selected})
		trial.set_meta("preview_program","res://.content/boss_%s.tres" % boss)
		root.add_child(trial)
		for frame in 300:
			await process_frame
			if trial.manual != null and not trial._switching: break
		native_check(trial.manual != null,boss+": 制作画面からC++ボスを配置する")
		if trial.manual == null:
			print("[cpp-boss-tools] 起動失敗: ",boss," ",trial.session.last_error," ",trial._manual_message.text if trial._manual_message!=null else "UI未構築"," switching=",trial._switching)
			trial.queue_free()
			await process_frame
			continue
		trial.session.playing = false
		var body: Dictionary = trial.manual.state()
		var original_phase: int = trial.manual._saved.get("phase",body.phase)
		native_check(trial.manual.requested==selected and body.busy and not body.selection,boss+": 選択技を単独再生する / "+trial.manual.message)
		var presentation = trial.session.scene.view.get_node("RunPresentation")
		for frame in 2: await process_frame
		native_check(not presentation.frame_view._boss_body_displays.is_empty(),boss+": 本番のボス表示へ接続する")
		var move: Resource = trial._selected_move()
		var original := float(move.warn)
		var key: String = trial._current_tuning_key()
		trial._drafts[key].warn = 1.75
		if trial._drafts[key].has("warn_p2"): trial._drafts[key].warn_p2 = 1.75
		trial._apply_tuning_preview()
		native_check(trial.manual.execute(selected,2),boss+": 未保存の技値で再実行する / "+trial.manual.message)
		var running: Array = trial.session.bridge.command("dev_boss_state").value
		var live_techniques: Array = running.filter(func(item): return item.actor==trial.manual.entity_id and item.stage<5)
		if live_techniques.is_empty():
			print("[cpp-boss-tools] 再生失敗: ",boss," ",trial.manual.message," ",trial.session.last_error)
			trial.queue_free()
			await process_frame
			continue
		var current: Dictionary = live_techniques[0]
		for i in 30: trial.session.step()
		running = trial.session.bridge.command("dev_boss_state").value
		current = running.filter(func(item): return item.actor==trial.manual.entity_id and item.stage<5)[0]
		native_check(trial.manual.state().phase==2 and is_equal_approx(current.windup_progress,float(current.get("age",current.elapsed))/1.75),boss+": 形態と変更後の予告時間をC++へ渡す")
		if boss=="monoceros": native_check(trial.manual.execute("horn_wave",2),"monoceros: 残留する角の衝撃波を再生する")
		for i in 480:
			trial.session.step()
			var live: Dictionary = trial.session.bridge.read_lab().value
			if not live.hostiles.is_empty() or not live.hazards.is_empty(): break
		native_check(trial.session.last_error.ok,boss+": 変更した技の状態を更新する")
		var attack: Dictionary = trial.session.bridge.read_lab().value
		native_check(not attack.hostiles.is_empty() or not attack.hazards.is_empty(),boss+": 本番の攻撃を発生する")
		trial._return_to_ai()
		attack = trial.session.bridge.read_lab().value
		native_check(attack.hostiles.is_empty() and attack.hazards.is_empty() and not trial.manual.state().busy,boss+": 試行終了時に残留攻撃と技を片付ける")
		native_check(trial.manual.state().phase==original_phase and trial.manual.state().selection,boss+": 形態と通常AIを復帰する")
		var source: Resource = trial._source_move(boss,selected)
		native_check(is_equal_approx(source.warn,original) and FileAccess.get_sha256(rules_path)==source_hash and not trial.session.spec.has("boss_programs"),boss+": 未保存値をSourceと通常ランへ漏らさない")
		trial._revert_tuning()
		trial._apply_tuning_preview()
		native_check(is_equal_approx(trial._selected_move().warn,original),boss+": 技の変更を破棄して保存済みの値を再読込する")
		# flowと予算も同じ生成に渡し、試行だけで保持する。
		trial.manual.program.data.flow.maximum_stamina = 23.0
		trial.manual.program.data.rules.costs[selected] = 2.5
		trial.manual.program.data.flow.sections[0].cap = 21.0
		native_check(trial.manual.execute(selected,1),boss+": フローと予算の未保存値も同じ生成で適用する")
		var flow: Array = trial.session.bridge.command("dev_boss_flow_state").value
		native_check(flow.any(func(item): return item.actor==trial.manual.entity_id and is_equal_approx(item.stamina,23.0)),boss+": 変更した予算から試行を開始する")
		if boss == "monoceros": native_combo_check(trial)
		trial._return_to_ai()
		trial.queue_free()
		await process_frame
		var roundtrip = load("res://tests/draco_editor_roundtrip.gd").new()
		failed += roundtrip.native_technique_roundtrip(root,boss)
		roundtrip.free()
	print("[cpp-boss-tools] failures=",failed)
	quit(1 if failed else 0)

func native_combo() -> void:
	var trial = load("res://gyms/boss_flow_trial.tscn").instantiate()
	trial.set_meta("preview_request",{"boss":"monoceros"})
	trial.set_meta("preview_program","res://.content/boss_monoceros.tres")
	root.add_child(trial)
	for frame in 300:
		await process_frame
		if trial.manual != null and not trial._switching: break
	if trial.manual == null:
		push_error("コンボ確認のボスを配置できません")
		quit(1)
		return
	trial.session.playing = false
	native_combo_check(trial)
	trial._return_to_ai()
	trial.queue_free()
	await process_frame
	print("[cpp-boss-tools-combo] failures=",failed)
	quit(1 if failed else 0)

func native_combo_check(trial) -> void:
	var rules: Resource = trial.manual.action_rules
	rules.combos.test_combo = {"type":"sequence","children":[{"type":"action","id":"charge"},{"type":"wait","seconds":0.1},{"type":"action","id":"charge"}]}
	rules.costs.test_combo = 3.0
	native_check(trial.manual.execute("test_combo",1),"monoceros: 制作中のコンボを単独再生する / "+trial.manual.message)
	for i in 600: trial.session.step()
	var body: Dictionary = trial.manual.state()
	native_check(body.flow_index==1 and not body.busy,"monoceros: 選んだコンボだけを最後まで実行する")

## 第2形態だけの技でも、終了時には再生前の第1形態へ戻す。
func native_canis_restore() -> void:
	var trial = load("res://gyms/boss_flow_trial.tscn").instantiate()
	trial.set_meta("preview_request",{"boss":"canis_major","technique":"sirius_flame"})
	trial.set_meta("preview_program","res://.content/boss_canis_major.tres")
	root.add_child(trial)
	for frame in 300:
		await process_frame
		if trial.manual!=null and not trial._switching: break
	if trial.manual==null:
		push_error("形態の復帰確認を開始できません")
		quit(1)
		return
	trial.session.playing = false
	var before: Dictionary = trial.manual._saved.duplicate(true)
	trial._return_to_ai()
	var restored: Dictionary = trial.manual.state()
	native_check(restored.phase==before.phase and restored.selection==before.selection,"canis_major: 再生前の形態と通常AIを復帰する")
	trial.queue_free()
	await process_frame
	print("[cpp-canis-tools-restore] failures=",failed)
	quit(1 if failed else 0)

func native_hydra() -> void:
	var boss := "hydra";var selected := "beam_bolt"
	var built: Dictionary=load("res://tools/content/build_boss_program.gd").build_boss(boss,"res://.content/boss_hydra.tres")
	native_check(built.get("error",FAILED)==OK,"ヒドラ: 共通変換で制作プログラムを生成する")
	var source_path := "res://data/bosses/hydra_moves/beam_bolt.tres"
	var source_hash := FileAccess.get_sha256(source_path)
	var rules_hash := FileAccess.get_sha256("res://data/bosses/ai/hydra_action_rules.tres")
	var trial=load("res://gyms/boss_flow_trial.tscn").instantiate()
	trial.set_meta("preview_request",{"boss":boss,"technique":selected});trial.set_meta("preview_program","res://.content/boss_hydra.tres");root.add_child(trial)
	for frame in 300:
		await process_frame
		if trial.manual!=null and not trial._switching:break
	native_check(trial.manual!=null,"ヒドラ: 制作画面からC++ボスを配置する")
	if trial.manual==null:print("ヒドラ起動失敗: ",trial.session.last_error," ",trial._manual_message.text);trial.queue_free();quit(1);return
	trial.session.playing=false
	var body: Dictionary=trial.manual.state()
	var original_phase: int=trial.manual._saved.get("phase",body.phase)
	native_check(trial._phase_picker.item_count==4 and body.phase==2 and body.count==5 and body.busy and not body.selection and trial.manual.requested==selected,"ヒドラ: 必要な5本の首で選んだ通常技だけを再生する")
	var presentation=trial.session.scene.view.get_node("RunPresentation")
	for frame in 2:await process_frame
	native_check(not presentation.frame_view._boss_body_displays.is_empty(),"ヒドラ: 本番のボス表示へ接続する")
	var move: Resource=trial._selected_move();var original: float=move.normal_charge
	var key: String=trial._current_tuning_key();trial._drafts[key].normal_charge=1.75;trial._apply_tuning_preview()
	native_check(trial.manual.execute(selected,2),"ヒドラ: 未保存の技値で再実行する / "+trial.manual.message)
	for tick in 30:trial.session.step()
	var running: Array=trial.session.bridge.command("dev_boss_state").value
	var active: Array=running.filter(func(t):return t.technique==selected and t.stage<5)
	native_check(active.size()==1 and active[0].actor!=trial.manual.entity_id and is_equal_approx(active[0].windup_progress,active[0].elapsed/1.75),"ヒドラ: 変更後の予告時間を首単位のC++技へ渡す")
	for tick in 480:
		trial.session.step()
		if not trial.session.bridge.read_lab().value.hazards.is_empty():break
	var lab: Dictionary=trial.session.bridge.read_lab().value
	native_check(trial.session.last_error.ok and not lab.hazards.is_empty(),"ヒドラ: 編集した値から本番の持続ビーム弾を発生する")
	trial._return_to_ai();lab=trial.session.bridge.read_lab().value;body=trial.manual.state()
	native_check(lab.hazards.is_empty() and lab.hostiles.is_empty() and not body.busy and body.phase==original_phase and body.selection,"ヒドラ: 停止時に残留攻撃を消して再生前の首構成とAIへ戻す")
	native_check(is_equal_approx(trial._source_move(boss,selected).normal_charge,original) and FileAccess.get_sha256(source_path)==source_hash and FileAccess.get_sha256("res://data/bosses/ai/hydra_action_rules.tres")==rules_hash and not trial.session.spec.has("boss_programs"),"ヒドラ: 未保存値をSourceと通常ランへ漏らさない")
	trial._revert_tuning();trial._apply_tuning_preview()
	native_check(is_equal_approx(trial._selected_move().normal_charge,original),"ヒドラ: 変更を破棄して保存済みの技値を再読込する")
	trial.manual.program.data.flow.maximum_stamina=23.0;trial.manual.program.data.flow.sections[0].cap=21.0;trial.manual.program.data.rules.costs[selected]=2.5
	native_check(trial.manual.execute(selected,2),"ヒドラ: 未保存のフローと予算を共通生成で試行へ適用する / "+trial.manual.message)
	var flow: Array=trial.session.bridge.command("dev_boss_flow_state").value
	native_check(flow.any(func(f):return f.actor==trial.manual.entity_id and is_equal_approx(f.stamina,23.0)),"ヒドラ: 変更した最大予算から試行を開始する")
	var records: Dictionary=load("res://tools/content/build_run_content.gd").hydra_set_package(root.get_node("ContentManager").bosses[&"hydra"],trial.manual.program.data.rules,trial.session._config).records
	native_check(records.HydraNormalDefinition.any(func(n):return records.BossTechniqueDefinition[n.technique-1].external_id==selected and is_equal_approx(n.cost,2.5)),"ヒドラ: 首の技にも編集後の消費値を生成する")
	trial._return_to_ai()
	native_check(trial.manual.execute("swarm",4),"ヒドラ: 分離後の技を本番の分離状態で試行する / "+trial.manual.message)
	body=trial.manual.state()
	native_check(body.phase==4 and body.count==8 and body.separated and body.bearer.alive and body.busy,"ヒドラ: 8本の首と不死首を持つ分離後へ切り替える")
	trial._return_to_ai();body=trial.manual.state()
	native_check(body.phase==original_phase and not body.separated and not body.busy and body.effects.is_empty(),"ヒドラ: 分離後の試行も停止して元の段階へ戻す")
	trial.queue_free();await process_frame
	var roundtrip=load("res://tests/draco_editor_roundtrip.gd").new();failed+=roundtrip.native_technique_roundtrip(root,boss);roundtrip.free()
	print("[cpp-hydra-tools] failures=",failed);quit(1 if failed else 0)

func native_hydra_retry() -> void:
	load("res://tools/content/build_boss_program.gd").build_boss("hydra","res://.content/boss_hydra.tres")
	var trial=load("res://gyms/boss_flow_trial.tscn").instantiate()
	trial.set_meta("preview_request",{"boss":"hydra","technique":"beam_bolt"});trial.set_meta("preview_program","res://.content/boss_hydra.tres");root.add_child(trial)
	for frame in 300:
		await process_frame
		if trial.manual!=null and not trial._switching:break
	if trial.manual==null:push_error("未成立の単独再生の準備に失敗: "+str(trial.session.last_error));quit(1);return
	trial.session.playing=false
	var body: Dictionary=trial.manual.state()
	native_check(trial._phase_picker.item_count==4 and body.phase==2 and body.count==5 and body.busy and not body.selection and trial.manual.requested=="beam_bolt","ヒドラ: 必要な5本の首で選んだ通常技だけを再生する")
	var presentation=trial.session.scene.view.get_node("RunPresentation")
	for frame in 2:await process_frame
	native_check(not presentation.frame_view._boss_body_displays.is_empty(),"ヒドラ: 本番のボス表示へ接続する")
	var key: String=trial._current_tuning_key();trial._drafts[key].normal_charge=1.75;trial._apply_tuning_preview()
	native_check(trial.manual.execute("beam_bolt",2),"ヒドラ: 未保存の技値で再実行する / "+trial.manual.message)
	for tick in 30:trial.session.step()
	var active: Array=trial.session.bridge.command("dev_boss_state").value.filter(func(t):return t.technique=="beam_bolt" and t.stage<5)
	native_check(active.size()==1 and active[0].actor!=trial.manual.entity_id and is_equal_approx(active[0].windup_progress,active[0].elapsed/1.75),"ヒドラ: 変更後の予告時間を首単位のC++技へ渡す")
	for tick in 480:
		trial.session.step()
		if not trial.session.bridge.read_lab().value.hazards.is_empty():break
	native_check(trial.session.last_error.ok and not trial.session.bridge.read_lab().value.hazards.is_empty(),"ヒドラ: 編集した値から本番の持続ビーム弾を発生する")
	trial.manual.program.data.flow.maximum_stamina=23.0;trial.manual.program.data.flow.sections[0].cap=21.0;trial.manual.program.data.rules.costs.beam_bolt=2.5
	native_check(trial.manual.execute("beam_bolt",2),"ヒドラ: 未保存のフローと予算を共通生成で試行へ適用する / "+trial.manual.message)
	trial._return_to_ai();trial.queue_free();await process_frame
	print("[cpp-hydra-tools-retry] failures=",failed);quit(1 if failed else 0)

func native_hydra_display() -> void:
	load("res://tools/content/build_boss_program.gd").build_boss("hydra","res://.content/boss_hydra.tres")
	var trial=load("res://gyms/boss_flow_trial.tscn").instantiate()
	trial.set_meta("preview_request",{"boss":"hydra","technique":"beam_bolt"});trial.set_meta("preview_program","res://.content/boss_hydra.tres");root.add_child(trial)
	for frame in 300:
		await process_frame
		if trial.manual!=null and not trial._switching:break
	if trial.manual==null:push_error("表示確認の準備に失敗: "+str(trial.session.last_error));quit(1);return
	trial.session.playing=false
	var presentation=trial.session.scene.view.get_node("RunPresentation")
	for frame in 2:await process_frame
	native_check(not presentation.frame_view._boss_body_displays.is_empty(),"ヒドラ: 本番のボス表示へ接続する")
	trial._return_to_ai()
	trial.queue_free();await process_frame
	print("[cpp-hydra-tools-display] failures=",failed);quit(1 if failed else 0)
