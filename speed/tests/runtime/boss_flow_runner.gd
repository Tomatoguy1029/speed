## 制作形式で作った固定フローをC++の本体から進める。
extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize() -> void: call_deferred("exercise")

# 待機ノードで技の長さを固定し、区間・抽選・休息だけを観測する。
func fixture(actions: Dictionary, sections: Array, options: Dictionary={}) -> Dictionary:
	var builder=load("res://tools/content/build_run_content.gd")
	var cfg: GameConfig=(root.get_node("ContentManager").get("base") as GameConfig).duplicate(true)
	cfg.planet_radius=0;cfg.moon_count=0;cfg.meteor_count=0;cfg.iron_count=0;cfg.saw_count=0
	var definition: BossDef=load("res://data/bosses/monoceros.tres").duplicate(true)
	definition.speed=0;definition.params.initial_wait=0.0
	var rules=load("res://scripts/data_types/boss_action_rules.gd").new()
	rules.adapter=&"monoceros"
	rules.techniques.assign([load("res://data/bosses/monoceros_moves/charge.tres")])
	rules.graph_nodes={"charge":{"hidden":true}}
	rules.allow_parallel_attacks=options.get("parallel",false)
	rules.selection_bias=options.get("bias",{})
	for id in actions:
		var action: Dictionary=actions[id]
		rules.combos[id]={"type":"wait","seconds":action.get("seconds",0.0)}
		rules.costs[id]=action.get("cost",1.0)
		rules.conditions[id]=action.get("gate",{})
		var group: String=action.get("group",id)
		if not rules.condition_groups.has(group):rules.condition_groups[group]={"category":action.get("category","normal"),"nodes":[]}
		rules.condition_groups[group].nodes.append(id)
	var flow=load("res://scripts/data_types/boss_flow_def.gd").new()
	flow.maximum_stamina=options.get("stamina",100000.0)
	flow.partial_rest=options.get("partial_rest",1.0)
	flow.empty_rest=options.get("empty_rest",3.0)
	flow.sections=sections.duplicate(true)
	var package: Dictionary=builder.boss_package(definition,cfg,null,{"rules":rules,"flow":flow})
	if package.is_empty():check(false,"固定フローを正規の制作形式から生成する");return {}
	# 旧Adapterの候補属性を、型付きの公開レコードで与える。
	for action: Dictionary in package.records.BossFlowAction:
		action.exclusive=actions[action.external_id].get("exclusive",true)
		action.post_gap=actions[action.external_id].get("post_gap",0.0)
	var bridge=load("res://scripts/runtime/run_bridge.gd").new()
	var bytes: PackedByteArray=builder.Schema.write_content(package.records,"1".repeat(64).hex_decode())
	if not bridge.configure(bytes,{"api_version":1,"run_id":245,"mode":1,"stage_id":"flow","profile":{},"settings":{"hitstop":false}}).ok:
		check(false,"固定フローをC++へ読み込む");return {}
	if not bridge.start(0,{"lab_mode":true}).ok or not bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).ok:
		check(false,"フローを実際のボス本体へ接続する");bridge.dispose();return {}
	bridge._core.set_run_guards({"invincible":true})
	return {"bridge":bridge,"rules":rules,"flow":flow,"package":package}

func state(f: Dictionary) -> Dictionary:
	var rows: Array=f.bridge.command("dev_boss_flow_state").value
	return {} if rows.is_empty() else rows[0]
func step(f: Dictionary, seconds: float=1.0/120.0) -> void:
	check(f.bridge.step(seconds,f.bridge.pack_intent(Intent.new()),{"logical_size":Vector2(1280,720)}).ok,"固定フローを世界更新する")
func advance(f: Dictionary, seconds: float) -> void:
	for i in ceili(seconds*120.0):step(f)
func until(f: Dictionary, predicate: Callable, limit: int=4096) -> bool:
	for i in limit:
		if predicate.call(state(f)):return true
		step(f)
	return predicate.call(state(f))
