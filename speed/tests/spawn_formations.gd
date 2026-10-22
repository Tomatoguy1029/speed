## 時間帯・雑魚の目標の数の曲線・強敵の群れ・出現のクリップの出し方と、攻撃の予算を確かめる。
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
	var run: RunSimulation = lab.run
	var em: EnemySystem = run.enemies
	var state := run.state
	var scene: PackedScene = load(FORMATION)
	# 実験場で、選んだ配置と出現位置のとおりに並べる
	var before := run.enemies.count()
	lab.perform("formation", {"path": FORMATION, "layout": 1, "entry": 0})
	check(run.enemies.count() == before + 3, "実験場で選んだ配置（3体）を並べる")
	_check_phases(run)
	_check_spawn(run, scene)
	_check_clips(run, scene)
	_check_budget(run)
	_check_curves(run)
	lab.queue_free()
	await get_tree().process_frame
	print("[spawn_formations] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

## 時間帯は開始の時刻だけを持ち、次の時間帯の開始まで続く。最後はボスの出現時刻まで。
func _check_phases(run: RunSimulation) -> void:
	var stage: StageDef = run.state.stage.duplicate()
	var phases := []
	for s in [0.0, 100.0, 200.0]:
		var p := PhaseDef.new()
		p.start = s
		p.id = StringName("p%d" % int(s))
		phases.append(p)
	stage.phases = phases
	stage.boss_time = 350.0
	run.state.stage = stage
	run.state.time = 150.0
	check(run.spawn.current_phase().id == &"p100", "時刻 150 は2つ目の時間帯")
	check(is_equal_approx(run.spawn._phase_end(1), 200.0), "2つ目は3つ目の開始で終わる")
	check(is_equal_approx(run.spawn._phase_end(2), 350.0), "最後はステージのボスピンの時刻で終わる")
	stage.boss_time = -1.0
	check(is_equal_approx(run.spawn._phase_end(2), run.cfg.boss_time), "ボス時刻の指定がなければ共通設定を使う")
	run.state.time = 0.0
	check(run.spawn.current_phase().id == &"p0", "時刻 0 は最初の時間帯")

## 出した群れは、画面に入らない目安の円の外に出て、機体の方へ配置の角度を保って向く。機体の向きに合わせて回る。
func _check_spawn(run: RunSimulation, scene: PackedScene) -> void:
	var em := run.enemies
	var state := run.state
	var data: Dictionary = load("res://tools/content/build_runtime_stage.gd").formation(scene)
	check(data.layouts.size() >= 1 and data.entries.size() >= 1, "組み合わせのシーンを読める")
	state.ship_pos = Vector2(5000, -2000)
	state.ship_vel = Vector2.ZERO
	for heading in [Vector2.UP, Vector2.RIGHT, Vector2(-1, 1).normalized()]:
		state.ship_heading = heading
		for n in 12:
			var layout: int = n % data.layouts.size()
			var rows := em.ctx.spawn.spawn_formation(data, layout)
			check(rows.size() >= 2, "群れの敵が出る")
			for k in range(0, rows.size(), 2):
				var i := rows[k]
				var rel: Vector2 = em.table.pos[i] - state.ship_pos
				check(rel.length() >= EnemyFormation.safe_radius() - 1.0, "目安の円の外に出る")
				check(rel.normalized().dot(heading) > 0.0, "機体の向きの側に出る")
				var to_ship := (-rel).normalized()
				var marker_rotation: float = data.layouts[layout].markers[k / 2].rot
				check(Vector2.from_angle(em.table.facing[i]).dot(to_ship.rotated(marker_rotation)) > 0.95, "機体の方へ配置の角度を保って向く")
			for k in range(0, rows.size(), 2):
				em.table.dead[rows[k]] = 1

## クリップは開始から長さの間だけ働き、同時の群れの数まで、出す間隔を空けて群れを出す。選んだ種類の敵だけを出す。
func _check_clips(run: RunSimulation, scene: PackedScene) -> void:
	var em := run.enemies
	var state := run.state
	var stage: StageDef = state.stage.duplicate()
	var clip := SpawnClip.new()
	var types: Array[StringName] = [&"telescope", &"reticle"]
	clip.types = types
	var forms: Array[PackedScene] = [scene]
	clip.formations = forms
	clip.time = 5.0
	clip.length = 10.0
	clip.groups = 1
	clip.interval = 3.0
	var clips: Array[SpawnClip] = [clip]
	stage.clips = clips
	state.stage = stage
	em.ctx.spawn._clip_groups.clear()
	em.ctx.spawn._clip_next.clear()
	em.ctx.spawn._type_counts.clear()
	var groups := func() -> int: return (em.ctx.spawn._clip_groups.get(0, []) as Array).size()
	var kill := func() -> void:
		for rows: PackedInt32Array in em.ctx.spawn._clip_groups.get(0, []):
			for k in range(0, rows.size(), 2):
				em.table.dead[rows[k]] = 1
	state.time = 4.0
	_tick_clip(run, clip)
	check(groups.call() == 0, "開始の前は出さない")
	state.time = 5.0
	_tick_clip(run, clip)
	check(groups.call() == 1, "開始で群れを出す")
	state.time = 6.0
	_tick_clip(run, clip)
	check(groups.call() == 1, "同時の群れの数を超えて出さない")
	kill.call()
	state.time = 7.0
	_tick_clip(run, clip)
	check(groups.call() == 0, "出す間隔が経つまで次を出さない")
	state.time = 8.0
	_tick_clip(run, clip)
	check(groups.call() == 1, "間隔が経てば次を出す")
	kill.call()
	state.time = 20.0
	_tick_clip(run, clip)
	check(groups.call() == 0, "長さが過ぎたら出さない")
	# 選んだ種類の敵だけを出す
	var only: Array[StringName] = [&"telescope"]
	clip.types = only
	em.ctx.spawn._clip_groups.clear()
	em.ctx.spawn._clip_next.clear()
	state.time = 6.0
	_tick_clip(run, clip)
	var all_tele := true
	for rows: PackedInt32Array in em.ctx.spawn._clip_groups.get(0, []):
		for k in range(0, rows.size(), 2):
			all_tele = all_tele and em.table.type[rows[k]] == &"telescope"
	check(groups.call() == 1 and all_tele, "クリップで選んだ種類の敵だけを出す")
	kill.call()
	# 種類ごとの上限に達するフォーメーションは選ばない（このテストでは、みずがめ座を1体までにする）
	var capped: EnemyDef = em.def_of(&"aquarius").duplicate()
	capped.max_alive = 1
	em.definitions[&"aquarius"] = capped
	var aqua_forms: Array[PackedScene] = [load("res://data/formations/aquarius_solo.tscn")]
	clip.formations = aqua_forms
	var aqua_types: Array[StringName] = [&"aquarius"]
	clip.types = aqua_types
	em.ctx.spawn._clip_groups.clear()
	em.ctx.spawn._clip_next.clear()
	em.ctx.spawn._type_counts[&"aquarius"] = 1
	_tick_clip(run, clip)
	check(groups.call() == 0, "上限に達している間は出さない")
	em.ctx.spawn._type_counts.clear()
	_tick_clip(run, clip)
	check(groups.call() == 1, "空いたら出す")
	kill.call()
	# クリップから出た群れは、遠くにいても再配置しない（隊列がばらばらにならない）
	em.ctx.spawn._clip_groups.clear()
	em.ctx.spawn._clip_next.clear()
	clip.formations = forms
	clip.types = types
	state.time = 6.0
	_tick_clip(run, clip)
	var rows: PackedInt32Array = em.ctx.spawn._clip_groups[0][0]
	var far := state.view_center + Vector2(0, -5000)
	em.table.pos[rows[0]] = far
	em.ctx.spawn._survey(0.0)
	check(em.table.pos[rows[0]] == far, "クリップの群れは再配置しない")
	kill.call()

## 攻撃の重さの合計が予算を超えないように待たせる。待っていた攻撃は、ばらつきの分だけ遅れて始める。
## 雑魚は管理しない。本番のランでは、時間帯の整数予算を使う。
func _check_budget(run: RunSimulation) -> void:
	var em := run.enemies
	var state := run.state
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
	var biter := em.spawn(em.def_of(&"biter"), state.ship_pos + Vector2(300, 0))
	check(em._lab_admit(biter, 0.016), "雑魚の攻撃は予算で止めない")
	run.projectiles.director.configure({"enabled": false, "budget": 4.0})
	# 本番のランでは、時間帯の攻撃の予算で管理する
	var phase := PhaseDef.new()
	phase.attack_budget = 5
	state.lab_mode = false
	em.ctx.spawn._sync_attack_budget(phase)
	check(run.projectiles.director.enabled and is_equal_approx(float(run.projectiles.director.settings.budget), 5.0), "時間帯の予算で管理する")
	phase.attack_budget = 0
	em.ctx.spawn._sync_attack_budget(phase)
	check(run.projectiles.director.enabled and run.projectiles.director.settings.budget == 0, "予算が0の時間帯も管理し、新しい強敵の攻撃を待たせる")
	state.lab_mode = true

## 雑魚の目標の数の曲線は点を通り、点の間で行き過ぎない。曲線のあるステージは、種類ごとに足りない分を補充する。
func _check_curves(run: RunSimulation) -> void:
	var pts := PackedVector2Array([Vector2(0, 10), Vector2(60, 40), Vector2(90, 40), Vector2(120, 5)])
	check(is_equal_approx(SpawnCurve.sample(pts, 60.0), 40.0), "曲線は点を通る")
	check(is_equal_approx(SpawnCurve.sample(pts, -5.0), 10.0) and is_equal_approx(SpawnCurve.sample(pts, 500.0), 5.0), "点の外は端の点の数")
	var ok := true
	for k in 1200:
		var v := SpawnCurve.sample(pts, k * 0.1)
		ok = ok and v >= 5.0 - 0.001 and v <= 40.0 + 0.001
	check(ok, "点の間で行き過ぎない")
	check(absf(SpawnCurve.sample(pts, 75.0) - 40.0) < 0.001, "平らな所は平らのまま")
	var em := run.enemies
	var state := run.state
	var stage: StageDef = state.stage.duplicate()
	var a := SpawnCurve.new()
	a.type = &"biter"
	a.points = PackedVector2Array([Vector2(0, 6)])
	var b := SpawnCurve.new()
	b.type = &"bomber"
	b.points = PackedVector2Array([Vector2(0, 0)])
	var curves: Array[SpawnCurve] = [a, b]
	stage.zako_curves = curves
	state.stage = stage
	state.time = 10.0
	var t := em.ctx.spawn.target()
	check(t.has("per_type") and is_equal_approx(float(t.per_type[&"biter"]), 6.0), "目標の数は曲線の値そのまま（密度倍率は掛けない）")
	em.ctx.spawn._zako_counts.clear()
	check(em.ctx.spawn._pick_short_type(t.per_type) == &"biter", "足りない種類を補充する")
	em.ctx.spawn._zako_counts[&"biter"] = 6
	check(em.ctx.spawn._pick_short_type(t.per_type) == &"", "目標の数に届いていれば補充しない")

## 編集元の変更は制作工程を通してからランへ渡す。
func _tick_clip(run: RunSimulation, source: SpawnClip) -> void:
	run.state.stage.clips = [load("res://tools/content/build_runtime_stage.gd").clip(source)]
	run.spawn._tick_clips()
