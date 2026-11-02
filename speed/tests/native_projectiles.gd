## 味方弾の命中順・寿命・貫通と行再利用を本番処理へ照合する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
const DATA := preload("res://tools/content/build_native_data.gd")
const SHIP := preload("res://tests/native_ship.gd")
const COMBAT := preload("res://tests/native_combat.gd")
var failed := 0
var friend_finished := false
var friend_retry := false
var t37_retry := false
var t37_state_only := false
func check(ok: bool, label: String) -> void:
	if t37_state_only and not ("出生順と抽選消費がPCG32" in label or "次の20回を消費" in label): return
	if t37_retry and not ("PCG32" in label or "角度" in label or "速度" in label or "通常の元を生成順" in label or "初期化後の元" in label): return
	if friend_retry and not ("の位置・寿命・命中済みID" in label or "の命中順と敵HP" in label or label=="味方弾の確認が最後まで進んだ"): return
	if not ok:
		failed += 1
		push_error(label)
func values(object: Object, keys: Array) -> Dictionary:
	var out := {}
	for key in keys: out[key] = object.get(key)
	return out
func _ready() -> void:
	if "--cpp-t37" in OS.get_cmdline_user_args() or "--cpp-t37-fixes" in OS.get_cmdline_user_args() or "--cpp-t37-state-format" in OS.get_cmdline_user_args():
		t37_state_only = "--cpp-t37-state-format" in OS.get_cmdline_user_args()
		t37_retry = t37_state_only or "--cpp-t37-fixes" in OS.get_cmdline_user_args()
		await check_cpp_t37()
		print("[cpp_t37] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return

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
		for key in ["row","generation","cause","type","pierce","knock","shatter_depth","callback","callback_knock","callback_no_crit"]: row.erase(key)
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

class T37BirthFixture extends AttackKind:
	func spawn(ps: ProjectileSystem, records: Array) -> void:
		for data: Dictionary in records:
			if data.has("nested"):
				ps.emit_attack(&"scatter_hull",[data.nested])
				continue
			var row: int = ps._add_friend(data.get("kind",0),StringName(data.get("cause","shot")),data.position,data.velocity,data.get("radius",5.0),data.get("damage",1.0),data.get("life",1.0),data.get("pierce",false),data.get("pierce_left",0),Color.BLACK,data.get("no_crit",false),data.get("knock",250.0),0.0,0.0,-1,StringName(data.get("type","")),StringName(data.get("visual_key","weapon/forward")),StringName(data.get("weapon_id","")))
			for id in data.get("hit_ids",PackedInt64Array()): ps.friend_hit[row][id] = true
			ps.friend_shatter_depth[row] = data.get("shatter_depth",0)
			ps.friend_age[row] = data.get("age",0.0)
			if data.get("callback","none")=="interceptor":
				ps.friend_on_hit[row] = func(enemy, damage, impact):
					ps.combat.damage_enemy(enemy,damage,{"cause":&"interceptor","impact":impact,"no_crit":data.get("callback_no_crit",true),"knock":data.get("callback_knock",160.0)})
			ps.friend_dmg[row] = data.get("post_damage",data.get("damage",1.0))

func t37_compare(ps: ProjectileSystem, core, label: String) -> void:
	var expected := []
	for row in ps.friend_alive.size():
		if not ps.friend_alive[row]: continue
		var hits: Array = ps.friend_hit[row].keys()
		hits.sort()
		expected.append({"kind":ps.friend_kind[row],"pos":ps.friend_pos[row],"vel":ps.friend_vel[row],"radius":ps.friend_r[row],"damage":ps.friend_dmg[row],"life":ps.friend_life[row],"age":ps.friend_age[row],"pierce_left":ps.friend_pierce_left[row],"knock":ps.friend_knock[row],"hit_ids":hits,"shatter_depth":ps.friend_shatter_depth[row],"callback":"interceptor" if ps.friend_on_hit[row].is_valid() else "none"})
	var actual: Array = core.projectiles_snapshot()
	check(actual.size()==expected.size(),label+"の元と複製の件数が一致する")
	if actual.size()!=expected.size(): return
	for i in actual.size():
		for key in expected[i]:
			if key=="vel":
				var velocity: Vector2 = actual[i][key]
				var angle: float = absf(velocity.angle())
				check(is_zero_approx(angle) or (angle>=deg_to_rad(15.0)-0.0001 and angle<=deg_to_rad(45.0)+0.0001 and velocity.length()>=270.0-0.002 and velocity.length()<=330.0+0.002),label+"の複製が角度と速度の範囲を保つ")
			elif expected[i][key] is Vector2: check((expected[i][key] as Vector2).distance_to(actual[i][key])<0.002,label+"の位置が一致する")
			elif expected[i][key] is float: check(is_equal_approx(expected[i][key],actual[i][key]),label+"の威力・寿命・経過と倍率が一致する")
			else: check(expected[i][key]==actual[i][key],label+"の種類・命中集合・深さ・callbackが一致する")

func t37_normal_contract(core, level: int, definition: TraitDef) -> void:
	# 設計17.1のPCG32をseed737から進めた、通常生成16回の期待列。
	var split_at: Array = [[0,3,8],[0,3,8,9],[0,3,8,9,10,14],[0,3,8,9,10,14],[0,3,8,9,10,14]][level-1]
	var final_state: String = ["-3220606506977829253","3273026683270212063","-7467066158754631833","-7467066158754631833","-7467066158754631833"][level-1]
	var shots: Array = core.projectiles_snapshot()
	check(shots.size()==16+split_at.size()*2,"各段でPCG32の確率抽選に従って元と複製を出す")
	var cursor := 0
	for original in 16:
		if cursor>=shots.size(): return
		check(shots[cursor].pos==Vector2(original*20,0) and shots[cursor].damage==10.0,"通常の元を生成順に保持する")
		cursor += 1
		if not original in split_at: continue
		for side in [-1.0,1.0]:
			if cursor>=shots.size(): return
			var shot: Dictionary = shots[cursor]
			var angle: float = shot.vel.angle()*side
			check(shot.pos==Vector2(original*20,0) and is_equal_approx(shot.damage,10.0*float(definition.params.damage_by_level[level-1])),"複製は初期化後の元から位置と各段の威力を引き継ぐ")
			check(angle>=deg_to_rad(float(definition.params.angle_min))-0.0001 and angle<=deg_to_rad(float(definition.params.angle_max))+0.0001 and shot.vel.length()>=450.0-0.002 and shot.vel.length()<=550.0+0.002,"通常生成の左右の角度と速度が定義の範囲に収まる")
			cursor += 1
	check(core.inspect().rng_state==final_state,"各段の出生順と抽選消費がPCG32の期待列に一致する")

func t37_fixture_bridge(config: GameConfig):
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var records: Dictionary = builder.chase_records(ContentManager.enemies[&"drifter"],config)
	# 既存split検査と同じく、入れ子と上限は抽選成功を固定して境界だけを見る。
	for row: Dictionary in records.DuplicatorDefinition: row.chance = 1.0
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	check(bridge.configure(schema.write_content(records,schema.sha256("複製の入れ子と上限".to_utf8_buffer())),{"api_version":1,"run_id":937,"mode":1,"stage_id":"T37","profile":{},"settings":{}}).ok,"入れ子と上限の固定場面を生成する")
	check(bridge.start(737,{"position":Vector2(-900,0)}).ok,"複製の固定場面を始める")
	bridge.collect_frame()
	return bridge

func check_cpp_t37() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	for field in ["planet_radius","moon_count","meteor_count","iron_count","saw_count"]: config.set(field,0)
	config.start_radius = 900.0
	config.base_crit_chance = 0.0
	var stage := RuntimeStage.new()
	stage.index = 87
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/run_T37"
	var builder = load("res://tools/content/build_run_content.gd")
	check(builder.build(stage,config,output,"複製の全段と表示".sha256_text())==OK,"複製の全段の実効値と資源を生成する")
	var path := output.path_join("stage_87.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":737},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"複製の通常のランと表示を用意する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	var initial: Dictionary = bridge.checkpoint()
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	for level in range(1,config.trait_max_stacks+1):
		if t37_state_only and level==2: continue
		bridge.restore(initial.value)
		bridge.collect_frame()
		await lab.reset({"seed":737,"empty":true,"config":{"planet_radius":0.0}})
		var run: RunSimulation = lab.run
		run.field.bodies.clear()
		run.loadout.reset_loadout()
		run.loadout.grant(&"trait",&"T37",level)
		check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T37","levels":level}).ok,"生成した複製を各段で取得する")
		run.state.rng.state = int(core.inspect().rng_state)
		for n in 16:
			var pos := Vector2(n*20,0)
			var opts := {"speed":500.0,"life":1.0,"pierce_left":2,"knock":137.0,"weapon_id":"W01","visual_key":"weapon/forward"}
			core.fire_shot(pos,0.0,10.0,opts)
		t37_normal_contract(core,level,ContentManager.definition(&"traits",&"T37"))
		if level==config.trait_max_stacks and not t37_retry:
			bridge.command("set_ui_overlay",{"active":false})
			var presentation: RunPresentation = session.view.get_node("RunPresentation")
			presentation._present_cpp(0.01)
			check(presentation.frame_view._duplicator_visual!=null and not presentation.frame_view._duplicator_visual.splits.is_empty(),"複製の光を実際の生成通知から通常の表示へ渡す")
			var age: float = presentation.frame_view._duplicator_visual.splits[0].age
			presentation.frame_view.update_effects(bridge.read_frame().value,0.2)
			check(presentation.frame_view._duplicator_visual.splits[0].age==age,"世界時計が止まる間は複製の光も止める")
			var before: Array = core.projectiles_snapshot()
			bridge.command("dev_remove_trait",{"id":"T37"})
			check(core.projectiles_snapshot()==before,"特性を外しても生成済みの複製は自然寿命まで残す")
			presentation._present_cpp(0.01)
			check(presentation.frame_view._duplicator_visual==null,"解除した複製の表示を片付ける")
	bridge.release_checkpoint(initial.value)
	session.free()
	var fixture = t37_fixture_bridge(config)
	core = fixture._core
	await lab.reset({"seed":737,"empty":true,"config":{"planet_radius":0.0}})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.loadout.reset_loadout()
	var definition: TraitDef = ContentManager.definition(&"traits",&"T37").duplicate(true)
	definition.params.chance_by_level = [1.0,1.0,1.0,1.0,1.0]
	run.state.traits[&"T37"] = 5
	run.loadout._sync_behavior(false,&"T37",definition,5)
	run.projectiles.register_attack(&"scatter_hull",T37BirthFixture.new())
	fixture.command("dev_remove_weapon",{"id":"W01"})
	fixture.command("dev_grant_equipment",{"kind":"trait","id":"T37","levels":5})
	run.state.rng.state = int(core.inspect().rng_state)
	var records := [{"position":Vector2(0,0),"velocity":Vector2(300,0),"damage":1.0,"post_damage":9.0,"life":0.8,"age":0.1,"hit_ids":PackedInt64Array([99]),"shatter_depth":3},
		{"nested":[{"position":Vector2(100,0),"velocity":Vector2(300,0),"post_damage":7.0,"callback":"interceptor","callback_knock":173.0,"callback_no_crit":true},{"position":Vector2(200,0),"velocity":Vector2(300,0),"kind":2,"cause":"saw","pierce":true}]},
		{"position":Vector2(300,0),"velocity":Vector2(300,0),"kind":1,"cause":"hullDebris","post_damage":11.0,"pierce":true}]
	run.projectiles.emit_attack(&"scatter_hull",[records])
	check(fixture.command("dev_friend_births",{"births":records}).ok,"入れ子の生成列を初期化してから完了する")
	t37_compare(run.projectiles,core,"入れ子と初期化完了")
	check(core.inspect().rng_state=="2861193922729689715","入れ子は内側2件→外側2件のPCG32抽選を消費する")
	check(core.projectiles_snapshot().size()==12,"4件の元から各2件を複製し、複製を再び複製しない")
	for shot: Dictionary in core.projectiles_snapshot():
		if shot.callback=="interceptor": check(shot.callback_knock==173.0 and shot.callback_no_crit,"callbackの型と値を複製へ引き継ぐ")
	var held: Dictionary = fixture.checkpoint()
	var state: Array = core.projectiles_snapshot()
	core.step_projectiles(0.1)
	var advanced: Array = core.projectiles_snapshot()
	check(fixture.restore(held.value).ok and core.projectiles_snapshot()==state,"命中集合・残り寿命・経過・深さ・callbackの値へ復帰する")
	core.step_projectiles(0.1)
	check(core.projectiles_snapshot()==advanced,"復帰後も元と複製が同じ飛行を再現する")
	fixture.release_checkpoint(held.value)
	core.step_projectiles(2.0)
	run.projectiles._update_friendly(2.0)
	run.state.rng.state = int(core.inspect().rng_state)
	check(core.projectiles_snapshot().is_empty(),"寿命が来た元と複製をすべて回収する")
	run.projectiles.emit_attack(&"scatter_hull",[records])
	fixture.command("dev_friend_births",{"births":records})
	t37_compare(run.projectiles,core,"回収後の行再利用")
	check(core.inspect().rng_state=="-7467066158754631833","回収後も同じ出生順でPCG32の次の20回を消費する")
	core.step_projectiles(2.0)
	fixture.command("dev_remove_trait",{"id":"T37"})
	var filling := []
	for n in 217: filling.append({"position":Vector2(n,0),"velocity":Vector2.ZERO,"life":1.0})
	check(fixture.command("dev_friend_births",{"births":filling}).ok,"通常の元の弾で上限直前まで埋める")
	fixture.command("dev_grant_equipment",{"kind":"trait","id":"T37","levels":5})
	check(fixture.command("dev_friend_reserve",{"count":1,"release":false}).ok,"未処理の飛ぶ攻撃を共通の上限へ予約する")
	var random: String = core.inspect().rng_state
	fixture.command("dev_friend_births",{"births":[{"position":Vector2.ZERO,"velocity":Vector2.RIGHT}]})
	check(core.projectiles_snapshot().size()==218 and core.inspect().rng_state==random,"予約分を含めて残り1枠なら抽選せず複製を出さない")
	check(fixture.command("dev_friend_reserve",{"count":1,"release":true}).ok,"処理済みの予約を一度だけ解放する")
	core.step_projectiles(2.0)
	fixture.command("dev_remove_trait",{"id":"T37"})
	fixture.command("dev_friend_births",{"births":filling})
	fixture.command("dev_grant_equipment",{"kind":"trait","id":"T37","levels":5})
	fixture.command("dev_friend_births",{"births":[{"position":Vector2.ZERO,"velocity":Vector2.RIGHT}]})
	check(core.projectiles_snapshot().size()==220,"残り2枠なら同じ生成で2件を複製する")
	core.step_projectiles(2.0)
	fixture.command("dev_remove_trait",{"id":"T37"})
	var debris := []
	for n in 198: debris.append({"position":Vector2(n,0),"velocity":Vector2.ZERO,"kind":1,"cause":"hullDebris"})
	fixture.command("dev_friend_births",{"births":debris})
	fixture.command("dev_grant_equipment",{"kind":"trait","id":"T37","levels":5})
	fixture.command("dev_friend_births",{"births":[{"position":Vector2.ZERO,"velocity":Vector2.RIGHT,"kind":1,"cause":"hullDebris"}]})
	check(core.projectiles_snapshot().size()==200,"星屑の残り1枠では複製中にも200件の上限を守る")
	random = core.inspect().rng_state
	fixture.command("dev_friend_births",{"births":[{"position":Vector2.ZERO,"velocity":Vector2.RIGHT,"kind":1,"cause":"hullDebris"}]})
	check(core.projectiles_snapshot().size()==201 and core.inspect().rng_state==random,"星屑が満杯なら元の生成後も複製の抽選を使わない")
	fixture.dispose()
	lab.free()
	await get_tree().process_frame
