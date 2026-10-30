extends "res://tests/native_forward.gd"
const PROGRESSION := preload("res://tools/content/native_progression_data.gd")
func compare_state(run: RunSimulation,core) -> void:
	var result: Dictionary = core.progression_snapshot()
	for key in ["level","xp","xp_gained","pending_levels","rerolls_left","start_pick","weapons","traits","cards"]:
		check(COMPARE.new().difference(COMPARE.new().plain(run.state.get(key)),COMPARE.new().plain(result[key])).is_empty(),"成長の結果が一致する: "+key)
	for key in result.stats:
		check(run.state.stats.get(key)==result.stats[key],"能力値が一致する: "+key)
	check(run.state.ship_hp==result.ship_hp,"成長後のHPが一致する")
	check(str(run.state.rng.state)==core.inspect().rng_state,"候補とおまけの乱数が一致する")
func prepare(run: RunSimulation):
	run.cfg.start_radius = 0.0
	var core = COMPARE.new().create_native()
	check(core.configure(DATA.compile_enemy(run.enemies.def_of(&"drifter"),run.cfg)),"敵を準備する")
	core.configure_ship(values(run.cfg,SHIP.CONFIG_KEYS),values(run.state.stats,SHIP.STAT_KEYS))
	core.configure_draw(values(run.cfg,SHIP.DRAW_CONFIG),values(run.state.stats,SHIP.DRAW_STATS))
	core.configure_combat(values(run.cfg,COMBAT.COMBAT_CONFIG),values(run.state.stats,COMBAT.COMBAT_STATS))
	var config := values(run.cfg,COMBAT.PICKUP_CONFIG)
	config.xp_bonus = 1.0
	core.configure_pickups(config,values(run.state.stats,["xp_mult","xp_pickup_radius","pickup_radius","pickup_speed_mult"]))
	core.configure_frame({"world_tick_div":3,"grid_cell":run.cfg.grid_cell,"trace_radius":run.cfg.trace_radius})
	check(core.configure_progression(PROGRESSION.compile(run.cfg,run.ctx.profile)),"固定成長データを準備する")
	core.start(1103,run.enemies._next_id)
	run.state.rng.seed = 1103
	return core
func settle(run: RunSimulation, core) -> void:
	for request in core.drain_resource_requests():
		var scope := run.loadout.resources_for_card(request.id)
		while scope!=null and not scope.is_ready(): await get_tree().process_frame
		var accepted: bool = core.resources_ready(request.revision,request.id,1)
		check(accepted or request.revision!=core.progression_snapshot().revision,"資源を準備した候補だけ許可する")
