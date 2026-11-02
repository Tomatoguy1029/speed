## 敵別停止時間、実命中、上限と中断後の再開を実際のランで確認する。
extends Node

var failures := 0
var session: RunSession

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func fresh() -> RunSimulation:
	if session != null: session.free()
	var stage := ContentManager.runtime_stage(1).duplicate(true) as RuntimeStage
	stage.boss_enabled = false
	var cfg := ContentManager.cfg.duplicate(true) as GameConfig
	session = RunManager.create_session(self, {"lab": true, "stage": stage, "config": cfg, "seed": 42}, false)
	session.auto_step = false
	session.sim.input_source = func(): return Intent.new()
	return session.sim

func enemy(sim: RunSimulation, multiplier := 1.0, type := &"drifter") -> int:
	var def := sim.enemies.def_of(type).duplicate(true) as EnemyDef
	def.hitstop_multiplier = multiplier
	var row := sim.enemies.spawn(def, Vector2(2000, 2000))
	sim.enemies.table.r[row] = 20.0
	return row

func kill(sim: RunSimulation, row: int, crit := false) -> void:
	sim.combat.damage_enemy(row, sim.enemies.table.hp[row] + 1.0, {"cause": &"ram", "crit": crit})

func _ready() -> void:
	var sim := fresh()
	for file in DirAccess.get_files_at("res://data/enemies"):
		if file.ends_with(".tres"):
			check(load("res://data/enemies/" + file).hitstop_multiplier == 1.0, "未指定の敵は共通時間を継承: " + file)
	for multiplier in [0.0, 0.1, 1.0, 2.0]:
		sim = fresh()
		var row := enemy(sim, multiplier)
		kill(sim, row)
		check(sim.enemies.table.dead[row] != 0, "停止倍率にかかわらず撃破を処理")
		check(is_equal_approx(sim.state.hitstop, sim.cfg.kill_hitstop * multiplier), "一撃撃破の時間倍率: %s" % multiplier)
		check(is_equal_approx(sim.combat.dash_stop, sim.state.hitstop), "使用予算は要求した停止時間")
	for killed in [false, true]:
		for multiplier in [0.0, 0.5, 1.0]:
			sim = fresh()
			var row := enemy(sim, multiplier)
			sim.enemies.table.r[row] = 30.0
			if killed: kill(sim, row, true)
			else: sim.combat.damage_enemy(row, 0.01, {"cause": &"ram", "crit": true})
			var base := maxf(0.05, sim.cfg.kill_hitstop * sim.cfg.hitstop_big_mult * sim.cfg.hitstop_crit_mult) if killed else 0.035
			check(is_equal_approx(sim.state.hitstop, base * multiplier), "大型・クリティカルの倍率を維持")
			check(is_equal_approx(sim.combat.dash_stop, sim.state.hitstop), "撃破とクリティカルの二重課金を防ぐ")
	sim = fresh()
	var tiny := enemy(sim, 0.1, &"drifter")
	var strong := enemy(sim, 2.0, &"armored")
	kill(sim, tiny)
	var short_stop := sim.state.hitstop
	kill(sim, strong)
	check(sim.state.hitstop > short_stop and is_equal_approx(sim.state.hitstop, sim.cfg.kill_hitstop * 2.0), "同時の異なる種類は最長時間を使う")
	check(is_equal_approx(sim.combat.dash_stop, sim.cfg.kill_hitstop * 2.1), "同時命中の要求合計は予算へ入る")
	for mode in ["zero", "negative", "guard", "locked", "protected", "paused", "gate", "shot", "touch", "bump"]:
		sim = fresh()
		var row := enemy(sim, 2.0)
		if mode == "guard": sim.enemies.table.guard[row] = 1.0
		if mode == "locked": sim.state.controls_locked = true
		if mode == "protected": sim.state.encounter_protected = true
		if mode == "paused": sim.set_phase(RunState.Phase.PAUSED)
		if mode == "gate": sim.enemies.table.gate[row] = EnemyTable.Gate.SOLID
		var cause := StringName(mode) if mode in ["shot", "touch", "bump"] else &"shot" if mode == "gate" else &"ram"
		sim.combat.damage_enemy(row, 0.0 if mode == "zero" else -1.0 if mode == "negative" else 0.01, {"cause": cause, "crit": true})
		check(sim.state.hitstop == 0.0 and sim.combat.dash_stop == 0.0, "拒否された命中・既存対象外の攻撃は停止しない: " + mode)
	sim = fresh()
	sim.state.tracing = true
	for index in 100:
		kill(sim, enemy(sim, 10000.0), true)
	check(is_equal_approx(sim.state.hitstop, sim.cfg.kill_hitstop_cap), "極端な倍率・連続命中も共通上限まで")
	check(is_equal_approx(sim.combat.dash_stop, sim.cfg.kill_hitstop_cap), "要求合計が上限を超えない")
	sim.combat.tick(1.0, 0.0)
	check(is_equal_approx(sim.combat.dash_stop, sim.cfg.kill_hitstop_cap), "突進中は予算を回復しない")
	sim.state.tracing = false
	sim.combat.tick(0.5, 0.0)
	check(is_equal_approx(sim.combat.dash_stop, sim.cfg.kill_hitstop_cap - 0.5 * sim.cfg.kill_hitstop_regen), "既存の予算回復速度を維持")
	sim = fresh()
	sim.combat.dash_stop = sim.cfg.kill_hitstop_cap - 0.001
	kill(sim, enemy(sim))
	check(is_equal_approx(sim.state.hitstop, 0.001), "上限の最後の1回も残量で切り詰める")
	for bad in [-1.0, INF, NAN]:
		sim = fresh()
		kill(sim, enemy(sim, bad))
		check(sim.state.hitstop == 0.0, "不正な倍率で停止が残らない")
	sim = fresh()
	sim.cfg.kill_hitstop_cap = 0.0
	kill(sim, enemy(sim, 2.0), true)
	check(sim.state.hitstop == 0.0, "ゼロ上限で除算せず停止を無効化")
	_check_collision()
	_check_lifecycle()
	_check_boss()
	session.free()
	await get_tree().process_frame
	print("[enemy_hitstop] failures=", failures)
	get_tree().quit(1 if failures else 0)

