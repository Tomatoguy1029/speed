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
	if not probe.has_method("friendly_buffer"):
		check(false, "W01の発射周期をネイティブランが所有する")
	else:
		for condition in [[1,1],[5,1],[5,3]]: await compare_frames(comparison, condition[0], condition[1])
	probe.close()
	print("[native_forward] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func compare_frames(comparison, level: int, division: int) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 631, "empty": true, "invincible": false})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	run.ship.setup(run.ship.ctx)
	run.state.enemy_aim = run.state.ship_pos
	run.cfg.world_tick_div = division
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
	core.start(631, run.enemies._next_id, run.pickups._gem_next_seq)
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
		var cycle := tick - 100
		var command := {"touch": true, "press": cycle == 0, "has_cursor": cycle >= 0 and cycle <= 8,
			"pen_release": cycle == 8, "pen": origin + Vector2(maxi(0,cycle)*30,0)}
		for key in command: input.set(key, command[key])
		var center := run.state.view_center
		var half := run.state.view_half
		var zoom := run.state.camera_zoom
		run.state.events.clear()
		run._play_tick(1.0/60.0)
		check(core.step_frame(1.0/60.0, command, center, half, zoom), "射撃も含めて一回の呼出しで更新する")
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
