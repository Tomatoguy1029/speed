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