func _check_collision() -> void:
	for mode in ["scaled", "zero", "guard", "disabled", "blocked"]:
		var sim := fresh()
		var row := enemy(sim, 0.0 if mode == "zero" else 0.2)
		var t := sim.enemies.table
		t.pos[row] = Vector2(500, 500)
		t.weak_arc[row] = PI
		t.armor[row] = 0.0
		t.hp[row] = 10000.0
		t.max_hp[row] = 10000.0
		if mode == "guard": t.guard[row] = 1.0
		if mode == "blocked": t.gate[row] = EnemyTable.Gate.SOLID
		if mode == "disabled": sim.state.hitstop_enabled = false
		sim.state.ship_pos = Vector2(550, 500)
		sim.state.ship_vel = Vector2(1000, 0)
		sim.state.glide = true
		sim.combat.rebuild_grid()
		sim.combat.collide_ship(Vector2(450, 500), sim.cfg.ship_radius, null)
		check(is_equal_approx(sim.state.hitstop, 0.007 if mode == "scaled" else 0.0), "実際の接触経路で停止倍率と拒否を適用: " + mode)

func _check_lifecycle() -> void:
	var sim := fresh()
	var engine_scale := Engine.time_scale
	kill(sim, enemy(sim, 2.0))
	var world := sim.state.world_time
	sim._play_tick(0.02)
	check(sim.state.world_time == world and sim.state.hitstop > 0.0, "実時間で停止を消費し、世界時間を止める")
	sim._play_tick(1.0)
	check(sim.state.hitstop == 0.0, "停止残量をゼロに収める")
	sim._play_tick(0.02)
	check(sim.state.world_time > world, "期限後に世界更新が再開する")
	check(Engine.time_scale == engine_scale, "Engine.time_scaleを変更しない")
	for phase in [RunState.Phase.PAUSED, RunState.Phase.LEVELUP, RunState.Phase.DYING, RunState.Phase.FINISHING, RunState.Phase.ENDED]:
		sim = fresh()
		kill(sim, enemy(sim))
		sim.set_phase(phase)
		check(sim.state.hitstop == 0.0, "PLAYを離れると停止を解除: %s" % phase)
	sim = fresh()
	kill(sim, enemy(sim))
	sim.command(&"pause")
	sim.command(&"resume")
	sim._play_tick(0.02)
	check(sim.state.hitstop == 0.0 and sim.state.world_time > 0.0, "ポーズ再開に停止を持ち越さない")
	for mode in ["locked", "protected", "disabled", "abort", "dispose"]:
		sim = fresh()
		kill(sim, enemy(sim))
		match mode:
			"locked": sim.state.controls_locked = true; sim._play_tick(0.02)
			"protected": sim.state.encounter_protected = true; sim._play_tick(0.02)
			"disabled": sim.options.hitstop = false; sim._read_settings()
			"abort": sim.command(&"abort")
			"dispose": sim.dispose()
		check(sim.state.hitstop == 0.0, "停止中の割り込みで残量を解除: " + mode)

func _check_boss() -> void:
	var sim := fresh()
	var def := load("res://data/bosses/draco.tres").duplicate(true) as BossDef
	def.hitstop_multiplier = 0.0
	sim.bosses.spawn(def, Vector2.ZERO)
	var actor := sim.bosses.actor
	actor.set("selection_enabled", false)
	sim.state.controls_locked = false
	sim.state.encounter_protected = false
	sim.enemies.table.guard[actor.body] = 0.0
	sim.combat.damage_enemy(actor.body, 1.0, {"cause": &"ram", "crit": true})
	check(sim.state.hitstop == 0.0 and actor.hit_feedback.sample(actor.body_id).white > 0.0, "ボスの停止なしでも白色化は独立して発生")
	def.hitstop_multiplier = 2.0
	sim.combat.damage_enemy(actor.body, 1.0, {"cause": &"ram", "crit": true})
	check(is_equal_approx(sim.state.hitstop, 0.07), "EnemyDefを持たないボスはBossDefの倍率を使う")
