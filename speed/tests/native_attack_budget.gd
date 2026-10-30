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
	print("[native_attack_budget] failed=%d" % failed)
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
	var old: bool = run.projectiles.director.request(owner,categories,row,id,1.0,priority,cost)
	check(core.request_attack(owner,PackedStringArray(categories),id,1.0,priority,cost) == old,"要求の許可と待機が一致する: "+owner)
	check(comparison.difference(snapshot(run.projectiles.director),core.attack_budget_snapshot()).is_empty(),"予算・共有枠・待機順が一致する: "+owner)
	check(events(run.state.events) == events(core.drain_events()),"許可した攻撃の通知が一致する: "+owner)
	check(str(run.state.rng.state) == core.inspect().rng_state,"要求で乱数消費を変えない")
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
