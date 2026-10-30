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
	if not probe.has_method("pickup_buffer"):
		check(false, "撃破から報酬の生成までネイティブランが所有する")
	else:
		for mode in ["touch", "pierce", "bounce", "kill", "collect", "controls_locked", "encounter_protected", "no_hitstop", "scaled", "elite"]:
			await compare_contacts(comparison, mode)
		for mode in ["normal", "rehit", "bounce", "stop_input"]: await compare_frames(comparison, mode)
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
	if mode in ["scaled", "elite"]:
		if mode == "scaled": definition.id = &"scalable"
		definition.radius = 27.3
		run.cfg.enemy_hp_mult = 1.137
		run.cfg.enemy_armor_mult = 1.231
		run.cfg.character_scale = 0.713
		run.cfg.base_attack = 100000.0
	definition.hp = 6 if mode in ["kill", "collect", "no_hitstop", "scaled", "elite"] else 1000
	definition.armor = 1000 if mode == "bounce" else 2
	var core = comparison.create_native()
	check(core.configure(DATA.compile_enemy(definition, run.cfg)), "接触用の敵を準備する")
	check(core.configure_ship(values(run.cfg, SHIP.CONFIG_KEYS), values(run.state.stats, SHIP.STAT_KEYS)), "接触用の機体を準備する")
	check(core.configure_combat(values(run.cfg, COMBAT_CONFIG), values(run.state.stats, COMBAT_STATS)), "接触の編集値を準備する")
	var pickup_config := values(run.cfg, PICKUP_CONFIG)
	pickup_config.xp_bonus = run.spawn.current_phase().xp_bonus
	check(not core.start(932), "報酬が未接続の戦闘を開始しない")
	check(core.configure_pickups(pickup_config, values(run.state.stats, ["xp_mult", "xp_pickup_radius", "pickup_radius", "pickup_speed_mult"])), "ドロップの編集値を準備する")
	core.start(932, run.enemies._next_id, run.pickups._gem_next_seq)
	run.state.rng.seed = 932
	if mode in ["controls_locked", "encounter_protected"]:
		run.state.set(mode, true)
		check(core.set_run_guards({mode: true}), "接触中の保護を設定する")
	elif mode == "no_hitstop":
		run.state.hitstop_enabled = false
		check(core.set_run_guards({"hitstop_enabled": false}), "停止演出を無効にする")
	var p := run.state.ship_pos
	if mode in ["scaled", "elite"]:
		var before_rng = core.inspect().rng_state
		check(core.spawn_enemy(definition.id, p, {NodePath("size"): NAN}) == -1, "文字列以外の設定キーを拒否する")
		check(core.spawn_enemy(definition.id, p, {"size": NAN}) == -1 and core.spawn_enemy(definition.id, p, {"size": 0.0}) == -1, "不正な大きさを受け付けない")
		check(core.enemies_snapshot().is_empty() and core.inspect().rng_state == before_rng, "拒否した出現で個体・乱数を進めない")
	var positions := [Vector2(0, 40), Vector2(0, 40), Vector2(0, 10), Vector2(300, 0)]
	if mode == "kill":
		for i in 64: positions.append(Vector2(0, 40))
	for offset in positions:
		var options := {}
		if mode in ["scaled", "elite"]: options = {"elite": offset.y != 10, "vel": Vector2(12,-7), "size": definition.radius * (1.137 if offset.x == 0 else 0.853), "facing": 0.37}
		run.enemies.spawn(definition, p + offset, options)
		if options.is_empty(): core.spawn_enemy(definition.id, p + offset)
		else: core.spawn_enemy(definition.id, p + offset, options)
	check(comparison.difference(comparison.snapshot(run, [], 0).enemies, core.enemies_snapshot()).is_empty(), "出現時の個体の大きさ・強さ・向きが一致する: " + mode)
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
	if mode in ["controls_locked", "encounter_protected"]:
		for enemy in core.enemies_snapshot(): check(is_equal_approx(enemy.hp, definition.base_hp(run.cfg)), "保護期間は敵も傷つかない")
	if mode == "no_hitstop": check(run.state.kills > 0 and run.state.hitstop == 0, "撃破しても停止設定が無効なら止めない")
	check_buffers(core, run, definition)
	check(run.state.hitstop == core.combat_snapshot().hitstop, "ヒットストップが一致する: " + mode)
	# 同じ更新で再接触しても、接触待ち時間中は再び傷つけない。
	run.state.events.clear()
	run.combat.collide_ship(from, run.cfg.ship_radius, null)
	core.collide_ship(from, run.cfg.ship_radius)
	check(comparison.difference(comparison.snapshot(run, [], 0).enemies, core.enemies_snapshot()).is_empty(), "接触の待ち時間を保つ: " + mode)
	check(core.drain_events().is_empty() and run.state.events.is_empty(), "同じ接触を重複通知しない: " + mode)
	if mode == "collect":
		var gained := 0.0
		var collected_coins := 0
		for tick in 60:
			run.state.events.clear()
			run.pickups.tick(1.0/60.0, 1.0/60.0)
			check(core.step_pickups(1.0/60.0), "回収を世界時間で進める")
			for item in core.drain_collections():
				if item.kind == "gem": gained += item.value * run.state.stats.xp_gain_mult
				elif item.kind == "coin": collected_coins += 1
			check(comparison.difference(comparison.plain(pickup_snapshot(run)), comparison.plain(core.pickups_snapshot())).is_empty(), "吸引と回収の位置・残数が一致する")
			check(comparison.difference(comparison.plain(run.state.events), comparison.plain(core.drain_events())).is_empty(), "回収の通知順が一致する")
			check(gained == run.state.xp_gained and collected_coins == run.state.coins, "成長側へ渡す経験値と部品が一致する")
		check(gained > 0 and core.drain_collections().is_empty(), "回収結果を重複して渡さない")
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

