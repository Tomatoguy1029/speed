## W01の周期と弾の更新を、描線・世界時間の間引きを含む実ランへ照合する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
const DATA := preload("res://tools/content/build_native_data.gd")
const SHIP := preload("res://tests/native_ship.gd")
const COMBAT := preload("res://tests/native_combat.gd")
const HOSTILES := preload("res://tests/native_hostiles.gd")
const SHOTS := preload("res://tests/native_projectiles.gd")
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
	if not probe.has_method("set_run_guards"):
		check(false, "停止と操作・被弾の保護をネイティブランが所有する")
	else:
		for condition in [[1,1],[5,1],[5,3]]: await compare_frames(comparison, condition[0], condition[1])
		await compare_frames(comparison, 5, 1, true)
		await compare_frames(comparison, 5, 1, true, true)
		await compare_frames(comparison, 5, 3, false, true)
	probe.close()
	print("[native_forward] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func compare_frames(comparison, level: int, division: int, guarded := false, spawning := false) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 631, "empty": true, "invincible": false})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	run.ship.setup(run.ship.ctx)
	run.state.enemy_aim = run.state.ship_pos
	run.cfg.world_tick_div = division
	if guarded: run.cfg.invuln_time = 0.25
	# 成長の所有者は別の比較で扱い、ここでは射撃とフレーム順序を独立して確認する。
	run.cfg.xp_base = 1e9
	check(run.loadout.grant(&"weapon", &"W01", level), "比較するW01を実際に装備する")
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
	core.configure_frame({"world_tick_div": division, "grid_cell": run.cfg.grid_cell, "trace_radius": run.cfg.trace_radius})
	var weapon = run.loadout.weapon_behaviors[&"W01"]
	check(core.configure_forward(weapon.def.params, level, run.cfg.character_scale), "W01の編集値とレベルを準備する")
	if spawning:
		var stage := RuntimeStage.new()
		stage.boss_enabled = false
		run.state.view_center = run.state.ship_pos
		# 追跡だけの比較条件では、通常の生成ステージと同じく攻撃枠を使わない。
		stage.attack_managed_by_type = {"drifter": false}
		var phase := PhaseDef.new()
		phase.id = &"補充比較"
		phase.pop_from = 35.0
		phase.pop_to = 35.0
		phase.rate = 13.2
		phase.xp_bonus = config.xp_bonus
		phase.wave_interval = 0.37
		phase.wave_type = &"drifter"
		phase.mix = {"drifter": 1.0}
		stage.phases = [phase]
		run.state.stage = stage
		run.enemies.definitions[&"drifter"] = definition
		check(core.configure_spawn_timeline(DATA.compile_spawn_timeline(stage,run.cfg)), "フレーム比較の出現条件を生成する")
		check(core.configure_population(values(run.cfg, ["spawn_recycle_scale", "spawn_region_cap", "spawn_margin", "field_radius", "planet_radius"])), "出現位置の編集値を渡す")
		check(core.configure_refill(values(run.cfg, ["spawn_total_cap", "spawn_refill_time"])), "フレームで使う補充を準備する")
	core.start(631, run.enemies._next_id, run.pickups._gem_next_seq)
	if spawning and not core.has_method("set_population_mode"):
		check(false, "補充の有効・無効をフレーム更新へ接続する")
		core.close()
		lab.free()
		return
	run.state.rng.seed = 631
	var origin := run.state.ship_pos
	for offset in [Vector2(0,-260),Vector2(0,-340),Vector2(0,-440),Vector2(120,0)]:
		run.enemies.spawn(definition, origin + offset)
		core.spawn_enemy(&"drifter", origin + offset)
	run.combat.rebuild_grid()
	core.rebuild_enemy_grid(run.cfg.grid_cell)
	var hostile := {"kind": 1, "pos": origin + Vector2(700,200), "vel": Vector2(-400,0), "speed": 400.0, "r": 9.0, "life": 4.5, "dmg": 7.0, "slow": 0.1, "turn": 1.6}
	run.projectiles._add_hostile(hostile.pos, hostile.vel, hostile.speed, hostile.r, hostile.life, hostile.dmg, hostile.slow, hostile.turn, hostile.kind)
	core.spawn_hostile(hostile)
	var hostile_helper = HOSTILES.new()
	var input := Intent.new()
	run.input_source = func(): return input
	var effects := BuildEffects.new()
	add_child(effects)
	effects.pixel = 1.82 * run.cfg.character_scale
	effects.clock = 0.531244
	var buffer_checked := false
	var helper = SHOTS.new()
	var fired := 0
	var shot_hits := 0
	for tick in 360:
		if spawning:
			run.options.auto_spawn = tick < 250 or tick >= 280
			var blocked := tick >= 150 and tick < 200
			run.projectiles.director.guard = {"until": INF} if blocked else {}
			check(core.set_population_mode(run.options.auto_spawn, false, blocked), "実験場の自動補充と出現待機を渡す")
		if guarded:
			var guards := {"controls_locked": tick >= 60 and tick < 80, "encounter_protected": tick >= 80 and tick < 95, "steering_locked": tick >= 200 and tick < 220, "invincible": tick >= 95 and tick < 100, "hitstop_enabled": tick < 150}
			for key in guards:
				if key == "invincible": run.ship.invincible = guards[key]
				else: run.state.set(key, guards[key])
			check(core.set_run_guards(guards), "操作・被弾の保護期間を渡す")
			if tick in [40,50]:
				run.set_phase(RunState.Phase.PAUSED if tick == 40 else RunState.Phase.PLAY)
				check(core.set_paused(tick == 40), "ポーズと再開を受け付ける")
			if tick in [60,80,95,100,160,200,220]:
				var direct := hostile.merged({"kind": 0, "pos": run.state.ship_pos, "vel": Vector2.ZERO, "speed": 0.0, "turn": 0.0}, true)
				hostile_helper.add_shot(run, core, direct)
		var cycle := tick - 100
		var command := {"touch": true, "press": cycle == 0, "has_cursor": cycle >= 0 and cycle <= 8,
			"pen_release": cycle == 8, "pen": origin + Vector2(maxi(0,cycle)*30,0)}
		if guarded:
			command.stick_active = (tick >= 60 and tick < 80) or (tick >= 200 and tick < 230)
			command.stick = Vector2.RIGHT if command.stick_active else Vector2.ZERO
			if tick in [65,205]: command.press = true; command.has_cursor = true
		for key in command: input.set(key, command[key])
		var center := run.state.view_center
		var half := run.state.view_half
		var zoom := run.state.camera_zoom
		run.state.events.clear()
		if run.state.phase == RunState.Phase.PLAY: run._play_tick(1.0/60.0)
		check(core.step_frame(1.0/60.0, command, center, half, zoom), "射撃も含めて一回の呼出しで更新する")
		if spawning:
			check(run.spawn._spawn_acc == core.refill_snapshot().accumulator and run.spawn._wave_t == core.refill_snapshot().wave_time, "補充を停止と世界時間の間引きに合わせる")
		if guarded and tick in [65,205]: check(not run.state.drawing, "操作ロック中は描線入力を受けない")
		check(run.state.phase == core.inspect().phase, "停止と再開の状態が一致する")
		check(is_equal_approx(run.state.time, core.inspect().time) and is_equal_approx(run.state.sim_time, core.inspect().sim_time), "停止中は両方の時計が止まる")
		if guarded and tick in [60,80,95,100,160,200,220]:
			var hurt := false
			for event in run.state.events: hurt = hurt or event.type == &"hurt"
			check(hurt == (tick >= 100), "保護中の接触と解除後の被弾を実際に通る tick%d" % tick)
		var difference: String = comparison.difference(comparison.snapshot(run, [], tick).enemies, core.enemies_snapshot())
		if difference.is_empty(): difference = comparison.difference(comparison.plain(helper.snapshot(run.projectiles)), comparison.plain(core.projectiles_snapshot()))
		if difference.is_empty(): difference = comparison.difference(comparison.plain(hostile_helper.snapshot(run.projectiles)), comparison.plain(core.hostiles_snapshot()))
		if difference.is_empty(): difference = comparison.difference(comparison.plain(values(run.state, SHIP.STATE_KEYS)), comparison.plain(core.ship_snapshot()))
		if difference.is_empty(): difference = comparison.difference(comparison.plain(run.state.events), comparison.plain(core.drain_events()))
		if difference.is_empty(): difference = comparison.difference({"elapsed": weapon._t, "recoil": weapon.recoil}, core.forward_snapshot())
		check(difference.is_empty(), "W01とフレーム順序が一致する Lv%d 間引き%d tick%d: %s" % [level,division,tick,difference])
		if tick % 15 == 0:
			effects.projectiles(run.projectiles)
			var reference: InstanceBatch = effects._shots["weapon/forward"]
			var buffer: PackedFloat32Array = core.friendly_buffer(&"weapon/forward", effects.pixel, effects.SETTINGS.number("weapon/forward", "effect_scale", 1.0), effects.clock)
			check(buffer == reference._buf.slice(0, reference._count * InstanceBatch.STRIDE), "弾のドット位置・向き・大きさ・表示時間を現行の表示へ照合する")
			buffer_checked = buffer_checked or not buffer.is_empty()
		check(str(run.state.rng.state) == core.inspect().rng_state, "発射・命中・報酬の乱数が一致する")
		core.drain_collections()
		for event in run.state.events:
			if event.type == &"weapon_fire": fired += 1
			if event.type == &"hit" and event.cause == &"shot": shot_hits += 1
		if not difference.is_empty(): break
	check(fired >= 2 and shot_hits > 0, "W01の発射と命中を実際に通る")
	check(buffer_checked, "発射中の弾の表示データを実際に比較する")
	effects.free()
	hostile_helper.free()
	helper.free()
	core.close()
	lab.free()
