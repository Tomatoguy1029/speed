## 武器と特性の育成完了への遷移・加算・実際の発射経路・ラン寿命を確認する。
extends "res://tests/thrill_acceptance.gd"

func _ready() -> void:
	var settings: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.data = SaveManager.default_data()
	SaveManager.settings = settings
	var saved := JSON.stringify(SaveManager.data)
	var config := ContentManager.cfg.duplicate(true) as GameConfig
	config.levelup_bonus_chance = 0.0
	scene = RunManager.create_session(self, {"lab": true, "seed": 42, "config": config}, false)
	scene.auto_step = false
	run = scene.sim
	_test_transition()
	_test_traits_and_stacks()
	_test_trait_levels()
	_test_hp_and_healing()
	_test_weapon_paths()
	_test_collision_and_pickups()
	_test_target_filtering()
	_test_time_caps()
	_test_selection_lifetime()
	_check(JSON.stringify(SaveManager.data) == saved, "全選択が永続セーブへ漏れない")
	await _test_legacy_lab_traits()
	await _close()
	var fresh := RunManager.create_session(self, {"lab": true, "seed": 84}, false)
	_check(fresh.sim.state.post_max_stacks.is_empty(), "次ランの追加強化は空")
	_check(is_equal_approx(fresh.sim.state.stats.max_hp, 100.0), "次ランに最大HPが漏れない")
	_check(is_equal_approx(fresh.sim.state.stats.crit_chance, 0.05), "次ランのRAMクリティカルは基礎値")
	fresh.free()
	print("[post_max_progression] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func _equip(ids: Array, lv := -1) -> void:
	run.loadout.reset_loadout()
	for id in ids:
		_check(run.loadout.grant(&"weapon", id, run.cfg.weapon_max_level if lv < 0 else lv), "装備 %s" % id)
	run.state.ship_hp = run.state.stats.max_hp
	run.set_phase(RunState.Phase.PLAY)

func _complete_traits() -> void:
	for id in [&"T01", &"T03", &"T04", &"T05"]:
		_check(run.loadout.grant(&"trait", id, run.cfg.trait_max_stacks), "特性 %s をMAX" % id)

func _test_trait_levels() -> void:
	_check(run.cfg.trait_slots == 4 and run.cfg.trait_max_stacks == 5, "新ランは特性4枠・Lv5")
	for lv in range(1, 6):
		run.loadout.reset_loadout()
		_check(run.loadout.grant(&"trait", &"T05", lv), "T05 Lv%d を装備" % lv)
		var sonic = run.loadout.trait_behaviors[&"T05"]
		_check(sonic._every() == [8, 6, 4, 4, 4][lv - 1], "T05 Lv%d の撃破間隔" % lv)
		_check(is_equal_approx(sonic.val("radius"), 270.0 + lv * 30.0), "T05 Lv%d の範囲" % lv)
		_check(is_equal_approx(sonic.val("damage"), 0.55 + lv * 0.05), "T05 Lv%d の威力倍率" % lv)
		_check(is_equal_approx(float(sonic.def.params.knock), 1000.0), "T05 Lv%d の吹き飛ばし" % lv)
		sonic.on_launch(false)
		sonic.on_kill(&"killSonic")
		_check(sonic._kills == 0, "T05 Lv%d の衝撃波撃破を次の発生数に含めない" % lv)
		_check(run.loadout.grant(&"trait", &"T13", lv), "T13 Lv%d を装備" % lv)
		var reactive = run.loadout.trait_behaviors[&"T13"]
		_check(is_equal_approx(reactive.val("radius"), 185.0 + lv * 15.0), "T13 Lv%d の範囲" % lv)
		_check(is_equal_approx(reactive.val("damage"), 1.0 + lv * 0.2), "T13 Lv%d の威力倍率" % lv)
		_check(is_equal_approx(float(reactive.def.params.knock), 450.0), "T13 Lv%d の吹き飛ばし" % lv)
	_check(not run.loadout.grant(&"trait", &"T05"), "Lv5より上へ進まない")
	run.loadout.reset_loadout()
	for id in [&"T01", &"T03", &"T04", &"T05"]:
		_check(run.loadout.grant(&"trait", id), "4枠を取得")
	_check(not run.loadout.grant(&"trait", &"T06"), "5個目の新規特性は取得しない")
	_check(run.loadout.grant(&"trait", &"T01"), "4枠でも所持特性はLv5まで上げられる")
	run.loadout.reset_loadout()
	var effect_levels := {
		&"T01": {"damage": [1.5, 1.75, 2.0, 2.25, 2.5], "radius": [210.0, 225.0, 240.0, 255.0, 270.0]},
		&"T03": {"radius": [215.0, 232.5, 250.0, 267.5, 285.0], "life": [1.9, 2.1, 2.3, 2.5, 2.7], "power": [270.0, 305.0, 340.0, 375.0, 410.0]},
		&"T04": {"mult": [1.5, 1.625, 1.75, 1.875, 2.0]},
		&"T06": {"damage": [2.4, 2.8, 3.2, 3.6, 4.0], "length": [840.0, 900.0, 960.0, 1020.0, 1080.0], "width": [40.0, 44.0, 48.0, 52.0, 56.0]},
	}
	for id in effect_levels:
		for lv in range(1, 6):
			run.loadout.reset_loadout()
			_check(run.loadout.grant(&"trait", id, lv), "%s Lv%d を装備" % [id, lv])
			var behavior: TraitBehavior = run.loadout.trait_behaviors[id]
			for key in effect_levels[id]:
				_check(is_equal_approx(behavior.val(key), float(effect_levels[id][key][lv - 1])), "%s Lv%d %s" % [id, lv, key])
	var stat_levels := {
		&"T07": {"field": "charge_time", "values": [1.25, 1.375, 1.5, 1.625, 1.75]},
		&"T08": {"field": "capacity", "values": [1.2, 1.4, 1.6, 1.8, 2.0]},
		&"T10": {"field": "max_speed", "values": [1.12, 1.19, 1.26, 1.33, 1.4]},
		&"T11": {"field": "attack_mult", "values": [1.2, 1.3, 1.4, 1.5, 1.6]},
		&"T12": {"field": "pickup_radius", "values": [1.3, 1.6, 1.9, 2.2, 2.5]},
		&"T14": {"field": "length_mult", "values": [1.25, 1.4, 1.55, 1.7, 1.85]},
		&"T31": {"field": "glide_duration_mult", "values": [1.25, 1.375, 1.5, 1.625, 1.75]},
	}
	for id in stat_levels:
		for lv in range(1, 6):
			run.loadout.reset_loadout()
			var field: String = stat_levels[id].field
			var baseline := float(run.state.stats.get(field))
			_check(run.loadout.grant(&"trait", id, lv), "%s Lv%d を装備" % [id, lv])
			var expected: float = stat_levels[id]["values"][lv - 1]
			var value := float(run.state.stats.get(field))
			_check(is_equal_approx(value, baseline / expected if id == &"T07" else baseline * expected), "%s Lv%d %s" % [id, lv, field])
	run.loadout.reset_loadout()

func _test_legacy_lab_traits() -> void:
	var lab: Node = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"traits": {"T01": 3, "T03": 3, "T04": 3, "T05": 3, "T06": 3}})
	_check(lab.run.cfg.trait_slots == 5 and lab.run.state.traits.size() == 5, "旧実験場の5枠装備を削除せず復元")
	_check(lab.run.state.traits.values().all(func(level): return level == 3), "旧実験場のLv3を維持")
	_check(not lab.run.loadout.all_traits_max() and lab.run.loadout.grant(&"trait", &"T06", 2), "旧装備もLv5まで成長できる")
	lab.queue_free()

