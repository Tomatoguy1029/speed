## 3択の間に候補を準備し、選ばなかった資源の保持を外す。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	if "--cpp" in OS.get_cmdline_user_args():
		await _cpp_ready()
		return
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	var loadout = session.sim.loadout
	check(loadout.has_method("resources_for_card"), "候補ごとの資源を準備する")
	if loadout.has_method("resources_for_card"):
		loadout.open_start_cards()
		var cards: Array[Dictionary] = session.sim.state.cards.duplicate(true)
		var scopes := []
		for card in cards:
			var scope: RefCounted = loadout.resources_for_card(card.id)
			scopes.append(scope)
			check(scope != null and scope.is_ready(), "表示中の候補の資源を準備する")
		var entry := ContentManager.catalog.find(&"weapons", cards[0].id)
		check(scopes[0].resources.has(entry.path), "候補の定義を保持する")
		# ディスクの速度に依存せず、読込待ちの間だけ進行を保留することを確認する。
		scopes[0].pending.append("test_delay")
		session.sim.choose_card(0)
		check(session.sim.state.phase == RunState.Phase.LEVELUP and session.sim.state.weapons.is_empty(), "資源が揃うまで戦闘へ戻らない")
		scopes[0].provide("test_delay", Resource.new())
		session.sim.state.lab_mode = false
		session.sim.physics_step(0.0)
		check(session.sim.state.phase == RunState.Phase.PLAY and session.sim.state.weapons.has(cards[0].id), "準備完了後に選択を反映して戦闘へ戻る")
		check(not scopes[0].cancelled, "選んだ装備の資源を引き継ぐ")
		for index in range(1, scopes.size()): check(scopes[index].cancelled and scopes[index].resources.is_empty(), "選ばなかった候補を解放する")
	session.free()
	await get_tree().process_frame
	print("[equipment_resources] %d failures" % failed)
	get_tree().quit(1 if failed else 0)

func _cpp_ready() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	config.weapon_slots = 1
	var stage := RuntimeStage.new()
	stage.index = 88
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/comet_resources"
	check(load("res://tools/content/build_run_content.gd").build(stage,config,output,"交換資源の所有".sha256_text())==OK,"正規生成を使う")
	var path := output.path_join("stage_88.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session := RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":42},false)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"交換資源のSessionを開始する")
	if session.bridge==null: get_tree().quit(1);return
	var bridge = session.bridge
	var choices = session.cpp_choices
	var made: Array[ContentResourceScope] = []
	choices.prepare = func(paths: PackedStringArray) -> ContentResourceScope:
		var scope := ContentResourceScope.new()
		for p in paths: scope.resources[p] = Resource.new()
		scope.pending.append("test_delay")
		scope.warmup_complete = true
		made.append(scope)
		return scope
	var step := func(): bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	bridge.command("dev_edit",{"kind":"comet_weapon","payload":{"id":"W22"}})
	step.call()
	choices.poll()
	var first: Dictionary = bridge._ui.cards.candidates[0]
	bridge.command("choose_swap",{"offer_id":bridge._ui.cards.offer_id,"candidate_id":first.candidate_id,"replace_weapon_id":str(first.id)})
	step.call()
	check(bridge._ui.weapon_levels[0].id=="W01" and made.size()==1,"交換先全候補で新武器のScopeを一つだけ準備する")
	made[0].provide("test_delay",Resource.new())
	choices.poll()
	step.call()
	choices.poll()
	check(bridge._ui.weapon_levels[0].id=="W22" and choices.equipped.get("weapon:W22")==made[0] and not made[0].cancelled,"新武器のScopeを装備へ引き継ぐ")
	bridge.command("dev_remove_weapon",{"id":"W22"})
	bridge.collect_frame()
	choices.poll()
	check(made[0].cancelled and made[0].resources.is_empty(),"外した武器のScopeを解放する")
	bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W01","levels":1})
	bridge.command("dev_edit",{"kind":"comet_weapon","payload":{"id":"W22"}})
	step.call()
	choices.poll()
	var checkpoint: Dictionary = bridge.checkpoint()
	check(checkpoint.ok,"準備中の交換候補を保持する")
	var keep: Dictionary = bridge._ui.cards.candidates.back()
	bridge.command("choose_card",{"offer_id":bridge._ui.cards.offer_id,"candidate_id":keep.candidate_id})
	step.call()
	choices.poll()
	check(made[1].cancelled and choices.equipped.is_empty(),"維持したときは未選択の新武器Scopeを取消す")
	if checkpoint.ok:
		check(bridge.restore(checkpoint.value).ok,"保持した交換候補へ復帰する")
		bridge.collect_frame()
		choices.poll()
		check(made.size()==3 and not made[2].cancelled,"復帰後は新epochの資源要求を準備する")
	var request: int = bridge._ui.cards.candidates[0].request_id
	session.free()
	check(made.back().cancelled,"終了時に準備中のScopeを回収する")
	check(not bridge.command("resources_complete",{"request_id":request,"status":1}).ok,"終了後の完了通知を拒否する")
	await get_tree().process_frame
	print("[equipment_resources_cpp] failures=%d" % failed)
	get_tree().quit(1 if failed else 0)