func next_action(f: Dictionary) -> Array:
	if state(f).get("active",false) and not until(f,func(s):return not s.active):return []
	if not until(f,func(s):return s.active):return []
	return state(f).last.duplicate()
func close(f: Dictionary) -> void:
	if not f.is_empty():f.bridge.dispose()
func done(name: String) -> void:
	print("[",name,"] failed=",failures)
	quit(1 if failures else 0)

func exercise() -> void:
	var actions={"a":{"group":"chosen"},"blocked":{"group":"chosen"},"m":{"category":"major"}}
	var first={"request":"normal","allowed_techniques":["a"],"next":1}
	var second={"request":"major","allowed_techniques":["m"],"weights":{"major":100.0},"next":0}
	var f:=fixture(actions,[first,second])
	if f.is_empty():done("boss-runner");return
	for expected in ["a","m","a"]:check(next_action(f)==[expected],"区間の許可リストと通常/大技を順に選ぶ: "+expected)
	close(f)
	first={"request":"any","allowed_techniques":["a"],"cap":2.0,"section_budget":2.0,"action_count":2,"action_interval":0.3,"next":1}
	f=fixture(actions,[first,second],{"stamina":4.0})
	if f.is_empty():done("boss-runner");return
	check(next_action(f)==["a"],"区間の最初の行動を始める")
	check(until(f,func(s):return not s.active),"最初の行動が終わる")
	check(state(f).index==0 and state(f).completed==1 and is_equal_approx(state(f).spent,1.0),"区間の回数と累積消費を保持する")
	advance(f,0.2)
	check(not state(f).active,"行動間隔が過ぎるまで次を始めない")
	check(next_action(f)==["a"],"間隔の後に二度目を始める")
	check(until(f,func(s):return not s.active) and state(f).index==1 and state(f).completed==0 and state(f).spent==0.0,"回数の上限で区間を進め消費を戻す")
	check(next_action(f)==["m"],"次の区間では同じ候補から大技を選べる")
	close(f)
	first.section_budget=1.0
	f=fixture(actions,[first,second],{"stamina":4.0})
	if not f.is_empty():
		check(next_action(f)==["a"] and next_action(f)==["m"],"区間の消費上限で回数未満でも次へ進む")
		close(f)
	f=fixture(actions,[{"allowed_techniques":[],"no_candidate_timeout":0.5,"fallback":1,"next":1},second])
	if not f.is_empty():
		advance(f,0.2)
		check(state(f).waiting and not state(f).active and state(f).stamina==100000.0,"候補がない間は攻撃もスタミナ消費もしない")
		check(next_action(f)==["m"],"候補なしの時間上限で指定区間へ進む")
		close(f)
	f=fixture(actions,[{"allowed_groups":["chosen"],"allowed_categories":["major"],"excluded_techniques":["blocked"],"weights":{"single":100.0,"major":0.0},"next":0}])
	if not f.is_empty():
		check(next_action(f)==["a"],"接続した群れ・分類・除外をまとめて選ぶ")
		close(f)
	for category in ["normal","combo"]:
		f=fixture({"a":{"category":category,"post_gap":0.6}},[{"request":"any","weights":{"single":100.0} if category=="normal" else {"combo":100.0},"next":0}])
		if f.is_empty():continue
		next_action(f);until(f,func(s):return not s.active)
		check(is_equal_approx(state(f).interval,0.6 if category=="normal" else 0.0),"通常技だけ終了後の間を持つ: "+category)
		close(f)
	f=fixture(actions,[{"allowed_techniques":[],"fallback":1,"next":0},{"request":"rest","next":0}])
	if not f.is_empty():
		check(until(f,func(s):return s.index==1,32),"時間上限のない互換fallbackはすぐ次へ進む")
		close(f)
	done("boss-runner")
