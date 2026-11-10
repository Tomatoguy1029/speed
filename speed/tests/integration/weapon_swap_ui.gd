## 交換画面の表示と選択を短時間確認する。セーブはメモリだけで扱う。
## Godot --headless --path speed res://tests/integration/weapon_swap_ui.tscn
## 描画付きでは --headless を外し、-- --out=/tmp/speed-swap-ui を付ける。
extends "res://tests/integration/thrill_acceptance.gd"
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS
var hud: Control

func _ready() -> void:
	await _cpp_ready()

func _settle() -> void:
	for i in 4:
		await get_tree().process_frame

func _cpp_ready() -> void:
	TranslationServer.set_locale("ja")
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	config.levelup_bonus_chance = 0.0
	var stage := RuntimeStage.new()
	stage.index = 88
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["splitling"])
	var output := "res://.content/dev/comet_swap_ui"
	_check(load("res://tools/content/build_run_content.gd").build(stage,config,output,"彗星交換の正式UI".sha256_text())==OK,"正規生成から交換資源を準備する")
	var path := output.path_join("stage_88.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session := RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":42},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	_check(session.bridge!=null,"正式Sessionを開始する")
	if session.bridge==null: get_tree().quit(1);return
	var bridge = session.bridge
	hud = session.view.get_node("Hud/HudRoot")
	var cards: Dictionary
	var before: Array
	var step := func(): bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	if "--cpp-ui-retry" not in OS.get_cmdline_user_args():
		bridge.command("dev_remove_weapon",{"id":"W01"})
		_check(bridge.command("dev_edit",{"kind":"comet_weapon","payload":{"id":"W22"}}).ok,"彗星の取得予約をC++へ渡す")
		step.call()
		_check(bridge._ui.cards.comet_direct and bridge._ui.weapon_levels.is_empty(),"空枠でも資源準備前には攻撃を開始しない")
		for i in 30:
			session.cpp_choices.poll()
			step.call()
			await get_tree().process_frame
			if int(bridge._ui.phase)==RunIds.Phase.Play: break
		_check(bridge._ui.weapon_levels.any(func(v): return v.id=="W22" and v.level==config.weapon_max_level),"空枠の彗星武器は最大段で取得する")
		bridge.command("dev_edit",{"kind":"comet_weapon","payload":{"id":"W22"}})
		step.call()
		_check(int(bridge._ui.phase)==RunIds.Phase.Play,"取得済み彗星武器は重複取得しない")
		bridge.command("dev_remove_weapon",{"id":"W22"})
		for i in config.weapon_slots: bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W%02d" % (i+1),"levels":i+1})
		bridge.command("dev_edit",{"kind":"progression","payload":{"pending_levels":1}})
		bridge.command("dev_edit",{"kind":"comet_weapon","payload":{"id":"W22"}})
		step.call()
		cards = bridge._ui.cards
		_check(cards.swap_pick=="W22" and cards.candidates.size()==config.weapon_slots+1,"保留レベルより先に交換候補を開く")
		_check(not bridge.command("reroll",{"offer_id":cards.offer_id}).ok,"交換候補は引き直せない")
		_check(not bridge.command("choose_swap",{"offer_id":cards.offer_id,"candidate_id":1,"replace_weapon_id":"W02"}).ok,"別の武器を指定した交換命令を拒否する")
		before = bridge._ui.weapon_levels.duplicate(true)
		var request := int(cards.candidates[0].request_id)
		_check(bridge.command("choose_swap",{"offer_id":cards.offer_id,"candidate_id":2,"replace_weapon_id":"W02"}).ok,"2番目の武器を交換先として選ぶ")
		step.call()
		_check(bridge._ui.weapon_levels==before and bridge._ui.cards.preparing,"準備中は旧装備と選択を保持する")
		_check(bridge.command("cancel_choice",{"offer_id":cards.offer_id}).ok,"待機中の選択を取り消す")
		_check(bridge.command("resources_complete",{"request_id":request,"status":-1}).ok,"資源の失敗を受理する")
		bridge.command("choose_swap",{"offer_id":cards.offer_id,"candidate_id":2,"replace_weapon_id":"W02"})
		step.call()
		_check(bridge._ui.weapon_levels==before and int(bridge._ui.cards.error_code)==-1,"失敗中は交換を確定しない")
		bridge.command("retry_resources",{"request_id":request})
		bridge.collect_frame()
		cards = bridge._ui.cards
		_check(not bridge.command("resources_complete",{"request_id":request,"status":1}).ok,"失効した完了通知を拒否する")
		bridge.command("resources_complete",{"request_id":cards.candidates[0].request_id,"status":1})
		step.call()
		_check(bridge._ui.weapon_levels.any(func(v): return v.id=="W22" and v.level==5) and not bridge._ui.weapon_levels.any(func(v): return v.id=="W02"),"指定武器だけを最大段の新武器へ交換する")
		_check(int(bridge._ui.pending_levels)==1 and str(bridge._ui.cards.swap_pick)=="","交換で保留レベルを消費せず通常候補を続ける")
		bridge.command("dev_edit",{"kind":"progression","payload":{"pending_levels":1}})
	else:
		bridge.command("dev_remove_weapon",{"id":"W01"})
		for i in config.weapon_slots: bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W%02d" % (i+1),"levels":i+1})
	if "--cpp-ui-retry" not in OS.get_cmdline_user_args():
		# 通常候補を1枚選び、続く彗星の維持を正式画面から選ぶ。
		cards = bridge._ui.cards
		for c in cards.candidates: bridge.command("resources_complete",{"request_id":c.request_id,"status":1})
		bridge.command("choose_card",{"offer_id":cards.offer_id,"candidate_id":cards.candidates[0].candidate_id})
		step.call()
	bridge.command("dev_remove_weapon",{"id":"W22"})
	bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W02","levels":2})
	bridge.command("dev_edit",{"kind":"comet_weapon","payload":{"id":"W22"}})
	step.call()
	bridge.collect_frame()
	await _settle()
	_check(hud.get("_swap_grid").get_child_count()==config.weapon_slots and not hud._cards_row.visible,"正式HUDに所持武器4枠を表示する")
	_check(hud.get("_swap_new_name").text==ContentManager.catalog.find(&"weapons",&"W22").get_display_name(),"新武器の正式名を既存の情報カードに表示する")
	for i in config.weapon_slots:
		var c: Dictionary = bridge._ui.cards.candidates[i]
		_check(hud.get("_swap_grid").get_child(i).tooltip_text.contains("Lv%d" % c.level),"所持武器の段を詳細へ表示する")
	before = bridge._ui.weapon_levels.duplicate(true)
	await get_tree().create_timer(0.35).timeout
	hud.get("_swap_keep").pressed.emit()
	step.call()
	_check(bridge._ui.weapon_levels==before and int(bridge._ui.phase)==RunIds.Phase.Play,"正式HUDの維持ボタンは資源を待たず元の装備で再開する")
	for i in 125: step.call()
	_check(bridge._ui.weapon_levels==before,"交換直後の攻撃更新でも所持装備を保つ")
	session.free()
	await get_tree().process_frame
	print("[weapon_swap_ui_cpp] passed=%d failed=%d" % [passed,failed])
	get_tree().quit(1 if failed else 0)
