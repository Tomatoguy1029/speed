## 噛みつきの円形判定・一度だけの被弾・残留する枠と表示状態を比較する。
extends "res://tests/native_attack_budget.gd"
const SHIP := preload("res://tests/native_ship.gd")
func values(object: Object,keys: Array) -> Dictionary:
	var out := {}
	for key in keys: out[key] = object.get(key)
	return out
func _ready() -> void:
	comparison = COMPARE.new()
	var probe = comparison.create_native()
	if not probe.has_method("fire_bite_zone"):
		check(false,"噛みつきの判定をネイティブが所有する")
	else:
		for effects in [false,true]: await compare_zones(effects)
	probe.close()
	print("[native_bite_zone] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func hazard_snapshot(ps: ProjectileSystem) -> Array:
	var out := []
	for row in ps.hazard_alive.size():
		if not ps.hazard_alive[row]: continue
		out.append({"row":row,"pos":ps.hazard_pos[row],"radius":ps.hazard_len[row],"time":ps.hazard_t[row],"delay":ps.hazard_delay[row],"active":ps.hazard_active[row],"damage":ps.hazard_dmg[row],"hit":ps.hazard_hit[row]!=0,"color":ps.hazard_color[row],"token":ps.lab_hazard_group.get(row,0)})
	return comparison.plain(out)
func add_zone(run: RunSimulation,core,at: Vector2,radius: float,delay: float,token: int) -> void:
	run.projectiles.lab_context = token
	var row := run.projectiles.fire_zone(at,radius,delay,3.0,ProjectileSystem.HazardStyle.BITE,Color(0.7,0.3,0.1,0.8))
	check(core.fire_bite_zone(at,radius,delay,3.0,Color(0.7,0.3,0.1,0.8),token) == row,"噛みつきの判定を同じ順で生成・再利用する")
func compare_zones(effects: bool) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":422,"empty":true,"invincible":false})
	var run: RunSimulation = lab.run
	var d = run.projectiles.director
	d.formation_mode = true
	run.state.stats.invulnerability = 0.06
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	run.ship.setup(run.ship.ctx)
	var library := load("res://.content/attack_visuals.res").duplicate(true)
	if effects:
		library.set_meta("looks",{"res://scenes/attacks/zone_bite.tscn":{"Hit":Resource.new(),"Fade":Resource.new()}})
	run.projectiles._end_visual_library = library
	run.projectiles._end_visual_phases.clear()
	var definition := run.enemies.def_of(&"drifter").duplicate(true) as EnemyDef
	definition.speed = 0.0
	var core = comparison.create_native()
	core.configure(DATA.compile_enemy(definition,run.cfg,run.state.stage))
	core.configure_ship(values(run.cfg,SHIP.CONFIG_KEYS),values(run.state.stats,SHIP.STAT_KEYS))
	core.set_attack_formation_mode(true)
	configure(d,core,true,1.0)
	check(core.configure_bite_zone(DATA.compile_bite_zone(library)),"判定の寿命と表示終了の条件を準備する")
	core.start(422,run.enemies._next_id)
	run.state.rng.seed = 422
	var at := run.state.ship_pos
	var row := run.enemies.spawn(definition,at+Vector2(1000,0))
	var id: int = core.spawn_enemy(&"drifter",at+Vector2(1000,0))
	run.state.events.clear()
	core.drain_events()
	request(run,core,"噛みつき",row,1.0)
	var token: int = d.token("噛みつき")
	add_zone(run,core,at,20.3,0.0,token)
	add_zone(run,core,at,20.3,0.0,0)
	add_zone(run,core,at+Vector2(1000,0),20.3,0.0,0)
	add_zone(run,core,at,20.3,0.113,0)
	d.cancel_attack("噛みつき",id)
	core.cancel_attack("噛みつき",id)
	var hit_count := 0
	var retained := false
	for tick in 60:
		if tick in [20,40]: add_zone(run,core,run.state.ship_pos,31.7,0.0,0)
		var dt := 0.3 if tick == 40 else 0.02
		run.state.events.clear()
		run.state.time += dt
		run.state.world_time += dt
		d.advance(run.state.world_time,run.enemies)
		core.advance_attack_budget(run.state.world_time)
		retained = retained or (d.groups.has(token) and run.state.world_time > 0.0)
		check(comparison.difference(snapshot(d),core.attack_budget_snapshot()).is_empty(),"範囲判定が消えるまで攻撃枠を保持する")
		run.enemies.tick(dt,dt)
		core.set_motion_context(run.state.ship_pos,run.state.view_center,run.state.view_half)
		core.step(dt)
		run.ship.intent.touch = true
		run.ship.tick(dt,dt)
		core.step_ship(dt,dt,{"touch":true})
		run.projectiles._update_hazards(dt)
		check(core.step_hazards(dt),"噛みつきの判定を世界時間で更新する")
		var diff: String = comparison.difference(hazard_snapshot(run.projectiles),comparison.plain(core.hazards_snapshot()))
		if diff.is_empty(): diff = comparison.difference(comparison.plain(values(run.state,SHIP.STATE_KEYS)),comparison.plain(core.ship_snapshot()))
		if diff.is_empty(): diff = comparison.difference(comparison.plain(run.state.events),comparison.plain(core.drain_events()))
		check(diff.is_empty(),"予告・被弾・寿命・表示終了が一致する tick%d: %s" % [tick,diff])
		for event in run.state.events:
			if event.type == &"hurt": hit_count += 1
		if not diff.is_empty(): break
	check(hit_count == 3,"同時発動は無敵で一回、遅延と再利用は各一回、寿命を飛び越す更新は被弾しない")
	check(retained and not d.groups.has(token),"残留中の枠の保持と最終解放を実際に通る")
	var before: Array = core.hazards_snapshot()
	check(core.fire_bite_zone(at,NAN,0.0,1.0,Color.WHITE,0) == -1 and before == core.hazards_snapshot(),"不正な範囲を追加しない")
	core.close()
	lab.free()