func compare_frames(comparison, mode: String) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 932, "empty": true})
	var run: RunSimulation = lab.run
	run.ship.setup(run.ship.ctx)
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	var core = comparison.create_native()
	var definition: EnemyDef = run.enemies.def_of(&"drifter").duplicate(true)
	if mode == "rehit":
		definition.hp = 18.0
		run.state.stats.crit_chance = 0.0
	elif mode == "bounce":
		definition.hp = 1000.0
		definition.armor = 1000.0
	elif mode == "stop_input": run.cfg.ram_speed_ratio = 0.0
	core.configure(DATA.compile_enemy(definition, run.cfg))
	core.configure_ship(values(run.cfg, SHIP.CONFIG_KEYS), values(run.state.stats, SHIP.STAT_KEYS))
	core.configure_draw(values(run.cfg, SHIP.DRAW_CONFIG), values(run.state.stats, SHIP.DRAW_STATS))
	core.configure_combat(values(run.cfg, COMBAT_CONFIG), values(run.state.stats, COMBAT_STATS))
	var config := values(run.cfg, PICKUP_CONFIG)
	config.xp_bonus = run.spawn.current_phase().xp_bonus
	core.configure_pickups(config, values(run.state.stats, ["xp_mult", "xp_pickup_radius", "pickup_radius", "pickup_speed_mult"]))
	check(core.configure_frame({"world_tick_div": run.cfg.world_tick_div, "grid_cell": run.cfg.grid_cell, "trace_radius": run.cfg.trace_radius}), "更新順と世界時間の設定を渡す")
	core.start(932, run.enemies._next_id, run.pickups._gem_next_seq)
	run.state.rng.seed = 932
	var origin := run.state.ship_pos
	var positions := [Vector2.ZERO] if mode == "stop_input" else [Vector2(180, 0)] if mode == "rehit" else [Vector2(180, 0), Vector2(300, 0), Vector2(1200, 300)]
	for offset in positions:
		run.enemies.spawn(definition, origin + offset)
		core.spawn_enemy(&"drifter", origin + offset)
	run.combat.rebuild_grid()
	core.rebuild_enemy_grid(run.cfg.grid_cell)
	var input := Intent.new()
	run.input_source = func(): return input
	var gained := 0.0
	var saw_stop := false
	var saw_rehit := false
	var saw_bounce := false
	var saw_input_in_stop := false
	for tick in 150:
		var command := {"press": tick == 2, "touch": true, "has_cursor": tick <= 12, "pen_release": tick == 12, "pen": origin + Vector2(maxi(0, tick-2)*35, 0)}
		if mode == "rehit":
			var x := (tick-2)*90 if tick <= 6 else (10-tick)*90 if tick <= 10 else (tick-10)*90
			command.pen = origin + Vector2(x, 0)
		var starts_in_stop: bool = run.state.hitstop > 0 and not run.state.tracing and command.press
		for key in command: input.set(key, command[key])
		var center := run.state.view_center
		var half := run.state.view_half
		var zoom := run.state.camera_zoom
		run.state.events.clear()
		run._play_tick(1.0/60.0)
		check(core.step_frame(1.0/60.0, command, center, half, zoom), "所有状態を1回の呼出しで更新する")
		for item in core.drain_collections():
			if item.kind == "gem": gained += item.value * run.state.stats.xp_gain_mult
		var difference: String = comparison.difference(comparison.snapshot(run, [], tick).enemies, core.enemies_snapshot())
		if difference.is_empty(): difference = comparison.difference(comparison.plain(values(run.state, SHIP.STATE_KEYS)), comparison.plain(core.ship_snapshot()))
		if difference.is_empty(): difference = comparison.difference(comparison.plain(values(run.state, SHIP.DRAW_STATE)), comparison.plain(core.draw_snapshot()))
		if difference.is_empty(): difference = comparison.difference(comparison.plain(run.state.events), comparison.plain(core.drain_events()))
		check(difference.is_empty(), "描線→接触→撃破→回収の更新順が一致する %s tick=%d: %s" % [mode, tick, difference])
		check(core.inspect().sim_time == run.state.sim_time and core.inspect().time == run.state.time and core.inspect().world_time == run.state.world_time, "実時間と世界時間が一致する")
		check(str(run.state.rng.state) == core.inspect().rng_state, "全更新を通した乱数消費が一致する")
		check(gained == run.state.xp_gained, "全更新を通した回収量が一致する")
		check(core.combat_snapshot().hitstop == run.state.hitstop, "停止の開始・消費が一致する")
		saw_stop = saw_stop or run.state.hitstop > 0
		saw_input_in_stop = saw_input_in_stop or (starts_in_stop and run.state.drawing)
		for event in run.state.events:
			if event.type == &"text" and event.get("text", "") == "×2": saw_rehit = true
			if event.type == &"trace_end" and not event.completed: saw_bounce = true
		if not difference.is_empty(): break
	if mode == "bounce": check(saw_bounce, "突進の途中で反発して終了する")
	else: check(saw_stop and run.state.kills > 0 and gained > 0, "撃破・時間停止・回収を実際に通る: " + mode)
	if mode == "rehit": check(saw_rehit, "同じ突進で離れて戻り、2回目で撃破する")
	if mode == "stop_input": check(saw_input_in_stop, "ヒットストップ中にも描き始められる")
	core.close()
	lab.free()