func _ready() -> void:
	var comparison = COMPARE.new()
	var probe = comparison.create_native()
	if not probe.has_method("configure_progression"):
		check(false,"成長と選択待ちをラン本体が所有する")
	else:
		var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
		add_child(lab)
		await lab.reset({"seed":1103,"empty":true,"level":0})
		var run: RunSimulation = lab.run
		var core = prepare(run)
		compare_state(run,core)
		for id in [&"T07",&"T08",&"T09",&"T10",&"T11",&"T12",&"T14",&"T31"]:
			check(run.loadout.grant(&"trait",id,2)==core.grant_equipment(&"trait",id,2),"特性を同じ重ね数で取得する")
			compare_state(run,core)
		for amount in [1.0,50.0,300.0]:
			run.state.events.clear()
			run.loadout.add_xp(amount)
			core.add_xp(amount)
			compare_state(run,core)
			check(comparison.plain(run.state.events)==comparison.plain(core.drain_events()),"レベルアップと表示通知が一致する")
		for initial in [true,false]:
			if initial: run.loadout.open_start_cards()
			else: run.loadout.try_open_cards()
			check(core.open_cards(initial),"候補を開く")
			compare_state(run,core)
			var obsolete: int = core.progression_snapshot().revision
			var old_id: StringName = core.progression_snapshot().cards[0].id
			run.loadout.reroll_cards()
			check(core.reroll_cards(),"候補を引き直す")
			check(not core.resources_ready(obsolete,old_id,1),"引き直し前の完了通知を拒否する")
			compare_state(run,core)
			var revision: int = core.progression_snapshot().revision
			var id: StringName = core.progression_snapshot().cards[0].id
			check(core.choose_card(0,revision),"準備中は選択を保留する")
			check(core.progression_snapshot().weapons==run.state.weapons,"準備前に取得しない")
			await settle(run,core)
			run.loadout.choose_card(0)
			compare_state(run,core)
			check(not core.resources_ready(revision,id,1) and not core.choose_card(0,revision),"重複通知と古い選択で二重取得しない")
			if not initial:
				# 続く選択も比較し、所有済み候補の重みとおまけを通す。
				for i in 4:
					if run.state.cards.is_empty(): break
					await settle(run,core)
					run.loadout.choose_card(0)
					var rev: int = core.progression_snapshot().revision
					core.choose_card(0,rev)
					compare_state(run,core)
		core.close()
		lab.free()
		await compare_failures()
		await compare_resource_session()
		await compare_open_timing()
	probe.close()
	print("[native_progression] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func compare_failures() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":1103,"empty":true,"level":0})
	var core = prepare(lab.run)
	for status in [-1,-2]:
		core.open_cards(true)
		var state: Dictionary = core.progression_snapshot()
		var requests: Array = core.drain_resource_requests()
		core.choose_card(0,state.revision)
		check(core.resources_ready(state.revision,state.cards[0].id,status),"失敗と取消の返答を受け付ける")
		check(core.progression_snapshot().weapons.is_empty() and core.progression_snapshot().pending_choice==-1,"失敗と取消で装備を付けない")
		check(not core.resources_ready(state.revision,state.cards[0].id,1),"取消後に遅れて成功しても付けない")
		core.reroll_cards()
	core.close()
	lab.free()

func compare_resource_session() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":1103,"empty":true,"level":0})
	var core = prepare(lab.run)
	var owner = load("res://scripts/runtime/native_session.gd").new()
	add_child(owner)
	owner.attach(core)
	core.open_cards(true)
	owner.sync_requests()
	var initial: Dictionary = core.progression_snapshot()
	var selected: StringName = initial.cards[0].id
	check(owner.choose(0),"実際の資源要求中にカードを選ぶ")
	for tick in 200:
		owner.poll_resources()
		if not core.progression_snapshot().start_pick: break
		await get_tree().process_frame
	check(core.progression_snapshot().weapons.has(selected),"既存の資源準備から選択を完了する")
	check(owner.candidates.is_empty() and owner.equipped.size()==1,"非同期選択後に未選択資源を取り消し、取得分だけ保持する")
	var scope: ContentResourceScope = owner.candidates.get(selected,owner.equipped.get(selected))
	check(scope!=null and not scope.cancelled,"選択済みの資源をランに保持する")
	owner.close()
	check(scope.cancelled and owner.core==null,"実際の終了で資源と本体を解放する")
	owner.free()
	lab.free()

func compare_open_timing() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":1103,"empty":true,"level":0})
	var core = prepare(lab.run)
	core.set_motion_context(Vector2.ZERO,Vector2.ZERO,Vector2(640,360))
	core.handle_draw({"touch":true,"press":true,"pen":Vector2.ZERO},0,1.0)
	check(core.draw_snapshot().drawing,"描線中にレベルアップを保留する条件を作る")
	core.add_xp(lab.run.loadout.xp_needed())
	check(not core.open_cards(false),"描線中はカードを開かない")
	core.step_frame(1.0/60.0,{"touch":true,"pen_release":true},Vector2.ZERO,Vector2(640,360),1.0)
	check(core.inspect().phase==1 and core.inspect().ticks==0,"世界更新がないフレームでも描線終了直後にカードを開く")
	core.close()
	lab.free()
