## 敵の技・構成員生成は通常出現の上限でも成立し、通常補充は止まる。
extends Node

var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("[enemy_generated_spawns] " + label)

func _ready() -> void:
	var stage = load("res://tools/content/build_runtime_stage.gd").compile(ContentManager.stage(4))
	var phase := PhaseDef.new()
	phase.pop_from = 2
	phase.pop_to = 2
	phase.rate = 100
	phase.mix = {&"drifter": 1.0}
	stage.phases = [phase]
	stage.clips.clear()
	stage.zako_curves.clear()
	var cfg := ContentManager.base.duplicate(true) as GameConfig
	for key in ["moon_count", "meteor_count", "iron_count", "saw_count"]: cfg.set(key, 0)
	cfg.density_mult = 1.0
	cfg.spawn_total_cap = 1.0
	var capture := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture = arg.trim_prefix("--capture=")
	var session := RunManager.create_session(self, {"lab": true, "seed": 42, "stage": stage, "config": cfg}, not capture.is_empty())
	session.auto_step = false
	var m := session.sim.enemies
	m.field.bodies.clear()
	m.field.planet.pos = Vector2(1e7, 1e7)
	m.field.planet.r = 0.0
	m.field.refresh_bodies()
	m.state.ship_pos = Vector2.ZERO
	m.state.view_center = Vector2.ZERO
	for population in [2, 5]:
		_fill(m, population)
		_check_split(session.sim)
		_fill(m, population)
		_check_deferred(m)
		_fill(m, population)
		_check_cepheus(session.sim)
		_fill(m, population)
		_check_ruler(m)
		_fill(m, population)
		_check_members(m)
		_check_normal(session.sim)
	_check_refill_family(session.sim, phase)
	_fill(m, 5)
	_check_hydra(session.sim)
	if not capture.is_empty():
		m.clear_all()
		m.spawn(m.def_of(&"cepheus"), Vector2(-300, -100))
		for step in 70: m.tick(0.02, 0.02)
		var ruler := m.spawn(m.def_of(&"ruler"), Vector2(250, 60))
		m.behavior(&"ruler")._split_ruler(ruler)
		var split := m.spawn(m.def_of(&"splitter"), Vector2(0, 150))
		session.sim.combat.kill_enemy(split)
		m._flush_new()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(capture) == OK, "描画付きの生成結果を保存")
	session.free()
	await get_tree().process_frame
	print("[enemy_generated_spawns] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func _fill(m: EnemySystem, population: int) -> void:
	m.clear_all()
	m.projectiles.clear_hostile()
	for k in population: m.spawn(m.def_of(&"drifter"), Vector2(k * 10, 0))
	check(m.ctx.spawn.count_population(false) >= m.ctx.spawn.target().pop, "通常キャップ到達・超過の前提")

func _check_split(run: RunSimulation) -> void:
	var m := run.enemies
	var source := m.def_of(&"splitter")
	var row := m.spawn(source, Vector2(100, 0), {"attack_priority": 4.0})
	run.combat.kill_enemy(row)
	m.cleanup()
	# 親の行を先に再利用しても、撃破時に確定した分裂は成立する。
	m.spawn(m.def_of(&"drifter"), Vector2.ZERO)
	m._flush_new()
	var children: Array = []
	for i in m.behavior(&"chase").rows():
		if m.table.type[i] == &"splitling": children.append(i)
	check(children.size() == int(source.params.death_split), "撃破時に既定数へ分裂")
	for child in children:
		check(m.table.attack_priority[child] == 4.0 and m.table.guard[child] == float(source.params.split_guard), "分裂体の優先度と保護時間を維持")
	var before := m.count()
	m._flush_new()
	check(m.count() == before, "予約を二重に実行しない")
	var budding := source.duplicate(true) as EnemyDef
	budding.params.max_buds = 2
	budding.params.bud_interval = 0.1
	row = m.spawn(budding, Vector2(150, 0))
	for step in 5:
		m.behavior(&"split").step(row, 0.1)
		m._flush_new()
	check(m.table.buds[row] == 2 and m.count() == before + 3, "生存中の増殖は既存max_budsまで")

func _check_deferred(m: EnemySystem) -> void:
	var before := m.count()
	# 同じ分裂体の別IDでも、行動由来の予約の意味は変わらない。
	var child := m.def_of(&"splitling").duplicate(true) as EnemyDef
	child.id = &"generated_spawn_fixture"
	m.spawn_later(child, Vector2.ZERO, {"guard": 0.5})
	m._flush_new()
	check(m.count() == before + 1, "遅延生成の成立を特定の敵IDへ依存させない")
	m.spawn_later(child, Vector2.ZERO)
	m.clear_all()
	m._flush_new()
	check(m.count() == 0, "ランの全消去で未実行の予約も破棄")

func _summon(m: EnemySystem, king: int) -> void:
	var b := m.behavior(&"cepheus")
	b.step(king, 0.01)
	b.step(king, float(m.table.def[king].params.summon_time))
	# 再編された既存兵が配置に着く。
	for j in b._soldiers_of(king): m.table.mode[j] = EnemyTable.Mode.MOVE
	b.step(king, 0.01)

func _check_cepheus(run: RunSimulation) -> void:
	var m := run.enemies
	var t := m.table
	var king := m.spawn(m.def_of(&"cepheus"), Vector2(-300, 0), {"attack_priority": 3.0})
	var b := m.behavior(&"cepheus")
	_summon(m, king)
	check(b._soldiers_of(king).size() == 3, "ケフェウス座の初回召喚")
	var child: int = b._soldiers_of(king)[0]
	check(t.target_id[child] == t.id[king] and t.attack_priority[child] == 3.0, "王のIDと優先度を兵へ継承")
	run.combat.kill_enemy(child)
	m.cleanup()
	b.step(king, 0.01)
	check(b._soldiers_of(king).size() == 2, "欠員は次の増援まで維持")
	for size in [5, 7, 7]:
		t.fire_t[king] = 0.0
		_summon(m, king)
		check(b._soldiers_of(king).size() == size, "増援を段階ごとの固有数に制限: %d" % size)
	var soldiers: PackedInt32Array = b._soldiers_of(king)
	run.combat.kill_enemy(king)
	m.cleanup()
	m.spawn(m.def_of(&"cepheus"), Vector2(300, 0))
	for j in soldiers:
		check(t.mode[j] == EnemyTable.Mode.RECOVER, "王の削除・行再利用後も旧兵は崩壊")
	for step in 50:
		for j in soldiers:
			if t.alive[j] and not t.dead[j]: m.behavior(&"soldier").step(j, 0.1)
	m.cleanup()
	for j in soldiers:
		check(not t.alive[j] or t.dead[j], "旧兵は崩壊後に残留しない")

func _check_ruler(m: EnemySystem) -> void:
	var t := m.table
	var row := m.spawn(m.def_of(&"ruler"), Vector2(200, 0), {"attack_priority": 2.0})
	var b := m.behavior(&"ruler")
	t.age[row] = float(t.def[row].params.split_delay)
	b.step(row, 0.01)
	var halves := b.rows().duplicate()
	check(halves.size() == 2 and t.buds[halves[0]] == -t.buds[halves[1]], "じょうぎ座は左右の二体へ分離")
	for step in 5:
		for j in halves: b.step(j, 0.01)
	check(b.rows().size() == 2 and t.attack_priority[halves[1]] == 2.0, "二分は一回だけ、優先度を維持")
	m.mark_dead(row)
	m.cleanup()
	check(b.rows().size() == 1, "片側が倒れても残る側を維持")

func _check_members(m: EnemySystem) -> void:
	for type in [&"hound", &"crow"]:
		var def := m.def_of(type)
		var row := m.spawn(def, Vector2.ZERO)
		var b := m.behavior(def.behavior)
		var expected := int(def.params.pack_count) if type == &"hound" else mini(int(def.params.flock), 4)
		check(b.rows().size() == expected, "群れを既存数で成立: " + String(type))
		m.mark_dead(row)
		m.cleanup()
		check(b.rows().size() == expected - 1, "起点を消しても仲間が残る: " + String(type))
	var triangle := m.spawn(m.def_of(&"triangle"), Vector2.ZERO)
	check(m.parts_alive(triangle) == 3, "みなみのさんかく座の三頂点を生成")
	var parts := m.table.parts[triangle].duplicate()
	m.mark_dead(parts[0])
	m.cleanup()
	check(m.parts_alive(triangle) == 2, "部位の死亡で欠員を認識")
	m.mark_dead(triangle)
	m.cleanup()
	for k in range(2, parts.size(), 2):
		m.behavior(&"triangle_star").step(parts[k], 0.01)
	m.cleanup()
	for k in range(2, parts.size(), 2):
		check(not m.is_same(parts[k], parts[k + 1]) or m.table.dead[parts[k]], "親削除で部位を回収")

func _check_normal(run: RunSimulation) -> void:
	var before := run.enemies.count()
	for step in 3: run.spawn.spawner_tick(0.1, 0.1)
	check(run.enemies.count() == before, "生成で通常キャップを超えた間は通常補充を停止")
	run.enemies.clear_all()
	run.spawn.spawner_tick(0.1, 0.1)
	check(run.enemies.count() > 0, "欠員ができたら通常補充を再開")

func _check_refill_family(run: RunSimulation, phase: PhaseDef) -> void:
	run.enemies.clear_all()
	phase.mix = {&"hound": 1.0}
	run.spawn.spawner_tick(0.1, 0.1)
	check(run.enemies.count() == int(run.enemies.def_of(&"hound").params.pack_count), "通常補充は群れ成立後の実数で次の出現を止める")
	phase.wave_type = &"hound"
	for seed_value in range(1, 9):
		run.enemies.clear_all()
		run.state.rng.seed = seed_value
		run.spawn._spawn_wave(run.spawn.target(), 2)
		check(run.enemies.count() == int(run.enemies.def_of(&"hound").params.pack_count), "波状出現も群れ成立後の実数で次の出現を止める")
	# 領域別に数を切り詰めても、生の総数上限で補充を止める。
	_fill(run.enemies, 2)
	var region_cap := run.cfg.spawn_region_cap
	run.cfg.spawn_region_cap = 0.01
	var before := run.enemies.count()
	run.spawn.spawner_tick(0.1, 0.1)
	check(run.enemies.count() == before, "領域別カウントが目標未満でも総数上限で補充を停止")
	run.cfg.spawn_region_cap = region_cap

func _check_hydra(run: RunSimulation) -> void:
	var m := run.enemies
	run.bosses.spawn_lab(&"hydra", Vector2.ZERO)
	var boss = run.bosses.actors.back()
	boss.hsm.set_active(false)
	check(boss.necks.size() == 3 and m.parts_alive(boss.body) == 3, "上限超過時もうみへび座の初期首を生成")
	for count in [5, 8]:
		boss._set_count(count)
		m.cleanup()
		check(m.parts_alive(boss.body) == count, "首増加は既存段階の本数へ制限")
	var neck = boss.necks[0]
	run.combat.damage_enemy(neck.row, 1e6, {"cause": &"weapon"})
	m.cleanup()
	boss._grow(neck)
	check(m.parts_alive(boss.body) == 8, "撃破した首を行再利用で再生")
	var debris = boss.necks.filter(func(n): return n.kind == &"debris")[0]
	debris.mode = &"rubble_lump"
	var before := m.count()
	load("res://data/bosses/hydra_moves/rubble_lump.tres").make_runner().launch_rubble(boss, debris, 0.0, 20.0)
	check(m.count() == before + 1, "通常技の瓦礫を生成")
	debris.mode = &"idle"
	for technique in [&"tornado", &"debris_shatter"]:
		boss.recovery_t = 0.0
		boss._tech_cd = 0.0
		boss.combo_wait = 0.0
		check(boss.try_start_tech(technique, 1.0), "瓦礫を使う大技を開始: " + String(technique))
		var peak := 0
		for step in 200:
			boss.sim_tick(0.025, 0.025)
			peak = maxi(peak, boss._rubble.size())
		check(peak > 0 and not boss.busy, "大技の瓦礫生成と完了: " + String(technique))
	boss.begin_separation()
	check(m.is_same(boss.immortal_row, boss.immortal_id), "分離時に羅針盤の担い手を生成")
	run.bosses.remove_boss()
	m.cleanup()
	m.clear_all()
