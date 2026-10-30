## 成長を止めるベンチでも、通常の結晶の生成と回収の負荷を保つ。
extends Node

var failed := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 932, "empty": true, "stage": 1,
		"config": {"drop_base": 0.0, "drop_max": 0.0}})
	lab.scene.auto_step = false
	var run: RunSimulation = lab.run
	run.state.level = 0
	run.state.xp = 0.0
	var probe = load("res://tools/profile_run.gd").new()
	probe.run = run
	var samples: Array[float] = []
	for i in 100:
		samples.append(float(i))
	var stats: Dictionary = probe._stats(samples)
	check(stats.get("p99", -1.0) == 98.0 and stats.get("min", -1.0) == 0.0,
		"計測値はp99と最小値を欠測と区別して返す")
	if probe.has_method("_frame_stats"):
		var frame_samples: Array[float] = [16.0, 1000.0 / 30.0, 33.34, 50.0]
		var frame_stats: Dictionary = probe.call("_frame_stats", frame_samples)
		check(frame_stats.get("over_33_33ms", -1) == 2,
			"30fpsの時間を超えたフレームだけを数え、境界値は含めない")
	else:
		check(false, "フレーム時間の引っかかりを集計できる")
	var drop_multiplier := run.state.stats.xp_mult
	probe._hold_level()
	check(run.state.stats.xp_mult == drop_multiplier, "成長停止は敵が落とす結晶の経験値を変えない")
	var enemy := run.enemies.spawn(run.enemies.def_of(&"biter"), run.state.ship_pos)
	run.pickups.on_enemy_killed(enemy)
	check(run.pickups.gem_slots.live > 0 and run.state.xp_dropped > 0.0, "成長停止中も通常の敵から結晶が出る")
	run.pickups._collect_gems(1.0)
	check(run.pickups.gem_slots.live == 0, "成長停止中も結晶を回収する")
	check(run.state.level == 0 and run.state.xp == 0.0 and run.state.pending_levels == 0,
		"結晶を回収してもレベルとカード待ちは増えない")
	probe.free()
	lab.queue_free()
	await get_tree().process_frame
	print("[profile_run_conditions] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
