## たて座の生成・追跡・旋回を、本番の編集値と更新へ照合する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
const DATA := preload("res://tools/content/build_native_data.gd")
const SHIP := preload("res://tests/native_ship.gd")
const COMBAT := preload("res://tests/native_combat.gd")
const HOSTILES := preload("res://tests/native_hostiles.gd")
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var comparison = COMPARE.new()
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 287, "empty": true, "invincible": false})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	var definition := run.enemies.def_of(&"shield")
	var data := DATA.compile_enemy(definition, run.cfg)
	check(not data.is_empty(), "たて座の編集値を実行用データへ生成できる")
	if not data.is_empty():
		var core = comparison.create_native()
		check(core.configure(data), "たて座を対応する行動として読み込む")
		core.start(287, run.enemies._next_id)
		run.state.rng.seed = 287
		core.set_motion_context(run.state.ship_pos, run.state.view_center, run.state.view_half)
		for position in [Vector2(500,100), Vector2(2500,200), Vector2(-2000,-300)]:
			run.enemies.spawn(definition, position)
			core.spawn_enemy(&"shield", position)
		for tick in 90:
			if tick in [20,50]: run.state.ship_pos = Vector2(130,180) if tick == 20 else Vector2(-170,400)
			core.set_motion_context(run.state.ship_pos, run.state.view_center, run.state.view_half)
			var dt := 1.0/60.0
			run.state.world_time += dt
			run.enemies.tick(dt,dt)
			core.step(dt)
			var difference: String = comparison.difference(comparison.snapshot(run, [], tick).enemies, core.enemies_snapshot())
			check(difference.is_empty(), "追跡・旋回・遠方の更新が一致する: %d %s" % [tick,difference])
			check(str(run.state.rng.state) == core.inspect().rng_state, "敵の移動で乱数消費を変えない")
		core.close()
	lab.free()
	for mode in ["front_touch", "front_ram", "rear_ram", "rear_zero_ram", "side_ram", "glide_cooldown", "front_shots", "back_shots", "front_debris"]: await compare_hits(comparison, mode)
	print("[native_shield] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func values(object: Object, keys: Array) -> Dictionary:
	var out := {}
	for key in keys: out[key] = object.get(key)
	return out
func compare_hits(comparison, mode: String, stone := false) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 287, "empty": true, "invincible": false})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	run.ship.setup(run.ship.ctx)
	if mode.ends_with("ram"): run.cfg.ram_speed_ratio = 0.0
	var definition: EnemyDef = run.enemies.def_of(&"shield").duplicate(true)
	if mode == "rear_zero_ram": definition.weak_arc = 0.0
	if mode == "glide_cooldown" or stone: definition.hp = 1000.0
	if stone: definition.armor = 1000.0
	var core = comparison.create_native()
	var budget_helper = load("res://tests/native_attack_budget.gd").new()
	core.configure(DATA.compile_enemy(definition, run.cfg))
	core.configure_ship(values(run.cfg, SHIP.CONFIG_KEYS), values(run.state.stats, SHIP.STAT_KEYS))
	core.configure_combat(values(run.cfg, COMBAT.COMBAT_CONFIG), values(run.state.stats, COMBAT.COMBAT_STATS))
	if mode == "glide_cooldown": core.configure_draw(values(run.cfg, SHIP.DRAW_CONFIG), values(run.state.stats, SHIP.DRAW_STATS))
	var config := values(run.cfg, COMBAT.PICKUP_CONFIG)
	config.xp_bonus = run.spawn.current_phase().xp_bonus
	core.configure_pickups(config, values(run.state.stats, ["xp_mult", "xp_pickup_radius", "pickup_radius", "pickup_speed_mult"]))
	core.configure_projectiles(values(run.cfg, ["hull_debris_life", "hull_debris_knock", "corpse_trail_points"]))
	core.start(287, run.enemies._next_id, run.pickups._gem_next_seq)
	run.state.rng.seed = 287
	if mode == "glide_cooldown":
		var start := run.state.ship_pos
		for tick in 120:
			var command := {"touch": true, "press": tick == 0, "has_cursor": true, "pen_release": tick == 2, "pen": start + Vector2(mini(tick,2)*100,0)}
			for key in command: run.draw.intent.set(key, command[key])
			run.draw.handle_input()
			core.handle_draw(command, tick*17, run.state.camera_zoom)
			run.draw.tick(1.0/60.0, 1.0/60.0)
			core.step_draw(1.0/60.0)
			if run.state.glide: break
		check(run.state.glide and core.ship_snapshot().glide, "実際のなぞりを終えて勢い中にする")
		core.drain_events()
	var origin := run.state.ship_pos
	var position := Vector2.ZERO if mode.ends_with("shots") or mode == "front_debris" else origin + (Vector2(40,0) if mode.begins_with("rear") else Vector2(0,40) if mode == "side_ram" else Vector2(-40,0))
	run.state.events.clear()
	var row := run.enemies.spawn(definition, position)
	var id: int = core.spawn_enemy(&"shield", position)
	if stone:
		run.enemies.table.stone[row] = 1.0
		check(core.set_enemy_motion(id,{"stone":1.0}),"石化中の接触と射撃を比較する")
	check(comparison.difference(comparison.plain(run.state.events), comparison.plain(core.drain_events())).is_empty(), "強敵の出現を同じ個体IDで通知する")
	run.combat.rebuild_grid()
	core.rebuild_enemy_grid(run.cfg.grid_cell)
	core.set_motion_context(run.state.ship_pos, run.state.view_center, run.state.view_half)
	for repeat in 2:
		run.state.events.clear()
		if mode.ends_with("shots"):
			var from := Vector2(200,0) if mode == "front_shots" else Vector2(-200,0)
			var angle := PI if mode == "front_shots" else 0.0
			var options := {"speed": 1200.0, "life": 1.0, "pierce_left": 5}
			run.projectiles.fire_shot(from, angle, 7.0, options)
			core.fire_shot(from, angle, 7.0, options)
			run.projectiles._update_friendly(0.2)
			core.step_projectiles(0.2)
		elif mode == "front_debris":
			run.projectiles.burst_debris(Vector2(40,0), 1, 0.0, 7.0, Color.RED, -1)
			core.burst_debris(Vector2(40,0), 1, 0.0, 7.0, Color.RED, -1)
			run.projectiles._update_friendly(0.01)
			core.step_projectiles(0.01)
		else:
			var from := origin + (Vector2(-100,0) if mode.begins_with("rear") else Vector2(0,-100) if mode == "side_ram" else Vector2(100,0))
			if mode == "glide_cooldown" and repeat == 0: from = position + Vector2(-60,-200)
			var bounced := run.combat.collide_ship(from, run.cfg.ship_radius, null)
			check(core.collide_ship(from, run.cfg.ship_radius) == bounced, "盾の前面と背面の接触を分ける: " + mode)
		var difference: String = comparison.difference(comparison.snapshot(run, [], 0).enemies, core.enemies_snapshot())
		check(difference.is_empty(), "盾のダメージと押出しが一致する: " + mode + difference)
		difference = comparison.difference(comparison.plain(values(run.state, SHIP.STATE_KEYS)), comparison.plain(core.ship_snapshot()))
		check(difference.is_empty(), "反発と盾の取得が一致する: " + mode + difference)
		var helper = HOSTILES.new()
		difference = comparison.difference(comparison.plain(helper.snapshot(run.projectiles)), comparison.plain(core.hostiles_snapshot()))
		helper.free()
		check(difference.is_empty(), "反射弾と反射の待ち時間が一致する: " + mode + difference)
		difference = comparison.difference(comparison.plain(run.state.events), comparison.plain(core.drain_events()))
		check(difference.is_empty(), "盾の通知順が一致する: " + mode + difference)
		check(str(run.state.rng.state) == core.inspect().rng_state, "背面命中とドロップの乱数が一致する: " + mode)
		check(comparison.difference(budget_helper.snapshot(run.projectiles.director),core.attack_budget_snapshot()).is_empty(),"撃破直後の接触枠も一致する: " + mode)
	if mode == "front_shots" and not stone: check(core.hostiles_snapshot().size() == 1, "反射の待ち時間中は追加の反射弾を出さない")
	if mode == "rear_ram" and not stone: check(run.state.ship_shield_t > 0 and core.ship_snapshot().ship_shield_t > 0, "背面から盾を奪う経路が実際に通る")
	if mode == "glide_cooldown": check(run.state.glide and core.ship_snapshot().glide, "接触待ち時間中の盾の前面接触は勢いを保つ")
	if mode == "rear_ram" and not stone:
		for elapsed in [0.21, 0.01, float(definition.params.shield_time)]:
			run.state.events.clear()
			run.ship.intent.touch = true
			run.ship.tick(elapsed, elapsed)
			core.step_ship(elapsed, elapsed, {"touch": true})
			var fields := {"kind": 0, "pos": run.state.ship_pos, "vel": Vector2.ZERO, "speed": 0.0, "r": 7.0, "life": 1.0, "dmg": 7.0, "slow": 0.2, "turn": 0.0}
			run.projectiles._add_hostile(fields.pos, fields.vel, fields.speed, fields.r, fields.life, fields.dmg, fields.slow, fields.turn, 0)
			core.spawn_hostile(fields)
			run.projectiles._update_hostile(0.01)
			core.step_hostiles(0.01)
			var difference: String = comparison.difference(comparison.plain(values(run.state, SHIP.STATE_KEYS)), comparison.plain(core.ship_snapshot()))
			check(difference.is_empty(), "奪った盾の防御・失効後の被弾が一致する: " + difference)
			difference = comparison.difference(comparison.plain(run.state.events), comparison.plain(core.drain_events()))
			check(difference.is_empty(), "盾の防御と失効通知が一致する: " + difference)
		check(core.ship_snapshot().ship_hp < run.state.stats.max_hp, "盾が切れた後の被弾を実際に通る")
	if stone:
		var pickup_helper = COMBAT.new()
		check(comparison.difference(comparison.plain(pickup_helper.pickup_snapshot(run)),comparison.plain(core.pickups_snapshot())).is_empty(),"石化の撃破でも同じ報酬を生成する")
		pickup_helper.free()
		check(run.state.kills == core.combat_snapshot().kills and run.state.hitstop == core.combat_snapshot().hitstop,"石化の撃破数と停止演出が一致する")
		if mode.ends_with("shots") or mode == "front_debris":
			check(run.enemies.table.hp[row] < definition.base_hp(run.cfg) and core.hostiles_snapshot().is_empty(),"石化中は盾で反射せずダメージを受ける")
		else:
			check(run.enemies.table.dead[row] != 0 and run.enemies.table.hp[row] > 0.0,"石化した敵はHPと装甲に関係なく接触で砕ける")
			check(run.state.ship_shield_t == 0.0,"石化した盾から盾を奪わない")
	budget_helper.free()
	core.close()
	lab.free()
