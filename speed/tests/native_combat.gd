## 地形・装備がない接触の、順序・HP・反発・乱数・表示通知を本番処理へ照合する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
const DATA := preload("res://tools/content/build_native_data.gd")
const SHIP := preload("res://tests/native_ship.gd")
const COMBAT_CONFIG := ["base_attack", "atk_scale", "ram_speed_ratio", "crit_armor", "touch_damage", "contact_cooldown", "bounce_keep", "bounce_min_speed", "kill_hitstop", "kill_hitstop_cap", "kill_hitstop_regen", "hitstop_big_mult", "hitstop_crit_mult", "max_enemy_radius"]
const COMBAT_STATS := ["attack_mult", "crit_chance", "crit_mult"]
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
	if not probe.has_method("configure_combat"):
		check(false, "接触とダメージをネイティブランが所有する")
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
	var definition: EnemyDef = run.enemies.def_of(&"drifter").duplicate(true)
	definition.hp = 6 if mode == "kill" else 1000
	definition.armor = 1000 if mode == "bounce" else 2
	var core = comparison.create_native()
	check(core.configure(DATA.compile_enemy(definition, run.cfg)), "接触用の敵を準備する")
	check(core.configure_ship(values(run.cfg, SHIP.CONFIG_KEYS), values(run.state.stats, SHIP.STAT_KEYS)), "接触用の機体を準備する")
	check(core.configure_combat(values(run.cfg, COMBAT_CONFIG), values(run.state.stats, COMBAT_STATS)), "接触の編集値を準備する")
	core.start(932, run.enemies._next_id)
	run.state.rng.seed = 932
	var p := run.state.ship_pos
	var positions := [Vector2(0, 40)] if mode == "kill" else [Vector2(0, 40), Vector2(0, 40), Vector2(0, 10), Vector2(300, 0)]
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
	# 撃破の報酬による乱数消費は、P07の回収経路で照合する。
	if mode != "kill": check(str(run.state.rng.state) == core.inspect().rng_state, "接触の乱数消費が一致する: " + mode)
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
