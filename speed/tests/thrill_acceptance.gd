## スリルと寄り道の受け入れ確認。セーブはメモリだけで扱う。
## Godot --headless --log-file /tmp/speed-acceptance.log --path speed res://tests/thrill_acceptance.tscn
extends Node

class MemorySave:
	extends "res://scripts/managers/save_manager.gd"
	func save() -> void:
		save_changed.emit()
	func _save_settings() -> void:
		pass

var scene: Node
var run: RunManager
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
	_test_field()
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
	SaveManager.set_script(save_script)
	SaveManager.data = saved_data
	SaveManager.settings = settings
	print("[acceptance] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func _test_debug_stage_selection() -> void:
	_check(OS.is_debug_build(), "ステージ選択：開発版で確認する")
	_check(SaveManager.is_stage_unlocked(1), "ステージ選択：通常の進行では最初にステージ1が開く")
	for stage in range(2, ConfigManager.stage_count() + 1):
		_check(not SaveManager.is_stage_unlocked(stage), "ステージ選択：ステージ%dのクリア記録は未解放のまま" % stage)
	_check(not SaveManager.is_stage_unlocked(0) and not SaveManager.is_stage_unlocked(6), "ステージ選択：存在しないステージは選べない")
	SaveManager.data = SaveManager._migrate({"version": 1, "cleared_stage": 0, "coins": 123}, SaveManager.default_data())
	var app: Node = load("res://scenes/app/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	for stage in range(1, ConfigManager.stage_count() + 1):
		GameManager.goto(GameManager.Screen.STAGE_SELECT)
		await get_tree().process_frame
		var buttons: Array = app._current.get_node("%Content").get_children().filter(func(n): return n is Button)
		var stage_button: Button = buttons[stage - 1]
		_check(not stage_button.disabled and stage_button.text.contains(ConfigManager.stage(stage).get_display_name()), "ステージ選択：未クリアの開発版でステージ%dを選べる" % stage)
		_check(buttons[-1].disabled, "ステージ選択：未実装のエンドレスは閉じている")
		if stage == 1:
			await _shot("debug_stage_select")
		if not stage_button.disabled:
			stage_button.pressed.emit()
			await get_tree().process_frame
			var initial_run: RunManager = app._current.get_node("Managers/RunManager")
			initial_run.set_physics_process(false)
			_check(initial_run.state.stage.index == stage and initial_run.state.time == 0.0 and initial_run.state.phase == RunState.Phase.LEVELUP, "ステージ選択：ステージ%dを0秒の武器選択から開始する" % stage)
			await _shot("debug_stage_%d_start" % stage)
			initial_run.command(&"choose_card", {"index": 0})
			_check(initial_run.state.phase == RunState.Phase.PLAY and initial_run.state.stage.boss_id == &"provisional", "ステージ選択：ステージ%dの通常ランと対応ボスを使う" % stage)
			GameManager.abort_run()
	_check(SaveManager.data.cleared_stage == 0 and SaveManager.coins() == 123 and SaveManager.data.best.runs == 0, "ステージ選択：全ステージを試しても既存の部品とクリア記録を保つ")
	app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	SaveManager.data = SaveManager.default_data()

func _start(stage: int) -> void:
	ConfigManager.reset_runtime()
	SaveManager.data = SaveManager.default_data()
	GameManager.run_stage = stage
	GameManager.run_endless = false
	scene = load("res://scenes/run/run.tscn").instantiate()
	add_child(scene)
	run = scene.get_node("Managers/RunManager")
	run.state.stage = run.state.stage.duplicate()
	run.state.stage.phases = []
	for phase_name in ["build", "pressure", "horde", "late"]:
		run.state.stage.phases.append(ConfigManager.phases[StringName("s%d_%s" % [stage, phase_name])])
	if stage == 4:
		run.state.stage.boss_id = &"hydra"
	run.set_physics_process(false)
	run.input.set_process_input(false)
	run.input.set_process_unhandled_input(false)
	await get_tree().process_frame
	run.command(&"choose_card", {"index": 0})
	run.build.reset_loadout()
	run.state.hitstop_enabled = false
	run.state.rng.seed = 401
	run.enemies.clear_all()
	run.field.bodies.clear()
	run.field.moons.clear()
	run.field.dust.clear()
	run.field.rocks.clear()
	run.field.setup(run.state, run.cfg)
	run.heroes.setup(run.state, run.cfg)
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
	var boss = run.bosses.actor
	var t := run.enemies.table
	run.state.world_time = 10.0
	for neck in boss.necks:
		run.combat.damage_enemy(neck.row, t.hp[neck.row] + 1.0, {"cause": &"fire", "no_crit": true})
	boss.sim_tick(0.01, 0.01)
	_check(boss.exposed_t > 0.0, "全頭を落とすと不死の首が現れる")
	_check(boss.necks.all(func(n): return n.burned), "火で落とした頭は再生が止まる")
	boss._tick_immortal(float(boss.def.params.expose_time) + 0.1)
	boss.sim_tick(1.0, 1.0)
	_check(boss.necks.all(func(n): return n.row < 0 and n.burned), "不死の首の露出が終わっても焼いた頭は次段階まで戻らない")
	t.hp[boss.body] = t.max_hp[boss.body] * 0.74
	boss.sim_tick(0.01, 0.01)
	_check(boss.count == 5 and boss.necks.all(func(n): return n.row >= 0 and not n.burned), "次段階で焼いた頭も戻り、新しい首が加わる")

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
	_check(not run.combat.collide_ship(from, run.cfg.ship_radius, TraceRun.new()) and t.hp[i] == 1000.0, "タスク1：閉じた口を貫通しても倒せない")
	s.ship_pos = run.field.planet.pos + Vector2(run.field.planet.r, 0)
	s.ship_vel = Vector2(-100, 0)
	run.ship._collide_bodies()
	_check(s.ship_vel.x > 0 and s.ship_hp == hp, "タスク1：惑星は被弾せず跳ね返る")
	_check(ConfigManager.stage(1).phases[0].mix == ConfigManager.stage(2).phases[0].mix, "復元：通常ステージは元の共通の出現構成を使う")
	s.time = run.cfg.boss_time - 1.0
	run.bosses.tick(0.0, 0.0)
	_check(not s.boss_spawned and s.boss_at >= run.cfg.boss_time and s.boss_at <= run.cfg.boss_time + run.cfg.boss_time_spread, "タスク3：ボス時刻は指定範囲で決まる")
	s.time = s.boss_at
	run.bosses.tick(0.0, 0.0)
	_check(s.boss_spawned, "タスク3：出現時刻にボスが現れる")
	s.time = 36000.0
	run._check_end()
	_check(s.phase == RunState.Phase.PLAY, "タスク3：時間切れで終了しない")
	s.time = 599.0
	var before: Dictionary = run.enemies._target()
	s.time = 660.0
	var after: Dictionary = run.enemies._target()
	_check(after.pop > before.pop and run.enemies.surge_steps() > 1, "タスク4：10分以降の波は段階ごとに大きくなる")

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
	var peaks := {"hazards": 0, "hostile": 0, "wells": 0}
	for k in ceili(seconds / 0.05):
		run.state.world_time += 0.05
		run.enemies.tick(0.05, 0.05)
		run.combat.rebuild_grid()
		run.projectiles.tick(0.05, 0.05)
		peaks.hazards = maxi(peaks.hazards, run.projectiles.hazard_count())
		peaks.hostile = maxi(peaks.hostile, run.projectiles.hostile_count())
		peaks.wells = maxi(peaks.wells, run.field.wells.size())
	return peaks

func _test_enemy_roster() -> void:
	for stage in ROSTERS:
		var expected: PackedStringArray = ROSTERS[stage].split(",")
		var found: Array[String] = []
		for phase: PhaseDef in ConfigManager.stage(stage).phases:
			for id in phase.mix:
				if not found.has(String(id)):
					found.append(String(id))
			_check(phase.wave_type == &"" or expected.has(String(phase.wave_type)), "タスク7〜12：ステージ%dの波の種類" % stage)
		_check(found.size() == expected.size() and found.all(func(id): return expected.has(id)), "タスク7〜12：ステージ%dの全出現種類" % stage)
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
			_check(run.state.events.any(func(e): return e.type == &"block_impact"), "タスク12：ケフェウス座は予告して号令する")
		elif type == &"aquarius":
			_check(run.state.ship_vel.length() > 1, "タスク11：みずがめ座の水流が遅い機体を押す")
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
	for type in [&"shield", &"crab"]:
		_clear()
		var i := _enemy(type, at)
		_check(_ram(at, Vector2.LEFT) and not t.dead[i], "タスク8・11：%sの正面は弾かれる" % type)
		_check(not _ram(at, Vector2.RIGHT) and t.dead[i] != 0, "タスク8・11：%sの背面は貫ける" % type)
	_clear()
	var pump := _enemy(&"pump", at)
	_check(not _ram(at, Vector2.RIGHT) and not t.dead[pump], "タスク8：口が閉じているポンプ座はすり抜ける")
	t.mode[pump] = EnemyTable.Mode.WINDUP
	_check(not _ram(at, Vector2.RIGHT) and t.dead[pump] != 0, "タスク8：吸っているポンプ座を倒せる")
	_clear()
	var lynx := _enemy(&"lynx", at)
	_check(not _ram(at, Vector2.RIGHT) and not t.dead[lynx] and t.shell_open[lynx] > 0, "タスク9：やまねこ座への最初の突進は殻を割る")
	_check(not _ram(at, Vector2.RIGHT) and t.dead[lynx] != 0, "タスク9：殻が開いた間の次の突進で倒せる")
	_clear()
	lynx = _enemy(&"lynx", at)
	run.combat.damage_enemy(lynx, float(t.def[lynx].params.shell_hp) * 0.5, {"cause": &"shot", "no_crit": true})
	_check(not t.dead[lynx] and t.shell_dmg[lynx] > 0, "タスク9：弾は殻の傷を溜める")
	_advance_enemies(8.0)
	_check(t.shell_dmg[lynx] == 0.0, "タスク9：攻撃が途切れると殻の傷が戻る")
	_clear()
	var triangle := _enemy(&"triangle", at)
	run.enemies._triangle(triangle, 0.01)
	_check(run.projectiles.hazard_count() == 3 and not _ram(at, Vector2.RIGHT) and not t.dead[triangle], "タスク10：三角の膜は中の核を守る")
	var star := t.parts[triangle][0]
	run.combat.damage_enemy(star, 1e6, {"cause": &"shot", "no_crit": true})
	run.enemies._triangle(triangle, 0.01)
	_check(run.projectiles.hazard_count() == 0 and not _ram(at, Vector2.RIGHT) and t.dead[triangle] != 0, "タスク10：頂点を壊すと膜が消えて核を倒せる")
	_clear()
	var crab := _enemy(&"crab", at)
	t.mode[crab] = EnemyTable.Mode.RECOVER
	_check(not _ram(at, Vector2.LEFT) and t.dead[crab] != 0, "タスク11：かに座の挟んだ直後は正面から倒せる")
	_clear()
	var corona := _enemy(&"corona", at)
	star = _enemy(&"drifter", at + Vector2(0, 100))
	run.combat.rebuild_grid()
	run.enemies.corona.tick(run.enemies, 0.01)
	_check(run.enemies.corona.members.has(star), "かんむり座は実在する雑魚を渦に捕捉する")
	run.combat.damage_enemy(star, 1e6, {"cause": &"shot", "no_crit": true})
	_check(t.dead[star] != 0 and not run.enemies.corona.members.has(star), "武器で雑魚を倒すと投擲の弾薬が減る")
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
	f._add_rock(s.rng, at + Vector2(100, 0), &"iron", Vector2.ZERO)
	var iron = f.rocks[-1]
	f._add_rock(s.rng, at + Vector2(100, 200), &"saw", Vector2.ZERO)
	var saw = f.rocks[-1]
	f._stream_t = 0.0
	f._stream_rocks(0.01)
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
	f._stream_rocks(0.01)
	_check(saw.destroyed, "タスク13：使った丸鋸は再出現しない")
	_clear()
	s.ship_pos = at + Vector2(200, 0)
	s.world_time = 10.0
	f._well_t = 1e6
	f.add_well(at, 3.0, 600.0, 1000.0)
	var enemy := _enemy(&"splitling", at + Vector2(180, 0))
	p.fire_enemy(enemy, 0, 100, &"bullet")
	var bullet := 0
	var old_velocity := p.hostile_vel[bullet]
	f._tick_wells(0.1)
	_check(s.ship_vel.x < 0 and t.vel[enemy].x < 0 and p.hostile_vel[bullet].x < old_velocity.x, "タスク14：重力は遅い機体・敵・敵弾の進路を曲げる")
	s.ship_vel = Vector2(10000, 0)
	f._tick_wells(0.1)
	_check(s.ship_vel == Vector2(10000, 0), "タスク14：高速の機体には重力が効かない")
	s.world_time = 13.1
	f._tick_wells(0.1)
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
		run._play_tick(0.1)
		if s.phase == RunState.Phase.LEVELUP:
			run.command(&"choose_card", {"index": 0})
		if tick == 150:
			var valid := true
			for bonus_row in t.alive.size():
				if t.alive[bonus_row] and not t.dead[bonus_row] and t.meteor_index[bonus_row] < 0 and t.def[bonus_row] != null:
					valid = valid and t.def[bonus_row].rank <= 2
			_check(valid, "タスク15：ボーナスの出現は雑魚と硬めの敵だけ")
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
	s.ship_pos = h.center
	s.view_center = h.center
	h.tick(0.01, 0.01)
	var guards := 0
	for i in t.alive.size():
		if t.alive[i] and not t.dead[i] and t.def[i] != null and t.def[i].rank >= 3 and t.def[i].rank <= 5:
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
			_check(run.combat.leo_width() > 1, "タスク17：しし座は帯を太くする")
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
			_check(not h.falls.is_empty(), "タスク17：火の隕石が降り始める")
			h.tick(float(def.params.fall_time) + 0.01, 0.01)
			_check(not h.burns.is_empty() and t.dead[victim] != 0, "タスク17：火の隕石は装甲を無視して焼き、燃える跡を残す")

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
	h.setup(s, run.cfg)
	var previous := h.hero.id
	h._free()
	h.tick(run.cfg.hero_next_time + 0.01, 0.01)
	_check(h.hero.id != previous and h.is_captive() and s.landmarks.is_empty(), "タスク16・19：エンドレスは次の英雄へ替わり、ヒントを消す")

func _test_immortal_hit() -> void:
	run.bosses.spawn()
	var boss = run.bosses.actor
	var t := run.enemies.table
	run.state.stats.crit_chance = 0.0
	run.state.world_time = 10.0
	for neck in boss.necks:
		run.combat.damage_enemy(neck.row, 1000, {"cause": &"shot", "no_crit": true})
	boss.sim_tick(0.01, 0.01)
	boss.sim_tick(0.01, 0.01)
	var immortal: int = boss.immortal_row
	var head_hp: float = t.hp[immortal]
	run.combat.damage_enemy(immortal, 1e6, {"cause": &"fire", "no_crit": true})
	_check(t.hp[immortal] == head_hp, "タスク20・23：不死の首は火で焼けない")
	var body_hp: float = t.hp[boss.body]
	_ram(t.pos[immortal], Vector2.RIGHT)
	boss.sim_tick(0.01, 0.01)
	_check(t.hp[boss.body] <= body_hp - t.max_hp[boss.body] * float(boss.def.params.immortal_dmg) + 0.01, "タスク20：不死の首を一度貫くと本体へ大きなダメージ")

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
	for neck in boss.necks:
		boss._release_attack(neck)
		boss._end(neck)
		neck.cd = 1e6
	run.projectiles.clear_hostile()
	run.projectiles.friend_slots.clear()
	run.field.wells.clear()
	run.field._well_t = 1e6
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
		peak.hazards = maxi(peak.hazards, run.projectiles.hazard_count())
		peak.hostile = maxi(peak.hostile, run.projectiles.hostile_count())
		peak.wells = maxi(peak.wells, run.field.wells.size())
		peak.rubble = maxi(peak.rubble, _living_type(&"hydra_rubble"))
		run.combat.rebuild_grid()
		run.field._tick_wells(0.05)
		run.projectiles.tick(0.05, 0.05)
		run.enemies.cleanup()
	return peak

func _test_hydra_attacks() -> void:
	run.bosses.spawn()
	var boss = run.bosses.actor
	var t := run.enemies.table
	var s := run.state
	t.pos[boss.body] = Vector2(-2000, -2000)
	s.ship_pos = t.pos[boss.body] + Vector2(400, 0)
	s.view_center = s.ship_pos
	s.enemy_aim = s.ship_pos
	run.ship.invincible = true
	_quiet_heads(boss)
	var hp: float = t.hp[boss.body]
	_ram(t.pos[boss.body], Vector2.RIGHT)
	run.combat.damage_enemy(boss.body, 1e6, {"cause": &"shot", "no_crit": true})
	_check(t.hp[boss.body] == hp, "タスク20：本体には体当たりも武器も通らない")
	s.ship_pos = t.pos[boss.body] + Vector2(400, 0)
	var first = boss.necks[0]
	run.combat.damage_enemy(first.row, 10.0, {"cause": &"shot", "no_crit": true})
	boss.sim_tick(0.01, 0.01)
	_check(is_equal_approx(t.hp[boss.body], hp - 10.0 * float(boss.def.params.head_share)), "タスク20：頭のダメージが本体の体力を削る")
	run.combat.damage_enemy(first.row, 1e6, {"cause": &"shot", "no_crit": true})
	boss.sim_tick(0.01, 0.01)
	_check(first.row < 0 and run.projectiles.friend_count() > 0, "タスク20・21：落とした頭の首は破片になる")
	await _advance_boss(float(boss.def.params.regrow) + 0.1)
	_check(first.row >= 0, "タスク20：焼いていない頭は時間で生え直す")
	for entry in [[0.74, 5], [0.49, 7], [0.24, 9]]:
		t.hp[boss.body] = t.max_hp[boss.body] * entry[0]
		boss.sim_tick(0.01, 0.01)
		_check(boss.count == entry[1], "タスク20：体力段階で首が%d本になる" % entry[1])
	for kind in [&"bite", &"vortex", &"debris", &"beam", &"homing"]:
		for variant in ["a", "b"]:
			_quiet_heads(boss)
			var neck = boss._first(kind)
			neck.mode = StringName(String(kind) + "_" + variant)
			var peak: Dictionary = await _advance_boss(4.0)
			var did_attack: bool = peak.hazards > 0 or peak.hostile > 0 or peak.wells > 0 or peak.rubble > 0
			_check(did_attack, "タスク21：%sの首の攻撃%s" % [kind, variant])

func _test_hydra_techniques() -> void:
	var boss = run.bosses.actor
	var t := run.enemies.table
	_quiet_heads(boss)
	boss._tech_cd = 0.0
	boss.sim_tick(0.01, 0.01)
	_check(boss.timeline.is_playing() and boss.tech != &"", "タスク22：Behavior Treeが条件を満たす技を自動で選ぶ")
	for name in [&"north", &"east", &"south", &"west"]:
		_quiet_heads(boss)
		_check(boss._tech_ok(name), "タスク22：%sは必要な首がそろうと使える" % name)
		boss.tech = name
		boss.busy = true
		boss.timeline.play(name)
		boss.timeline.advance(0.0)
		await get_tree().process_frame
		_check(boss._spin_t > 0, "タスク22：%sの前に羅針盤が回る" % name)
		var early: Dictionary = await _advance_boss(1.25)
		await _shot("hydra_compass_" + String(name))
		_check(absf(Geom.angle_diff(boss.compass_angle(), boss.TECH_DIR[name])) < 0.01, "タスク22：羅針盤が%sの方位で止まる" % name)
		var late: Dictionary = await _advance_boss(5.0, name == &"east")
		_check(early.hazards + early.hostile + early.wells + early.rubble + late.hazards + late.hostile + late.wells + late.rubble > 0, "タスク22：%sのタイムラインが攻撃を出す" % name)
		var pattern_ok: bool = late.hostile >= 3 if name == &"north" else (late.hostile >= 6 if name == &"east" else (late.hostile >= 48 if name == &"south" else late.hazards >= 2))
		_check(pattern_ok, "タスク22：%sの組み合わせの攻撃" % name)
		_check(not boss.busy and not boss.timeline.is_playing(), "タスク22：%sが完了して通常攻撃へ戻る" % name)
		_quiet_heads(boss)
		boss.tech = name
		boss.busy = true
		boss.timeline.play(name)
		boss.timeline.advance(0.0)
		await get_tree().process_frame
		_resume_for_check()
		var kind: StringName = &"bite" if name == &"north" else (&"vortex" if name == &"south" else &"beam")
		# 技が必要とする種類を落とす。西は2本必要なので、片方を落とすだけでよい。
		for neck in boss.necks:
			if neck.kind == kind and boss._alive(neck):
				run.combat.damage_enemy(neck.row, 1e6, {"cause": &"shot", "no_crit": true})
				if name == &"west":
					break
		boss.sim_tick(0.01, 0.01)
		_check(not boss.busy and not boss.timeline.is_playing(), "タスク22：%sは必要な首を先に落とすと崩せる" % name)
		boss._set_count(9)
		# 次の技は同じ体力段階で確認する。
		t.hp[boss.body] = t.max_hp[boss.body] * 0.24

func _play_steps(count: int, dt: float) -> void:
	for tick in count:
		_resume_for_check()
		if run.state.phase == RunState.Phase.LEVELUP:
			run.command(&"choose_card", {"index": 0})
		if run.state.phase == RunState.Phase.PLAY:
			run._play_tick(dt)
		else:
			run._physics_process(dt)

func _test_app_flow() -> void:
	ConfigManager.reset_runtime()
	SaveManager.data = SaveManager.default_data()
	GameManager.goto(GameManager.Screen.TITLE, false)
	var app: Node = load("res://scenes/app/main.tscn").instantiate()
	add_child(app)
	app._current.get_node("%StartButton").pressed.emit()
	_check(GameManager.screen == GameManager.Screen.MAIN_MENU, "通し確認：タイトルからゲームスタート")
	for stage in range(1, 6):
		app._current.get_node("%StageSelectButton").pressed.emit()
		var buttons: Array = app._current.get_node("%Content").get_children().filter(func(n): return n is Button)
		_check(not buttons[stage - 1].disabled, "通し確認：ステージ%dが選択できる" % stage)
		if stage == 1:
			_check(not buttons[1].disabled, "通し確認：開発版では未クリアの先のステージも選べる")
		buttons[stage - 1].pressed.emit()
		scene = app._current
		run = scene.get_node("Managers/RunManager")
		run.set_physics_process(false)
		run.input._touch = true
		await get_tree().process_frame
		run.command(&"choose_card", {"index": 0})
		run.command(&"debug_invincible")
		run.state.hitstop_enabled = false
		_check(run.state.phase == RunState.Phase.PLAY and run.state.hero_power == &"", "通し確認：ステージ%dは初期装備選択から始まり英雄の力を持ち越さない" % stage)
		for clock in [0.0, 100.0, 250.0, 378.0, 550.0]:
			run.command(&"debug_time", {"seconds": maxf(0.0, clock - run.state.time)})
			_play_steps(60, 0.05)
			run.command(&"debug_gauge_full")
			var at := run.state.ship_pos
			_line(PackedVector2Array([at, at + Vector2(300, 150)]))
			_play_steps(20, 0.05)
			var expected: PackedStringArray = ROSTERS[stage].split(",")
			var valid := true
			var regular := 0
			var t := run.enemies.table
			for i in t.alive.size():
				if t.alive[i] and not t.dead[i] and not t.is_boss[i] and t.parent[i] < 0 and t.meteor_index[i] < 0:
					regular += 1
					valid = valid and (expected.has(String(t.type[i])) or t.type[i] == &"splitling")
			_check(valid and regular > 0, "通し確認：ステージ%dの%.0f秒で決めた敵が出る" % [stage, clock])
			await get_tree().process_frame
		run.command(&"debug_time", {"seconds": run.state.boss_at + 0.1 - run.state.time})
		_play_steps(2, 0.05)
		_check(run.state.boss_spawned and run.bosses.actor.def.id == &"provisional", "通し確認：ステージ%dに対応するボスが出る" % stage)
		await _shot("stage_%d_boss" % stage)
		var enemies := run.enemies.table
		for row in enemies.alive.size():
			if enemies.alive[row] and not enemies.is_boss[row] and enemies.parent[row] < 0 and enemies.meteor_index[row] < 0:
				run.enemies.mark_dead(row)
		run.enemies.cleanup()
		_play_steps(20, 0.05)
		var replenished := false
		for row in enemies.alive.size():
			if enemies.alive[row] and not enemies.dead[row] and not enemies.is_boss[row] and enemies.parent[row] < 0 and enemies.meteor_index[row] < 0:
				replenished = true
		_check(replenished, "タスク23・通し確認：ステージ%dのボス戦でも通常敵が補充される" % stage)
		for attempt in 100:
			if run.state.boss_dead:
				break
			if run.state.phase == RunState.Phase.LEVELUP:
				run.command(&"choose_card", {"index": 0})
			# 攻めどきと当たりの確認用に、調整機能と同じ実行時の強さを使う。
			run.state.stats.attack_mult = 1000.0
			var boss = run.bosses.actor
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
			_play_steps(20, 0.05)
			await get_tree().process_frame
		_check(run.state.boss_dead, "通し確認：ステージ%dのボスを線の攻撃で倒せる" % stage)
		if not run.state.boss_dead:
			app.queue_free()
			await get_tree().process_frame
			return
		if DisplayServer.get_name() == "headless":
			_play_steps(200, 0.05)
		else:
			# 画面切り替えとGPUの後始末は、通常の更新で進める。
			run.set_physics_process(true)
			var finish_time := run.cfg.boss_finish_slow_time + run.cfg.boss_finish_blast_time + run.cfg.boss_finish_clear_time
			await get_tree().create_timer(finish_time + 1.0).timeout
		await get_tree().process_frame
		await _shot("stage_%d_result" % stage, app._current.get_node("%Heading"))
		_check(GameManager.screen == GameManager.Screen.RESULT and GameManager.last_result.cleared, "通し確認：ステージ%dのクリア演出から結果画面へ進む" % stage)
		if stage < 5:
			_check(SaveManager.is_stage_unlocked(stage + 1), "通し確認：クリアしたステージ%dの次が選べる" % stage)
		app._current.get_node("%MenuButton").pressed.emit()
		await get_tree().process_frame
	_check(int(SaveManager.data.best.clears) == 5, "通し確認：5ステージ分のクリアを記録する")
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
		var target := run.heroes._fire_target()
		for neck in boss.necks:
			if boss._alive(neck) and target.distance_to(t.pos[neck.row]) < 65:
				near_heads += 1
				break
	_check(near_heads > 60, "タスク23：火の隕石は雑魚が多くてもボスの頭に少し寄せる")
	run.heroes.falls.append(Vector3(t.pos[head.row].x, t.pos[head.row].y, 0.01))
	run.heroes.tick(0.02, 0.02)
	boss.sim_tick(0.02, 0.02)
	for tick in 20:
		if head.burned:
			break
		run.heroes.tick(0.26, 0.26)
		boss.sim_tick(0.26, 0.26)
	_check(head.row < 0 and head.burned, "タスク23：英雄の火の隕石と燃える跡で頭の再生を止める")

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
	var target: Dictionary = run.enemies._target()
	for steps in [0, 20]:
		_clear()
		run.state.rng.seed = 208
		run.enemies._survey(0.0)
		var request: Dictionary = target.duplicate()
		request.phase = ConfigManager.phases[&"s1_late"]
		request.steps = steps
		request.surge = {"ranged": run.cfg.surge_ranged * steps, "elite": run.cfg.surge_elite * steps}
		for attempt in 600:
			run.enemies._spawn_one(request)
		var sample := {"all": 0, "elite": 0, "ranged": 0}
		var t := run.enemies.table
		for row in t.alive.size():
			if t.alive[row] and not t.dead[row] and t.def[row] != null and t.parent[row] < 0 and t.meteor_index[row] < 0:
				sample.all += 1
				sample.elite += int(t.elite[row] != 0)
				sample.ranged += int(t.def[row].ranged)
		samples.append(sample)
	_check(float(samples[1].elite) / samples[1].all > float(samples[0].elite) / samples[0].all + 0.05, "タスク4：後の波ではエリートの割合が増える")
	_check(float(samples[1].ranged) / samples[1].all > float(samples[0].ranged) / samples[0].all + 0.1, "タスク4：後の波では弾とビームを撃つ敵の割合が増える")
	var render: RenderManager = scene.get_node("Managers/RenderManager")
	var batch: InstanceBatch = render._batches[&"beamer"]
	_check(batch.texture == null and batch.multimesh.mesh != null, "タスク2：pngのない敵も図形の描画を持つ")
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
	var head_hp: float = run.enemies.table.hp[old_row]
	var at := run.enemies.table.pos[old_row]
	run.state.world_time = 10.0
	run.combat.damage_enemy(old_row, 1000, {"cause": &"fire", "no_crit": true})
	run.state.pending_levels = 0
	# 世界側を進めない物理更新で頭が片付くと、次の世界更新までに分裂体が行を再利用できる。
	run._play_tick(1.0 / 120.0)
	_enemy(&"splitling", at + Vector2(500, 0))
	run._play_tick(1.0 / 120.0)
	_check(neck.row < 0 and neck.burned, "タスク20・23：世界更新の間に倒れた頭も、火による再生停止を保つ")
	_check(is_equal_approx(run.enemies.table.hp[boss.body], hp - head_hp * float(boss.def.params.head_share)), "タスク20：行の解放と世界更新で頭のダメージを二重に数えない")