func _test_transition() -> void:
	_check(not run.loadout.all_weapons_max(), "武器なしでは全MAXにならない")
	_equip([&"W01"])
	_check(not run.loadout.all_weapons_max(), "1本MAXでも空き枠があれば通常")
	run.state.level = 999
	for i in 20:
		_check(run.loadout.roll_cards().all(func(c): return c.kind != &"post_max"), "プレイヤーレベルでは解禁しない")
	_equip([&"W01", &"W03", &"W08", &"W17"], 1)
	for id in [&"W01", &"W03", &"W08"]:
		run.loadout.grant(&"weapon", id, 10)
	_check(not run.loadout.all_weapons_max(), "最後の1本が未完成なら通常")
	var normal := run.loadout.roll_cards()
	_check(normal.all(func(c): return c.kind == &"weapon" or c.kind == &"trait"), "通常抽選の種類を維持")
	run.loadout.grant(&"weapon", &"W17", 10)
	_check(run.loadout.all_weapons_max() and not run.loadout.normal_progression_complete(), "武器が全MAXでも特性の育成を続ける")
	_check(run.loadout.roll_cards().all(func(c): return c.kind != &"post_max"), "空の特性枠があれば追加強化を出さない")
	_check(not run.loadout.post_max.select(&"duration"), "通常育成中は直接の追加取得も拒否")
	for id in [&"T01", &"T03", &"T04"]:
		run.loadout.grant(&"trait", id, run.cfg.trait_max_stacks)
	_check(not run.loadout.all_traits_max() and run.loadout.roll_cards().all(func(c): return c.kind != &"post_max"), "特性3/4枠では未取得特性を優先")
	_equip([&"W01", &"W03", &"W08", &"W17"])
	for id in [&"T31"]:
		run.loadout.grant(&"trait", id, run.cfg.trait_max_stacks)
	for id in [&"T01", &"T14", &"T12"]:
		run.loadout.grant(&"trait", id)
	_check(run.loadout.all_weapons_max() and not run.loadout.all_traits_max(), "MAX直前も通常育成")
	var three := run.loadout.roll_cards()
	_check(three.size() == 3 and three.all(func(c): return c.kind == &"trait"), "通常候補3件を提示し回復なし")
	run.loadout.grant(&"trait", &"T01", 4)
	var unfinished := run.loadout.roll_cards()
	_check(unfinished.size() == 2 and unfinished.all(func(c): return c.kind == &"trait"), "通常候補2件を提示し回復なし")
	run.loadout.grant(&"trait", &"T14", 4)
	var last := run.loadout.roll_cards()
	_check(last.size() == 1 and last[0].kind == &"trait" and last[0].id == &"T12", "通常候補1件で回復・追加強化なし")
	run.loadout.grant(&"trait", &"T12", 4)
	_check(run.loadout.normal_progression_complete(), "4枠の所持特性が全てLv5で解禁")
	for i in 100:
		var cards := run.loadout.roll_cards()
		var seen := {}
		_check(cards.size() == 3 and cards.any(func(c): return c.kind == &"post_max"), "毎回同じ3択に追加強化を提示")
		for card in cards:
			_check(not seen.has(card.id), "1画面に同じ候補は1枚")
			seen[card.id] = true
			_check(card.kind != &"trait", "通常育成完了後は特性の未完成候補なし")
	# データ欠落・特殊設定で候補0になっても、空のカード画面で停止しない。
	var weapon_slots := run.cfg.weapon_slots
	run.cfg.weapon_slots = 0
	run.state.pending_levels = 2
	run.state.cards = []
	_check(run.loadout.roll_cards().is_empty(), "MAX判定未成立で候補0を検出")
	_check(not run.loadout.try_open_cards() and run.state.pending_levels == 0 and run.state.cards.is_empty(), "候補0は空画面を開かず保留を完了")
	run.cfg.weapon_slots = weapon_slots
	_equip([&"W01", &"W03", &"W21", &"W22"])
	_complete_traits()
	_check(run.loadout.normal_progression_complete(), "彗星限定も装備枠のMAXとして扱う")
	_check(not ContentManager.catalog.table(&"weapons").has(&"W06"), "廃止W06を復元しない")