func check_buffers(core, run: RunSimulation, definition: EnemyDef) -> void:
	var reference := InstanceBatch.new()
	var view := Rect2(-10000, -10000, 20000, 20000)
	for kind in ["gem", "coin"]:
		reference.begin()
		var color := Color("#b8a0ff") if kind == "gem" else Color("#ffd24a")
		var base := 5.0 if kind == "gem" else 6.0
		for item in pickup_snapshot(run).gems if kind == "gem" else pickup_snapshot(run).coins:
			var radius := base
			if kind == "gem" and item.value > 1.0: radius *= minf(pow(item.value, 0.2), 3.0)
			reference.add_upright(item.pos, radius, color)
		check(core.pickup_buffer(kind, base, color, view) == reference._buf.slice(0, reference._count * InstanceBatch.STRIDE), "回収物の表示データが一致する: " + kind)
	reference.begin()
	var table := run.enemies.table
	var scale := 1.0 / definition.visual_value("collision_scale", 1.0)
	for i in table.alive.size():
		if table.alive[i] != 0 and table.dead[i] == 0:
			reference.add(table.pos[i], table.facing[i]+PI/2.0, table.r[i]*scale, Color(1 if table.flash[i] > 0 else 0, 0, 0, 1))
	check(core.enemy_buffer(definition.id, scale, PI/2.0) == reference._buf.slice(0, reference._count * InstanceBatch.STRIDE), "敵の命中フラッシュと死亡の表示データが一致する")
	reference.free()
