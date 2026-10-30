## 味方弾の命中順・寿命・貫通と行再利用を本番処理へ照合する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
const DATA := preload("res://tools/content/build_native_data.gd")
const SHIP := preload("res://tests/native_ship.gd")
const COMBAT := preload("res://tests/native_combat.gd")
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
	if not probe.has_method("fire_shot"):
		check(false, "弾の生成と命中をネイティブランが所有する")
	else:
		for mode in ["pierce", "kill", "expiry", "reuse"]: await compare_shots(comparison, mode)
	probe.close()
	print("[native_projectiles] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func compare_shots(comparison, mode: String) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 763, "empty": true})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	run.ship.setup(run.ship.ctx)
	var definition: EnemyDef = run.enemies.def_of(&"drifter").duplicate(true)
	definition.hp = 3.0 if mode == "kill" else 1000.0
	var core = comparison.create_native()
	core.configure(DATA.compile_enemy(definition, run.cfg))
	core.configure_ship(values(run.cfg, SHIP.CONFIG_KEYS), values(run.state.stats, SHIP.STAT_KEYS))
	core.configure_combat(values(run.cfg, COMBAT.COMBAT_CONFIG), values(run.state.stats, COMBAT.COMBAT_STATS))
	var config := values(run.cfg, COMBAT.PICKUP_CONFIG)
	config.xp_bonus = run.spawn.current_phase().xp_bonus
	core.configure_pickups(config, values(run.state.stats, ["xp_mult", "xp_pickup_radius", "pickup_radius", "pickup_speed_mult"]))
	core.start(763, run.enemies._next_id, run.pickups._gem_next_seq)
	run.state.rng.seed = 763
	for position in [Vector2(60,0), Vector2(60,0), Vector2(100,0), Vector2(160,0), Vector2(200,0)]:
		run.enemies.spawn(definition, position)
		core.spawn_enemy(&"drifter", position)
	run.combat.rebuild_grid()
	core.rebuild_enemy_grid(run.cfg.grid_cell)
	var opts := {"speed": 720.0, "life": 0.7, "pierce_left": 2, "knock": 271.3, "visual_key": "weapon/forward", "weapon_id": &"forward"}
	if mode == "expiry": opts.life = 0.05
	if mode == "reuse": opts.life = 0.1
	run.projectiles.fire_shot(Vector2.ZERO, 0.0, 7.0, opts)
	check(core.fire_shot(Vector2.ZERO, 0.0, 7.0, opts), "弾を生成できる")
	check(not core.fire_shot(Vector2.ZERO, 0.0, 7.0, {"on_hit": func(): pass}), "未対応の命中処理を黙って捨てない")
	check(not core.fire_shot(Vector2.ZERO, 0.0, 7.0, {"cause": &"fire"}), "未対応の持続ダメージや外力を通常弾として受けない")
	for tick in 30:
		if mode == "reuse" and tick == 15:
			# 弾と敵の行を再利用しても、以前の命中IDを引き継がない。
			var old_id: int = run.enemies.table.id[0]
			run.enemies._release_row(0)
			core.remove_enemy(old_id)
			run.enemies.spawn(definition, Vector2(35,0))
			core.spawn_enemy(&"drifter", Vector2(35,0))
			run.combat.rebuild_grid()
			core.rebuild_enemy_grid(run.cfg.grid_cell)
			run.projectiles.fire_shot(Vector2.ZERO, 0.0, 7.0, opts)
			core.fire_shot(Vector2.ZERO, 0.0, 7.0, opts)
		run.state.events.clear()
		run.projectiles._update_friendly(1.0/60.0)
		check(core.step_projectiles(1.0/60.0), "弾を更新できる")
		var difference: String = comparison.difference(comparison.plain(snapshot(run.projectiles)), comparison.plain(core.projectiles_snapshot()))
		check(difference.is_empty(), "弾の位置・寿命・命中IDが一致する: %s %d %s" % [mode, tick, difference])
		difference = comparison.difference(comparison.snapshot(run, [], 0).enemies, core.enemies_snapshot())
		check(difference.is_empty(), "命中順・HP・押出しが一致する: %s %d %s" % [mode, tick, difference])
		check(comparison.difference(comparison.plain(run.state.events), comparison.plain(core.drain_events())).is_empty(), "弾の命中・撃破通知が一致する: " + mode)
		check(str(run.state.rng.state) == core.inspect().rng_state, "弾の撃破報酬の乱数が一致する")
	core.close()
	check(not core.step_projectiles(0.1), "終了したランの弾を更新しない")
	lab.free()
func snapshot(ps: ProjectileSystem) -> Array:
	var out: Array = []
	for row in ps.friend_alive.size():
		if ps.friend_alive[row] == 0: continue
		var ids: Array = ps.friend_hit[row].keys()
		ids.sort()
		out.append({"row": row, "kind": ps.friend_kind[row], "pos": ps.friend_pos[row], "vel": ps.friend_vel[row], "radius": ps.friend_r[row], "damage": ps.friend_dmg[row], "life": ps.friend_life[row], "age": ps.friend_age[row], "pierce_left": ps.friend_pierce_left[row], "hit_ids": ids, "angle": ps.friend_angle[row], "trail": ps.friend_trail[row]})
	return out
