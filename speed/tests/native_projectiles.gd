## 味方弾の命中順・寿命・貫通と行再利用を本番処理へ照合する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
const DATA := preload("res://tools/content/build_native_data.gd")
const SHIP := preload("res://tests/native_ship.gd")
const COMBAT := preload("res://tests/native_combat.gd")
var failed := 0
var friend_finished := false
var friend_retry := false
func check(ok: bool, label: String) -> void:
	if friend_retry and not ("の位置・寿命・命中済みID" in label or "の命中順と敵HP" in label or label=="味方弾の確認が最後まで進んだ"): return
	if not ok:
		failed += 1
		push_error(label)
func values(object: Object, keys: Array) -> Dictionary:
	var out := {}
	for key in keys: out[key] = object.get(key)
	return out
func _ready() -> void:
	if "--cpp-friend-shot" in OS.get_cmdline_user_args() or "--cpp-friend-shot-fixes" in OS.get_cmdline_user_args():
		friend_retry = "--cpp-friend-shot-fixes" in OS.get_cmdline_user_args()
		await check_cpp_friend_shot()
		check(friend_finished,"味方弾の確認が最後まで進んだ")
		print("[cpp_friend_shot] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	var comparison = COMPARE.new()
	var probe = comparison.create_native()
	if not probe.has_method("burst_debris"):
		check(false, "弾の生成と命中をネイティブランが所有する")
	else:
		for mode in ["pierce", "kill", "expiry", "reuse", "debris", "split", "split_reuse"]: await compare_shots(comparison, mode)
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
	run.cfg.hull_debris_life = 0.2
	run.cfg.corpse_trail_points = 6
	var split := {}
	if mode.begins_with("split"):
		var trait_def: TraitDef = ContentManager.definition(&"traits", &"T37").duplicate(true)
		trait_def.params.chance_by_level = [1.0]
		trait_def.params.max = 8
		trait_def.params.generations = 2
		run.state.traits[&"T37"] = 1
		run.loadout._sync_behavior(false, &"T37", trait_def, 1)
		split = trait_def.params.duplicate(true)
		split.chance = split.chance_by_level[0]
		split.damage = split.damage_by_level[0]
	check(core.configure_projectiles(values(run.cfg, ["hull_debris_life", "hull_debris_knock", "corpse_trail_points"]), split), "破片と分裂の編集値を渡す")
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
	run.state.events.clear()
	core.drain_events()
	if mode == "split_reuse":
		run.projectiles.fire_shot(Vector2.ZERO, 0.0, 0.0, {"life": 0.0})
		core.fire_shot(Vector2.ZERO, 0.0, 0.0, {"life": 0.0})
	if mode == "debris":
		run.projectiles.burst_debris(Vector2(40,0), 5, 150.0, 4.0, Color.RED, run.enemies.table.id[0])
		check(core.burst_debris(Vector2(40,0), 5, 150.0, 4.0, Color.RED, run.enemies.table.id[0]), "破片を同じ乱数で生成する")
	run.projectiles.fire_shot(Vector2.ZERO, 0.0, 7.0, opts)
	check(core.fire_shot(Vector2.ZERO, 0.0, 7.0, opts), "弾を生成できる")
	check(not core.fire_shot(Vector2.ZERO, 0.0, 7.0, {"on_hit": func(): pass}), "未対応の命中処理を黙って捨てない")
	check(not core.fire_shot(Vector2.ZERO, 0.0, 7.0, {"cause": &"fire"}), "未対応の持続ダメージや外力を通常弾として受けない")
	check(comparison.difference(comparison.plain(run.state.events), comparison.plain(core.drain_events())).is_empty(), "発射・破片の生成通知が一致する")
	var saw_duplicate := false
	var saw_trail := false
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
		for event in run.state.events:
			if event.type == &"duplicate": saw_duplicate = true
			if event.type == &"debris_trail": saw_trail = true
		check(str(run.state.rng.state) == core.inspect().rng_state, "弾の撃破報酬の乱数が一致する")
	if mode.begins_with("split"): check(saw_duplicate, "連鎖する弾の生成が実際に通る")
	if mode == "debris": check(saw_trail, "破片の終了時の航跡が実際に通る")
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

func friend_states(run: RunSimulation, core, comparison, label: String, id_map: Dictionary, source_rows: Array, check_snapshot: bool) -> void:
	var old_shots := snapshot(run.projectiles)
	for row: Dictionary in old_shots:
		row.erase("row")
		row.hit_ids = row.hit_ids.map(func(id): return id_map[id])
	var current: Array = core.projectiles_snapshot()
	for row: Dictionary in current:
		for key in ["row","generation","cause","type","pierce"]: row.erase(key)
	var diff: String = comparison.difference(comparison.plain(old_shots),comparison.plain(current))
	if check_snapshot: check(diff.is_empty(),label+"の位置・寿命・命中済みID: "+diff)
	var hp := []
	for row: Dictionary in core.enemies_snapshot(): hp.append(row.hp)
	var old := []
	for i: int in source_rows: old.append(run.enemies.table.hp[i])
	check(comparison.difference(comparison.plain(old),comparison.plain(hp)).is_empty(),label+"の命中順と敵HP")

func check_cpp_friend_shot() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 900.0
	config.planet_radius = 100.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	var stage := RuntimeStage.new()
	stage.index = 85
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter","shield"])
	var output := "res://.content/dev/run_friend_shot"
	var builder = load("res://tools/content/build_run_content.gd")
	var built: Error = builder.build(stage,config,output,"味方弾の地形・貫通・盾".sha256_text())
	check(built==OK,"味方弾の型と当たり定義を生成する")
	if built!=OK: return
	var path := output.path_join("stage_85.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":763},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"味方弾の通常の状態・表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	bridge.command("dev_ship_motion",{"position":Vector2(-900,0),"velocity":Vector2.ZERO})
	var initial: Dictionary = bridge.checkpoint()
	var comparison = COMPARE.new()
	for kind in ["pierce","history","expiry","terrain","shield"]:
		bridge.restore(initial.value)
		var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
		add_child(lab)
		await lab.reset({"seed":763,"empty":true,"field":{"terrain":true,"rocks":false,"gimmicks":false},"invincible":false,
			"config":{"start_radius":900.0,"planet_radius":100.0}})
		var run: RunSimulation = lab.run
		var from := Vector2(-900,400)
		var angle := 0.0
		var positions := [from+Vector2(60,0),from+Vector2(100,0),from+Vector2(160,0),from+Vector2(200,0)]
		var definition := run.enemies.def_of(&"drifter")
		var opts := {"speed":720.0,"life":0.7,"pierce_left":2,"knock":0.0,"visual_key":"weapon/forward","weapon_id":&"W01"}
		var steps := [0.05,0.05,0.05,0.05,0.05]
		if kind=="history":
			positions = [from+Vector2(5,0)]
			opts.speed = 100.0
			steps = [0.01,0.01]
		elif kind=="expiry":
			positions = [from+Vector2(20,0)]
			opts.life = 0.05
			steps = [0.1]
		elif kind=="terrain":
			from = Vector2(-200,0)
			positions = [Vector2(-150,0),Vector2(150,0)]
			opts.speed = 800.0
			steps = [0.5]
		elif kind=="shield":
			from = Vector2(-400,300)
			positions = [Vector2(-600,300)]
			definition = run.enemies.def_of(&"shield")
			angle = PI
			opts.speed = 800.0
			steps = [0.25]
		var source_rows := []
		var id_map := {}
		for at: Vector2 in positions:
			var row := run.enemies.spawn(definition,at)
			source_rows.append(row)
			var created: Dictionary = bridge.command("dev_spawn",{"definition_id":String(definition.id),"position":at})
			id_map[run.enemies.table.id[row]] = created.value
		var full_hp: Array = core.enemies_snapshot().map(func(row): return row.hp)
		run.combat.rebuild_grid()
		run.projectiles.fire_shot(from,angle,1.0,opts)
		check(core.fire_shot(from,angle,1.0,opts),"W01の武器IDと編集値から味方弾を生成する: "+kind)
		if kind=="pierce" and not friend_retry:
			var presentation: RunPresentation = session.view.get_node("RunPresentation")
			presentation._present_cpp(0.0)
			var frame: Dictionary = bridge.read_render(Rect2(-1600,-100,1500,1000)).value
			check(presentation.frame_view.apply_frame(frame),"味方弾の位置と向きを通常の表示へ渡す")
			var shown := false
			for visual: Dictionary in session.cpp_resources.visuals:
				if visual.role==2:
					var batch: InstanceBatch = presentation.frame_view.batches.get(visual.id)
					shown = batch!=null and batch.multimesh.visible_instance_count>0
			check(shown,"通常のドットの味方弾を表示する")
			await get_tree().process_frame
		var step_index := 0
		for dt: float in steps:
			run.projectiles._update_friendly(dt)
			core.step_projectiles(dt)
			friend_states(run,core,comparison,kind,id_map,source_rows,not friend_retry or kind=="history" or (kind=="pierce" and step_index in [1,2]))
			step_index += 1
		if kind=="pierce":
			var enemies: Array = core.enemies_snapshot()
			check(enemies[0].hp<full_hp[0] and enemies[1].hp<full_hp[1] and enemies[2].hp<full_hp[2] and enemies[3].hp==full_hp[3],"貫通回数を使い切った弾は次の敵へ届かない")
		elif kind=="terrain":
			var enemies: Array = core.enemies_snapshot()
			check(enemies[0].hp<full_hp[0] and enemies[1].hp==full_hp[1] and core.projectiles_snapshot().is_empty(),"地形の手前だけ命中し奥の敵へ届かない")
		elif kind=="shield":
			check(core.projectiles_snapshot().is_empty() and core.hostiles_snapshot().size()==1 and run.projectiles.hostile_slots.live==1,"盾の正面で貫通弾も止まり危険な反射弾へ変わる")
		elif kind=="history" and not friend_retry:
			var held: Dictionary = bridge.checkpoint()
			var before: Array = core.projectiles_snapshot()
			core.step_projectiles(0.1)
			var after: Array = core.projectiles_snapshot()
			bridge.restore(held.value)
			check(core.projectiles_snapshot()==before,"貫通弾の命中済みIDと残り回数を復元する")
			core.step_projectiles(0.1)
			check(core.projectiles_snapshot()==after,"保持点から同じ飛行と一度だけの命中を再現する")
			bridge.release_checkpoint(held.value)
		lab.free()
	if friend_retry:
		bridge.release_checkpoint(initial.value)
		session.free()
		friend_finished = true
		return
	# 同じ本体の複数部位を通っても、ダメージと命中履歴は本体IDで一度だけ。
	bridge.restore(initial.value)
	var parent: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(-650,400)}).value
	var part: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(-750,400)}).value
	bridge.command("dev_enemy_combat",{"entity_id":part,"damage_target":parent})
	var full_hp: Array = core.enemies_snapshot().map(func(row): return row.hp)
	core.fire_shot(Vector2(-900,400),0.0,1.0,{"speed":1000.0,"life":1.0,"pierce_left":3,"weapon_id":&"W01"})
	core.step_projectiles(0.3)
	var enemies: Array = core.enemies_snapshot()
	var live: Array = core.projectiles_snapshot()
	check(is_equal_approx(enemies[0].hp,full_hp[0]-1.0) and enemies[1].hp==full_hp[1] and live.size()==1 and live[0].hit_ids==[parent],"部位と本体への重複命中を本体IDで避ける")
	var weapon_seen := false
	for event: Dictionary in core.drain_events():
		if event.type==&"combat_damage" and event.get("weapon_id")==1: weapon_seen = true
	check(weapon_seen,"味方弾の武器IDを共通のダメージ記録へ渡す")
	bridge.release_checkpoint(initial.value)
	session.free()
	friend_finished = true
