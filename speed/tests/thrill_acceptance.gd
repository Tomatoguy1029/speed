## スリルと寄り道の受け入れ確認。セーブはメモリだけで扱う。
## Godot --headless --log-file /tmp/speed-acceptance.log --path speed res://tests/thrill_acceptance.tscn
extends Node

class MemorySave:
	extends "res://scripts/managers/save_manager.gd"
	func save() -> void:
		save_changed.emit()
	func _save_settings() -> void:
		pass

var scene: RunSession
var run: RunSimulation
var passed := 0
var failed := 0
var shots := ""

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			shots = arg.trim_prefix("--out=")
	if shots != "" and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(shots)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	var settings: Dictionary = SaveManager.settings.duplicate(true)
	var saved_data: Dictionary = SaveManager.data
	var save_script: Script = SaveManager.get_script()
	SaveManager.set_script(MemorySave)
	SaveManager.data = SaveManager.default_data()
	SaveManager.data.intro_seen = true
	SaveManager.settings = settings
	await _test_debug_stage_selection()
	await _start(4)
	_test_head_world_steps()
	await _close()
	await _start(4)
	_test_immortal_hit()
	await _close()
	await _start(4)
	_test_fire_regrowth()
	run.command(&"debug_kill_boss")
	_check(run.state.boss_dead, "タスク20・調整機能：倒し方を持つボスも撃破コマンドで倒せる")
	await _close()
	await _start(1)
	_test_foundation()
	_test_surge()
	_test_shapes()
	_test_enemy_roster()
	_test_enemy_gates()
	await _close()
	await _start(1)
	await _test_field()
	await _close()
	for stage in range(1, 5):
		await _start(stage)
		await _test_hero()
		await _shot("hero_%d" % stage)
		await _close()
	await _start(1)
	await _test_landmarks()
	await _shot("endless_next_hero")
	await _close()
	await _start(4)
	await _test_hydra_attacks()
	await _test_hydra_techniques()
	_test_hydra_fire()
	await _close()
	await _test_app_flow()
	for player: AudioStreamPlayer in AudioManager._players:
		player.stop()
		player.stream=null
	await get_tree().process_frame
	await get_tree().process_frame
	SaveManager.set_script(save_script)
	SaveManager.data = saved_data
	SaveManager.settings = settings
	print("[acceptance] passed=%d failed=%d" % [passed, failed])
	# 音声スレッドが停止要求を消費してから、実行体を終了する。
	await get_tree().create_timer(maxf(0.05,AudioServer.get_output_latency()*2.0)).timeout
	get_tree().quit(1 if failed else 0)

