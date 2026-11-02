extends SceneTree
var cpp_failed := 0
func cpp_check(ok: bool, message: String) -> void:
	print("[cpp_b01] ","PASS " if ok else "FAIL ",message)
	if not ok: cpp_failed += 1
func _initialize() -> void:
	call_deferred("check_cpp_flow")

func cpp_fixture(program: Dictionary, section_options := {}, second_actor := false) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	var actor = load("res://data/enemies/drifter.tres").duplicate(true)
	actor.speed = 0.0
	actor.radius = 96.0
	var boss = load("res://data/bosses/monoceros.tres")
	var move = load("res://data/bosses/monoceros_moves/charge.tres").duplicate(true)
	move.warn = 0.02
	move.active = 0.02
	move.recover = 0.02
	move.cd = 0.0
	move.distance = 1.0
	var records: Dictionary = builder.chase_records(actor,cfg)
	var techniques: Dictionary = builder.boss_technique_records(boss,move)
	for key in techniques: records[key] = techniques[key]
	var rules = load("res://scripts/data_types/boss_action_rules.gd").new()
	rules.adapter = &"hydra" if second_actor else &"monoceros"
	rules.techniques.assign([move])
	if not program.is_empty(): rules.combos = {"combo":program}
	var flow = load("res://scripts/data_types/boss_flow_def.gd").new()
	flow.maximum_stamina = 1.0
	flow.empty_rest = 0.2
	flow.partial_rest = 0.1
	var section := {"request":"any","cap":3.0,"next":0,"weights":{"single":100.0} if program.is_empty() else {"combo":100.0},"allowed_techniques":["charge"] if program.is_empty() else ["combo"]}
	section.merge(section_options,true)
	flow.sections = [section]
	if section_options.has("fallback"): flow.sections.append({"request":"rest","next":0})
	rules.costs = {"charge":1.0,"combo":1.0}
	var compiled: Dictionary = builder.boss_flow_records(rules,flow,techniques.BossTechniqueDefinition)
	if compiled.is_empty(): return {}
	for key in compiled: records[key] = compiled[key]
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var bytes: PackedByteArray = builder.Schema.write_content(records,"0".repeat(64).hex_decode())
	if not bridge.configure(bytes,{"api_version":1,"run_id":143,"mode":1,"stage_id":"B01","profile":{},"settings":{"hitstop":false}}).ok: return {}
	bridge.start(143,{"position":Vector2(200,0)})
	bridge.command("dev_ship_motion",{"position":Vector2(200,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(200,0),Vector2(200,0),Vector2(640,360))
	var ids := PackedInt64Array()
	for i in (2 if second_actor else 1):
		var id: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(0,i*10)}).value
		bridge._core.set_enemy_motion(id,{"facing":0.0})
		ids.append(id)
	if not bridge.command("dev_boss_flow",{"entity_id":ids[0],"definition":1,"participants":ids}).ok: return {}
	return {"bridge":bridge,"actor":ids[0],"records":records,"rules":rules,"flow":flow,"techniques":techniques}

func cpp_flow(bridge) -> Dictionary: return bridge.command("dev_boss_flow_state").value[0]
func cpp_steps(bridge, count: int) -> void:
	for i in count:
		if not bridge._core.step(0.02): cpp_check(false,"世界更新を実行する")

