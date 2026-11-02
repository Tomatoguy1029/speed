## 個体・共有枠の要求、予算の丸め、優先度と待機順を比較する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
const DATA := preload("res://tools/content/build_native_data.gd")
var failed := 0
var comparison
func check(ok: bool,label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	comparison = COMPARE.new()
	var probe = comparison.create_native()
	if not probe.has_method("request_attack"):
		check(false,"攻撃の予算と待機順をネイティブが保持する")
	else:
		for formation in [false,true]: await compare_budget(formation)
	probe.close()
	check_director_lifecycle()
	check_biter_budget_path()
	print("[run_attack_budget] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func snapshot(d) -> Dictionary:
	var groups := []
	for token in d.groups:
		var group: Dictionary = d.groups[token]
		var members := []
		for id in group.get("members",{}):
			var member: Dictionary = group.members[id]
			members.append({"id":int(id),"until":member.until,"begun":member.begun,"closed":member.closed})
		groups.append({"token":token,"owner":group.owner,"id":group.id,"cost":group.get("cost",1.0),"until":group.until,"start":group.start,"passive":group.passive,"members":members})
	var waiting := []
	for owner in d.waiting:
		var item: Dictionary = d.waiting[owner]
		var row := {"owner":owner,"id":item.id,"since":item.since,"priority":item.priority,"cost":item.get("cost",1.0)}
		if item.has("ready"): row.ready = item.ready
		waiting.append(row)
	return {"used":d.used_cost(),"serial":d.serial,"now":d.now,"groups":groups,"waiting":waiting}
func events(source: Array) -> Array:
	var out := source.duplicate(true)
	# 格納行の番号は内部表現。攻撃元の対応は個体IDで比較する。
	for event in out: event.erase("row")
	return comparison.plain(out)
func request(run: RunSimulation,core,owner: String,row: int,cost: float,priority := 0.0,categories: Array = ["beam"]) -> void:
	run.state.events.clear()
	var id: int = run.enemies.table.id[row]
	var previous_rng: String = str(run.state.rng.state)
	var previous_native_rng: String = core.inspect().rng_state
	var old: bool = run.projectiles.director.request(owner,categories,row,id,1.0,priority,cost)
	check(core.request_attack(owner,PackedStringArray(categories),id,1.0,priority,cost) == old,"要求の許可と待機が一致する: "+owner)
	check(comparison.difference(snapshot(run.projectiles.director),core.attack_budget_snapshot()).is_empty(),"予算・共有枠・待機順が一致する: "+owner)
	check(events(run.state.events) == events(core.drain_events()),"許可した攻撃の通知が一致する: "+owner)
	check(str(run.state.rng.state)==previous_rng and core.inspect().rng_state==previous_native_rng,"時刻0の要求でどちらの乱数も進めない")
	run.state.events.clear()
func configure(d,core,enabled: bool,budget: float) -> void:
	var settings := {"enabled":enabled,"budget":budget,"jitter":0.3}
	d.configure(settings)
	check(core.configure_attack_budget(settings),"攻撃予算の設定を受け付ける")
func compare_budget(formation: bool) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":422,"empty":true})
	var run: RunSimulation = lab.run
	var d = run.projectiles.director
	d.formation_mode = formation
	var definition := run.enemies.def_of(&"drifter")
	var core = comparison.create_native()
	core.configure(DATA.compile_enemy(definition,run.cfg,run.state.stage))
	core.set_attack_formation_mode(formation)
	configure(d,core,true,0.3)
	core.start(422,run.enemies._next_id)
	run.state.rng.seed = 422
	var rows := []
	for i in 4:
		rows.append(run.enemies.spawn(definition,Vector2(i*20,0)))
		core.spawn_enemy(&"drifter",Vector2(i*20,0))
	run.state.events.clear()
	core.drain_events()
	request(run,core,"a",rows[0],0.1)
	request(run,core,"b",rows[1],0.2)
	request(run,core,"微小",rows[2],1e-18)
	request(run,core,"共有",rows[0],0.0)
	request(run,core,"分類なし",rows[0],1.0,0.0,[])
	configure(d,core,true,2.0)
	request(run,core,"重い",rows[2],1.8,5.0)
	request(run,core,"軽い",rows[3],0.1,0.0)
	request(run,core,"上限超過",rows[0],3.0,100.0)
	request(run,core,"a",rows[1],0.1)
	configure(d,core,true,0.0)
	request(run,core,"a",rows[0],0.1)
	request(run,core,"a",rows[2],0.1)
	configure(d,core,false,0.0)
	d.guard = {"until":INF}
	check(core.set_attack_guard(true,INF),"解除まで続く攻撃の待機期間を設定する")
	request(run,core,"保護中",rows[3],0.5)
	d.guard.clear()
	core.set_attack_guard(false,0.0)
	request(run,core,"保護中",rows[3],0.5)
	request(run,core,"重い",rows[2],1.8,5.0)
	var before: Dictionary = core.attack_budget_snapshot()
	check(not core.configure_attack_budget({"enabled":true,"budget":NAN}),"不正な予算で有効な設定を上書きしない")
	check(before == core.attack_budget_snapshot(),"不正な設定で攻撃枠と待機を変えない")
	core.close()
	lab.free()

func director_fixture(phases: Array = [], enemy: StringName = &"drifter"):
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.world_tick_div = 1
	config.start_radius = 0.0
	var stage := RuntimeStage.new()
	stage.phases.assign(phases)
	var data: Dictionary = builder.chase_records(ContentManager.enemies[enemy],config,stage)
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	check(bridge.configure(schema.write_content(data,"攻撃枠の固定入力".sha256_buffer()),{"api_version":1,"run_id":91,"mode":1,"stage_id":"director","profile":{},"settings":{}}).ok,"時刻別の攻撃予算を生成して読む")
	check(bridge.start(42).ok,"通常の窓口から攻撃枠の確認を始める")
	return bridge

func spawn_owner(bridge, offset: float) -> int:
	var response: Dictionary = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(3000+offset,3000)})
	check(response.ok,"攻撃元を通常の生成経路で登録する")
	return int(response.value) if response.ok else 0