func _test_debug_stage_selection() -> void:
	_check(OS.is_debug_build(), "ステージ選択：開発版で確認する")
	_check(SaveManager.is_stage_unlocked(1), "ステージ選択：通常の進行では最初にステージ1が開く")
	for stage in range(2, ContentManager.stage_count() + 1):
		_check(not SaveManager.is_stage_unlocked(stage), "ステージ選択：ステージ%dのクリア記録は未解放のまま" % stage)
	_check(not SaveManager.is_stage_unlocked(0) and not SaveManager.is_stage_unlocked(6), "ステージ選択：存在しないステージは選べない")
	# ここは導入後の選択を検証する。未視聴・再生・練習はintro_flowの受け入れで扱う。
	SaveManager.data = SaveManager._migrate({"version": 1, "intro_seen": true, "cleared_stage": 0, "coins": 123}, SaveManager.default_data())
	var app: Node = load("res://scenes/app/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	for stage in range(1, ContentManager.stage_count() + 1):
		GameManager.goto(GameManager.Screen.STAGE_SELECT)
		await _settle_screen()
		var map = app._current._map
		map._select(stage - 1)
		_check(not map._launch.disabled, "開発版でステージ%dを選べる" % stage)
		map._launch.pressed.emit()
		await _settle_screen()
		if app._current is RunSession:
			var initial_run: RunSimulation = app._current.sim
			app._current.auto_step = false
			_check(initial_run.state.stage.index == stage and initial_run.state.time == 0.0 and initial_run.state.phase == RunState.Phase.LEVELUP, "ステージ選択：ステージ%dを0秒の武器選択から開始する" % stage)
			await _shot("debug_stage_%d_start" % stage)
			initial_run.command(&"choose_card", {"index": 0})
			_check(initial_run.state.phase == RunState.Phase.PLAY and initial_run.state.stage.boss_id == (&"hydra" if stage==4 else &"monoceros" if stage==1 else &"draco" if stage==5 else &""), "ステージ選択：ステージ%dの通常ランと対応ボスを使う" % stage)
			GameManager.abort_run()
			await _settle_screen()
	_check(SaveManager.data.cleared_stage == 0 and SaveManager.coins() == 123 and SaveManager.data.best.runs == 0, "ステージ選択：全ステージを試しても既存の部品とクリア記録を保つ")
	app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	SaveManager.data = SaveManager.default_data()
	SaveManager.data.intro_seen = true

func _start(stage: int) -> void:
	ContentManager.reset_runtime()
	SaveManager.data = SaveManager.default_data()
	SaveManager.data.intro_seen = true
	GameManager.run_stage = stage
	GameManager.run_endless = false
	scene = RunManager.create_run()
	# 行動単体の確認では、そのステージに登場しない敵も配置する。
	# 通常ランの資源境界を保ち、fixtureが使う追加の外観を開始前にScopeへ渡す。
	var extra := ContentManager.prepare_resources(PackedStringArray(ContentManager.visual_index.look_paths.values()), false)
	_check(extra.is_ready() and not extra.failed, "行動fixture：ステージ外の敵外観も事前に準備する")
	for path in extra.resources:
		scene.resources.provide(path, extra.resources[path])
	extra.cancel()
	add_child(scene)
	if scene.sim.state == null: await scene.started
	run = scene.sim
	for path: String in ContentManager.visual_index.look_paths.values():
		run.ctx.resources.provide(path, load(path))
	run.state.stage = run.state.stage.duplicate()
	scene.auto_step = false
	run.input.set_process_input(false)
	run.input.set_process_unhandled_input(false)
	await get_tree().process_frame
	run.command(&"choose_card", {"index": 0})
	run.loadout.reset_loadout()
	run.state.hitstop_enabled = false
	run.state.rng.seed = 401
	run.enemies.clear_all()
	run.field.bodies.clear()
	run.field.moons.clear()
	run.field.rocks.clear()
	run.field.setup(run.ctx)
	run.heroes.setup(run.ctx)
	run.state.ship_vel = Vector2.ZERO
	_clear()

func _close() -> void:
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _clear() -> void:
	run.enemies.clear_regular()
	run.enemies.cleanup()
	run.projectiles.clear_hostile()
	run.projectiles.friend_slots.clear()
	run.field.wells.clear()
	run.combat.rebuild_grid()
	run.state.events.clear()
	run.state.phase = RunState.Phase.PLAY
	run.state.ship_invuln = 0.0
	run.state.ship_vel = Vector2.ZERO
	run.state.ship_hp = run.state.stats.max_hp

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("[acceptance] OK ", label)
	else:
		failed += 1
		push_error("[acceptance] FAIL " + label)

func _test_fire_regrowth() -> void:
	run.bosses.spawn()
	var boss=run.bosses.actor
	boss.hsm.set_active(false)
	run.state.world_time=10.0
	for neck in boss.necks:
		run.combat.damage_enemy(neck.row,100000.0,{"cause":&"fire","no_crit":true})
	run.enemies.cleanup()
	boss.sim_tick(0.01,0.01)
	_check(boss.chance_t>0.0,"全頭を倒すと中央のチャンスタイムになる")
	_check(boss.necks.all(func(n):return n.burned and n.regrow>float(boss.def.params.regrow)),"火は倒れた頭の再生待ち時間を延ばす")
	boss.sim_tick(float(boss.def.params.chance_time)+0.1,float(boss.def.params.chance_time)+0.1)
	_check(boss.necks.all(func(n):return boss._alive(n)),"全頭ダウンのチャンスタイム後は頭が戻る")
	run.enemies.table.hp[boss.body]=run.enemies.table.max_hp[boss.body]*0.74
	boss.sim_tick(0.01,0.01)
	_check(boss.count==5 and boss.necks.all(func(n):return boss._alive(n) and not n.burned),"HP段階の増加は全首を回復する")

func _enemy(type: StringName, at: Vector2) -> int:
	return run.enemies.spawn(run.enemies.def_of(type), at)

func _test_foundation() -> void:
	var s := run.state
	var t := run.enemies.table
	s.stats.crit_chance = 0.0
	var from := s.ship_pos
	var i := _enemy(&"beamer", from + Vector2(50, 0))
	t.hp[i] = 1000.0
	s.ship_vel = Vector2(10, 0)
	s.ship_pos = from + Vector2(80, 0)
	run.combat.rebuild_grid()
	var hp := s.ship_hp
	run.combat.collide_ship(from, run.cfg.ship_radius, null)
	_check(t.hp[i] < 1000.0 and s.ship_hp == hp, "タスク1：普段の接触で敵だけが傷つく")
	_clear()
	i = _enemy(&"beamer", from + Vector2(50, 0))
	t.armor[i] = 1e9
	s.ship_pos = from + Vector2(80, 0)
	s.ship_vel = Vector2(s.stats.max_speed * 2, 0)
	run.combat.rebuild_grid()
	_check(run.combat.collide_ship(from, run.cfg.ship_radius, TraceRun.new()) and s.ship_hp == hp, "タスク1：装甲に弾かれても被弾しない")
	_clear()
	i = _enemy(&"pump", from + Vector2(50, 0))
	s.ship_pos = from + Vector2(80, 0)
	t.hp[i] = 1000.0
	run.combat.rebuild_grid()
	run.combat.collide_ship(from, run.cfg.ship_radius, TraceRun.new())
	_check(t.hp[i] < 1000.0 and s.ship_hp == hp, "ポンプ座への接触で敵だけが傷つく")
	s.ship_pos = run.field.planet.pos + Vector2(run.field.planet.r, 0)
	s.ship_vel = Vector2(-100, 0)
	run.ship._collide_bodies()
	_check(s.ship_vel.x > 0 and s.ship_hp == hp, "タスク1：惑星は被弾せず跳ね返る")
	var expected := ContentManager.runtime_stage(1)
	# runtime_stage()は独立したResourceを返す。参照同一性でなく、実際に使う構成を照合する。
	var phases := func(stage: RuntimeStage) -> Array:
		return stage.phases.map(func(p): return [p.id, p.start, p.mix, p.attack_budget])
	var curves := func(stage: RuntimeStage) -> Array:
		return stage.zako_curves.map(func(c): return [c.type, c.points])
	var clips := func(stage: RuntimeStage) -> Array:
		return stage.clips.map(func(c): return [c.time, c.length, c.types, c.groups, c.interval])
	_check(phases.call(s.stage) == phases.call(expected) and curves.call(s.stage) == curves.call(expected) \
		and clips.call(s.stage) == clips.call(expected) and not s.stage.zako_curves.is_empty() and not s.stage.clips.is_empty(),
		"ステージ1：専用の時間帯・種類別曲線・強敵クリップを通常ランへ引き継ぐ")
	s.time = s.stage.boss_start(run.cfg) - 0.01
	run.bosses.tick(0.0, 0.0)
	_check(not s.boss_spawned and is_equal_approx(s.boss_at, s.stage.boss_time), "ボス時刻：ステージ指定時刻の直前までは出現しない")
	s.time = s.boss_at
	run.bosses.tick(0.0, 0.0)
	_check(s.boss_spawned, "タスク3：出現時刻にボスが現れる")
	_test_boss_time_fallback()
	s.time = 36000.0
	run._check_end()
	_check(s.phase == RunState.Phase.PLAY, "タスク3：時間切れで終了しない")
	s.time = 599.0
	var before: Dictionary = run.spawn.target()
	s.time = 660.0
	var after: Dictionary = run.spawn.target()
	_check(after.pop > before.pop and run.spawn.surge_steps() > 1, "タスク4：10分以降の波は段階ごとに大きくなる")

func _test_boss_time_fallback() -> void:
	for enabled in [true, false]:
		var stage := run.state.stage.duplicate() as RuntimeStage
		stage.boss_time = -1.0
		stage.boss_enabled = enabled
		var session := RunManager.create_session(self, {"lab": true, "seed": 271, "stage": stage}, false)
		session.auto_step = false
		var sim := session.sim
		sim.bosses.tick(0.0, 0.0)
		if enabled:
			_check(sim.state.boss_at >= sim.cfg.boss_time and sim.state.boss_at <= sim.cfg.boss_time + sim.cfg.boss_time_spread,
				"ボス時刻：ステージ指定が負なら共通設定の範囲から決める")
			sim.state.time = sim.state.boss_at - 0.01
			sim.bosses.tick(0.0, 0.0)
			_check(not sim.state.boss_spawned and sim.bosses.actors.is_empty(), "ボス時刻：共通設定でも直前までは出現しない")
			sim.state.time = sim.state.boss_at
			sim.bosses.tick(0.0, 0.0)
			sim.bosses.tick(0.0, 0.0)
			_check(sim.state.boss_spawned and sim.bosses.actors.size() == 1, "ボス時刻：境界到達で1体だけ出現する")
		else:
			sim.state.time = sim.cfg.boss_time + sim.cfg.boss_time_spread + 1.0
			sim.bosses.tick(0.0, 0.0)
			_check(not sim.state.boss_spawned and sim.bosses.actors.is_empty(), "ボス時刻：無効なステージでは予定時刻を超えても出現しない")
		session.free()

func _test_shapes() -> void:
	_clear()
	var s := run.state
	var p := run.projectiles
	var at := Vector2(-2000, -2000)
	s.ship_pos = at + Vector2(80, 0)
	var hp := s.ship_hp
	p.fire_beam(at, 0, 200, 20, 0.2, 0.3, 2)
	p._update_hazards(0.1)
	_check(s.ship_hp == hp, "タスク5：ビームの予告中は被弾しない")
	p._update_hazards(0.11)
	_check(s.ship_hp < hp, "タスク5：予告後のビームは被弾する")
	_clear()
	hp = s.ship_hp
	p.fire_zone(s.ship_pos, 40, 0.2, 2)
	p._update_hazards(0.1)
	_check(s.ship_hp == hp, "タスク5：範囲攻撃は照準のあとに弾ける")
	p._update_hazards(0.11)
	_check(s.ship_hp < hp, "タスク5：弾けた範囲で被弾する")
	_clear()
	hp = s.ship_hp
	s.ship_pos = at + Vector2(80, 0)
	p.fire_wave(at, 0, PI, 200, 100, 10, 0, 2, 0, 0.3)
	p._update_hazards(0.8)
	_check(s.ship_hp == hp, "タスク6：広がる輪の切れ目を抜けられる")
	s.ship_pos = at + Vector2(-90, 0)
	p._update_hazards(0.1)
	_check(s.ship_hp < hp, "タスク6：輪の帯に触れると被弾する")
	_clear()
	hp = s.ship_hp
	p.fire_wall(at, 0, 200, 20, 0, 0.3, 2)
	s.ship_pos = at + Vector2(80, 0)
	p._update_hazards(0.1)
	_check(s.ship_hp < hp, "タスク6：残る線に触れると被弾する")
	p._update_hazards(0.3)
	_check(p.hazard_count() == 0, "タスク6：残る線は時間で消える")
	p.fire_cross(at, 0, 200, 20, 0.2, 0.3, 2)
	_check(p.hazard_count() == 4, "タスク5：十字ビームは4方向に予告つきで出る")
	p.clear_hostile()
	p.fire_rings(at, 4, 0.3, 200, 100, 10, 0.2, 2, 0, 0.3, 0.5)
	_check(p.hazard_count() == 4 and p.hazard_gap[0] != p.hazard_gap[1] and p.hazard_delay[0] != p.hazard_delay[1], "タスク6：多層の輪は切れ目と広がる時刻がずれる")

const IMPLEMENTED_ROSTERS := {
	1: "rocket,bomber,beamer,pulser,pump,telescope,shield,ruler,clock",
	2: "rocket,bomber,volatile,splitter,beamer,missile,pump,crow,lynx,reticle,dolphin",
	3: "rocket,bomber,volatile,beamer,spreader,triangle,lynx,cross,reticle,ruler,phoenix",
	4: "rocket,volatile,splitter,pulser,missile,spreader,triangle,crow,crab,dolphin,marlin,aquarius",
	5: "rocket,bomber,volatile,splitter,beamer,pulser,missile,spreader,shield,cross,auriga,corona,cepheus,aquila"
}

const ORIGINAL_ROSTER := "drifter,swarm,darter,armored,gunner,missile,splitter,splitling,titan,battleship"
const ROSTERS := {1: ORIGINAL_ROSTER, 2: ORIGINAL_ROSTER, 3: ORIGINAL_ROSTER, 4: ORIGINAL_ROSTER, 5: ORIGINAL_ROSTER}

func _advance_enemies(seconds: float) -> Dictionary:
	# 行動単体の検証では予算を外す。予算はattack_priorityで別途確認する。
	run.projectiles.director.configure({"enabled": false})
	var peaks := {"hazards": 0, "hostile": 0, "wells": 0}
	for k in ceili(seconds / 0.05):
		run.state.world_time += 0.05
		run.projectiles.director.advance(run.state.world_time,run.enemies)
		run.enemies.tick(0.05, 0.05)
		run.combat.rebuild_grid()
		run.projectiles.tick(0.05, 0.05)
		peaks.hazards = maxi(peaks.hazards, run.projectiles.hazard_count())
		peaks.hostile = maxi(peaks.hostile, run.projectiles.hostile_count())
		peaks.wells = maxi(peaks.wells, run.field.wells.size())
	return peaks

func _test_enemy_roster() -> void:
	for stage in range(1, ContentManager.stage_count() + 1):
		for id in _stage_types(ContentManager.stage(stage)):
			_check(ContentManager.enemies.has(StringName(id)), "ステージ%dの出現種類%sに定義がある" % [stage, id])
	var all_types: Array[StringName] = []
	for roster in IMPLEMENTED_ROSTERS.values():
		for id in roster.split(","):
			if not all_types.has(StringName(id)):
				all_types.append(StringName(id))
	all_types.append(&"splitling")
	_check(all_types.size() == 28, "タスク7〜12：分裂体を含め通常敵28種類")
	run.state.time = 1.0
	run.ship.invincible = true
	for type in all_types:
		_clear()
		run.state.ship_pos = Vector2(-2000, -2000)
		run.state.enemy_aim = run.state.ship_pos
		var i := _enemy(type, run.state.ship_pos + Vector2(180, 0))
		var t := run.enemies.table
		var from := t.pos[i]
		t.fire_t[i] = 0.01
		if type == &"pump":
			t.buds[i] = int(t.def[i].params.store_max)
		if type == &"crow":
			for n in 4:
				var food := _enemy(&"splitling", t.pos[i] + Vector2(0, n * 5))
				run.combat.kill_enemy(food, {"cause": &"test"})
		var peaks := _advance_enemies(14.0)
		if type in [&"volatile", &"splitter", &"splitling"]:
			_check(t.dead[i] != 0 or t.pos[i].distance_to(from) > 1, "タスク7〜12：%sが追ってくる" % type)
		elif type == &"shield":
			_check(absf(t.facing[i]) > 0.5, "タスク8：たて座は機体に向き直る")
		elif type == &"corona":
			_check(t.parts[i].is_empty() and t.pos[i].distance_to(from) > 50, "かんむり座は弾薬が空でも接近を続ける")
		elif type == &"cepheus":
			_check(run.state.events.any(func(e): return e.type == &"cepheus_summon"), "タスク12：ケフェウス座は予告して号令する")
		elif type == &"crow":
			_check(t.dead[i] != 0 or t.pos[i].distance_to(from) > 1, "からす座は群れで横断して退場する")
		elif type == &"reticle":
			_check(t.dead[i] != 0 or t.mode[i] == EnemyTable.Mode.DASH, "支援先のいないレチクル座は退却する")
		elif type == &"aquarius":
			_check(peaks.hazards > 0, "みずがめ座は広がる水流の当たりを出す")
		else:
			_check(peaks.hazards > 0 or peaks.hostile > 0 or peaks.wells > 0, "タスク7〜12：%sが固有の攻撃を出す" % type)
	_clear()
	var first := _enemy(&"volatile", run.state.ship_pos)
	var second := _enemy(&"volatile", run.state.ship_pos + Vector2(10, 0))
	var third := _enemy(&"splitling", run.state.ship_pos + Vector2(25, 0))
	run.combat.rebuild_grid()
	run.ship.invincible = false
	var hp := run.state.ship_hp
	run.combat.kill_enemy(first, {"cause": &"test"})
	_advance_enemies(1.0)
	_check(run.enemies.table.dead[second] != 0 and run.enemies.table.dead[third] != 0 and run.state.ship_hp < hp, "タスク7：誘爆は敵と機体を巻き込み連鎖する")
	_clear()
	var splitter := _enemy(&"splitter", run.state.ship_pos)
	run.combat.kill_enemy(splitter)
	_advance_enemies(0.05)
	run.enemies.cleanup()
	var children := 0
	for i in run.enemies.table.alive.size():
		if run.enemies.table.alive[i] and not run.enemies.table.dead[i] and run.enemies.table.type[i] == &"splitling":
			children += 1
	_check(children >= 2 and children <= 3, "タスク7：分裂後は2〜3体の分裂体が残る")

func _ram(at: Vector2, direction: Vector2, approach := 100.0) -> bool:
	_resume_for_check()
	run.state.ship_pos = at + direction * 100.0
	run.state.ship_vel = direction * run.state.stats.max_speed * 2.0
	run.combat.rebuild_grid()
	return run.combat.collide_ship(at - direction * approach, run.cfg.ship_radius, TraceRun.new())

func _test_enemy_gates() -> void:
	var t := run.enemies.table
	var at := Vector2(-2000, -2000)
	run.state.stats.attack_mult = 1000.0
	_clear()
	var shield := _enemy(&"shield", at)
	_check(_ram(at, Vector2.LEFT) and not t.dead[shield], "たて座：正面は弾かれる")
	_check(not _ram(at, Vector2.RIGHT) and t.dead[shield] != 0, "たて座：背面は貫ける")
	for direction in [Vector2.LEFT, Vector2.RIGHT]:
		_clear()
		var row := _enemy(&"crab", at)
		_check(not _ram(at, direction) and t.dead[row] != 0, "かに座：正面・背面とも通常の突進で倒せる: " + str(direction))
	_clear()
	var pump := _enemy(&"pump", at)
	_check(not _ram(at, Vector2.RIGHT) and t.dead[pump] != 0, "ポンプ座は通常の突進で倒せる")
	_clear()
	var lynx := _enemy(&"lynx", at)
	_check(not _ram(at, Vector2.RIGHT) and t.dead[lynx] != 0, "やまねこ座は通常の突進で倒せる")
	_clear()
	var triangle := _enemy(&"triangle", at)
	var triangles := run.enemies.behavior(&"triangle")
	triangles.step(triangle, 0.01)
	var parts := t.parts[triangle].duplicate()
	_check(run.enemies.parts_alive(triangle) == 3 and run.projectiles.hazard_count() == 0 \
		and run.enemies.gate_check(triangle, at, Vector2.RIGHT, &"ram") == EnemyTable.GateResult.PASS,
		"三角：停止中は3頂点を持ち、中心の当たりと膜を持たない")
	triangles._start_travel(triangle)
	_check(run.projectiles.hazard_count() == 3, "三角：頂点が移動し始めると3本の軌跡を出す")
	for k in range(0, parts.size(), 2):
		_check(run.enemies.gate_check(parts[k], t.pos[parts[k]], Vector2.RIGHT, &"ram") == EnemyTable.GateResult.PASS,
			"三角：移動中の頂点には攻撃が通らない")
	triangles.step(triangle, float(t.def[triangle].params.move_time) + 0.01)
	_check(run.projectiles.hazard_count() == 0, "三角：移動が終わると軌跡を消す")
	for k in range(0, parts.size(), 2):
		_check(run.enemies.gate_check(parts[k], t.pos[parts[k]], Vector2.RIGHT, &"ram") == EnemyTable.GateResult.ALLOW,
			"三角：止まった頂点には通常攻撃が通る")
	run.combat.damage_enemy(parts[0], 1e6, {"cause": &"shot", "no_crit": true})
	triangles.after_tick(0.01)
	_check(run.enemies.parts_alive(triangle) == 2 and not t.dead[triangle], "三角：1頂点を倒しても残る2頂点と中心が生存する")
	for k in range(2, parts.size(), 2):
		run.combat.damage_enemy(parts[k], 1e6, {"cause": &"shot", "no_crit": true})
	triangles.after_tick(0.01)
	_check(run.enemies.parts_alive(triangle) == 0 and t.dead[triangle] != 0, "三角：全頂点を倒すと中心も崩壊する")
	run.enemies.cleanup()
	_check(t.alive[triangle] == 0 and t.alive[parts[0]] == 0 and t.alive[parts[2]] == 0 and t.alive[parts[4]] == 0,
		"三角：崩壊後は中心と全頂点の行を回収する")
	_clear()
	var crab := _enemy(&"crab", at)
	_check(not _ram(at, Vector2.LEFT) and t.dead[crab] != 0, "かに座は通常時も正面から攻撃できる")
	_clear()
	crab=_enemy(&"crab",at)
	t.mode[crab] = EnemyTable.Mode.RECOVER
	_check(not _ram(at, Vector2.LEFT) and t.dead[crab] != 0, "タスク11：かに座の挟んだ直後は正面から倒せる")
	_clear()
	var corona := _enemy(&"corona", at)
	var star := _enemy(&"drifter", at + Vector2(0, 100))
	run.combat.rebuild_grid()
	run.enemies.behavior(&"corona").after_tick(0.01)
	_check(run.enemies.behavior(&"corona").vortex.members.has(star), "かんむり座は実在する雑魚を渦に捕捉する")
	run.combat.damage_enemy(star, 1e6, {"cause": &"shot", "no_crit": true})
	_check(t.dead[star] != 0 and not run.enemies.behavior(&"corona").vortex.members.has(star), "武器で雑魚を倒すと投擲の弾薬が減る")
	_ram(at, Vector2.RIGHT, 400.0)
	_check(t.dead[corona] != 0, "かんむり座の本体を通常の体当たりで貫ける")
	_clear()
	var king := _enemy(&"cepheus", at)
	var ruler := _enemy(&"ruler", at + Vector2(60, 0))
	t.fire_t[ruler] = 100.0
	t.fire_t[king] = 0.01
	run.combat.rebuild_grid()
	_advance_enemies(2.0)
	_check(run.projectiles.hazard_count() > 0, "タスク12：王の号令で近くの強敵が攻撃する")
	run.state.stats.attack_mult = 1.0

func _line(points: PackedVector2Array) -> void:
	var it := Intent.new()
	it.pen = points[0]
	it.press = true
	run.draw.intent = it
	run.draw.handle_input()
	for k in range(1, points.size()):
		it = Intent.new()
		it.pen = points[k]
		it.has_cursor = true
		run.draw.intent = it
		run.draw.handle_input()
	it.press = true
	run.draw._first_point_msec -= ceili(run.cfg.draw_confirm_delay * 1000.0)
	run.draw.handle_input()

func _test_field() -> void:
	var s := run.state
	var t := run.enemies.table
	var f := run.field
	var p := run.projectiles
	var at := Vector2(-2000, -2000)
	for direction in 32:
		var candidate := Vector2.from_angle(TAU * direction / 32.0) * run.cfg.field_radius * 0.7
		if f.body_gap(candidate, 700.0) > 0.0:
			at = candidate
			break
	s.ship_pos = at
	s.view_center = at
	f.rocks.clear()
	run.enemies.clear_all()
	f.gimmick(&"meteors")._add_rock(s.rng, at + Vector2(100, 0), &"iron", Vector2.ZERO)
	var iron = f.rocks[-1]
	f.gimmick(&"meteors")._add_rock(s.rng, at + Vector2(100, 200), &"saw", Vector2.ZERO)
	var saw = f.rocks[-1]
	f.gimmick(&"meteors")._stream_t = 0.0
	f.gimmick(&"meteors")._stream_rocks(0.01)
	var hp := s.ship_hp
	_check(_ram(t.pos[iron.row], Vector2.RIGHT) and s.ship_hp == hp and not t.dead[iron.row], "タスク13：鉄のがれきは弾いて火花を出す")
	var target := _enemy(&"splitling", t.pos[saw.row] + Vector2(200, 0))
	var row: int = saw.row
	_ram(t.pos[row], Vector2.RIGHT)
	_check(t.dead[row] != 0 and p.friend_count() > 0, "タスク13：丸鋸は進んでいた向きへ飛び、一度で壊れる")
	run.combat.rebuild_grid()
	_resume_for_check()
	p._update_friendly(0.5)
	_check(t.dead[target] != 0, "タスク13：飛んだ丸鋸はその先の敵を巻き込む")
	f.gimmick(&"meteors")._stream_rocks(0.01)
	_check(saw.destroyed, "タスク13：使った丸鋸は再出現しない")
	_clear()
	s.ship_pos = at + Vector2(200, 0)
	s.world_time = 10.0
	f.gimmick(&"gravity")._well_t = 1e6
	f.add_well(at, 3.0, 600.0, 1000.0)
	var enemy := _enemy(&"splitling", at + Vector2(180, 0))
	p.fire_enemy(enemy, 0, 100, &"bullet")
	var bullet := 0
	var old_velocity := p.hostile_vel[bullet]
	f.gimmick(&"gravity")._tick_wells(0.1)
	_check(s.ship_vel.x < 0 and t.vel[enemy].x < 0 and p.hostile_vel[bullet].x < old_velocity.x, "タスク14：重力は遅い機体・敵・敵弾の進路を曲げる")
	s.ship_vel = Vector2(10000, 0)
	f.gimmick(&"gravity")._tick_wells(0.1)
	_check(s.ship_vel == Vector2(10000, 0), "タスク14：高速の機体には重力が効かない")
	s.world_time = 13.1
	f.gimmick(&"gravity")._tick_wells(0.1)
	_check(f.wells.is_empty(), "タスク14：重力は寿命で消える")
	_clear()
	s.time = 240.0
	run.ship.invincible = true
	s.view_center = at
	s.ship_pos = at
	run.input._touch = true
	run.command(&"debug_warp")
	_check(f.warp_gone > s.world_time and f.warp_pos.distance_to(s.view_center) > 100, "タスク15：ワープホールは画面の端の近くに現れる")
	s.ship_pos = f.warp_pos
	run._play_tick(0.01)
	_check(s.bonus_t == run.cfg.bonus_time and f.warp_gone < 0, "タスク15：ホールに触れるとボーナスへ入る")
	var clock := s.time
	_line(PackedVector2Array([at, at + Vector2(300, 0)]))
	_check(s.tracing and s.gauge == 1.0, "タスク15：ボーナスは放つとゲージが満タンになる")
	for tick in ceili(run.cfg.bonus_time / 0.1) + 2:
		if s.bonus_t <= 0.0:
			break
		_resume_for_check()
		run._play_tick(0.1)
		if s.phase == RunState.Phase.LEVELUP:
			await _choose_for_check()
		if tick == 150:
			var valid := true
			var population := 0
			for bonus_row in t.alive.size():
				if t.alive[bonus_row] and not t.dead[bonus_row] and t.meteor_index[bonus_row] < 0 and t.def[bonus_row] != null:
					population += 1
					valid = valid and t.def[bonus_row].max_alive == 0
			_check(valid and population > 0, "タスク15：ボーナスには雑魚と硬めの敵が実際に出現する")
	_check(s.time == clock and s.bonus_t == 0, "タスク15：時計を止めたまま30秒で通常フィールドへ戻る")
	run._play_tick(0.1)
	_check(s.time > clock, "タスク15：戻ったあとはランの時計が進む")

func _finish_trace() -> void:
	for tick in 500:
		_resume_for_check()
		if not run.state.tracing and not run.state.twin_tracing:
			break
		run.draw.tick(0.01, 0.01)
		run.heroes.tick(0.01, 0.01)

func _test_hero() -> void:
	var h := run.heroes
	var s := run.state
	var t := run.enemies.table
	var def := h.hero
	_check(def != null and def.stage == s.stage_index, "タスク16：ステージ%dの英雄が配置される" % s.stage_index)
	_check(h.center.length() > run.cfg.field_radius * 0.7, "タスク16：英雄はフィールドの端に配置される")
	# 護衛の条件を満たす出現定義を持つステージを、独立したfixtureとして用意する。
	var guard_phase: PhaseDef = s.stage.phases[0].duplicate(true)
	guard_phase.mix[&"telescope"] = 1.0
	var guard_def: EnemyDef = ContentManager.enemies[&"telescope"].duplicate(true)
	guard_def.max_alive = 4
	run.enemies.definitions[&"telescope"] = guard_def
	s.stage.phases[0] = guard_phase
	s.ship_pos = h.center
	s.view_center = h.center
	h.tick(0.01, 0.01)
	var guards := 0
	for i in t.alive.size():
		if t.alive[i] and not t.dead[i] and t.def[i] != null and t.def[i].max_alive > 0 and t.def[i].radius < 50.0:
			guards += 1
	_check(guards == run.cfg.hero_guards, "タスク16：そのステージの強敵が英雄を守る")
	_clear()
	for k in range(0, def.links.size(), 2):
		var a := h.stars[def.links[k]]
		var b := h.stars[def.links[k + 1]]
		var u := (b - a).normalized()
		s.gauge = 1.0
		_line(PackedVector2Array([a - u * 80, b + u * 80]))
		_finish_trace()
	_check(not h.is_captive() and s.hero_power == def.id and h.lit.count(1) == h.lit.size(), "タスク16：星座の線を全部なぞって%sを解放できる" % def.id)
	s.ship_pos = h.center
	s.view_center = h.center
	s.ship_vel = Vector2.ZERO
	s.glide = false
	var victim := _enemy(&"shield" if def.id == &"perseus" else &"beamer", s.ship_pos + Vector2(150, 0))
	t.hp[victim] = 1.0
	t.armor[victim] = 1e6
	run.combat.rebuild_grid()
	run.projectiles.fire_enemy(victim, PI, 100, &"bullet")
	InputActions.register_defaults()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.pressed = true
	run.input._touch = true
	run.input._unhandled_input(key)
	run._play_tick(0.01)
	_check(s.hero_power == def.id and s.hero_cd > 0 and s.hero_active_t > 0, "タスク16：Q入力から%sの力が発動する" % def.id)
	var cd := s.hero_cd
	h.activate()
	_check(s.hero_cd == cd, "タスク16：クールダウン中は再発動しない")
	match def.id:
		&"leo":
			_check(run.combat.trace_width() > 1, "タスク17：しし座は帯を太くする")
			var a := s.ship_pos - Vector2(100, 0)
			var b := s.ship_pos + Vector2(300, 0)
			t.pos[victim] = s.ship_pos + Vector2(0, run.cfg.trace_radius * 1.5)
			run.combat.rebuild_grid()
			s.ship_pos = b
			run.combat.collide_ship(a, run.combat.trace_radius(), TraceRun.new())
			_check(t.dead[victim] != 0, "タスク17：太い帯の敵は装甲に関係なく貫ける")
			s.gauge = 1.0
			_line(PackedVector2Array([a, b]))
			await _shot("leo_wide_trace")
			_finish_trace()
		&"perseus":
			var before := t.pos[victim]
			_advance_enemies(0.1)
			_check(t.stone[victim] > 0 and t.pos[victim] == before, "タスク18：メドゥーサで敵が石になり止まる")
			var hp := s.ship_hp
			run.projectiles.hostile_pos[0] = s.ship_pos
			run.projectiles._update_hostile(0.01)
			_check(run.projectiles.hostile_count() == 0 and s.ship_hp == hp, "タスク18：石の弾に触れると安全に砕ける")
			_ram(t.pos[victim], Vector2.LEFT)
			_check(t.dead[victim] != 0, "タスク18：石の敵は装甲と倒し方に関係なく一撃で砕ける")
		&"gemini":
			t.armor[victim] = 0.0
			var at := s.ship_pos
			t.pos[victim] = at + Vector2(150, 0)
			var other := _enemy(&"beamer", at + Vector2(150, 200))
			t.hp[other] = 1.0
			t.armor[other] = 0.0
			run.combat.rebuild_grid()
			s.gauge = 1.0
			_line(PackedVector2Array([at, at + Vector2(300, 0)]))
			_check(s.drawing and not s.tracing and s.twin_first.size() >= 2, "タスク18：1本目のあとに2本目を描ける")
			_line(PackedVector2Array([at + Vector2(0, 200), at + Vector2(300, 200)]))
			_check(s.tracing and s.twin_tracing, "タスク18：自分と双子が同時に駆ける")
			await _shot("gemini_two_lines")
			_finish_trace()
			_check(t.dead[victim] != 0 and t.dead[other] != 0, "タスク18：2本それぞれの線の敵を貫ける")
		&"hercules":
			_check(not h.behavior(&"hercules").falls.is_empty(), "タスク17：火の隕石が降り始める")
			h.tick(float(def.params.fall_time) + 0.01, 0.01)
			_check(not h.behavior(&"hercules").burns.is_empty() and t.dead[victim] != 0, "タスク17：火の隕石は装甲を無視して焼き、燃える跡を残す")

func _test_landmarks() -> void:
	var h := run.heroes
	var s := run.state
	var t := run.enemies.table
	run.cfg.landmark_chance = 1.0
	_check(not h.revealed() and s.landmarks.is_empty(), "タスク19：英雄の場所は最初は隠れている")
	var places := [Vector2(-2000, -2000), Vector2(-4000, -2000)]
	for k in 2:
		s.ship_pos = places[k]
		s.view_center = places[k]
		var enemy := _enemy(&"beamer", s.ship_pos + Vector2(60, 0))
		run.combat.rebuild_grid()
		h._landmark_t = 0.0
		h.tick(0.01, 0.01)
		_check(t.landmark[enemy] == 1, "タスク19：%dつ目の目印の星を強めの敵に持たせる" % (k + 1))
		run.combat.damage_enemy(enemy, 1e6, {"cause": &"shot", "no_crit": true})
		_check(s.landmarks.size() == k + 1, "タスク19：倒した地点からヒントの線が増える")
	_check(h.revealed(), "タスク19：2本の線がそろうと英雄の場所が分かる")
	var a := s.landmarks[0]
	var b := s.landmarks[1]
	_check(absf((h.center - a).cross(h.center - b)) > 1.0, "タスク19：別の方向からの線が英雄の位置で交わる")
	await _shot("landmark_radar")
	s.endless = true
	h.setup(run.ctx)
	var previous := h.hero.id
	h._free()
	h.tick(run.cfg.hero_next_time + 0.01, 0.01)
	_check(h.hero.id != previous and h.is_captive() and s.landmarks.is_empty(), "タスク16・19：エンドレスは次の英雄へ替わり、ヒントを消す")

func _test_immortal_hit() -> void:
	run.bosses.spawn()
	var boss=run.bosses.actor
	boss.hsm.set_active(false)
	var t:=run.enemies.table
	run.combat.damage_enemy(boss.body,100000.0,{"cause":&"shot","no_crit":true})
	for i in 100:boss.sim_tick(0.05,0.05)
	_check(boss.separated and boss.immortal_row>=0 and not run.state.boss_dead,"中央破壊は勝利ではなく蛇の分離へ進む")
	var row: int=boss.immortal_row
	var before: float=t.hp[row]
	run.combat.damage_enemy(row,10.0,{"cause":&"fire","no_crit":true})
	_check(t.hp[row]<before,"護衛が残っていても不死の蛇へ通常ダメージが通る")

func _living_type(type: StringName) -> int:
	var count := 0
	var t := run.enemies.table
	for i in t.alive.size():
		if t.alive[i] and not t.dead[i] and t.type[i] == type:
			count += 1
	return count

func _quiet_heads(boss) -> void:
	_resume_for_check()
	boss.timeline.stop()
	boss.tech_end()
	boss._tech_cd = 1e6
	boss.combo_wait=1e6
	boss.hsm.set_active(false)
	boss.attack_field.clear_effects()
	var director=run.projectiles.director
	director.groups.clear()
	director.owners.clear()
	director.waiting.clear()
	director.configure({"enabled":true,"budget":4.0,"jitter":0.0})
	for neck in boss.necks:
		boss._release_attack(neck)
		boss._end(neck)
		neck.cd = 1e6
	run.projectiles.clear_hostile()
	run.projectiles.friend_slots.clear()
	run.field.wells.clear()
	run.field.gimmick(&"gravity")._well_t = 1e6
	var t := run.enemies.table
	for i in t.alive.size():
		if t.alive[i] and t.type[i] == &"hydra_rubble":
			run.enemies.mark_dead(i)
	run.enemies.cleanup()

func _advance_boss(seconds: float, place_rubble_on_beam := false) -> Dictionary:
	var boss = run.bosses.actor
	var peak := {"hazards": 0, "hostile": 0, "wells": 0, "rubble": 0}
	for tick in ceili(seconds / 0.05):
		_resume_for_check()
		run.state.world_time += 0.05
		run.projectiles.director.advance(run.state.world_time,run.enemies)
		run.enemies.tick(0.05, 0.05)
		if place_rubble_on_beam:
			for neck in boss.necks:
				if neck.mode == &"tech_beam" and not boss._rubble.is_empty():
					var rubble: Vector2i = boss._rubble[0]
					var from: Vector2 = boss._head_pos(neck)
					run.enemies.table.pos[rubble.x] = from + Vector2.from_angle(neck.angle) * 100
					break
		boss.sim_tick(0.05, 0.05)
		if boss.timeline.is_playing():
			await get_tree().process_frame
		peak.hazards = maxi(peak.hazards, run.projectiles.hazard_count()+boss.attack_field.effects.size())
		peak.hostile = maxi(peak.hostile, run.projectiles.hostile_count())
		peak.wells = maxi(peak.wells, run.field.wells.size())
		peak.rubble = maxi(peak.rubble, _living_type(&"hydra_rubble"))
		run.combat.rebuild_grid()
		run.field.gimmick(&"gravity")._tick_wells(0.05)
		run.projectiles.tick(0.05, 0.05)
		run.enemies.cleanup()
	return peak

func _test_hydra_attacks() -> void:
	run.bosses.spawn()
	var boss=run.bosses.actor
	var t:=run.enemies.table
	_quiet_heads(boss)
	var before: float=t.hp[boss.body]
	run.combat.damage_enemy(boss.body,1.0,{"cause":&"shot","no_crit":true})
	_check(t.hp[boss.body]<before,"中央は通常の武器で直接削れる")
	before=t.hp[boss.body]
	run.combat.damage_enemy(boss.necks[0].row,1.0,{"cause":&"shot","no_crit":true})
	_check(t.hp[boss.body]==before,"頭と中央は別のHPを持つ")
	for entry in [[0.74,5],[0.39,8]]:
		t.hp[boss.body]=t.max_hp[boss.body]*entry[0]
		boss.sim_tick(0.01,0.01)
		_check(boss.count==entry[1],"HP閾値で首が%d本になる"%entry[1])
		boss.sim_tick(1.1,1.1)
	t.hp[boss.body]=t.max_hp[boss.body]
	for attack in boss.def.params.normal_rules:
		_quiet_heads(boss)
		var rule: Dictionary=boss.def.params.normal_rules[attack]
		var n=boss._first(rule.kind)
		t.facing[boss.body]=-n.base_angle
		n.angle=0.0
		n.length=float(boss.def.params.neck_rest)
		run.state.ship_pos=boss._head_pos(n)+Vector2(170.0 if float(rule.min)==0.0 else 450.0,0)
		if attack == &"bite_sweep":
			run.state.ship_pos = boss._neck_base(n) + Vector2(float(boss.move_params(attack).sweep_reach) * 0.7, 0)
		run.state.view_center=run.state.ship_pos
		n.cd=0.0
		var started: bool=boss.start_normal(boss.necks.find(n),attack)
		_check(started,"位置条件から通常技%sを開始"%attack)
		var peak: Dictionary=await _advance_boss(3.5)
		_check(peak.hazards+peak.hostile+peak.rubble>0,"通常技%sが実判定を出す"%attack)

func _test_hydra_techniques() -> void:
	var boss=run.bosses.actor
	var t:=run.enemies.table
	for name in [&"north",&"sequence",&"curve",&"tornado",&"debris_shatter",&"beam_pincer"]:
		_quiet_heads(boss)
		boss._set_count(8)
		t.hp[boss.body]=t.max_hp[boss.body]
		t.facing[boss.body]=0.0
		run.state.ship_pos=t.pos[boss.body]+Vector2(400,0)
		run.state.view_center=run.state.ship_pos
		boss._tech_cd=0.0
		boss.combo_wait=0.0
		boss.recovery_t=0.0
		boss._tech_until.clear()
		_check(boss.try_start_tech(name,1.0),"成立する参加者で%sを開始"%name)
		var peak: Dictionary=await _advance_boss(5.0)
		_check(peak.hazards+peak.hostile+peak.rubble>0,"大技%sのタイムラインが実判定を出す"%name)
		_check(not boss.busy,"大技%sの終了後に攻めどきへ進む"%name)
		await _shot("hydra_"+String(name))

## 非同期の装備読込とGPUウォームアップは、ゲーム時計を進めず通常のフレームで完了させる。
func _choose_for_check() -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while run.state.phase == RunState.Phase.LEVELUP and Time.get_ticks_msec() < deadline:
		run.flush_events()
		scene.view.get_node("Hud/HudRoot")._rewards.cancel()
		_resume_for_check()
		run.command(&"choose_card", {"index": 0})
		if run.state.phase != RunState.Phase.LEVELUP: return
		await get_tree().process_frame
		run.physics_step(0.0)
	_check(run.state.phase != RunState.Phase.LEVELUP, "選択fixture：装備資源の準備を完了してゲームへ戻る")

func _play_steps(count: int, dt: float) -> void:
	for tick in count:
		_resume_for_check()
		run.flush_events()
		scene.view.get_node("Hud/HudRoot")._rewards.cancel()
		if run.state.phase == RunState.Phase.LEVELUP:
			await _choose_for_check()
		if run.state.phase == RunState.Phase.PLAY:
			run._play_tick(dt)
		else:
			run.physics_step(dt)

func _test_app_flow() -> void:
	ContentManager.reset_runtime()
	SaveManager.data = SaveManager.default_data()
	SaveManager.data.intro_seen = true
	GameManager.goto(GameManager.Screen.TITLE, false)
	var app: Node = load("res://scenes/app/main.tscn").instantiate()
	add_child(app)
	app._current.get_node("%StartButton").pressed.emit()
	_check(GameManager.screen == GameManager.Screen.MAIN_MENU, "通し確認：タイトルからゲームスタート")
	var expected_clears := 0
	for stage in range(1, ContentManager.stage_count() + 1):
		app._current._stage_button.pressed.emit()
		await _settle_screen()
		var map = app._current._map
		map._select(stage - 1)
		_check(not map._launch.disabled, "通し確認：ステージ%dが選択できる" % stage)
		map._launch.pressed.emit()
		await _settle_screen()
		scene = app._current
		run = scene.sim
		scene.auto_step = false
		run.input._touch = true
		await get_tree().process_frame
		run.command(&"choose_card", {"index": 0})
		run.command(&"debug_invincible")
		run.state.hitstop_enabled = false
		_check(run.state.phase == RunState.Phase.PLAY and run.state.hero_power == &"", "通し確認：ステージ%dは初期装備選択から始まり英雄の力を持ち越さない" % stage)
		for clock in [0.0, 100.0, 250.0, 378.0, 550.0]:
			run.command(&"debug_time", {"seconds": maxf(0.0, clock - run.state.time)})
			await _play_steps(60, 0.05)
			run.command(&"debug_gauge_full")
			var at := run.state.ship_pos
			_line(PackedVector2Array([at, at + Vector2(300, 150)]))
			await _play_steps(20, 0.05)
			var expected := _stage_types(ContentManager.stage(stage))
			var valid := true
			var regular := 0
			var t := run.enemies.table
			for i in t.alive.size():
				if t.alive[i] and not t.dead[i] and not t.is_boss[i] and t.parent[i] < 0 and t.meteor_index[i] < 0:
					regular += 1
					valid = valid and (expected.has(String(t.type[i])) or t.type[i] == &"splitling")
			_check(valid and regular > 0, "通し確認：ステージ%dの%.0f秒で決めた敵が出る" % [stage, clock])
			await get_tree().process_frame
		var definition := ContentManager.stage(stage)
		if not definition.boss_enabled:
			run.command(&"debug_time", {"seconds": maxf(0.0, definition.boss_start(run.cfg) + 1.0 - run.state.time)})
			await _play_steps(2, 0.05)
			_check(not run.state.boss_spawned and run.bosses.actors.is_empty() and not run.state.boss_dead,
				"通し確認：ボス無効のステージ%dは仮ボスや勝利を発生させない" % stage)
			_check(int(SaveManager.data.best.clears) == expected_clears, "通し確認：未制作ボスのクリアを記録しない")
			GameManager.abort_run()
			await _settle_screen()
			continue
		expected_clears += 1
		run.command(&"debug_time", {"seconds": maxf(0.0, run.state.boss_at + 0.1 - run.state.time)})
		await _play_steps(2, 0.05)
		_check(run.state.boss_spawned and run.bosses.actor.def.id == ContentManager.stage(stage).boss_id, "通し確認：ステージ%dに対応するボスが出る" % stage)
		await _shot("stage_%d_boss" % stage)
		var enemies := run.enemies.table
		for row in enemies.alive.size():
			if enemies.alive[row] and not enemies.is_boss[row] and enemies.parent[row] < 0 and enemies.meteor_index[row] < 0:
				run.enemies.mark_dead(row)
		run.enemies.cleanup()
		await _play_steps(20, 0.05)
		var replenished := false
		var spawn_target: Dictionary=run.spawn.target()
		var automatic_types: Array=spawn_target.per_type.keys() if spawn_target.has("per_type") else spawn_target.phase.mix.keys()
		for row in enemies.alive.size():
			if enemies.alive[row] and not enemies.dead[row] and not enemies.is_boss[row] and enemies.parent[row] < 0 and enemies.meteor_index[row] < 0 and (enemies.type[row] in automatic_types or String(enemies.type[row]) in automatic_types):
				replenished = true
		_check(replenished == (float(run.spawn.target().pop) > 0.0), "通し確認：ステージ%dのボス戦は設定した出現目標に従う" % stage)
		for attempt in 100:
			if run.state.boss_dead:
				break
			if run.state.phase == RunState.Phase.LEVELUP:
				run.command(&"choose_card", {"index": 0})
			# 攻めどきと当たりの確認用に、調整機能と同じ実行時の強さを使う。
			run.state.stats.attack_mult = 1000.0
			var boss = run.bosses.actor
			if boss.def.id==&"draco" and boss.mode==&"finale":
				var it:=Intent.new()
				if boss.finale.stage==&"input":
					it.press=not boss.finale.began;it.has_cursor=true;it.pen=run.state.ship_pos;it.pen_release=boss.finale.began
				run.input_source=func(): return it
				_play_steps(40,0.05)
				run.input_source=Callable()
				continue
			var target: Vector2 = run.enemies.table.pos[boss.body]
			if boss.def.id == &"hydra":
				if boss.immortal_row >= 0:
					target = run.enemies.table.pos[boss.immortal_row]
				else:
					for neck in boss.necks:
						if boss._alive(neck):
							target = run.enemies.table.pos[neck.row]
							break
			run.state.ship_vel = Vector2.ZERO
			run.state.glide = false
			run.command(&"debug_gauge_full")
			_line(PackedVector2Array([target - Vector2(150, 0), target + Vector2(150, 0)]))
			await _play_steps(20, 0.05)
			await get_tree().process_frame
		_check(run.state.boss_dead, "通し確認：ステージ%dのボスを線の攻撃で倒せる" % stage)
		if not run.state.boss_dead:
			app.queue_free()
			await get_tree().process_frame
			return
		if DisplayServer.get_name() == "headless":
			await _play_steps(200, 0.05)
		else:
			# 画面切り替えとGPUの後始末は、通常の更新で進める。
			scene.auto_step = true
			var finish_time := run.finish_reveal_start() + run.finish_reveal_duration() + run.cfg.boss_finish_clear_time
			await get_tree().create_timer(finish_time + 1.0).timeout
		await get_tree().process_frame
		await _settle_screen()
		await _shot("stage_%d_result" % stage, app._current.get_node("%Heading"))
		_check(GameManager.screen == GameManager.Screen.RESULT and GameManager.last_result.cleared, "通し確認：ステージ%dのクリア演出から結果画面へ進む" % stage)
		if stage < 5:
			_check(SaveManager.is_stage_unlocked(stage + 1), "通し確認：クリアしたステージ%dの次が選べる" % stage)
		app._current.get_node("%MenuButton").pressed.emit()
		await _settle_screen()
	_check(expected_clears > 0 and int(SaveManager.data.best.clears) == expected_clears,
		"通し確認：有効な専用ボスのステージだけクリアを記録する")
	app.queue_free()
	await get_tree().process_frame

func _test_hydra_fire() -> void:
	var boss = run.bosses.actor
	var t := run.enemies.table
	_quiet_heads(boss)
	var head = boss.necks[0]
	run.state.ship_pos = t.pos[head.row] + Vector2(20, 0)
	run.state.view_center = run.state.ship_pos
	for k in 60:
		_enemy(&"beamer", run.state.ship_pos + Vector2(220, k - 30))
	run.combat.rebuild_grid()
	var near_heads := 0
	for sample in 300:
		var target: Vector2 = run.heroes.behavior(&"hercules")._fire_target()
		for neck in boss.necks:
			if boss._alive(neck) and target.distance_to(t.pos[neck.row]) < 65:
				near_heads += 1
				break
	_check(near_heads > 60, "タスク23：火の隕石は雑魚が多くてもボスの頭に少し寄せる")
	t.hp[head.row]=1.0
	run.heroes.behavior(&"hercules").falls.append(Vector3(t.pos[head.row].x, t.pos[head.row].y, 0.01))
	run.heroes.tick(0.02, 0.02)
	boss.sim_tick(0.02, 0.02)
	for tick in 20:
		if head.burned:
			break
		run.heroes.tick(0.26, 0.26)
		boss.sim_tick(0.26, 0.26)
	_check(head.row < 0 and head.burned, "英雄の火の隕石と燃える跡で頭を倒し再生を遅らせる")

func _shot(label: String, redraw: CanvasItem = null) -> void:
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	if is_instance_valid(run):
		run._update_camera(1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	if redraw != null:
		redraw.queue_redraw()
	# 静止画面やフォーカスを外した画面でも、撮影前に描画を完了させる。
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	get_viewport().get_texture().get_image().save_png(shots.path_join(label + ".png"))
	print("[acceptance] CAPTURE ", label)

func _test_surge() -> void:
	var samples: Array[Dictionary] = []
	run.state.view_center = Vector2(-2000, -2000)
	run.state.time = 599.0
	# mix方式を検証するfixture。実ステージのper_type（種類別曲線）を持ち込まない。
	var phase := PhaseDef.new()
	phase.mix = {&"drifter": 1.0, &"gunner": 1.0}
	_check(not run.enemies.def_of(&"drifter").ranged and run.enemies.def_of(&"gunner").ranged \
		and run.enemies.def_of(&"drifter").max_alive == 0 and run.enemies.def_of(&"gunner").max_alive == 0,
		"強化帯fixture：上限のない近接・射撃の2種類を同じ重みで使う")
	for steps in [0, 20]:
		_clear()
		run.state.rng.seed = 208
		run.spawn._survey(0.0)
		var request := {"phase": phase, "steps": steps,
			"surge": {"ranged": run.cfg.surge_ranged * steps, "elite": run.cfg.surge_elite * steps}}
		for attempt in 600:
			run.spawn._spawn_one(request)
		var sample := {"all": 0, "elite": 0, "ranged": 0}
		var t := run.enemies.table
		for row in t.alive.size():
			if t.alive[row] and not t.dead[row] and t.def[row] != null and t.parent[row] < 0 and t.meteor_index[row] < 0:
				sample.all += 1
				sample.elite += int(t.elite[row] != 0)
				sample.ranged += int(t.def[row].ranged)
		samples.append(sample)
		_check(sample.all == 600, "強化帯fixture：種類別の欠員制限に止められず600体を抽出する")
	_check(float(samples[1].elite) / samples[1].all > float(samples[0].elite) / samples[0].all + 0.05, "タスク4：後の波ではエリートの割合が増える")
	_check(float(samples[1].ranged) / samples[1].all > float(samples[0].ranged) / samples[0].all + 0.1, "タスク4：後の波では弾とビームを撃つ敵の割合が増える")
	var render: RunPresentation = scene.view.get_node("RunPresentation")
	var batch: InstanceBatch = render._ensure_enemy_batch(&"beamer")
	_check(batch.texture != null or batch.multimesh.mesh != null, "初めて出る敵に画像または図形の描画を準備する")
	_clear()

## 描画付きの確認では、Codexへフォーカスを戻したときのポーズを計測に混ぜない。
func _resume_for_check() -> void:
	if run.state.phase == RunState.Phase.PAUSED:
		run.command(&"resume")

func _test_head_world_steps() -> void:
	run.bosses.spawn()
	var boss = run.bosses.actor
	var neck = boss.necks[0]
	var old_row: int = neck.row
	var hp: float = run.enemies.table.hp[boss.body]
	var at := run.enemies.table.pos[old_row]
	run.state.world_time = 10.0
	run.combat.damage_enemy(old_row, 1000, {"cause": &"fire", "no_crit": true})
	run.state.pending_levels = 0
	# 世界側を進めない物理更新で頭が片付くと、次の世界更新までに分裂体が行を再利用できる。
	run._play_tick(1.0 / 120.0)
	_enemy(&"splitling", at + Vector2(500, 0))
	run._play_tick(1.0 / 120.0)
	_check(neck.row < 0 and neck.burned, "タスク20・23：世界更新の間に倒れた頭も、火による再生遅延を保つ")
	_check(is_equal_approx(run.enemies.table.hp[boss.body], hp), "タスク20：行の解放と世界更新で頭のダメージを二重に数えない")

func _stage_types(stage: StageDef) -> PackedStringArray:
	var types := PackedStringArray()
	for curve: SpawnCurve in stage.zako_curves:
		if not types.has(String(curve.type)): types.append(String(curve.type))
	for phase: PhaseDef in stage.phases:
		for id in phase.mix:
			if not types.has(String(id)): types.append(String(id))
		if phase.wave_type != &"" and not types.has(String(phase.wave_type)): types.append(String(phase.wave_type))
	for clip: SpawnClip in stage.clips:
		for formation: PackedScene in clip.formations:
			for layout in load("res://tools/content/build_runtime_stage.gd").formation(formation).get("layouts", []):
				for marker in layout.markers:
					if (clip.types.is_empty() or StringName(marker.type) in clip.types) and not types.has(String(marker.type)):
						types.append(String(marker.type))
	return types

func _settle_screen() -> void:
	while GameManager.screen_transition_active:
		await get_tree().process_frame
	await get_tree().process_frame