func _test_traits_and_stacks() -> void:
	_equip([&"W01", &"W03", &"W08", &"W17"])
	var pm := run.loadout.post_max
	for trait_count in range(0, run.cfg.trait_max_stacks + 1):
		for count in [0, 1, 2, 9, 10, 11, 1000]:
			run.state.traits = {&"T09": trait_count}
			run.state.post_max_stacks = {&"crit_chance": count}
			run.loadout.refresh_stats()
			var expected := 0.05 + mini(trait_count, 3) * 0.05 + maxi(trait_count - 3, 0) * 0.03 + minf(0.04, count * 0.01)
			_check(is_equal_approx(run.state.stats.crit_chance, expected), "T09 %d / 追加 %d の確率" % [trait_count, count])
			var before := run.state.stats.crit_chance
			for repeat in 4: run.loadout.refresh_stats()
			_check(is_equal_approx(run.state.stats.crit_chance, before), "再計算で加算を重複しない")
			run.state.post_max_stacks = JSON.parse_string(JSON.stringify(run.state.post_max_stacks))
			run.loadout.refresh_stats()
			_check(is_equal_approx(run.state.stats.crit_chance, expected), "全T09枚数・追加回数でJSON読込が等価")
			_check(pm.eligible(&"crit_chance") == (count < 4), "追加クリティカルの上限と無効候補除外")
			if trait_count < run.cfg.trait_max_stacks:
				run.state.traits[&"T09"] += 1
				run.loadout.refresh_stats()
				_check(is_equal_approx(run.state.stats.crit_chance - before, 0.05 if trait_count < 3 else 0.03), "T09の既存3段と上位2段の増分を維持")
	# 上限を越える特殊設定でも、クリティカル率を30%以内に保つ。
	var original_max := run.cfg.trait_max_stacks
	run.cfg.trait_max_stacks = 7
	for trait_count in range(8):
		run.state.traits = {&"T09": trait_count}
		run.state.post_max_stacks = {&"crit_chance": 1000}
		run.loadout.refresh_stats()
		_check(is_equal_approx(run.state.stats.crit_chance, minf(0.3, 0.05 + mini(trait_count, 3) * 0.05 + maxi(trait_count - 3, 0) * 0.03)), "特性だけで上限に届く設定でも予約・総上限を維持")
		_check(not pm.eligible(&"crit_chance"), "特性予約が上限を使い切ると追加確率を除外")
	run.cfg.trait_max_stacks = original_max
	# 通常育成完了後、上限に達した追加確率は消費しない。
	run.state.traits = {&"T09": 5, &"T01": 5, &"T03": 5, &"T04": 5}
	run.state.post_max_stacks = {}
	run.loadout.refresh_stats()
	for i in 4: _check(pm.select(&"crit_chance"), "MAX特性後に追加確率を取得")
	for i in 2: _check(not pm.select(&"crit_chance"), "効かない5枚目以降を消費しない")
	run.loadout.refresh_stats()
	_check(is_equal_approx(run.state.stats.crit_chance, 0.3), "T09をMAXにしてから追加確率で30%")
	_check(int(run.state.post_max_stacks[&"crit_chance"]) == 4, "追加確率の上限は4枚")
	# 全既存の数値特性と永続強化を含む基準に、増分を加算する。
	run.ctx.profile = ProfileManager.compute({"speed": 5, "atk": 5, "hp": 5, "charge": 5, "pickup": 5, "length": 5, "xp": 5})
	run.state.post_max_stacks = {}
	run.state.traits = {&"T07": 5, &"T08": 5, &"T09": 5, &"T10": 5, &"T11": 5, &"T12": 5, &"T14": 5, &"T31": 5}
	run.loadout.refresh_stats()
	var base := pm.baseline.duplicate()
	var attack := run.combat.attack_power()
	var capacity := run.state.stats.capacity
	for key in [&"max_speed", &"acceleration", &"turn_rate", &"line_length", &"charge_time", &"pickup_radius", &"pickup_speed", &"xp_gain", &"crit_mult"]:
		for i in 5: _check(pm.select(key), "繰り返し取得 %s" % key)
	run.loadout.refresh_stats()
	_check(is_equal_approx(run.state.stats.max_speed, float(base[&"max_speed"]) * 1.15), "速度は永続・T10込み基準+15%、累乗しない")
	_check(is_equal_approx(run.state.stats.length_mult * run.cfg.draw_length, float(base[&"line_length"]) * 1.25), "T14と線の追加分を両立")
	_check(is_equal_approx(run.state.stats.xp_pickup_radius, float(base[&"pickup_radius"]) * 1.25), "T12とXP吸引範囲を両立")
	_check(is_equal_approx(run.state.stats.pickup_radius, float(base[&"pickup_radius"])), "XP半径の追加分を硬貨・カプセルへ漏らさない")
	_check(is_equal_approx(run.state.stats.charge_time, float(base[&"charge_time"]) * 0.85), "T07と永続充填を保持して15%短縮")
	_check(is_equal_approx(run.state.stats.xp_mult * run.state.stats.xp_gain_mult, float(base[&"xp_gain"]) * 1.15), "永続XP倍率を基準に加算")
	_check(is_equal_approx(run.state.stats.crit_mult, 2.5), "RAM倍率は5回で+0.5")
	_check(is_equal_approx(run.combat.attack_power(), attack) and run.state.stats.capacity == capacity, "RAM威力・T08を武器強化で書き換えない")
	# JSONで読み直したラン内カウントでも、基準から同じ結果を再構築できる。
	var reloaded: Dictionary = JSON.parse_string(JSON.stringify(run.state.post_max_stacks))
	run.state.post_max_stacks = reloaded
	run.loadout.refresh_stats()
	_check(is_equal_approx(run.state.stats.max_speed, float(base[&"max_speed"]) * 1.15), "カウントの保存形式読込・再計算が等価")
	run.ctx.profile = ProfileManager.compute({})

