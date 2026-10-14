## スリルと寄り道の受け入れ確認。セーブはメモリだけで扱う。
## Godot --headless --log-file /tmp/speed-acceptance.log --path speed res://tests/thrill_acceptance.tscn
extends Node

class MemorySave:
	extends "res://scripts/managers/save_manager.gd"
	func save() -> void:
		save_changed.emit()

var scene: Node
var run: RunManager
var passed := 0
var failed := 0

func _ready() -> void:
	var settings: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.data = SaveManager.default_data()
	SaveManager.settings = settings
	await _start(4)
	_test_fire_regrowth()
	await _close()
	await _start(1)
	_test_foundation()
	_test_shapes()
	_test_enemy_roster()
	_test_enemy_gates()
	await _close()
	print("[acceptance] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func _start(stage: int) -> void:
	ConfigManager.reset_runtime()
	SaveManager.data = SaveManager.default_data()
	GameManager.run_stage = stage
	GameManager.run_endless = false
	scene = load("res://scenes/run/run.tscn").instantiate()
	add_child(scene)
	run = scene.get_node("Managers/RunManager")
	run.set_physics_process(false)
	run.input.set_process_input(false)
	run.input.set_process_unhandled_input(false)
	await get_tree().process_frame
	run.command(&"choose_card", {"index": 0})
	run.build.reset_loadout()
	run.state.hitstop_enabled = false
	run.state.rng.seed = 401
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
	return run.enemies.spawn(run.enemies.def_of(type), 1.0, at)

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
	_check(ConfigManager.stage(1).phases[0].mix != ConfigManager.stage(2).phases[0].mix, "タスク2：出現の重みはステージごとに異なる")
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
	_check(after.pop > before.pop and after.level > before.level and run.enemies.surge_steps() > 1, "タスク4：10分以降の波は段階ごとに大きく強くなる")
	_check(run.field.danger_at(0.0) == 0 and run.field.danger_at(run.cfg.field_radius) > run.field.danger_at(run.cfg.zone_outer), "タスク4：危険度は外縁ほど高い")

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

const ROSTERS := {
	1: "rocket,bomber,beamer,pulser,pump,telescope,shield,ruler,clock",
	2: "rocket,bomber,volatile,splitter,beamer,missile,pump,crow,lynx,reticle,dolphin",
	3: "rocket,bomber,volatile,beamer,spreader,triangle,lynx,cross,reticle,ruler,phoenix",
	4: "rocket,volatile,splitter,pulser,missile,spreader,triangle,crow,crab,dolphin,marlin,aquarius",
	5: "rocket,bomber,volatile,splitter,beamer,pulser,missile,spreader,shield,cross,auriga,corona,cepheus,aquila"
}

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
	for roster in ROSTERS.values():
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
			_check(run.enemies.parts_alive(i) > 3 and t.pos[t.parts[i][0]].distance_to(from) > 50, "タスク12：かんむり座は小さな星の輪を回す")
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
	star = t.parts[corona][0]
	_check(_ram(t.pos[star], Vector2.DOWN) and not t.dead[star], "タスク12：かんむり座の輪の星への突進は弾かれる")
	run.combat.damage_enemy(star, 1e6, {"cause": &"shot", "no_crit": true})
	_check(t.dead[star] != 0, "タスク12：輪の星は武器で壊せる")
	t.fire_t[corona] = 0.0
	run.enemies._corona(corona, 0.01)
	run.enemies._corona(corona, 1.0)
	_ram(at, Vector2.from_angle(t.facing[corona] + PI / float(t.def[corona].params.stars)), 400.0)
	_check(t.dead[corona] != 0, "タスク12：輪の隙間を通すと本体を貫ける")
	_clear()
	var king := _enemy(&"cepheus", at)
	var ruler := _enemy(&"ruler", at + Vector2(60, 0))
	t.fire_t[ruler] = 100.0
	t.fire_t[king] = 0.01
	run.combat.rebuild_grid()
	_advance_enemies(2.0)
	_check(run.projectiles.hazard_count() > 0, "タスク12：王の号令で近くの強敵が攻撃する")
	run.state.stats.attack_mult = 1.0
