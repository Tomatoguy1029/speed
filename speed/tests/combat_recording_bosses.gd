## 直接攻撃の接触・実ダメージと、行動の境界をJSONLまで確認する。
extends "res://tests/combat_recording.gd"

func boss(id: StringName, enabled := true) -> void:
	fresh(1, false)
	sim.bosses.remove_boss()
	sim.bosses.spawn(load("res://data/bosses/%s.tres" % id), Vector2.ZERO)
	actor = sim.bosses.actors.back()
	if "selection_enabled" in actor: actor.selection_enabled = false
	else: actor.hsm.set_active(false)
	if "mode" in actor: actor.mode = &"idle"
	sim.state.ship_pos = Vector2(400, 0)
	sim.state.view_center = Vector2.ZERO
	sim.state.view_half = Vector2(1000, 700)
	sim.state.enemy_aim = sim.state.ship_pos
	sim.projectiles.director.formation_mode = true
	if enabled: begin_recording()

func damage_row(cause: String) -> Dictionary:
	var found := events("combat_damage").filter(func(e): return e.target == "player" and e.cause == cause)
	return found.back() if not found.is_empty() else {}

func _ready() -> void:
	SaveManager.data = SaveManager.default_data()
	SaveManager.dev_meta_override = {}
	boss(&"centaurus")
	check(actor.start_attack(&"rear_attack"), "ケンタウルスの背後攻撃を開始")
	actor._runner.strike_on(actor)
	sim.state.ship_pos = actor.rear_center(actor.rule())
	actor._previous_ship = sim.state.ship_pos
	actor._strike_tick()
	actor._strike_tick()
	actor.finish_technique()
	actor.sim_tick(2.0, 2.0)
	var rear := outcome("rear_attack")
	check(rear.get("contacts", 0) == 1 and rear.get("applied", 0.0) > 0.0, "背後攻撃の一度だけの接触と実ダメージ")
	check(not damage_row("rear_attack").is_empty(), "背後攻撃の被弾を保存")
	check(events("boss_action").any(func(e): return e.action == "rear_attack" and e.step == "telegraph"), "背後攻撃の予告を保存")
	check(events("boss_action").any(func(e): return e.action == "rear_attack" and e.step == "execute"), "背後攻撃の実行を保存")

	boss(&"canis_major")
	check(actor.start_attack(&"pounce"), "おおいぬ座の飛びかかりを開始")
	actor._runner._hit_ship(actor, 7.0)
	actor.cancel_attack()
	var pounce := outcome("pounce")
	check(pounce.get("contacts", 0) == 1 and is_equal_approx(pounce.get("applied", 0.0), 7.0 * sim.cfg.atk_scale), "飛びかかりの倍率と実ダメージ")
	check(pounce.get("step") == "interrupted", "キャンセルした行動を終了")
	check(damage_row("pounce").get("action") == "pounce", "飛びかかりと被弾の対応")

	boss(&"hydra")
	var n = actor.necks[0]
	n.cd = 0.0
	check(actor.start_normal(0, &"bite_thrust"), "ヒドラの噛みつきを開始")
	var at := sim.state.ship_pos
	actor.attack_field.add_shape(PackedVector2Array([at, at + Vector2.RIGHT]), 20.0, 0.0, 1.0, 9.0, &"bite", n.row)
	actor.attack_field.tick(DT)
	actor.attack_field.tick(DT)
	actor.finish_normal(n)
	var bite := outcome("bite_thrust")
	check(bite.get("contacts", 0) == 1 and is_equal_approx(bite.get("applied", 0.0), 9.0 * sim.cfg.atk_scale), "ヒドラの首ごとの一度だけの接触と倍率")
	check(damage_row("bite").get("action") == "bite_thrust", "ヒドラの首の行動と被弾の対応")
	n.cd = 0.0
	check(actor.start_normal(0, &"bite_thrust"), "記録終了中の首の行動を開始")
	rec._end("stopped")
	check(outcome("bite_thrust").get("step") == "observation_end", "録画を止めると首の観測も終了")

	boss(&"monoceros")
	actor.combat_trace.begin(&"charge", "external_forced")
	sim.bosses.recording_actor = actor
	sim.projectiles.fire_slash(Vector2.ZERO, 0.0, 100.0, 100.0, 10.0, 5.0, 1.0)
	sim.bosses.recording_actor = null
	var ps := sim.projectiles
	var shape = load("res://scripts/attacks/slash.gd").new()
	var point: Vector2 = shape.slash_points(Vector2.ZERO, 0.0, 100.0, 1.0, 0)[8]
	sim.state.ship_pos = point
	ps.hostile_slow[0] = 0.0
	shape.contact(ps, 0, Vector2.ZERO, Vector2.ZERO, null, point, sim.cfg.ship_radius, DT)
	ps._end_hostile(0, "contact", point)
	var effect := events("boss_effect").filter(func(e): return e.step == "end")
	check(not effect.is_empty() and effect.back().contacts == 1 and effect.back().applied > 0.0, "斬撃も共通の敵弾経路で接触と実ダメージを保存")
	_test_other_damage_paths()
	_test_hydra_major_and_partial_recording()
	for id in [&"centaurus", &"canis_major", &"hydra"]:
		var enabled := boss_trial(id, true)
		var disabled := boss_trial(id, false)
		check(enabled == disabled, "%sは録画の有無でHP・行動・位置・乱数が変わらない" % id)
	close()
	print("[combat_recording_bosses] checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func boss_trial(id: StringName, enabled: bool) -> Array:
	boss(id, enabled)
	if id == &"hydra":
		actor.necks[0].cd = 0.0
		actor.start_normal(0, &"bite_thrust")
	else: actor.start_attack(&"rear_attack" if id == &"centaurus" else &"pounce")
	for frame in 300:
		sim.state.time += DT
		sim.state.world_time += DT
		sim.state.ship_invuln = maxf(0.0, sim.state.ship_invuln - DT)
		actor.sim_tick(DT, DT)
	return [sim.state.ship_hp, actor.table.pos[actor.body], sim.state.rng.state, sim.projectiles.hostile_count()]

func _test_other_damage_paths() -> void:
	boss(&"centaurus")
	check(actor.start_attack(&"rain"), "矢の雨を開始")
	actor._runner.begin_rain(actor)
	actor._rain_tick(0.0)
	var r: Dictionary = actor.rule()
	var trace: Dictionary = actor.rain_traces[0]
	actor._rain_left = 0
	actor.clock = float(trace.t0) + float(r.get("drop_delay", 0.0)) + float(r.fall) + 0.05
	sim.state.ship_pos = actor.trace_point(trace, float(r.trace_speed) * 0.025)
	actor._rain_tick(0.0)
	check(damage_row("arrow").get("action") == "rain", "矢の雨の被弾と行動の対応")
	actor.cancel_attack()
	check(actor.start_attack(&"shower_chase"), "追跡する矢の雨を開始")
	r = actor.rule()
	actor.clock += float(r.warn) + float(r.mark_time) + 0.01
	actor._runner.launched = true
	actor._runner.placed = int(r.count)
	actor._runner._add_mark(sim.state.ship_pos, actor.clock - float(r.mark_time))
	sim.state.ship_invuln = 0.0
	actor._runner.tick(actor, 0.0)
	check(damage_row("arrow").get("action") == "shower_chase", "着弾する矢の雨の被弾と行動の対応")
	actor.cancel_attack()
	check(actor.start_attack(&"stomp"), "踏みつけを開始")
	r = actor.rule()
	actor.clock += float(r.warn) + 0.001
	sim.state.ship_pos = actor.stomp_center() + Vector2.from_angle(actor.table.facing[actor.body]) * 10.0
	sim.state.ship_invuln = 0.0
	actor._runner.tick(actor, 0.0)
	check(damage_row("stomp").get("action") == "stomp", "踏みつけの被弾と行動の対応")

	boss(&"canis_major")
	check(actor.start_attack(&"sirius"), "シリウスの光を開始")
	var effects = actor.sirius_effects
	var jet: Dictionary = effects.start_jet(sim.state.ship_pos, 0.0, 200.0, 30.0, 1.0, 6.0, effects.FLAME_FIRE)
	effects._tick_particles(0.0)
	check(damage_row("sirius").get("action") == "sirius", "炎の粒の被弾と行動の対応")
	effects.add_trail(jet, {"trail_delay": 0.0, "trail_time": 1.0, "trail_width": 30.0, "trail_damage": 4.0})
	jet.trail.length = 200.0
	sim.state.ship_shield_t = 1.0
	effects.tick(0.0)
	check(damage_row("sirius_trail").get("reason") == "shield", "炎の軌跡は盾で防いだ接触も記録")
	actor.cancel_attack()
	effects.clear()
	sim.state.ship_shield_t = 0.0
	sim.state.ship_invuln = 0.0
	check(actor.start_attack(&"nova"), "シリウスの閃光を開始")
	r = actor.rule()
	actor.clock = actor._runner.started + float(r.warn) + 0.01
	sim.state.ship_pos = actor.mouth() + Vector2(30.0 + float(r.ring_speed) * 0.01, 0.0)
	actor._runner.update_effect(actor, 0.0)
	check(damage_row("nova").get("action") == "nova", "閃光の輪の被弾と行動の対応")

	actor.cancel_attack()
	effects.clear()
	actor._spawn_pack()
	check(actor.start_attack(&"stream"), "猟犬の突進を開始")
	var hound: int = actor.led[0]
	actor._runner.launch_hound(actor, hound, 300.0, 1.0, 8.0)
	sim.state.ship_pos = actor.table.pos[hound]
	sim.state.ship_invuln = 0.0
	actor._runner.tick_lunges(actor)
	check(damage_row("stream").get("action") == "stream", "猟犬の突進の被弾と行動の対応")
	actor.cancel_attack()
	check(actor.start_attack(&"blaze"), "猟犬の爆発を開始")
	r = actor.rule()
	effects.ignite(hound, r)
	effects.burning[hound].blink_age = float(r.blink)
	sim.state.ship_pos = actor.table.pos[hound]
	sim.state.ship_invuln = 0.0
	effects._tick_burning(0.01)
	check(damage_row("blaze").get("action") == "blaze", "猟犬の爆発の被弾と行動の対応")

func _test_hydra_major_and_partial_recording() -> void:
	boss(&"hydra")
	actor._set_count(8)
	actor._tech_cd = 0.0
	check(actor.try_start_tech(&"sequence", 1.0), "ヒドラの大技を開始")
	for frame in 720:
		actor.sim_tick(DT, DT)
		if not actor.busy: break
	check(outcome("sequence").get("step") == "completed", "大技の観測を完了する")
	check(events("boss_action").any(func(e): return e.action == "sequence" and e.step == "execute"), "大技の実行段階を保存")
	boss(&"hydra", false)
	actor.necks[0].cd = 0.0
	check(actor.start_normal(0, &"bite_thrust"), "録画前に首の行動を開始")
	begin_recording()
	var at := sim.state.ship_pos
	actor.attack_field.add_shape(PackedVector2Array([at, at + Vector2.RIGHT]), 20.0, 0.0, 1.0, 9.0, &"bite", actor.necks[0].row)
	actor.attack_field.tick(DT)
	var row := damage_row("bite")
	check(row.get("action") == "bite_thrust" and not row.get("observed_start", true) and row.get("action_id") == null, "途中録画は首の行動を保ち、未観測の開始を補わない")