func _test_hp_and_healing() -> void:
	_equip([&"W01", &"W03", &"W08", &"W17"])
	_complete_traits()
	var pm := run.loadout.post_max
	run.state.ship_hp = 40.0
	_check(pm.select(&"max_hp"), "最大HPカードを選択")
	run.loadout.refresh_stats()
	_check(run.state.stats.max_hp == 105.0 and run.state.ship_hp == 40.0, "最大HP+5は現在HPを回復しない")
	for i in 5: run.loadout.refresh_stats()
	_check(run.state.ship_hp == 40.0, "再計算によるHP水増しなし")
	run.loadout.add_xp(run.loadout.xp_needed())
	_check(is_equal_approx(run.state.ship_hp, 48.4), "通常レベルアップ回復を保持")
	_check(pm.select(&"heal"), "追加即時修理を選択")
	_check(is_equal_approx(run.state.ship_hp, 79.9), "通常回復に加え最大HPの30%を回復")
	pm.select(&"heal")
	_check(run.state.ship_hp == 105.0, "即時回復は最大HPにクランプ")
	_check(not pm.eligible(&"heal") and not pm.select(&"heal"), "満HPの回復を候補・取得から除外")
	_check(not run.state.post_max_stacks.has(&"heal"), "回復カードは永続スタックを作らない")
	run.state.post_max_stacks[&"repair"] = 90
	run.loadout.refresh_stats()
	_check(is_equal_approx(run.state.stats.repair_fraction, 1.0) and not pm.eligible(&"repair"), "修理キットは最大HPの100%まで")
	run.state.ship_hp = 1.0
	run.pickups.collect(&"heal")
	_check(run.state.ship_hp == 105.0, "実際の修理キット経路に適用")
	run.state.post_max_stacks[&"invulnerability"] = 1000
	run.loadout.refresh_stats()
	_check(is_equal_approx(run.state.stats.invulnerability, 2.0) and not pm.eligible(&"invulnerability"), "無敵時間の上限・無効候補を確認")
	run.state.ship_invuln = 0.0
	run.ship.damage(1.0, 0.0, &"test")
	_check(is_equal_approx(run.state.ship_invuln, 2.0), "被弾の実経路に世界秒の無敵時間を適用")