func retained_attack(bridge, owner: int, token: int, attached := false) -> Dictionary:
	var response: Dictionary = bridge.command("dev_emit_attack",{"pool":1,"position":Vector2(10000,0),"owner_id":owner,"budget":token,"policies":1,"attached":attached})
	check(response.ok,"発生元と予算トークンを持つ残留攻撃を生成する")
	return response.value if response.ok else {}

func check_director_lifecycle() -> void:
	var bridge = director_fixture()
	var core = bridge._core
	var owners := [spawn_owner(bridge,0),spawn_owner(bridge,100),spawn_owner(bridge,200)]
	var cats := PackedStringArray(["beam"])
	core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	check(not core.request_attack("先",cats,owners[0],0.2,0.0,1.0) and not core.request_attack("後",cats,owners[1],0.2,0.0,1.0),"容量0では同順位の待機を登録順に保つ")
	core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
	check(not core.request_attack("後",cats,owners[1],0.2,0.0,1.0) and core.request_attack("先",cats,owners[0],0.2,0.0,1.0),"同順位は先に待った攻撃だけに枠を渡す")
	var token: int = core.attack_token("先")
	var remaining := retained_attack(bridge,owners[0],token)
	bridge.command("dev_remove",{"entity_id":owners[0]})
	check(core.advance_attack_budget(0.3) and core.attack_token("先")==token,"発生元死亡後も残留がある枠を保持する")
	check(not core.request_attack("後",cats,owners[1],0.2,0.0,1.0),"残留枠を新しい攻撃へ二重に渡さない")
	bridge.command("dev_end_attack",{"handle":remaining.handle})
	check(core.advance_attack_budget(0.3) and core.attack_token("先")==0 and core.request_attack("後",cats,owners[1],0.2,0.0,1.0),"最後の残留終了後に待機していた攻撃が再取得する")
	token = core.attack_token("後")
	var attached := retained_attack(bridge,owners[1],token,true)
	remaining = retained_attack(bridge,owners[1],token)
	check(core.advance_attack_budget(0.31) and core.attack_budget_snapshot().groups[0].members[0].begun,"付随する判定が生きているあいだは行動中の枠を保つ")
	check(bridge.command("dev_relocate",{"entity_id":owners[1],"position":Vector2(-3000,0)}).ok,"出現側の再配置を敵の共通操作へ通す")
	var active: Array = core.attack_snapshot()
	check(not active.any(func(row):return row.id==attached.id) and active.any(func(row):return row.id==remaining.id),"再配置では付随判定を終え、残る弾の枠を保つ")
	check(core.advance_attack_budget(0.6) and core.attack_token("後")==token,"再配置後も残留枠の終了を待つ")
	bridge.command("dev_end_attack",{"handle":remaining.handle})
	check(core.advance_attack_budget(0.6) and core.attack_budget_snapshot().used==0.0,"再配置した攻撃の最後の残留を回収する")
	var passive: int = core.passive_attack("常設",owners[2])
	check(passive>0,"非能動の攻撃にも独立したトークンを振る")
	core.track_attack_external(passive,"外部の線")
	check(core.advance_attack_budget(0.7) and core.attack_budget_snapshot().groups.size()==1,"外部で保持している判定は枠を維持する")
	core.release_attack_external(passive,"外部の線")
	check(core.advance_attack_budget(0.7) and core.attack_budget_snapshot().groups.is_empty(),"外部の最後の保持を外すと枠を解放する")
	bridge.dispose()
	var phases := []
	for row in [[0.0,1],[2.0/120.0,2],[3.0/120.0,0]]:
		var phase := PhaseDef.new()
		phase.start = row[0]
		phase.attack_budget = row[1]
		phases.append(phase)
	bridge = director_fixture(phases)
	core = bridge._core
	owners = [spawn_owner(bridge,0),spawn_owner(bridge,100),spawn_owner(bridge,200)]
	check(core.request_attack("最初",cats,owners[0],1.0,0.0,1.0) and not core.request_attack("追加",cats,owners[1],1.0,0.0,1.0),"開始時のタイムライン予算を攻撃側へ適用する")
	for tick in range(2): check(bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)}).ok,"通常の世界更新で時刻別の予算を更新する")
	check(core.request_attack("追加",cats,owners[1],1.0,0.0,1.0),"予算が増えた時点で同じ待機列から取得する")
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	check(not core.request_attack("停止",cats,owners[2],1.0,0.0,1.0) and core.attack_budget_snapshot().used==2.0,"予算0への変更で新規攻撃を止め、取得済みの枠は保つ")
	bridge.dispose()

