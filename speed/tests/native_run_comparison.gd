## 同じ戦闘実体を使い、成長の所有境界だけ変えて比較する。
extends "res://tests/native_progression.gd"
const OWNER := preload("res://scripts/runtime/native_session.gd")
var samples := {"B":[],"C":[]}
var wait_samples := {"B":[],"C":[]}
func setup_core(run: RunSimulation, whole: bool):
	var core = COMPARE.new().create_native()
	var definition: EnemyDef = run.enemies.def_of(&"drifter").duplicate(true)
	definition.speed = 0
	definition.hp = 1
	definition.armor = 0
	core.configure(DATA.compile_enemy(definition,run.cfg))
	core.configure_ship(values(run.cfg,SHIP.CONFIG_KEYS),values(run.state.stats,SHIP.STAT_KEYS))
	core.configure_draw(values(run.cfg,SHIP.DRAW_CONFIG),values(run.state.stats,SHIP.DRAW_STATS))
	core.configure_combat(values(run.cfg,COMBAT.COMBAT_CONFIG),values(run.state.stats,COMBAT.COMBAT_STATS))
	var config := values(run.cfg,COMBAT.PICKUP_CONFIG)
	config.xp_bonus = 1.0
	core.configure_pickups(config,values(run.state.stats,["xp_mult","xp_pickup_radius","pickup_radius","pickup_speed_mult"]))
	core.configure_frame({"world_tick_div":1,"grid_cell":run.cfg.grid_cell,"trace_radius":run.cfg.trace_radius})
	core.configure_forward(ContentManager.definition(&"weapons",&"W01").params,1,run.cfg.character_scale)
	if whole: core.configure_progression(PROGRESSION.compile(run.cfg,run.ctx.profile))
	core.start(1331,run.enemies._next_id)
	if whole: core.grant_equipment(&"weapon",&"W01",1)
	core.set_run_guards({"invincible":true})
	for i in 45: core.spawn_enemy(&"drifter",Vector2(0,-100-i*15))
	return core