func _test_weapon_paths() -> void:
	_equip([&"W01", &"W08", &"W17", &"W27"])
	var b: WeaponBehavior = run.loadout.weapon_behaviors[&"W01"]
	var ram := run.combat.attack_power()
	run.state.post_max_stacks = {&"weapon_damage": 2, &"followup": 2, &"projectile_speed": 2, &"duration": 2, &"knockback": 2, &"area": 2}
	run.loadout.refresh_stats()
	_check(is_equal_approx(b.atk(), ram * 1.14), "武器共通4%と対象追撃10%は基準に加算")
	_check(run.combat.attack_power() == ram, "武器威力をRAM本体へ掛けない")
	var f := run.projectiles.friend_alive.size()
	b.tick(1.0, false)
	_check(run.projectiles.friend_alive.size() > f, "実際の武器発射を検証")
	_check(is_equal_approx(run.projectiles.friend_vel[f].length(), 1430.0), "武器弾の速度+10%")
	_check(is_equal_approx(run.projectiles.friend_life[f], 0.99), "武器弾の寿命+10%")
	_check(is_equal_approx(run.projectiles.friend_knock[f], 275.0), "武器弾の吹き飛ばし+10%")
	_check(is_equal_approx(run.projectiles.friend_dmg[f], ram * 1.14 * b.dmg_k() * 0.4), "武器弾ダメージを二重適用しない")
	run.projectiles.fire_shot(Vector2.ZERO, 0.0, 7.0)
	var normal := run.projectiles.friend_dmg.find(7.0)
	_check(is_equal_approx(run.projectiles.friend_vel[normal].length(), 1300.0) and is_equal_approx(run.projectiles.friend_dmg[normal], 7.0), "特性・共通弾へ武器補正を漏らさない")
	var sonic: WeaponBehavior = run.loadout.weapon_behaviors[&"W08"]
	sonic.on_launch(false)
	var wave: Dictionary = run.projectiles.attached_attack(&"sonic").waves.back()
	_check(is_equal_approx(wave.radius, float(sonic.def.params.radius) * sonic.radius_k() * 1.1), "W08実波動の巻き込み半径")
	_check(is_equal_approx(wave.life, float(sonic.def.params.travel) * 1.1), "W08の実際に攻撃する持続時間")
	var arc: WeaponBehavior = run.loadout.weapon_behaviors[&"W17"]
	_check(is_equal_approx(arc.p("range"), float(arc.def.params.range) * 1.1), "W17電撃探索の到達距離")
	var echo: WeaponBehavior = run.loadout.weapon_behaviors[&"W27"]
	echo.on_launch(false)
	_check(is_equal_approx(float(echo.echoes.back().share) * echo.echoes.back().copies.size(), echo.level_value("echo_total_by_level") * 1.04), "W27は武器共通威力だけ適用し未定の役割を追加しない")
	var enemy := run.enemies.spawn(run.enemies.def_of(&"biter"), Vector2(500, 0))
	run.combat.damage_enemy(enemy, 1.0, {"cause": &"shot"})
	var hits := run.state.events.filter(func(e): return e.type == &"hit")
	_check(not hits.is_empty() and not hits.back().crit, "共通武器ダメージにクリティカルを追加しない")