func check_cpp_flow() -> void:
	var fixture := cpp_fixture({"type":"sequence","children":[{"type":"action","id":"charge"},{"type":"wait","seconds":0.05},{"type":"action","id":"charge"}]})
	cpp_check(not fixture.is_empty(),"型付きの条件・連続・待機をC++へ読み込む")
	if fixture.is_empty():
		quit(1)
		return
	var bridge = fixture.bridge
	cpp_steps(bridge,2)
	cpp_check(bridge.command("dev_boss_state").value.size()==1,"sequenceの最初の技を実行する")
	for i in 30:
		if cpp_flow(bridge).nodes[0].cursor!=0: break
		cpp_steps(bridge,1)
	var state := cpp_flow(bridge)
	cpp_check(state.nodes.size()==2 and state.nodes[0].cursor==1,"子の完了tickでは次のwaitを実行しない")
	cpp_steps(bridge,1)
	cpp_check(cpp_flow(bridge).nodes.size()==3 and is_equal_approx(cpp_flow(bridge).nodes[2].elapsed,0.02),"次tickで次の子の時計を進める")
	var held: Dictionary = bridge.checkpoint()
	cpp_steps(bridge,2)
	cpp_check(bridge.read_frame().ok and bridge.delivery_error.is_empty(),"固定更新の通知を公開契約で読み出す")
	var expected := cpp_flow(bridge)
	bridge.restore(held.value)
	cpp_steps(bridge,2)
	cpp_check(cpp_flow(bridge)==expected,"カーソル・待機・技チケットを保持して同じ先へ復帰する")
	bridge.release_checkpoint(held.value)
	bridge.dispose()
	fixture = cpp_fixture({"type":"parallel","children":[{"type":"action","id":"charge"},{"type":"action","id":"charge"}]})
	bridge = fixture.bridge
	cpp_steps(bridge,2)
	cpp_check(bridge.command("dev_boss_state").value[0].stage==7,"parallelの後続が失敗したら先行技も取り消す")
	bridge.dispose()
	fixture = cpp_fixture({"type":"parallel","children":[{"type":"action","id":"charge"},{"type":"sequence","children":[{"type":"wait","seconds":0.08},{"type":"action","id":"charge","participant":1}]}]}, {}, true)
	bridge = fixture.bridge
	cpp_steps(bridge,6)
	cpp_check(cpp_flow(bridge).active and cpp_flow(bridge).nodes[1].status==1 and bridge.command("dev_boss_state").value[0].id==2,"並行の開始順を保ち後から始まる参加者も待つ")
	var ticks := 0
	while cpp_flow(bridge).active and ticks<30:
		cpp_steps(bridge,1)
		ticks += 1
	cpp_check(not cpp_flow(bridge).active and cpp_flow(bridge).rest>0.0,"全技の終了後に一度だけスタミナ枯渇休息へ進む")
	for i in 20:
		if cpp_flow(bridge).rest<=0.0: break
		cpp_steps(bridge,1)
	cpp_check(cpp_flow(bridge).stamina==1.0 and cpp_flow(bridge).last==["combo"],"休息でスタミナを戻して技の履歴を残す")
	bridge.dispose()
	fixture = cpp_fixture({}, {"allowed_techniques":[],"no_candidate_timeout":0.04,"fallback":1,"next":1})
	bridge = fixture.bridge
	cpp_steps(bridge,1)
	cpp_check(cpp_flow(bridge).waiting and cpp_flow(bridge).last.is_empty(),"候補なしで攻撃やスタミナを消費しない")
	cpp_steps(bridge,2)
	cpp_check(cpp_flow(bridge).index==1,"候補なしの時間上限で指定区間へ進む")
	bridge.dispose()
	var deep := {"type":"action","id":"charge"}
	for i in 26: deep = {"type":"sequence","children":[deep]}
	fixture.rules.combos = {"deep":deep}
	cpp_check(load("res://tools/content/build_run_content.gd").boss_flow_records(fixture.rules,fixture.flow,fixture.techniques.BossTechniqueDefinition).is_empty(),"最大深さを超えるフローを生成時に拒否する")
	fixture = cpp_fixture({"type":"branch","condition":{"max":100.0},"children":[{"type":"wait","seconds":0.01},{"type":"wait","seconds":0.2}]})
	bridge = fixture.bridge
	cpp_steps(bridge,2)
	bridge.command("dev_ship_motion",{"position":Vector2(50,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(50,0),Vector2(50,0),Vector2(640,360))
	cpp_steps(bridge,3)
	cpp_check(cpp_flow(bridge).active and cpp_flow(bridge).nodes[1].elapsed>0.07,"分岐を選んだ時点を保持し途中で選び直さない")
	bridge.dispose()
	print("[cpp_b01] failed=%d"%cpp_failed)
	quit(1 if cpp_failed else 0)
