## ビルドの組み合わせ・一撃・分裂・耐久の重要な境界を確認する。
extends "res://tests/thrill_acceptance.gd"

func _ready() -> void:
	var settings: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.data = SaveManager.default_data()
	SaveManager.settings = settings
	scene = RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	scene.auto_step = false
	run = scene.sim
	_test_multipliers()
	_test_duplication()
	_test_discovery()
	_test_shooting()
	_test_one_shot()
	_test_hull_kill_exclusion()
	_test_barrier()
	_test_distance()
	_test_endpoint()
	_test_shooting_multiplier_hits()
	_test_sonic_edge()
	_test_hole_capture()
	await _close()
	print("[build_rework] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func _test_multipliers() -> void:
	_check(run.loadout.grant(&"trait", &"T34", 5), "大振りを装備")
	_check(is_equal_approx(run.loadout.area_multiplier(), 1.3), "大振りLv5の半径")
	_check(run.loadout.grant(&"trait", &"T35", 5), "マルチショットを装備")
	_check(run.loadout.shot_count(1) == 2 and run.loadout.shot_count(8) == 16, "武器ごとの弾数を同じ割合で増やす")
	_check(run.loadout.grant(&"trait", &"T36", 5), "フルバーストを装備")
	run.state.gauge = 0.99
	_check(is_equal_approx(run.loadout.shooting_rate(), 1.0), "1単位未満では連射を増やさない")
	run.state.gauge = 1.0
	_check(is_equal_approx(run.loadout.shooting_rate(), 1.45), "1単位で連射が増える")
	run.state.gauge = 2.0
	_check(is_equal_approx(run.loadout.shooting_rate(), 1.9), "容量を増やした分も連射に含める")
	run.loadout.reset_loadout()

func _test_duplication() -> void:
	_check(run.loadout.grant(&"trait", &"T37", 5), "デュプリケーターを装備")
	var behavior = run.loadout.trait_behaviors[&"T37"]
	behavior.def = behavior.def.duplicate(true)
	behavior.def.params.chance_by_level = [0.0,0.0,0.0,0.0,0.0]
	_check(run.loadout.split_vectors(Vector2.RIGHT,0).is_empty(),"分裂は装備した定義を使い、局所的な試遊の設定も反映する")
	behavior.def.params.chance_by_level = [1.0,1.0,1.0,1.0,1.0]
	var ps := run.projectiles
	ps.fire_shot(Vector2.ZERO, 0.0, 10.0)
	var original := 0
	var source_hit := {123: true}
	ps.friend_hit[original] = source_hit
	var before := ps.friend_count()
	for attempt in 100:
		if ps.duplicate_friend(original, Vector2.ONE): break
	_check(ps.friend_count() == before + 2, "分裂で2発増える")
	for i in range(1, 3):
		_check(ps.friend_generation[i] == 1 and is_equal_approx(ps.friend_dmg[i], 8.0), "Lv5の子は8割・次の世代")
		_check(ps.friend_hit[i].has(123), "同じ敵へ分裂直後に再命中しない")
	ps.friend_hit[1][456] = true
	_check(not ps.friend_hit[2].has(456), "左右の命中履歴を独立させる")
	ps.friend_generation[1] = 6
	_check(not ps.duplicate_friend(1, Vector2.ONE), "6世代で止まる")
	while ps.friend_count() < 219:
		ps.fire_shot(Vector2.ZERO, 0.0, 1.0)
	_check(not ps.duplicate_friend(0, Vector2.ZERO), "220を超える分裂を止める")
	ps.friend_slots.clear()
	run.loadout.reset_loadout()

func _test_discovery() -> void:
	SaveManager.data = SaveManager._migrate({"encyclopedia": ["T01", "T13", "W01"]}, SaveManager.default_data())
	_check(SaveManager.is_module_known(&"W29"), "終端爆縮の取得をエンドブラストへ引き継ぐ")
	_check(not SaveManager.is_module_known(&"T13"), "廃止した反応波動を表示しない")
	_check(SaveManager.is_module_known(&"W01"), "他の獲得記録を保つ")

func _test_shooting() -> void:
	for id in [&"W01", &"W23"]:
		run.loadout.reset_loadout()
		_check(run.loadout.grant(&"weapon", id, 5), "前後の射撃を装備")
		var behavior = run.loadout.weapon_behaviors[id]
		behavior.tick(0.5, false)
		_check(run.projectiles.friend_count() == 1, "Lv5も基準は1発")
		_check(run.projectiles.friend_pierce_left[0] == 2, "Lv5は2体を貫く")
		run.projectiles.friend_slots.clear()
	run.loadout.reset_loadout()

func _test_one_shot() -> void:
	_clear()
	run.loadout.reset_loadout()
	run.loadout.grant(&"weapon", &"W03", 5)
	var shatter = run.loadout.weapon_behaviors[&"W03"]
	shatter.def = shatter.def.duplicate(true)
	shatter.def.params.chance_by_level = [1.0, 1.0, 1.0, 1.0, 1.0]
	var t := run.enemies.table
	for cause in [&"shot", &"ram", &"afterimage"]:
		var i := _enemy(&"drifter", Vector2(100, 100))
		t.max_hp[i] = 10.0
		t.hp[i] = 8.0
		var before := run.projectiles.friend_count()
		run.combat.damage_enemy(i, 8.0, {"cause": cause})
		_check(run.projectiles.friend_count() == before + (0 if cause == &"afterimage" else 2), "分身以外の8割の一撃で小さい敵も砕く")
	var weak := _enemy(&"drifter", Vector2(200, 100))
	t.max_hp[weak] = 10.0
	t.hp[weak] = 7.99
	var before := run.projectiles.friend_count()
	run.combat.damage_enemy(weak, 7.99, {"cause": &"shot"})
	_check(run.projectiles.friend_count() == before, "8割未満のとどめでは砕かない")
	while run.projectiles.debris_count() < 199:
		run.projectiles._add_friend(ProjectileSystem.FriendKind.DEBRIS, &"hullDebris", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0, 1.0, false, 0, Color.WHITE, true, 0.0, 0.0, 0.0, -1)
	var last := _enemy(&"armored", Vector2(300, 100))
	t.max_hp[last] = 10.0
	t.hp[last] = 10.0
	run.combat.damage_enemy(last, 10.0, {"cause": &"shot", "dir": Vector2.RIGHT})
	_check(run.projectiles.debris_count() == 200, "破片を200個までに絞る")
	var finite:=true
	for row in run.projectiles.friend_alive.size():
		if run.projectiles.friend_alive[row]!=0 and not run.projectiles.friend_vel[row].is_finite():finite=false
	_check(finite,"上限まで残り1個でも破片の位置と速度を有限に保つ")
	_clear()
	run.loadout.reset_loadout()

func _test_barrier() -> void:
	run.loadout.grant(&"weapon", &"W05", 1)
	var b = run.loadout.weapon_behaviors[&"W05"]
	var center := run.state.ship_pos
	_check(b.block_segment(center + Vector2(100, 0), center, 1.0, 10.0) != null, "弾が殻を横切れば受け止める")
	_check(is_equal_approx(b.durability, 5.0) and b.ready(), "耐久をダメージ分だけ減らす")
	_check(b.block_segment(center + Vector2(100, 0), center, 1.0, 100.0) != null, "耐久を超える最後の1発も受け止める")
	_check(not b.ready() and b.waves.size() == 2, "砕ける回にも波動が出る")
	_check(b.block_segment(center + Vector2(100, 0), center, 1.0, 10.0) == null, "壊れている間は弾を通す")
	b.tick(6.01, false)
	_check(b.ready() and is_equal_approx(b.durability, 15.0), "時間が来ると耐久が全部戻る")
	run.loadout.reset_loadout()

func _test_distance() -> void:
	run.loadout.grant(&"trait", &"T04", 5)
	run.loadout.grant(&"trait", &"T32", 5)
	var gear = run.loadout.trait_behaviors[&"T04"]
	var start = run.loadout.trait_behaviors[&"T32"]
	_check(is_equal_approx(gear.multiplier(0.0), 1.0) and is_equal_approx(gear.multiplier(1000.0), 2.0), "ギアアップは0から基本線長まで成長")
	_check(is_equal_approx(gear.multiplier(2000.0), 2.0), "長い線も最大倍率を維持")
	_check(is_equal_approx(start.multiplier(600.0), 3.0), "助走は600で最大")
	_check(start.multiplier(300.0) < 1.4, "助走は後半ほど大きく伸びる")
	run.loadout.reset_loadout()

func _test_endpoint() -> void:
	run.loadout.grant(&"weapon", &"W29", 5)
	var blast = run.loadout.weapon_behaviors[&"W29"]
	blast.on_end()
	_check(blast.pending.size() == 7, "エンドブラストLv5の二段目は7個")
	blast.tick(0.13, false)
	_check(blast.pending.size() == 7, "二段目は0.14秒まで待つ")
	blast.tick(0.3, false)
	_check(blast.pending.is_empty(), "二段目が時間差で全部発動する")
	run.loadout.reset_loadout()
	run.loadout.grant(&"weapon", &"W07", 5)
	var mines = run.loadout.weapon_behaviors[&"W07"]
	run.state.ship_heading = Vector2.RIGHT
	mines.on_end()
	_check(mines.mines.size() == 24 and mines.mines.all(func(m): return m.to.x >= m.from.x), "機雷は前方へ24個")
	mines.on_end()
	mines.on_end()
	_check(mines.mines.size() == 60, "機雷は古いものから消して60個")
	# 終点で反射しても、機雷は到着した区間の進行方向へ出る。
	_clear()
	mines.mines.clear()
	run.state.ship_heading=Vector2.LEFT
	run.state.trace_path=PackedVector2Array([Vector2(-100,0),Vector2.ZERO])
	run.draw.run=TraceRun.new()
	mines.on_end()
	_check(mines.mines.all(func(m):return m.to.x>=m.from.x),"終点の反射後も入ってきた方向へ機雷を出す")
	run.draw.run=null
	# 発射直後に敵へ触れても、着地前は爆発と誘爆を始めない。
	for mine in mines.mines: mine.to=run.state.ship_pos
	var victim := _enemy(&"drifter",run.state.ship_pos)
	run.enemies.table.hp[victim]=100000.0
	run.combat.rebuild_grid()
	mines.tick(0.13,false)
	_check(mines.mines.size()==24,"飛行中の機雷は敵と重なっても残る")
	mines.tick(0.02,false)
	_check(mines.mines.is_empty(),"停止した機雷は敵の接近で爆発し、周囲も誘爆する")
	_clear()
	run.loadout.reset_loadout()

func _test_shooting_multiplier_hits() -> void:
	_clear()
	run.loadout.reset_loadout()
	run.field.bodies.clear()
	run.field.moons.clear()
	run.loadout.grant(&"weapon",&"W25",1)
	run.loadout.grant(&"trait",&"T35",5)
	var victim:=_enemy(&"drifter",run.state.ship_pos+Vector2(180,0))
	run.enemies.table.hp[victim]=1000.0
	run.enemies.table.max_hp[victim]=1000.0
	run.combat.rebuild_grid()
	var wing=run.loadout.weapon_behaviors[&"W25"]
	wing.tick(1.0,false)
	var count:=run.projectiles.friend_count()
	var damage:float=wing.atk()*float(wing.value("damage_by_level"))
	run.projectiles._update_friendly(0.3)
	_check(count>=2 and is_equal_approx(run.enemies.table.hp[victim],1000.0-damage*count),"ウィングの追加弾を同時着弾でも全部ダメージに反映する")
	_clear()
	run.loadout.reset_loadout()

func _test_sonic_edge() -> void:
	_clear()
	run.loadout.reset_loadout()
	run.loadout.grant(&"weapon",&"W08",1)
	var sonic=run.loadout.weapon_behaviors[&"W08"]
	run.state.ship_pos=Vector2(200,0)
	run.state.ship_heading=Vector2.RIGHT
	run.state.ship_vel=Vector2(100,0)
	var victim:=_enemy(&"drifter",Vector2(50,100))
	run.enemies.table.r[victim]=50.0
	run.enemies.table.hp[victim]=100.0
	for i in 3:sonic.frames.append({"pos":Vector2(50,0),"age":60.0/sonic.wave_speed()})
	sonic.pulse=0.25
	run.combat.rebuild_grid()
	sonic.tick(0.01,false)
	_check(sonic.pending.size()==1,"音の輪が大型敵の外周へ触れたときも当てる")
	_check(run.enemies.table.hp[victim]==100.0,"押してから威力まで一拍待つ")
	sonic.tick(0.1,false)
	_check(run.enemies.table.hp[victim]<100.0,"押した敵へ遅れて威力を与える")
	_clear()
	run.loadout.reset_loadout()

func _test_hole_capture() -> void:
	_clear()
	run.loadout.reset_loadout()
	run.loadout.grant(&"trait", &"T03", 5)
	var hole = run.loadout.trait_behaviors[&"T03"]
	var victim := _enemy(&"drifter", run.state.ship_pos + Vector2(30,0))
	run.enemies.table.guard[victim] = 1.0
	run.combat.rebuild_grid()
	hole.on_end()
	hole.tick(0.2, false)
	_check(run.enemies.table.dead[victim] == 0 and run.enemies.table.hull_scattered[victim] == 0, "無敵の敵はエンドホールへ吸い込んだ扱いにしない")
	_clear()
	run.loadout.reset_loadout()

func _test_hull_kill_exclusion() -> void:
	_clear()
	run.loadout.reset_loadout()
	run.loadout.grant(&"weapon", &"W03", 5)
	run.loadout.grant(&"weapon", &"W21", 1)
	run.loadout.grant(&"trait", &"T33", 1)
	var shatter = run.loadout.weapon_behaviors[&"W03"]
	shatter.def = shatter.def.duplicate(true)
	shatter.def.params.chance_by_level = [1.0, 1.0, 1.0, 1.0, 1.0]
	var tow = run.loadout.weapon_behaviors[&"W21"]
	var rampage = run.loadout.trait_behaviors[&"T33"]
	var t := run.enemies.table
	run.state.tracing = true
	for cause in [&"shot", &"afterimage"]:
		var i := _enemy(&"drifter", run.state.ship_pos + Vector2(30, 0))
		var kills := run.state.kills
		var count: int = tow.cargo.size()
		var triggered: int = rampage.kills
		run.combat.kill_enemy(i, {"cause": cause, "one_shot": true})
		_check(run.projectiles.debris_count() == 0, "船体を使った撃破では星砕きが発動しない")
		_check(tow.cargo.size() == count + (0 if cause == &"afterimage" else 1), "分身の撃破では船体を牽引しない")
		_check(rampage.kills == triggered + (0 if cause == &"afterimage" else 1), "牽引は撃破特性を保ち、分身の撃破は発動を抑える")
		_check(run.state.kills == kills + 1 and t.dead[i] != 0, "どちらの撃破も撃破数へ加算する")
	run.state.tracing = false
	var i := _enemy(&"drifter", run.state.ship_pos)
	t.hull_scattered[i] = 1
	run.combat.kill_enemy(i, {"cause": &"vortex", "one_shot": true})
	_check(run.projectiles.debris_count() == 2, "一時的なhull_scatteredだけでは星砕きを抑えない")
	_clear()
	run.loadout.reset_loadout()