func _test_collision_and_pickups() -> void:
	_equip([&"W03", &"W21", &"W22", &"W26"])
	_clear()
	var drone: WeaponBehavior = run.loadout.weapon_behaviors[&"W26"]
	var victim := run.enemies.spawn(run.enemies.def_of(&"biter"), Vector2.ZERO)
	var t := run.enemies.table
	var radius := float(drone.def.params.drone_hit_radius) * run.cfg.character_scale
	t.pos[victim] = Vector2(50.0, t.r[victim] + radius * 1.025)
	run.combat.rebuild_grid()
	var hp := t.hp[victim]
	drone._hit_along(Vector2.ZERO, Vector2(100, 0), Vector2.RIGHT)
	_check(t.hp[victim] == hp, "W26基準半径の外側には当たらない")
	run.state.post_max_stacks = {&"area": 1}
	drone._hit_along(Vector2.ZERO, Vector2(100, 0), Vector2.RIGHT)
	_check(t.hp[victim] < hp, "範囲+5%でW26の実接触判定が外側へ届く")
	var tow: WeaponBehavior = run.loadout.weapon_behaviors[&"W21"]
	var beam: WeaponBehavior = run.loadout.weapon_behaviors[&"W22"]
	_check(is_equal_approx(tow.p("capture_radius"), float(tow.def.params.capture_radius) * 1.05), "W21は回収判定の半径を拡大")
	_check(is_equal_approx(beam.p("width"), float(beam.def.params.width) * 1.05), "W22は実判定ビーム幅を拡大")
	# W03で飛ばす船体と破片は、W03の値に追加強化の補正を受ける。
	var ram: WeaponBehavior = run.loadout.weapon_behaviors[&"W03"]
	var corpse := run.enemies.spawn(run.enemies.def_of(&"biter"), Vector2(300, 300))
	t.dead[corpse] = 1
	t.r[corpse] = 80.0
	run.state.post_max_stacks = {&"area": 2, &"duration": 2, &"projectile_speed": 2, &"knockback": 2}
	var initial := run.projectiles.friend_count()
	ram.on_contact(corpse, t.pos[corpse], Vector2.RIGHT)
	_check(run.projectiles.friend_count() > initial, "W03の実接触から攻撃破片を発射")
	var debris := run.projectiles.friend_cause.find(&"hullDebris")
	_check(debris >= 0, "W03の船体破片を取得")
	if debris >= 0:
		_check(is_equal_approx(run.projectiles.friend_r[debris], 80.0 * 0.17 * 1.1), "W03の破片接触半径を拡大")
		_check(is_equal_approx(run.projectiles.friend_life[debris], run.cfg.hull_debris_life * 1.1), "W03の攻撃破片の持続に適用")
		_check(is_equal_approx(run.projectiles.friend_vel[debris].length(), (float(ram.def.params.speed_base) + float(ram.def.params.speed_per_tier) * ram.tier()) * 1.2 * 0.85), "W03の弾速と吹き飛ばしは基準へ加算")
	_clear()
	run.state.post_max_stacks = {&"pickup_radius": 2, &"pickup_speed": 2, &"xp_gain": 2, &"acceleration": 2, &"turn_rate": 2}
	run.loadout.refresh_stats()
	run.state.ship_pos = Vector2.ZERO
	run.state.ship_vel = Vector2.ZERO
	var gem := run.pickups._add_gem(Vector2(100, 0), 1.0)
	run.pickups._collect_gems(0.01)
	_check(is_equal_approx(run.pickups.gem_pos[gem].x, 92.3), "XP結晶は実吸引式700×1.1で移動")
	var enemy := run.enemies.spawn(run.enemies.def_of(&"biter"), Vector2(400, 0))
	var before := run.state.xp_dropped
	run.pickups.on_enemy_killed(enemy)
	_check(is_equal_approx(run.state.xp_dropped - before, t.xp[enemy]), "取得XPの追加分を敵ドロップ時に二重適用しない")
	var gained := run.state.xp_gained
	run.pickups.collect(&"gem", 10.0)
	_check(is_equal_approx(run.state.xp_gained - gained, 10.6), "通常・大きいXP結晶の取得入口で+6%を適用")
	run.pickups._clear_gems()
	run.pickups._add_gem(Vector2(800, 0), 20.0)
	gained = run.state.xp_gained
	run.pickups.collect(&"magnet")
	_check(is_equal_approx(run.state.xp_gained - gained, 21.2), "回収ビーコンも取得XP+6%を一度だけ適用")
	run.ship._steer_toward(0.0, 0.01, run.cfg.steer_cruise)
	_check(is_equal_approx(run.state.ship_vel.x, 9.9), "通常操縦は基準加速900の+10%")
	run.state.ship_vel = Vector2.RIGHT * 250.0
	run.ship._steer_toward(PI / 2.0, 0.01, run.cfg.steer_cruise)
	_check(is_equal_approx(run.state.ship_vel.angle(), 4.5 * 1.06 * 0.01), "通常操縦の旋回速度+6%")