func _ready() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":1331,"empty":true,"level":0})
	var run: RunSimulation = lab.run
	run.cfg.start_radius = 0
	run.cfg.xp_base = 3
	run.cfg.xp_growth = 0.5
	run.cfg.xp_curve = 0.2
	run.loadout.grant(&"weapon",&"W01",1)
	var b = setup_core(run,false)
	var c = setup_core(run,true)
	var owner = OWNER.new()
	add_child(owner)
	owner.set_process(false)
	owner.attach(c)
	var choices := 0
	var collected := 0
	var comp = COMPARE.new()
	for tick in 600:
		# 同じXP入力で複数の保留・選択を必ず通す。戦闘からの回収も併せて扱う。
		if tick in [60,180,300]:
			run.loadout.add_xp(10)
			c.add_xp(10)
			if run.state.cards.is_empty(): run.loadout.try_open_cards()
			c.open_cards(false)
			b.apply_external_progression(values(run.state.stats,run.state.stats.get_property_list().filter(func(p):return p.type in [TYPE_FLOAT,TYPE_INT]).map(func(p):return p.name)),run.state.ship_hp,not run.state.cards.is_empty(),run.state.rng.state)
		var command := {"touch":true}
		var active: bool = b.inspect().phase==0
		var before := Time.get_ticks_usec()
		b.step_frame(1.0/60.0,command,Vector2.ZERO,Vector2(640,360),1.0)
		run.state.time = b.inspect().time
		run.state.world_time = b.inspect().world_time
		run.state.ship_pos = b.ship_snapshot().ship_pos
		run.state.ship_hp = b.ship_snapshot().ship_hp
		run.state.rng.state = b.random_state()
		var notifications: Array = b.drain_events()
		for item in b.drain_collections():
			if item.kind==&"gem": run.loadout.add_xp(item.value); collected += 1
		if run.state.cards.is_empty(): run.loadout.try_open_cards()
		if not run.state.cards.is_empty(): b.apply_external_progression(values(run.state.stats,run.state.stats.get_property_list().filter(func(p):return p.type in [TYPE_FLOAT,TYPE_INT]).map(func(p):return p.name)),run.state.ship_hp,true,run.state.rng.state)
		var b_time := Time.get_ticks_usec()-before
		before = Time.get_ticks_usec()
		c.step_frame(1.0/60.0,command,Vector2.ZERO,Vector2(640,360),1.0)
		c.drain_collections()
		var native_events: Array = c.drain_events()
		owner.sync_requests()
		var c_time := Time.get_ticks_usec()-before
		if tick>=60:
			var target: Dictionary = samples if active else wait_samples
			target.B.append(b_time); target.C.append(c_time)
		if not run.state.cards.is_empty():
			owner.sync_requests()
			for frame in 100:
				owner.poll_resources()
				var ready := true
				for scope in run.loadout._candidate_resources.values(): ready = ready and scope.is_ready()
				for scope in owner.candidates.values(): ready = ready and scope.is_ready()
				if ready: break
				await get_tree().process_frame
			# 比較の戦闘経路はW01と能力値特性に固定する。
			var index := -1
			for i in run.state.cards.size():
				var id: StringName = run.state.cards[i].id
				if id in [&"W01",&"T07",&"T08",&"T09",&"T10",&"T11",&"T12",&"T14",&"T31"]: index = i; break
			if index<0 and run.state.rerolls_left>0:
				run.loadout.reroll_cards(); c.reroll_cards()
				b.apply_external_progression(values(run.state.stats,run.state.stats.get_property_list().filter(func(p):return p.type in [TYPE_FLOAT,TYPE_INT]).map(func(p):return p.name)),run.state.ship_hp,true,run.state.rng.state)
			elif index>=0:
				run.state.rng.state = b.random_state()
				run.loadout.choose_card(index)
				owner.choose(index)
				b.set_forward_level(int(run.state.weapons.get(&"W01",1)))
				b.apply_external_progression(values(run.state.stats,run.state.stats.get_property_list().filter(func(p):return p.type in [TYPE_FLOAT,TYPE_INT]).map(func(p):return p.name)),run.state.ship_hp,not run.state.cards.is_empty(),run.state.rng.state)
				choices += 1
		compare_state(run,c)
		var diff: String = comp.difference(comp.plain(b.enemies_snapshot()),comp.plain(c.enemies_snapshot()))
		if diff.is_empty(): diff = comp.difference(comp.plain(b.ship_snapshot()),comp.plain(c.ship_snapshot()))
		if diff.is_empty(): diff = comp.difference(comp.plain(b.projectiles_snapshot()),comp.plain(c.projectiles_snapshot()))
		if diff.is_empty(): diff = comp.difference(comp.plain(b.pickups_snapshot()),comp.plain(c.pickups_snapshot()))
		check(diff.is_empty(),"BとCで戦闘・停止・回収の結果が一致する tick%d: %s"%[tick,diff])
		if failed: break
	check(choices>=2,"複数のカード選択を実際に比較する")
	check(collected>0,"戦闘の撃破から経験値を回収する")
	var metrics := {}
	for key in samples:
		var sorted: Array = samples[key].duplicate(); sorted.sort()
		var total := 0.0
		for x in sorted: total += x
		if not sorted.is_empty(): metrics[key] = {"mean_ms":total/sorted.size()/1000.0,"p95_ms":sorted[ceili(sorted.size()*0.95)-1]/1000.0,"max_ms":sorted.back()/1000.0,"samples":sorted.size()}
	print("RUN_COMPARISON ",JSON.stringify({"metrics":metrics,"wait_samples":wait_samples.B.size(),"choices":choices,"collections":collected,"failed":failed}))
	owner.close(); owner.free(); b.close(); lab.free()
	print("[native_run_comparison] failed=%d"%failed)
	get_tree().quit(1 if failed else 0)