func check_biter_budget_path() -> void:
	var phases := []
	for row in [[0.0,0],[2.0/120.0,1]]:
		var phase := PhaseDef.new()
		phase.start = row[0]
		phase.attack_budget = row[1]
		phases.append(phase)
	var bridge = director_fixture(phases,&"biter")
	var response: Dictionary = bridge.command("dev_spawn",{"definition_id":"biter","position":Vector2(40,0)})
	check(response.ok,"噛みつく敵を通常の定義から出す")
	var id: int = response.value
	var saw_hazard := false
	var reclaimed := false
	for tick in range(100):
		check(bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)}).ok,"待機から発射・終了まで通常の世界更新を進める")
		var snapshot: Dictionary = bridge._core.attack_budget_snapshot()
		var hazards: Array = bridge._core.hazards_snapshot()
		if tick==0: check(snapshot.groups.is_empty() and not snapshot.waiting.is_empty(),"予算0の世界更新では予告前に待つ")
		if not hazards.is_empty():
			saw_hazard = true
			check(snapshot.used==1.0,"発生した判定が同じ攻撃枠を保持する")
		if saw_hazard and hazards.is_empty():
			bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
			reclaimed = bridge._core.attack_token(str(id))==0
			break
	check(saw_hazard and reclaimed,"予算更新後に噛みつきを発射し、残留終了後に枠を戻す")
	bridge.dispose()
