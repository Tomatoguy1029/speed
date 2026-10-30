## 致死被弾後の時計・攻撃・回収の停止と敗北演出を現行ランへ照合する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
const DATA := preload("res://tools/content/build_native_data.gd")
const SHIP := preload("res://tests/native_ship.gd")
const COMBAT := preload("res://tests/native_combat.gd")
const HOSTILES := preload("res://tests/native_hostiles.gd")
const SHOTS := preload("res://tests/native_projectiles.gd")
const DEATH_KEYS := ["death_freeze_time", "death_explosion_time", "death_game_over_time"]
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
	if not probe.has_method("configure_lifecycle"):
		check(false, "敗北の遷移をネイティブランが所有する")
	else:
		for mode in ["normal", "large_step", "zero_time"]: await compare_death(comparison, mode)
	probe.close()
	print("[native_lifecycle] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func compare_death(comparison, mode: String) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 716, "empty": true, "invincible": false})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	run.ship.setup(run.ship.ctx)
	run.state.enemy_aim = run.state.ship_pos
	run.state.lab_mode = false
	run.cfg.world_tick_div = 1
	if mode == "zero_time":
		for key in DEATH_KEYS: run.cfg.set(key, 0.0)
	var definition: EnemyDef = run.enemies.def_of(&"drifter").duplicate(true)
	definition.speed = 0.0
	var core = comparison.create_native()
	core.configure(DATA.compile_enemy(definition, run.cfg))
	core.configure_ship(values(run.cfg, SHIP.CONFIG_KEYS), values(run.state.stats, SHIP.STAT_KEYS))
	core.configure_draw(values(run.cfg, SHIP.DRAW_CONFIG), values(run.state.stats, SHIP.DRAW_STATS))
	core.configure_combat(values(run.cfg, COMBAT.COMBAT_CONFIG), values(run.state.stats, COMBAT.COMBAT_STATS))
	var config := values(run.cfg, COMBAT.PICKUP_CONFIG)
	config.xp_bonus = run.spawn.current_phase().xp_bonus
	core.configure_pickups(config, values(run.state.stats, ["xp_mult", "xp_pickup_radius", "pickup_radius", "pickup_speed_mult"]))
	core.configure_frame(values(run.cfg, ["world_tick_div", "grid_cell", "trace_radius"]))
	check(core.configure_lifecycle(values(run.cfg, DEATH_KEYS)), "敗北演出の編集値を準備する")
	check(core.start(716, run.enemies._next_id, run.pickups._gem_next_seq), "敗北を扱うランを開始する")
	run.state.rng.seed = 716
	var origin := run.state.ship_pos
	# 致死被弾の直前に撃破する。敗北開始後は死亡行の整理と回収へ進まない。
	run.enemies.spawn(definition, origin + Vector2(300,0))
	core.spawn_enemy(&"drifter", origin + Vector2(300,0))
	run.projectiles.fire_shot(origin + Vector2(300,0), 0.0, 1e6)
	core.fire_shot(origin + Vector2(300,0), 0.0, 1e6)
	run.combat.rebuild_grid()
	core.rebuild_enemy_grid(run.cfg.grid_cell)
	var helper = HOSTILES.new()
	helper.add_shot(run, core, {"kind": 0, "pos": origin, "vel": Vector2.ZERO, "speed": 0.0, "r": 30.0, "life": 2.0, "dmg": 1e6, "slow": 0.3, "turn": 0.0})
	var shots = SHOTS.new()
	var commands := Intent.new()
	commands.touch = true
	run.input_source = func(): return commands
	var ended: Array = []
	var delivered: Array = []
	run.finished.connect(func(result): ended.append(result))
	run.frame_events.connect(func(events): delivered.append_array(events))
	var sequence_events: Array = []
	var dt := 1.0 / 60.0
	for tick in 200:
		if tick > 0 and mode == "large_step": dt = 4.0
		delivered.clear()
		run.state.events.clear()
		if run.state.phase == RunState.Phase.PLAY: run._play_tick(dt)
		else: run.physics_step(dt)
		check(core.step_frame(dt, {"touch": true}, run.state.view_center, run.state.view_half, run.state.camera_zoom), "敗北演出の時間を進める")
		var expected_events: Array = delivered.duplicate()
		expected_events.append_array(run.state.events)
		var difference: String = comparison.difference(comparison.plain(expected_events), comparison.plain(core.drain_events()))
		if difference.is_empty(): difference = comparison.difference(comparison.plain(values(run.state, SHIP.STATE_KEYS)), comparison.plain(core.ship_snapshot()))
		if difference.is_empty(): difference = comparison.difference(comparison.plain(shots.snapshot(run.projectiles)), comparison.plain(core.projectiles_snapshot()))
		if difference.is_empty(): difference = comparison.difference(comparison.plain(helper.snapshot(run.projectiles)), comparison.plain(core.hostiles_snapshot()))
		check(difference.is_empty(), "致死被弾後の更新と通知が一致する %s tick%d: %s" % [mode,tick,difference])
		check(run.state.phase == core.inspect().phase and is_equal_approx(run.sequence_t, core.inspect().sequence_t), "敗北の段階と時刻が一致する")
		check(run.state.time == core.inspect().time and run.state.world_time == core.inspect().world_time and run.state.sim_time == core.inspect().sim_time, "敗北後は戦闘の時計を進めない")
		for event in expected_events:
			if event.type in [&"ship_death", &"ship_explode", &"game_over"]: sequence_events.append(event.type)
		if tick == 0:
			check(run.state.phase == RunState.Phase.DYING and run.state.kills == 1, "撃破直後の致死被弾で敗北を開始する")
			check(not core.enemies_snapshot().is_empty(), "敗北開始後は死亡行の整理へ進まない")
		if run.state.phase == RunState.Phase.ENDED:
			check(not core.set_paused(false), "終了したランをポーズ解除で再開しない")
			if tick > 180 or mode != "normal": break
		if not difference.is_empty(): break
	check(ended.size() == 1 and not ended[0].cleared, "敗北結果を一度だけ渡す")
	check(sequence_events == ([&"ship_death"] if mode == "zero_time" else [&"ship_death", &"ship_explode", &"game_over"]), "敗北演出の通知を順に一度だけ出す")
	core.close()
	check(not core.set_paused(true) and not core.set_run_guards({"invincible": true}), "解放したランへ操作を渡さない")
	helper.free()
	shots.free()
	lab.free()