func _test_target_filtering() -> void:
	var old_slots := run.cfg.weapon_slots
	run.cfg.weapon_slots = 1
	var expectations := {
		&"W01": [&"weapon_interval", &"projectile_speed", &"duration", &"knockback", &"followup"],
		&"W03": [&"projectile_speed", &"duration", &"knockback", &"area"], &"W04": [&"knockback", &"area"],
		&"W05": [&"weapon_interval", &"knockback", &"followup"], &"W07": [&"duration", &"knockback", &"followup"],
		&"W08": [&"weapon_interval", &"duration", &"knockback", &"area"], &"W17": [&"knockback", &"area"],
		&"W21": [&"projectile_speed", &"duration", &"knockback", &"area", &"followup"],
		&"W22": [&"knockback", &"area", &"followup"],
		&"W23": [&"weapon_interval", &"projectile_speed", &"duration", &"knockback", &"followup"],
		&"W25": [&"weapon_interval", &"projectile_speed", &"duration", &"knockback", &"followup"],
		&"W26": [&"area"], &"W27": []}
	for weapon in expectations:
		_equip([weapon])
		for id in [&"weapon_interval", &"projectile_speed", &"duration", &"knockback", &"area", &"followup"]:
			_check(run.loadout.post_max.eligible(id) == expectations[weapon].has(id), "%s の実適用先に応じて %s を抽選" % [weapon, id])
		if weapon == &"W22":
			var b: WeaponBehavior = run.loadout.weapon_behaviors[weapon]
			var visual_life: float = b.p("life")
			run.state.post_max_stacks[&"duration"] = 10
			_check(b.p("life") == visual_life, "W22の演出寿命をゲームプレイ強化にしない")
		if weapon == &"W26":
			var b: WeaponBehavior = run.loadout.weapon_behaviors[weapon]
			var span: float = b.level_value("half_span_by_level")
			var tail: float = b.level_value("tail_by_level")
			run.state.post_max_stacks[&"area"] = 2
			_check(b.level_value("half_span_by_level") == span and b.level_value("tail_by_level") == tail, "W26の固定編隊幅・演出光跡を保つ")
			_check(is_equal_approx(b.p("drone_hit_radius"), float(b.def.params.drone_hit_radius) * 1.1), "W26は接触半径を広げて隙間を増やさない")
	run.cfg.weapon_slots = old_slots

