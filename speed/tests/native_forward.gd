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
func compare_frames(comparison, level: int, division: int, guarded := false, spawning := false, budgeting := false, enemy_type: StringName = &"drifter") -> void:
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
	var definition: EnemyDef = run.enemies.def_of(enemy_type).duplicate(true)
	if enemy_type == &"drifter": definition.speed = 0.0
	var core = comparison.create_native()
	if not core.configure(DATA.compile_enemy(definition, run.cfg)):
		check(false,"比較する敵の行動をネイティブへ読み込む: " + String(enemy_type))
		core.close()
		lab.free()
		return
	if enemy_type == &"biter":
		check(core.configure_bite_zone(DATA.compile_bite_zone(load("res://.content/attack_visuals.res"))),"噛みつきの範囲判定を準備する")
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
		phase.wave_interval = 0.05 if division == 3 else 0.37
		phase.wave_type = &"" if division == 3 else enemy_type
		phase.mix = {String(enemy_type): 1.0}
		stage.phases = [phase]
		if budgeting:
			phase.attack_budget = 0
			for setting in [[0.8,3],[1.6,1],[2.4,0],[3.6,2]]:
				var next: PhaseDef = phase.duplicate(true)
				next.id = StringName("予算%d" % stage.phases.size())
				next.start = setting[0]
				next.attack_budget = setting[1]
				stage.phases.append(next)
		var clip := RuntimeClip.new()
		clip.time = 0.6
		clip.length = 1.2
		clip.groups = 1
		clip.interval = 0.5
		clip.prepared = [{"layouts":[{"weight":1.0,"value":-1.0,"markers":[{"type":enemy_type,"pos":Vector2.ZERO,"rot":0.0}]}],"entries":[{"weight":1.0,"pos":Vector2(0,-700),"rot":PI}]}]
		stage.clips = [clip]
		run.state.stage = stage
		run.enemies.definitions[enemy_type] = definition
		check(core.configure_spawn_timeline(DATA.compile_spawn_timeline(stage,run.cfg)), "フレーム比較の出現条件を生成する")
		check(core.configure_population(values(run.cfg, ["spawn_recycle_scale", "spawn_region_cap", "spawn_margin", "field_radius", "planet_radius"])), "出現位置の編集値を渡す")
		check(core.configure_refill(values(run.cfg, ["spawn_total_cap", "spawn_refill_time"])), "フレームで使う補充を準備する")
		check(core.configure_clips(DATA.compile_spawn_clips(stage,run.cfg)), "フレームで使うクリップを準備する")
	if budgeting:
		run.state.lab_mode = false
		run.spawn._sync_attack_budget(run.spawn.current_phase())
		check(core.set_attack_budget_mode(true,true), "時間帯の予算と世界時計を有効にする")
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
		core.spawn_enemy(enemy_type, origin + offset)
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
	var empty_wave_clip := false
	var budget_helper = load("res://tests/native_attack_budget.gd").new()
	var zone_helper = load("res://tests/native_bite_zone.gd").new()
	zone_helper.comparison = comparison
	var bite_seen := false
	var permitted := 0
	var denied := 0
	for tick in 360:
		if spawning:
			run.options.auto_spawn = budgeting or tick < 250 or tick >= 280
			var blocked := tick >= 150 and tick < 200
			run.projectiles.director.guard = {"until": INF} if blocked else {}
			check(core.set_population_mode(run.options.auto_spawn, false, blocked and not budgeting), "実験場の自動補充と出現待機を渡す")
		if budgeting:
			check(core.set_attack_guard(tick >= 150 and tick < 200,INF),"出現にも攻撃待機を反映する")
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
		if budgeting and tick % 12 == 0:
			for row in run.enemies.table.alive.size():
				if not run.enemies.table.alive[row] or run.enemies.table.dead[row]: continue
				var id: int = run.enemies.table.id[row]
				var owner := "比較:%d" % id
				var accepted: bool = run.projectiles.director.request(owner,["beam"],row,id,0.3,0.0,1.0)
				check(core.request_attack(owner,PackedStringArray(["beam"]),id,0.3,0.0,1.0) == accepted,"時間帯ごとの要求が一致する")
				if accepted: permitted += 1
				else: denied += 1
				break
		if run.state.phase == RunState.Phase.PLAY: run._play_tick(1.0/60.0)
		check(core.step_frame(1.0/60.0, command, center, half, zoom), "射撃も含めて一回の呼出しで更新する")
		if budgeting:
			check(comparison.difference(budget_helper.snapshot(run.projectiles.director),core.attack_budget_snapshot()).is_empty(),"攻撃枠の時計と寿命を停止・間引き・撃破に合わせる")
		if spawning:
			check(run.spawn._spawn_acc == core.refill_snapshot().accumulator and run.spawn._wave_t == core.refill_snapshot().wave_time, "補充を停止と世界時間の間引きに合わせる")
		if guarded and tick in [65,205]: check(not run.state.drawing, "操作ロック中は描線入力を受けない")
		check(run.state.phase == core.inspect().phase, "停止と再開の状態が一致する")
		check(is_equal_approx(run.state.time, core.inspect().time) and is_equal_approx(run.state.sim_time, core.inspect().sim_time), "停止中は両方の時計が止まる")
		if guarded and division == 1 and tick in [60,80,95,100,160,200,220]:
			var hurt := false
			for event in run.state.events: hurt = hurt or event.type == &"hurt"
			check(hurt == (tick >= 100), "保護中の接触と解除後の被弾を実際に通る tick%d" % tick)
		var difference: String = comparison.difference(comparison.snapshot(run, [], tick).enemies, core.enemies_snapshot())
		if difference.is_empty(): difference = comparison.difference(comparison.plain(helper.snapshot(run.projectiles)), comparison.plain(core.projectiles_snapshot()))
		if difference.is_empty(): difference = comparison.difference(comparison.plain(hostile_helper.snapshot(run.projectiles)), comparison.plain(core.hostiles_snapshot()))
		if difference.is_empty(): difference = comparison.difference(comparison.plain(values(run.state, SHIP.STATE_KEYS)), comparison.plain(core.ship_snapshot()))
		if difference.is_empty(): difference = comparison.difference(comparison.plain(run.state.events), comparison.plain(core.drain_events()))
		if difference.is_empty(): difference = comparison.difference({"elapsed": weapon._t, "recoil": weapon.recoil}, core.forward_snapshot())
		if enemy_type == &"biter":
			if difference.is_empty(): difference = comparison.difference(zone_helper.hazard_snapshot(run.projectiles),comparison.plain(core.hazards_snapshot()))
			bite_seen = bite_seen or run.projectiles.hazard_count() > 0
			var rows_by_id := {}
			for row in run.enemies.table.alive.size():
				if run.enemies.table.alive[row]: rows_by_id[run.enemies.table.id[row]] = row
			for state in core.enemy_motion_snapshot():
				if not rows_by_id.has(state.id): continue
				var row: int = rows_by_id[state.id]
				for key in ["mode","timer","charge","fire_t"]:
					check(run.enemies.table.get(key)[row] == state[key],"噛みつきの予告と回復の状態が一致する: " + key)
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
			if spawning and division == 3 and event.type == &"clip_group" and run.spawn._wave_t == 0.0 and run.enemies.count() < float(run.spawn.target().pop):
				empty_wave_clip = true
			if event.type == &"weapon_fire": fired += 1
			if event.type == &"hit" and event.cause == &"shot": shot_hits += 1
		if not difference.is_empty(): break
	if budgeting: check(permitted > 0 and denied > 0,"時間帯の予算による許可と待機を両方通る")
	if enemy_type == &"biter": check(bite_seen,"実際の敵が噛みつきの判定を発生させる")
	zone_helper.free()
	budget_helper.free()
	if spawning and division == 3: check(empty_wave_clip, "出現種類のない波の更新と同時にクリップを実際に出す")
	check(fired >= 2 and shot_hits > 0, "W01の発射と命中を実際に通る")
	check(buffer_checked, "発射中の弾の表示データを実際に比較する")
	effects.free()
	hostile_helper.free()
	helper.free()
	core.close()
	lab.free()
