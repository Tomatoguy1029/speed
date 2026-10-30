## P10の固定1300体診断。実ステージや描画を含むfpsの判定には使わない。
extends "res://tests/native_forward.gd"
var batches := {}
func display_data(run: RunSimulation, definitions: Array) -> Array:
	var out := []
	var t := run.enemies.table
	for definition: EnemyDef in definitions:
		var batch: InstanceBatch = batches[definition.id]
		batch.begin()
		var scale := 1.0 / definition.visual_value("collision_scale",1.0)
		for row in t.alive.size():
			if not t.alive[row] or t.dead[row] or t.type[row] != definition.id: continue
			batch.add(t.pos[row],t.facing[row]+PI/2.0,t.r[row]*scale,Color(1 if t.flash[row]>0 else 0,0,0,1))
		out.append(batch._buf.slice(0,batch._count*InstanceBatch.STRIDE))
	return out
func native_display(core, definitions: Array) -> Array:
	var out := []
	for definition: EnemyDef in definitions:
		out.append(core.enemy_buffer(definition.id,1.0/definition.visual_value("collision_scale",1.0),PI/2.0))
	return out
func metrics(samples: Array) -> Dictionary:
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for value in samples: total += value
	return {"mean_ms":total/samples.size()/1000.0,"median_ms":sorted[sorted.size()/2]/1000.0,"p95_ms":sorted[ceili(sorted.size()*0.95)-1]/1000.0,"max_ms":sorted.back()/1000.0}
func _ready() -> void:
	var comparison = COMPARE.new()
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":1300,"empty":true,"invincible":true})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	run.cfg.start_radius = 0.0
	run.state.ship_pos = Vector2.ZERO
	run.state.enemy_aim = run.state.ship_pos
	run.state.view_center = Vector2.ZERO
	run.state.view_half = Vector2(640,360)
	var definitions: Array = []
	for type in [&"drifter",&"biter",&"hound"]:
		definitions.append(run.enemies.def_of(type))
		batches[type] = InstanceBatch.new()
	var data := DATA.compile_enemy(definitions[0],run.cfg)
	for definition in definitions.slice(1): data.enemies.append_array(DATA.compile_enemy(definition,run.cfg).enemies)
	var core = comparison.create_native()
	check(core.configure(data),"1300体の比較定義を準備する")
	core.configure_ship(values(run.cfg,SHIP.CONFIG_KEYS),values(run.state.stats,SHIP.STAT_KEYS))
	core.configure_bite_zone(DATA.compile_bite_zone(load("res://.content/attack_visuals.res")))
	core.start(1300,run.enemies._next_id)
	core.set_run_guards({"invincible":true})
	core.set_motion_context(run.state.ship_pos,run.state.view_center,run.state.view_half)
	run.state.rng.seed = 1300
	var counts := [430,435,87]
	var serial := 0
	for kind in 3:
		for k in counts[kind]:
			var at := Vector2.from_angle(serial*2.399963)*(350.0+float(serial%40)*15.0)
			run.enemies.spawn(definitions[kind],at)
			core.spawn_enemy(definitions[kind].id,at)
			serial += 1
	check(run.enemies.count()==1300 and core.enemies_snapshot().size()==1300,"追跡430・噛みつき435・猟犬435体を固定する")
	var samples := {"gd_update":[],"native_update":[],"gd_display":[],"native_display":[],"gd_total":[],"native_total":[]}
	var zone_helper = load("res://tests/native_bite_zone.gd").new()
	zone_helper.comparison = comparison
	var hazard_seen := false
	for tick in 660:
		var dt := 1.0/60.0
		var gd_buffer: Array
		var cpp_buffer: Array
		var times := {}
		var notifications := {}
		# 実行順を交互にして、先に動かす側だけに偏らないようにする。
		for native_side in ([false,true] if tick%2==0 else [true,false]):
			var begin := Time.get_ticks_usec()
			if native_side:
				core.step(dt)
				core.avoid_strong(dt)
				core.step_hazards(dt)
				notifications.native = core.drain_events()
			else:
				run.state.time += dt
				run.state.world_time += dt
				run.enemies.tick(dt,dt)
				run.enemies.avoid_strong(dt)
				run.projectiles._update_hazards(dt)
				notifications.gd = run.state.events
				run.state.events = []
			var update := Time.get_ticks_usec()-begin
			begin = Time.get_ticks_usec()
			if native_side: cpp_buffer = native_display(core,definitions)
			else: gd_buffer = display_data(run,definitions)
			var display := Time.get_ticks_usec()-begin
			var prefix := "native" if native_side else "gd"
			times[prefix+"_update"] = update
			times[prefix+"_display"] = display
			times[prefix+"_total"] = update+display
		check(comparison.difference(comparison.plain(notifications.gd),comparison.plain(notifications.native)).is_empty(),"計測中の命中と表示通知が一致する")
		if tick >= 60:
			for key in samples: samples[key].append(times[key])
		if tick%60 == 0 or tick==659:
			var diff: String = comparison.difference(comparison.snapshot(run,[],tick).enemies,core.enemies_snapshot())
			check(diff.is_empty(),"計測中の移動結果が一致する tick%d: %s"%[tick,diff])
			check(gd_buffer==cpp_buffer,"計測中の表示用配列が完全一致する")
			check(comparison.difference(zone_helper.hazard_snapshot(run.projectiles),comparison.plain(core.hazards_snapshot())).is_empty(),"計測中の噛みつき判定が一致する")
			hazard_seen = hazard_seen or run.projectiles.hazard_count()>0
			if failed: break
	check(hazard_seen,"計測中に噛みつきが実際に発生する")
	var result := {"count":1300,"mix":{"drifter":430,"biter":435,"hound":435},"warmup":60,"samples":samples.gd_total.size(),"dt":1.0/60.0,"display_server":DisplayServer.get_name(),"engine":Engine.get_version_info().string,"failed":failed,"metrics":{}}
	for key in samples:
		if not samples[key].is_empty(): result.metrics[key] = metrics(samples[key])
	print("NATIVE_CROWD_BENCH ",JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			var file := FileAccess.open(arg.trim_prefix("--output="),FileAccess.WRITE)
			file.store_string(JSON.stringify(result,"\t"))
	zone_helper.free()
	for batch in batches.values(): batch.free()
	core.close()
	lab.free()
	print("[native_crowd_bench] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
