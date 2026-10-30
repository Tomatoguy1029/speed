## 保持したC++ランを複製し、隠れた待機・時計・集合を含む先の結果を比較する。
extends "res://tests/native_progression.gd"
func observe(core) -> Dictionary:
	return {"run":core.inspect(),"ship":core.ship_snapshot(),"draw":core.draw_snapshot(),"combat":core.combat_snapshot(),"enemies":core.enemies_snapshot(),"motion":core.enemy_motion_snapshot(),"packs":core.hound_snapshot(),"budget":core.attack_budget_snapshot(),"friends":core.projectiles_snapshot(),"hostiles":core.hostiles_snapshot(),"hazards":core.hazards_snapshot(),"pickups":core.pickups_snapshot(),"weapon":core.forward_snapshot(),"growth":core.progression_snapshot()}
func create_run(run: RunSimulation):
	var core = COMPARE.new().create_native()
	var data := DATA.compile_enemy(run.enemies.def_of(&"drifter"),run.cfg)
	for type in [&"biter",&"hound",&"shield"]: data.enemies.append_array(DATA.compile_enemy(run.enemies.def_of(type),run.cfg).enemies)
	check(core.configure(data),"保持対象の全行動を準備する")
	core.configure_ship(values(run.cfg,SHIP.CONFIG_KEYS),values(run.state.stats,SHIP.STAT_KEYS))
	core.configure_draw(values(run.cfg,SHIP.DRAW_CONFIG),values(run.state.stats,SHIP.DRAW_STATS))
	core.configure_combat(values(run.cfg,COMBAT.COMBAT_CONFIG),values(run.state.stats,COMBAT.COMBAT_STATS))
	var config := values(run.cfg,COMBAT.PICKUP_CONFIG); config.xp_bonus = 1.0
	core.configure_pickups(config,values(run.state.stats,["xp_mult","xp_pickup_radius","pickup_radius","pickup_speed_mult"]))
	core.configure_frame({"world_tick_div":3,"grid_cell":run.cfg.grid_cell,"trace_radius":run.cfg.trace_radius})
	core.configure_bite_zone(DATA.compile_bite_zone(load("res://.content/attack_visuals.res")))
	core.configure_progression(PROGRESSION.compile(run.cfg,run.ctx.profile))
	core.configure_attack_budget({"enabled":true,"budget":2,"jitter":0.2})
	core.start(1251,run.enemies._next_id)
	core.grant_equipment(&"weapon",&"W01",2)
	core.set_run_guards({"invincible":true})
	core.set_attack_budget_mode(true,false)
	for k in 24: core.spawn_enemy(&"drifter",Vector2(k%3*25,-160-k*15))
	core.spawn_enemy(&"hound",Vector2(130,0))
	core.spawn_enemy(&"biter",Vector2(0,80))
	core.spawn_enemy(&"shield",Vector2(150,-200))
	return core
func advance(core, tick: int) -> void:
	var cycle := tick%100
	var input := {"touch":true,"press":cycle==0,"has_cursor":cycle<5,"pen_release":cycle==5,"pen":Vector2(cycle*40,0)}
	if tick==100: core.add_xp(100)
	if tick%7==0:
		for request in core.drain_resource_requests(): core.resources_ready(request.revision,request.id,1)
		var state: Dictionary = core.progression_snapshot()
		if not state.cards.is_empty(): core.choose_card(0,state.revision)
	core.step_frame(1.0/60.0,input,Vector2.ZERO,Vector2(640,360),1.0)
func _ready() -> void:
	var comparison = COMPARE.new()
	var probe = comparison.create_native()
	if not probe.has_method("checkpoint"):
		check(false,"隠れた状態を含むラン全体を保持する")
	else:
		var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
		add_child(lab)
		await lab.reset({"seed":1251,"empty":true,"level":0})
		lab.run.cfg.start_radius = 0
		var core = create_run(lab.run)
		for tick in 83: advance(core,tick)
		var rows: Array = core.enemies_snapshot()
		var target: int = rows[0].id
		core.request_attack("保持中",PackedStringArray(["beam"]),target,1.0,0.0,1.0)
		core.request_attack("待機中",PackedStringArray(["beam"]),rows[1].id,1.0,1.0,5.0)
		core.fire_bite_zone(Vector2(100,0),24.0,0.6,8.0,Color.WHITE)
		core.fire_shot(Vector2.ZERO,-PI/2,3.0,{"pierce_left":5,"speed":200.0,"life":3.0})
		var begin := Time.get_ticks_usec()
		var saved = core.checkpoint()
		var checkpoint_us := Time.get_ticks_usec()-begin
		var baseline: Dictionary = observe(saved)
		var restored = saved.checkpoint()
		check(comparison.difference(comparison.plain(observe(core)),comparison.plain(observe(restored))).is_empty(),"保持直後の全観測値が一致する")
		for tick in range(83,243):
			advance(core,tick); advance(restored,tick)
			var diff: String = comparison.difference(comparison.plain(observe(core)),comparison.plain(observe(restored)))
			if diff.is_empty(): diff = comparison.difference(comparison.plain(core.drain_events()),comparison.plain(restored.drain_events()))
			if diff.is_empty(): diff = comparison.difference(comparison.plain(core.drain_collections()),comparison.plain(restored.drain_collections()))
			check(diff.is_empty(),"復帰後の移動・射撃・待機・成長・通知が一致する tick%d: %s"%[tick,diff])
			if not diff.is_empty(): break
		check(observe(saved)==baseline,"元のランと復帰先を動かしても保持点を変更しない")
		var other_before: Dictionary = observe(restored)
		var definition: EnemyDef = lab.run.enemies.def_of(&"drifter").duplicate(true)
		definition.hp *= 2
		definition.speed *= 1.5
		var original: Array = core.enemies_snapshot()
		check(core.update_enemy_definition(&"drifter",DATA.compile_enemy(definition,lab.run.cfg)),"別ランから独立したライブ変更を適用する")
		var edited: Array = core.enemies_snapshot()
		for i in original.size():
			if original[i].type=="drifter" and not original[i].dead: check(edited[i].hp==original[i].hp*2 and edited[i].pos==original[i].pos and edited[i].id==original[i].id,"編集で残HP割合と位置とIDを保つ")
		check(observe(restored)==other_before and observe(saved)==baseline,"編集を別ランと保持点へ漏らさない")
		check(not core.update_enemy_definition(&"drifter",{}),"不正な定義で既存状態を書き換えない")
		var removed: int = core.enemies_snapshot()[0].id
		core.remove_enemy(removed)
		var new_id: int = core.spawn_enemy(&"drifter",Vector2.ZERO)
		check(new_id!=removed and not core.set_enemy_motion(removed,{"stone":1.0}),"再利用後に古いIDを拒否する")
		core.close()
		check(not saved.enemies_snapshot().is_empty(),"元のラン終了後も保持点を復帰に使える")
		restored.close(); saved.close(); lab.free()
		print("CHECKPOINT ",JSON.stringify({"copy_us":checkpoint_us,"replay_ticks":160,"failed":failed}))
	probe.close()
	print("[native_checkpoint] failed=%d"%failed)
	get_tree().quit(1 if failed else 0)
