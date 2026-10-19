## 時間帯・強敵の群れ・クリップの出し方と、攻撃の組み合わせの表・攻撃の予算を確かめる。
##   Godot --headless --path speed res://tests/spawn_formations.tscn
extends Node

const FORMATION := "res://data/formations/telescope_reticle.tscn"

var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("[spawn_formations] " + label)

func _ready() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 932, "empty": true, "stage": 4})
	var run: RunManager = lab.run
	var em: EnemyManager = run.enemies
	var state := run.state
	var scene: PackedScene = load(FORMATION)
	# 実験場で、選んだ配置と出現位置のとおりに並べる
	var before := run.enemies.count()
	lab.perform("formation", {"path": FORMATION, "layout": 1, "entry": 0, "level": 1})
	check(run.enemies.count() == before + 3, "実験場で選んだ配置（3体）を並べる")
	_check_phases(run)
	_check_spawn(run, scene)
	_check_clips(run, scene)
	_check_refill(run, scene)
	_check_rules(run, scene)
	_check_budget(run)
	lab.queue_free()
	await get_tree().process_frame
	print("[spawn_formations] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

## 時間帯は開始の時刻だけを持ち、次の時間帯の開始まで続く。最後はボスの出現時刻まで。
func _check_phases(run: RunManager) -> void:
	var stage: StageDef = run.state.stage.duplicate()
	var phases := []
	for s in [0.0, 100.0, 200.0]:
		var p := PhaseDef.new()
		p.start = s
		p.id = StringName("p%d" % int(s))
		phases.append(p)
	stage.phases = phases
	run.state.stage = stage
	run.state.time = 150.0
	check(run.enemies.current_phase().id == &"p100", "時刻 150 は2つ目の時間帯")
	check(is_equal_approx(run.enemies._phase_end(1), 200.0), "2つ目は3つ目の開始で終わる")
	check(is_equal_approx(run.enemies._phase_end(2), run.cfg.boss_time), "最後はボスの出現時刻で終わる")
	run.state.time = 0.0
	check(run.enemies.current_phase().id == &"p0", "時刻 0 は最初の時間帯")

## 出した群れは、画面に入らない目安の円の外に出て、機体の方を向く。機体の向きに合わせて回る。
func _check_spawn(run: RunManager, scene: PackedScene) -> void:
	var em := run.enemies
	var state := run.state
	var data := em.formation_data(scene)
	check(data.layouts.size() == 2 and data.entries.size() == 3, "組み合わせのシーンを読める")
	state.ship_pos = Vector2(5000, -2000)
	state.ship_vel = Vector2.ZERO
	for heading in [Vector2.UP, Vector2.RIGHT, Vector2(-1, 1).normalized()]:
		state.ship_heading = heading
		for n in 12:
			var rows := em.spawn_formation(data, 1.0)
			check(rows.size() >= 4, "群れの敵が出る")
			for k in range(0, rows.size(), 2):
				var i := rows[k]
				var rel: Vector2 = em.table.pos[i] - state.ship_pos
				check(rel.length() >= EnemyFormation.safe_radius() - 1.0, "目安の円の外に出る")
				check(rel.normalized().dot(heading) > 0.0, "機体の向きの側に出る")
				var to_ship := (-rel).normalized()
				check(Vector2.from_angle(em.table.facing[i]).dot(to_ship) > 0.95, "機体の方を向く")
			for k in range(0, rows.size(), 2):
				em.table.dead[rows[k]] = 1

## クリップは決めた時刻に、決めた回数だけ出す。
func _check_clips(run: RunManager, scene: PackedScene) -> void:
	var em := run.enemies
	var state := run.state
	var stage: StageDef = state.stage.duplicate()
	var clip := SpawnClip.new()
	clip.formation = scene
	clip.time = 5.0
	clip.interval = 3.0
	clip.count = 2
	stage.clips = [clip]
	state.stage = stage
	em._clip_fired.clear()
	em._type_counts.clear()
	var fired := func() -> int: return int(em._clip_fired.get(0, 0))
	for pair in [[4.0, 0], [5.0, 1], [7.0, 1], [8.0, 2], [30.0, 2]]:
		state.time = pair[0]
		em._tick_clips(1.0)
		check(fired.call() == pair[1], "時刻 %.0f までに %d 回出す" % [pair[0], pair[1]])
	# 途中の時刻から始めたランでは、それより前の出現は出さない
	em._clip_fired.clear()
	em._clips_ready = false
	state.time = 6.0
	var before := em.count()
	em._tick_clips(1.0)
	check(fired.call() == 1 and em.count() == before, "始めた時刻より前の出現は出さない")
	state.time = 8.0
	em._tick_clips(1.0)
	check(fired.call() == 2 and em.count() > before, "始めた時刻のあとの出現は出す")
	# 種類ごとの上限に達している間は待ち、空いたら出す（みずがめ座は1体まで）
	clip.formation = load("res://data/formations/aquarius_solo.tscn")
	em._clip_fired.clear()
	em._clips_ready = true
	em._type_counts[&"aquarius"] = 1
	state.time = 5.0
	em._tick_clips(1.0)
	check(fired.call() == 0, "上限に達している間は待つ")
	em._type_counts.clear()
	em._tick_clips(1.0)
	check(fired.call() == 1, "空いたら出す")

## 強敵の群れは、目標の数まで、間隔を空けて補充する。
func _check_refill(run: RunManager, scene: PackedScene) -> void:
	var em := run.enemies
	var phase := PhaseDef.new()
	phase.formations = {scene: 1.0}
	phase.formation_count = 1
	phase.formation_interval = 10.0
	em._groups.clear()
	em._formation_t = 0.0
	em._type_counts.clear()
	em._tick_formations(phase, 0.1, 1.0)
	check(em._groups.size() == 1, "目標の数まで群れを出す")
	em._tick_formations(phase, 0.1, 1.0)
	check(em._groups.size() == 1, "目標の数を超えて出さない")
	for k in range(0, em._groups[0].size(), 2):
		em.table.dead[em._groups[0][k]] = 1
	em._tick_formations(phase, 1.0, 1.0)
	check(em._groups.is_empty(), "倒した群れは数えない")
	em._tick_formations(phase, 9.0, 1.0)
	check(em._groups.size() == 1, "間隔が空いたら次の群れを出す")

## 表の組み合わせは、相手の攻撃が終わって決めた時間が経つまで待たせる。表にない組み合わせは同時に撃ってよい。
func _check_rules(run: RunManager, scene: PackedScene) -> void:
	var em := run.enemies
	var state := run.state
	var rules := AttackRules.new()
	rules.pairs = {"aquarius/telescope": 2.0}
	run.cfg.attack_rules = rules
	em._attacks.clear()
	var tele := em.spawn(em.def_of(&"telescope"), 1.0, state.ship_pos + Vector2(900, 0))
	var aqua := em.spawn(em.def_of(&"aquarius"), 1.0, state.ship_pos + Vector2(-900, 0))
	var cross := em.spawn(em.def_of(&"cross"), 1.0, state.ship_pos + Vector2(0, 900))
	var t0 := state.world_time
	check(em._rules_admit(tele, rules, 3.0), "最初の攻撃は撃てる")
	check(em._rules_admit(tele, rules, 3.0), "許可した攻撃の間は、同じ敵にまた許可する")
	check(not em._rules_admit(aqua, rules, 3.0), "表の相手が攻撃中なら待たせる")
	check(em._rules_admit(cross, rules, 3.0), "表にない組み合わせは同時に撃てる")
	state.world_time = t0 + 4.0
	check(not em._rules_admit(aqua, rules, 3.0), "終わってから決めた時間が経つまで待たせる")
	state.world_time = t0 + 5.1
	check(em._rules_admit(aqua, rules, 3.0), "決めた時間が経てば撃てる")
	check(AttackRules.key(&"telescope", &"aquarius") == "aquarius/telescope", "組み合わせのキーは並びをそろえる")

## 攻撃の重さの合計が予算を超えないように待たせる。待っていた攻撃は、ばらつきの分だけ遅れて始める。
## 雑魚は管理しない。本番のランでは、時間帯の攻撃の予算で管理を切り替える。
func _check_budget(run: RunManager) -> void:
	var em := run.enemies
	var state := run.state
	run.cfg.attack_rules = null
	var d = load("res://scripts/encounters/attack_director.gd").new()
	d.state = state
	d.projectiles = run.projectiles
	d.configure({"enabled": true, "budget": 3.0, "slots": {"beam": 5, "aimed": 5, "wave": 5}, "gaps": {"beam": 0.0, "aimed": 0.0, "wave": 0.0}, "jitter": 0.0})
	d.advance(10.0, em)
	check(d.request("a", ["beam"], 0, 1, 5.0, 0.0, 2.0), "重さ 2 の攻撃は予算 3 に収まる")
	check(d.request("b", ["aimed"], 1, 2, 5.0, 0.0, 1.0), "重さの合計 3 までは同時に撃てる")
	check(not d.request("c", ["wave"], 2, 3, 5.0, 0.0, 0.5), "予算を超える攻撃は待たせる")
	check(is_equal_approx(d.used_cost(), 3.0), "今の重さの合計を数える")
	d.configure({"jitter": 2.0})
	d.advance(15.5, em)
	var first: bool = d.request("c", ["wave"], 2, 3, 5.0, 0.0, 0.5)
	var ready: float = float(d.waiting["c"].get("ready", 0.0)) if d.waiting.has("c") else 15.5
	check(first == (ready <= 15.5), "待っていた攻撃は、ばらつきの分だけ遅れて始める")
	d.advance(17.6, em)
	check(first or d.request("c", ["wave"], 2, 3, 5.0, 0.0, 0.5), "ばらつきの時間が過ぎたら始める")
	# 雑魚は管理しない
	run.projectiles.director.configure({"enabled": true, "budget": 0.0})
	var biter := em.spawn(em.def_of(&"biter"), 1.0, state.ship_pos + Vector2(300, 0))
	check(em._lab_admit(biter, 0.016), "雑魚の攻撃は予算で止めない")
	run.projectiles.director.configure({"enabled": false, "budget": 4.0})
	# 本番のランでは、時間帯の攻撃の予算で管理する
	var phase := PhaseDef.new()
	phase.attack_budget = 5.0
	state.lab_mode = false
	em._sync_attack_budget(phase)
	check(run.projectiles.director.enabled and is_equal_approx(float(run.projectiles.director.settings.budget), 5.0), "時間帯の予算で管理する")
	phase.attack_budget = 0.0
	em._sync_attack_budget(phase)
	check(not run.projectiles.director.enabled, "予算が 0 の時間帯は管理しない")
	state.lab_mode = true
