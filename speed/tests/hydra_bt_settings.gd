extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	print("[hydra-bt-settings] ", "PASS " if ok else "FAIL ", label)
	if not ok: failed += 1
func _ready() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty": true, "stage": 4, "ship_pos": [400, 0]})
	lab.run.bosses.spawn_lab(&"hydra", Vector2.ZERO)
	var a = lab.run.bosses.actors.back()
	a.hsm.set_active(false)
	check(a.has_method("move_settings"), "BT technique resource is the execution source")
	if a.has_method("move_settings"):
		await exercise(a, lab)
	lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
func exercise(a, lab) -> void:
	var config = a.move_settings(&"bite_thrust")
	check(config != null, "normal action exposes its settings")
	config.parameters.normal_charge = 0.1
	config.parameters.normal_lunge = 0.1
	config.parameters.normal_hold = 0.1
	config.parameters.attack_cd = 2.1
	config.parameters.bite_radius = 117.0
	config.parameters.bite_dmg = 31.0
	var n = a.necks[0]
	n.cd = 0.0
	check(a.start_normal(0, &"bite_thrust"), "normal start uses conditions and settings")
	a.sim_tick(0.15, 0.15)
	check(a.attack_field.effects.any(func(e): return is_equal_approx(e.width, 117.0) and is_equal_approx(e.damage, 31.0)), "normal width and damage reach actual geometry")
	lab.run.state.ship_pos = Vector2(-5000, 0)
	a.sim_tick(0.05, 0.05)
	check(n.mode == &"bite_thrust", "position change does not interrupt a running normal")
	a.sim_tick(0.15, 0.15)
	check(n.mode == &"idle" and is_equal_approx(n.cd, 2.1), "normal phase times and cooldown execute")
	check(not a.normal_ready(0, &"bite_thrust"), "start condition rejects an out-of-range target")
	lab.run.state.ship_pos = Vector2(500, 0)
	a._set_count(8)
	a._tech_cd = 0.0
	var major = a.move_settings(&"beam_pincer")
	major.parameters.warning_time = 0.2
	major.parameters.performance_time = 1.0
	major.parameters.pincer_delay = 0.1
	major.parameters.pincer_time = 0.4
	major.parameters.beam_width = 91.0
	major.parameters.beam_dmg = 43.0
	major.parameters.tech_recovery = 0.7
	major.parameters.cooldown = 2.3
	check(a.try_start_tech(&"beam_pincer", 1.0), "major starts through the same resource")
	for i in 5: a.sim_tick(0.1, 0.1)
	check(a.attack_field.effects.any(func(e): return is_equal_approx(e.width, 91.0) and is_equal_approx(e.damage, 43.0)), "major width and damage reach actual geometry")
	lab.run.state.ship_pos = Vector2(-5000, 0)
	a.sim_tick(0.1, 0.1)
	check(a.busy, "position change does not interrupt a running major")
	var clock: float = a.timeline.current_animation_position
	a.sim_tick(0.1, 0.0)
	check(a.timeline.current_animation_position == clock, "simulation pause freezes configured phases")
	for i in 7: a.sim_tick(0.1, 0.1)
	check(not a.busy and a.last_tech_result == &"finished", "configured major end is generated without editing Timeline")
	check(a.recovery_t > 0.5 and a.recovery_t <= 0.7, "configured major recovery executes")
	check(is_equal_approx(a._tech_until[&"beam_pincer"] - a._time + (0.7-a.recovery_t), 2.3), "individual major cooldown executes")
