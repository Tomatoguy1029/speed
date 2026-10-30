## 世界時計・共有枠の取消・死亡・残った弾による枠の保持を比較する。
extends "res://tests/native_attack_budget.gd"
const SHIP := preload("res://tests/native_ship.gd")
func values(object: Object,keys: Array) -> Dictionary:
	var out := {}
	for key in keys: out[key] = object.get(key)
	return out
func _ready() -> void:
	comparison = COMPARE.new()
	var probe = comparison.create_native()
	if not probe.has_method("advance_attack_budget"):
		check(false,"攻撃枠の時計と寿命をネイティブが保持する")
	else:
		for formation in [false,true]: await compare_lifetime(formation)
	probe.close()
	print("[native_attack_lifetime] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func same(run: RunSimulation,core,label: String) -> void:
	var diff: String = comparison.difference(snapshot(run.projectiles.director),core.attack_budget_snapshot())
	check(diff.is_empty(),label+": "+diff)
	check(events(run.state.events) == events(core.drain_events()),label+"の通知が一致する")
	check(str(run.state.rng.state) == core.inspect().rng_state,label+"の乱数消費が一致する")
	run.state.events.clear()
func advance(run: RunSimulation,core,at: float) -> void:
	run.projectiles.director.advance(at,run.enemies)
	check(core.advance_attack_budget(at),"攻撃枠の世界時計を進める")
	same(run,core,"枠の失効時刻 %.3f" % at)
func compare_lifetime(formation: bool) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":422,"empty":true})
	var run: RunSimulation = lab.run
	var d = run.projectiles.director
	d.formation_mode = formation
	var definition := run.enemies.def_of(&"drifter").duplicate(true) as EnemyDef
	definition.params.fire_interval = 0.2
	definition.params.telegraph = 0.3
	var core = comparison.create_native()
	core.configure(DATA.compile_enemy(definition,run.cfg,run.state.stage))
	core.configure_ship(values(run.cfg,SHIP.CONFIG_KEYS),values(run.state.stats,SHIP.STAT_KEYS))
	core.set_attack_formation_mode(formation)
	configure(d,core,true,1.0)
	core.start(422,run.enemies._next_id)
	run.state.rng.seed = 422
	var rows := []
	for i in 4:
		rows.append(run.enemies.spawn(definition,Vector2(i*20,0)))
		core.spawn_enemy(&"drifter",Vector2(i*20,0))
	run.state.events.clear()
	core.drain_events()
	request(run,core,"先頭",rows[0],1.0)
	request(run,core,"待機",rows[1],1.0)
	advance(run,core,0.5)
	request(run,core,"待機",rows[1],1.0)
	advance(run,core,1.0)
	request(run,core,"待機",rows[1],1.0)
	check(d.waiting.has("待機") and d.waiting["待機"].has("ready"),"待っていた攻撃のばらつきを実際に通る")
	advance(run,core,1.4)
	request(run,core,"待機",rows[1],1.0)
	var token: int = d.token("待機")
	check(token > 0 and core.attack_token("待機") == token,"開始した待機の枠を取得する")
	d.cancel_attack("待機",run.enemies.table.id[rows[0]])
	core.cancel_attack("待機",run.enemies.table.id[rows[0]])
	same(run,core,"別個体からの取消")
	d.track_external(token,"残る判定")
	core.track_attack_external(token,"残る判定")
	d.cancel_attack("待機",run.enemies.table.id[rows[1]])
	core.cancel_attack("待機",run.enemies.table.id[rows[1]])
	same(run,core,"本人からの取消")
	advance(run,core,1.5)
	check(d.groups.has(token),"外側に残る判定が枠を保持する")
	d.release_external(token,"残る判定")
	core.release_attack_external(token,"残る判定")
	advance(run,core,1.6)
	request(run,core,"共有",rows[0],1.0)
	request(run,core,"共有",rows[1],1.0)
	var id: int = run.enemies.table.id[rows[0]]
	d.cancel_attack("共有",id)
	core.cancel_attack("共有",id)
	for row in [rows[0],rows[1]]:
		id = run.enemies.table.id[row]
		check(core.owns_attack("共有",id) == d.owns_action("共有",id),"共有中の別個体の行動は保持する")
	advance(run,core,1.7)
	# 同じ格納行に別個体が入っても、元の共有枠を引き継がない。
	id = run.enemies.table.id[rows[1]]
	core.remove_enemy(id)
	run.enemies.mark_dead(rows[1])
	run.enemies.cleanup()
	var previous_row: int = rows[1]
	rows[1] = run.enemies.spawn(definition,Vector2(20,0))
	check(rows[1] == previous_row,"死亡した個体の格納行を実際に再利用する")
	core.spawn_enemy(&"drifter",Vector2(20,0))
	advance(run,core,1.8)
	configure(d,core,true,1.0)
	d.settings.jitter = 0.0
	core.configure_attack_budget({"enabled":true,"jitter":0.0})
	d.guard = {"until":INF}
	core.set_attack_guard(true,INF)
	request(run,core,"古い待機",rows[0],1.0,0.0)
	advance(run,core,2.8)
	request(run,core,"新しい待機",rows[2],1.0,0.1)
	d.guard.clear()
	core.set_attack_guard(false,0.0)
	request(run,core,"新しい待機",rows[2],1.0,0.1)
	request(run,core,"古い待機",rows[0],1.0,0.0)
	check(d.token("古い待機") > 0 and d.token("新しい待機") == 0,"待機時間の長さで優先度が逆転する")
	id = run.enemies.table.id[rows[2]]
	d.cancel_wait("新しい待機",id+100)
	core.cancel_attack_wait("新しい待機",id+100)
	same(run,core,"待機取消のID違い")
	core.remove_enemy(id)
	run.enemies.mark_dead(rows[2])
	run.enemies.cleanup()
	advance(run,core,2.9)
	check(not d.waiting.has("新しい待機"),"死亡した個体の待機が消える")
	advance(run,core,4.0)
	request(run,core,"弾を保持",rows[0],1.0)
	token = d.token("弾を保持")
	var origin := run.state.ship_pos + Vector2(200,0)
	core.set_motion_context(run.state.ship_pos,run.state.ship_pos,Vector2(640,360))
	var fields := {"kind":0,"pos":origin,"vel":Vector2.ZERO,"speed":0.0,"r":2.0,"life":0.1,"dmg":0.0,"slow":0.0,"turn":0.0,"attack_token":token}
	var shot: int = run.projectiles._add_hostile(origin,Vector2.ZERO,0.0,2.0,0.1,0.0,0.0,0.0,0)
	run.projectiles.lab_hostile_group[shot] = token
	check(core.spawn_hostile(fields) == shot,"弾と攻撃枠を対応させる")
	d.cancel_attack("弾を保持",run.enemies.table.id[rows[0]])
	core.cancel_attack("弾を保持",run.enemies.table.id[rows[0]])
	advance(run,core,4.1)
	check(d.groups.has(token),"生きている弾が攻撃枠を保持する")
	run.projectiles._update_hostile(0.2)
	core.step_hostiles(0.2)
	advance(run,core,4.2)
	check(not d.groups.has(token),"最後の弾が消えたあとに枠が解放される")
	token = d.passive("接触",rows[0],run.enemies.table.id[rows[0]])
	check(core.passive_attack("接触",run.enemies.table.id[rows[0]]) == token,"接触攻撃の枠と本番での無効化が一致する")
	same(run,core,"接触攻撃の枠")
	advance(run,core,4.3)
	core.close()
	lab.free()
