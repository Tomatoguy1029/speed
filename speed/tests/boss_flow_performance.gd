extends SceneTree
func _initialize() -> void: call_deferred("exercise")
func exercise() -> void:
	var compiler = load("res://tools/content/build_boss_program.gd")
	var panel = load("res://tools/editor/boss_flow/editor.gd").new()
	root.add_child(panel)
	DirAccess.make_dir_recursive_absolute("res://.content/tests")
	var path := "res://.content/tests/perf_move.tres"
	ResourceSaver.save(load("res://data/bosses/hydra_moves/bite_thrust.tres").duplicate(true), path)
	panel.open_technique(path)
	var generations: int = compiler.generation_count
	var begin := Time.get_ticks_usec()
	for i in 500: panel.set_value("bite_dmg", float(i + 1))
	var edit_us := Time.get_ticks_usec() - begin
	panel.save_current()
	assert(compiler.generation_count == generations)
	print("[boss-perf] 500 edits=", edit_us, "us, generations=0")
	panel.queue_free()
	await process_frame
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	root.add_child(lab)
	await lab.reset({"empty": true, "stage": 4, "ship_pos": [400, 0], "invincible": true})
	lab.run.bosses.spawn_lab(&"hydra", Vector2.ZERO)
	var actor = lab.run.bosses.actors.back()
	actor.hsm.set_active(false)
	for separated in [false, true]:
		actor._set_count(8)
		if separated:
			actor.begin_separation()
			actor.separation_t = 0.0
		for n in actor.necks: n.cd = 0.0
		var query_total := 0
		var select_total := 0
		var max_us := 0
		var count := 0
		for i in 100:
			begin = Time.get_ticks_usec()
			var options: Array = actor.flow_adapter.candidates({"request": "normal"}).candidates
			query_total += Time.get_ticks_usec() - begin
			count = options.size()
			begin = Time.get_ticks_usec()
			actor.flow_runner.selector.choose(options, {"cap": 3.0, "weights": {"single": 50.0, "parallel": 30.0, "combo": 20.0}}, [])
			var elapsed := Time.get_ticks_usec() - begin
			select_total += elapsed
			max_us = maxi(max_us, elapsed)
		print("[boss-perf] split=",separated," candidates=",count," query_mean=",query_total/100.0,"us select_mean=",select_total/100.0,"us select_max=",max_us,"us")
	lab.queue_free()
	await process_frame
	quit()
