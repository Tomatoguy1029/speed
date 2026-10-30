## 地形・装備がない接触の、順序・HP・反発・乱数・表示通知を本番処理へ照合する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
const DATA := preload("res://tools/content/build_native_data.gd")
const SHIP := preload("res://tests/native_ship.gd")
const COMBAT_CONFIG := ["base_attack", "atk_scale", "ram_speed_ratio", "crit_armor", "touch_damage", "contact_cooldown", "bounce_keep", "bounce_min_speed", "kill_hitstop", "kill_hitstop_cap", "kill_hitstop_regen", "hitstop_big_mult", "hitstop_crit_mult", "max_enemy_radius"]
const COMBAT_STATS := ["attack_mult", "crit_chance", "crit_mult"]
const PICKUP_CONFIG := ["gem_max", "drop_base", "drop_max", "drop_power_exp", "big_crystal_shift_time", "big_crystal_xp", "big_crystal_weights_start", "big_crystal_weights_end"]
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func values(object: Object, keys: Array) -> Dictionary:
	var out := {}
	for key in keys: out[key] = object.get(key)
	return out
func _ready() -> void:
	var comparison = COMPARE.new()
	var probe = comparison.create_native()
	if not probe.has_method("configure_pickups"):
		check(false, "撃破から報酬の生成までネイティブランが所有する")
	else:
		for mode in ["touch", "pierce", "bounce", "kill"]:
			await compare_contacts(comparison, mode)
	print("[native_combat] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func compare_contacts(comparison, mode: String) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 932, "empty": true})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.ship.setup(run.ship.ctx)
	if mode != "touch": run.cfg.ram_speed_ratio = 0.0
	run.state.stats.crit_chance = 0.5
	if mode == "kill":
		run.cfg.drop_base = 1.0
		run.cfg.drop_max = 1.0
		run.cfg.gem_max = 1
	var definition: EnemyDef = run.enemies.def_of(&"drifter").duplicate(true)
	definition.hp = 6 if mode == "kill" else 1000
	definition.armor = 1000 if mode == "bounce" else 2
	var core = comparison.create_native()
	check(core.configure(DATA.compile_enemy(definition, run.cfg)), "接触用の敵を準備する")
	check(core.configure_ship(values(run.cfg, SHIP.CONFIG_KEYS), values(run.state.stats, SHIP.STAT_KEYS)), "接触用の機体を準備する")
	check(core.configure_combat(values(run.cfg, COMBAT_CONFIG), values(run.state.stats, COMBAT_STATS)), "接触の編集値を準備する")
	var pickup_config := values(run.cfg, PICKUP_CONFIG)
	pickup_config.xp_bonus = run.spawn.current_phase().xp_bonus
	check(not core.start(932), "報酬が未接続の戦闘を開始しない")
	check(core.configure_pickups(pickup_config, {"xp_mult": run.state.stats.xp_mult}), "ドロップの編集値を準備する")
	core.start(932, run.enemies._next_id, run.pickups._gem_next_seq)
	run.state.rng.seed = 932
	var p := run.state.ship_pos
	var positions := [Vector2(0, 40), Vector2(0, 40), Vector2(0, 10), Vector2(300, 0)]
	if mode == "kill":
		for i in 64: positions.append(Vector2(0, 40))
	for offset in positions:
		run.enemies.spawn(definition, p + offset)
		core.spawn_enemy(&"drifter", p + offset)
	run.combat.rebuild_grid()
	core.rebuild_enemy_grid(run.cfg.grid_cell)
	run.state.events.clear()
	var from := p + Vector2(0,100)
	var bounced := run.combat.collide_ship(from, run.cfg.ship_radius, null)
	check(core.collide_ship(from, run.cfg.ship_radius) == bounced, "反発する条件が一致する: " + mode)
	check(comparison.difference(comparison.snapshot(run, [], 0).enemies, core.enemies_snapshot()).is_empty(), "接触順・ダメージ・押出しが一致する: " + mode)
	check(comparison.difference(comparison.plain(values(run.state, SHIP.STATE_KEYS)), comparison.plain(core.ship_snapshot())).is_empty(), "反発後の機体が一致する: " + mode)
	check(comparison.difference(comparison.plain(run.state.events), comparison.plain(core.drain_events())).is_empty(), "命中と反発の表示通知が一致する: " + mode)
	check(str(run.state.rng.state) == core.inspect().rng_state, "接触・撃破・ドロップの乱数消費が一致する: " + mode)
	check(comparison.difference(comparison.plain(pickup_snapshot(run)), comparison.plain(core.pickups_snapshot())).is_empty(), "結晶・部品・大きな結晶と上限時の合流が一致する: " + mode + comparison.difference(comparison.plain(pickup_snapshot(run)), comparison.plain(core.pickups_snapshot())))
	if mode == "kill":
		check(not pickup_snapshot(run).coins.is_empty(), "部品の生成も実際に通る")
		check(run.combat.dash_stop == run.cfg.kill_hitstop_cap, "同時撃破でヒットストップの合計上限へ届く")
	check(run.state.kills == core.combat_snapshot().kills, "撃破の重複がない: " + mode)
	check(run.state.hitstop == core.combat_snapshot().hitstop, "ヒットストップが一致する: " + mode)
	# 同じ更新で再接触しても、接触待ち時間中は再び傷つけない。
	run.state.events.clear()
	run.combat.collide_ship(from, run.cfg.ship_radius, null)
	core.collide_ship(from, run.cfg.ship_radius)
	check(comparison.difference(comparison.snapshot(run, [], 0).enemies, core.enemies_snapshot()).is_empty(), "接触の待ち時間を保つ: " + mode)
	check(core.drain_events().is_empty() and run.state.events.is_empty(), "同じ接触を重複通知しない: " + mode)
	core.close()
	lab.free()

func pickup_snapshot(run: RunSimulation) -> Dictionary:
	var p := run.pickups
	var gems: Array = []
	var coins: Array = []
	for i in p.gem_alive.size():
		if p.gem_alive[i] != 0: gems.append({"pos": p.gem_pos[i], "value": p.gem_value[i], "seq": p.gem_seq[i], "pulled": p.gem_pulled[i] != 0})
	for i in p.coin_alive.size():
		if p.coin_alive[i] != 0: coins.append({"pos": p.coin_pos[i], "pulled": p.coin_pulled[i] != 0})
	return {"gems": gems, "coins": coins, "xp_dropped": run.state.xp_dropped}
