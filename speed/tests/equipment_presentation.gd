## 特性の槍は発動時だけ飛び、装備を外したあとは残る演出の終了で解放する。
extends Node
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
	_check_lance_lifetime()
	var legendary_preview := ModulePreview.new()
	legendary_preview.setup(LegendaryModuleDef.new(), true)
	legendary_preview.free()
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, true)
	session.auto_step = false
	var world := session.view.get_node("World")
	var presentation: Node = session.view.get_node("RunPresentation")
	presentation.set_process(false)
	check(ContentManager.catalog.find(&"weapons", &"W24") == null, "廃止したW24を武器プールと図鑑から除く")
	check(not session.sim.loadout.grant(&"weapon", &"W24"), "旧W24への付与要求を安全に無視する")
	var old_save := SaveManager.default_data()
	old_save.encyclopedia = ["W24", "T06"]
	var migrated: Dictionary = SaveManager._migrate(old_save, SaveManager.default_data())
	check(migrated.encyclopedia.has("T06"), "旧W24を含むセーブのT06取得記録を保つ")
	check(world.find_child("CriticalLances", true, false) == null, "取得前に特性用の表示を作らない")
	session.sim.loadout.grant(&"trait", &"T06")
	session.sim.loadout.grant(&"weapon", &"W27")
	await get_tree().process_frame
	var lance: Node = world.find_child("CriticalLances", true, false)
	check(lance != null, "T06の発動演出を準備する")
	if lance != null:
		check(lance.shots.is_empty(), "特性を持つだけでは常駐する槍を表示しない")
		var state: RunState = session.sim.state
		state.phase = RunState.Phase.PLAY
		state.events.clear()
		state.ship_vel = Vector2.RIGHT * 100.0
		var lance_trait = session.sim.loadout.trait_behaviors[&"T06"]
		lance_trait.on_critical(Vector2.ZERO)
		var effects := state.events.filter(func(e): return e.type == &"critical_lance")
		check(effects.size() == 1, "クリティカルで槍を1本だけ発射する")
		check(state.events.all(func(e): return e.type != &"beam"), "T06は従来のビーム演出を出さない")
		if not effects.is_empty():
			check(effects[0].to == Vector2(840, 0) and effects[0].width == 40.0, "T06の射程と幅を維持する")
		lance_trait.on_critical(Vector2.ZERO)
		check(state.events.filter(func(e): return e.type == &"critical_lance").size() == 1, "既存の発動間隔を維持する")
		session.sim.flush_events()
		check(lance.shots.size() == 1, "発動イベントだけが槍の演出を作る")
		presentation._process(0.05)
		var age: float = lance.shots[0].age
		state.hitstop = 0.05
		presentation._process(0.03)
		check(lance.shots[0].age == age, "ヒットストップ中は槍の保持と減衰も停止する")
		state.hitstop = 0.0
		state.phase = RunState.Phase.PAUSED
		presentation._process(0.05)
		check(lance.shots[0].age == age, "ポーズ中は槍の飛行も停止する")
		state.phase = RunState.Phase.PLAY
	session.sim.loadout.reset_loadout()
	presentation._process(0.02)
	await get_tree().process_frame
	check(world.find_child("Afterimages", true, false) == null, "残像の専用表示を解放する")
	if lance != null:
		check(is_instance_valid(lance), "装備を外しても発射済みの槍は飛び終える")
	presentation._process(0.5)
	await get_tree().process_frame
	check(world.find_child("CriticalLances", true, false) == null, "飛び終えた槍の表示を解放する")

	_check_lance_combat(session)
	session.free()
	await get_tree().process_frame
	print("[equipment_presentation] %d failures" % failed)
	get_tree().quit(1 if failed else 0)

func _check_lance_lifetime() -> void:
	var lance := load("res://scripts/render/light_lance.gd").new() as Node2D
	add_child(lance)
	var event := {"from": Vector2.ZERO, "to": Vector2(840, 0), "width": 40.0}
	lance.fire(event)
	lance.step(0.40, 1.0, 1.0)
	check(lance.shots.size() == 1, "以前の消滅時刻でも槍の消え際を見せる")
	lance.fire(event)
	check(lance.shots.size() == 2 and is_equal_approx(lance.shots[0].age, 0.40), "次の槍で既存の表示を消去・巻き戻ししない")
	lance.step(0.11, 1.0, 1.0)
	check(lance.shots.size() == 1 and is_equal_approx(lance.shots[0].age, 0.11), "古い槍だけを寿命で回収する")
	lance.step(0.51, 1.0, 1.0)
	var interval: float = ContentManager.definition(&"traits", &"T06").params.cooldown
	for shot in 20:
		lance.step(interval, 1.0, 1.0)
		lance.fire(event)
		check(lance.shots.size() <= 4, "最短間隔の連続発動でも表示が蓄積し続けない")
	lance.step(0.51, 1.0, 1.0)
	check(lance.shots.is_empty(), "連続発動が終わったあと全表示を回収する")
	lance.free()

func _check_lance_combat(session: RunSession) -> void:
	var sim := session.sim
	var state := sim.state
	state.ship_vel = Vector2.RIGHT * 100.0
	state.stats.crit_chance = 1.0
	var table := sim.enemies.table
	var rows: Array[int] = []
	for pos in [Vector2(200, 0), Vector2(400, 0), Vector2(1400, 0), Vector2(200, 200)]:
		var row := sim.enemies.spawn(ContentManager.definition(&"enemies", &"drifter"), pos)
		table.hp[row] = 10000.0
		table.max_hp[row] = 10000.0
		rows.append(row)
	sim.combat.rebuild_grid()
	for stacks in range(1, 4):
		sim.loadout.grant(&"trait", &"T06")
		state.time += 1.0
		state.events.clear()
		var hp := table.hp[rows[0]]
		var damage := sim.combat.attack_power() * (1.6 + 0.8 * stacks)
		sim.loadout.on_critical(Vector2.ZERO)
		check(is_equal_approx(hp - table.hp[rows[0]], damage), "T06の重ね数%dの威力を維持する" % stacks)
		check(table.hp[rows[0]] == table.hp[rows[1]], "同一直線の複数の敵を貫く")
		check(table.hp[rows[2]] == 10000.0 and table.hp[rows[3]] == 10000.0, "射程外と攻撃線の外には当てない")
		check(state.events.filter(func(e): return e.type == &"critical_lance").size() == 1, "槍の命中から次の槍を発動しない")
	state.time += 1.0
	state.events.clear()
	state.ship_vel = Vector2.ZERO
	state.ship_heading = Vector2.UP
	sim.loadout.on_critical(Vector2.ZERO)
	var effects := state.events.filter(func(e): return e.type == &"critical_lance")
	check(effects.size() == 1 and effects[0].to == Vector2(0, -1080), "停止中は機首方向へ撃つ")