func _test_time_caps() -> void:
	_equip([&"W01", &"W05", &"W23", &"W25"])
	var pm := run.loadout.post_max
	run.state.post_max_stacks = {&"weapon_interval": 1000, &"charge_time": 1000}
	run.loadout.refresh_stats()
	_check(not pm.eligible(&"weapon_interval") and not pm.eligible(&"charge_time"), "時間短縮が下限で候補から消える")
	_check(is_equal_approx(run.state.stats.charge_time, 1.2), "充填は基準6秒の20%で止まる")
	for b: WeaponBehavior in run.loadout.weapon_behaviors.values():
		_check(b.interval(0.5) >= 0.1 and b.interval(0.1) >= 0.05, "間隔は比率・秒の下限を守る")
		_check(is_equal_approx(b.interval(0.01), 0.01), "元から短い間隔を遅くしない")
	# 強い永続・特性で既に短い場合、追加上限がそれを弱めない。
	run.ctx.profile.reduce[&"charge_time"] = 0.001
	run.loadout.refresh_stats()
	_check(run.state.stats.charge_time <= 0.00601, "既存の極短充填を絶対下限で弱めない")
	run.ctx.profile = ProfileManager.compute({})

func _test_selection_lifetime() -> void:
	_equip([&"W01", &"W03", &"W08", &"W17"])
	_complete_traits()
	run.state.pending_levels = 3
	run.loadout.try_open_cards()
	_check(run.state.phase == RunState.Phase.LEVELUP, "既存LEVELUPフェーズを再利用")
	var cards := run.state.cards.duplicate(true)
	var initial := run.state.time
	run.command(&"pause")
	run.command(&"choose_card", {"index": 0})
	run.physics_step(1.0)
	_check(run.state.cards == cards and run.state.pending_levels == 3 and run.state.time == initial, "ポーズ中の選択入力・時計を停止")
	run.command(&"resume")
	for i in 3:
		_check(run.state.cards[0].kind == &"post_max", "保留レベルごとに追加強化を提示")
		var info: Dictionary = preload("res://scripts/ui/hud.gd").card_info(run.state.cards[0])
		_check(not info.name.is_empty() and info.desc.length() <= 24 and (info.desc.contains("+") or info.desc.contains("−")), "カード正面は短い今回の増分")
		_check(info.tooltip_desc.contains("→") and info.color == Color("#9fe8ff"), "累計詳細をツールチップに残し色を固定")
		run.command(&"choose_card", {"index": 0})
	_check(run.state.pending_levels == 0 and run.state.phase == RunState.Phase.PLAY, "保留3レベルを1回ずつ選択して再開")
	var counts := run.state.post_max_stacks.duplicate()
	run.state.pending_levels = 1
	run.loadout.try_open_cards()
	_check(run.loadout.reroll_cards(), "同じリロール処理を利用")
	_check(run.state.post_max_stacks == counts, "リロールでは増分を付与しない")
	var reloaded := ResourceLoader.load("res://data/post_max.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as PostMaxConfig
	_check(reloaded.increments == run.cfg.post_max.increments, "調整リソースを再読込して同じ値を得る")
	# メニュー中の開発操作などで表示後に満HPになっても、無効な回復でレベルを消費しない。
	run.state.ship_hp = 50.0
	run.state.cards = [{"kind": &"post_max", "id": &"heal", "level": 1, "info": run.loadout.post_max.card_info(&"heal")}]
	run.loadout._publish_cards()
	run.ship.heal(run.state.stats.max_hp)
	run.command(&"choose_card", {"index": 0})
	_check(run.state.pending_levels == 1 and not run.state.cards.any(func(c): return c.kind == &"post_max" and c.id == &"heal"), "表示後に無効になった回復は再抽選しレベルを保持")
	run.loadout.reset_loadout()
	_check(run.state.post_max_stacks.is_empty() and run.state.stats.max_hp == 100.0, "調整用装備リセットでも追加分を消す")
