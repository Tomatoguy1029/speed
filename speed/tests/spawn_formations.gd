## 時間帯・強敵の群れ・クリップの出し方を確かめる。
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
	_check_phases(run)
	_check_spawn(run, scene)
	_check_clips(run, scene)
	_check_refill(run, scene)
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
	var fired := func() -> int: return int(em._clip_fired.get(0, 0))
	for pair in [[4.0, 0], [5.0, 1], [7.0, 1], [8.0, 2], [30.0, 2]]:
		state.time = pair[0]
		em._tick_clips(1.0)
		check(fired.call() == pair[1], "時刻 %.0f までに %d 回出す" % [pair[0], pair[1]])

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
