extends "res://tests/draco_encounter_capture.gd"
func _ready() -> void:
	get_window().set_flag(Window.FLAG_NO_FOCUS,true)
	output="/tmp/draco-qa-evidence/feedback-variety/render"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-output="): output=arg.trim_prefix("--capture-output=")
	DirAccess.make_dir_recursive_absolute(output)
	stage_template=ContentManager.runtime_stage(5)
	identity_start=_identity()
	viewport=SubViewport.new()
	viewport.world_2d=World2D.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.size=Vector2i(1280,720)
	add_child(viewport)
	for form in ["normal","depth","copy"]:
		var sim := _fresh(Vector2i(1280,720))
		var actor = sim.bosses.actor
		var target: int=actor.body
		var hit_row: int=actor.body_rows[6]
		sim.state.camera_zoom=0.6
		sim.state.view_center=Vector2(-500,0)
		if form=="depth":
			actor.apply_depth(0.35,0.55)
			actor.table.guard[actor.body]=1.0
			sim.state.camera_zoom=1.3
			sim.state.view_center=Vector2(-150,0)
		if form=="copy":
			actor.phase=2;actor.start_attack(&"clones")
			var unit: Dictionary=actor._runner.units[1]
			target=unit.row;hit_row=unit.parts[6].row
			actor._presentation.hide()
			actor._runner.units[2].visual.hide()
			# Keep the other copy hidden across its normal process; only the selected copy is in view.
			actor._runner.units[2].visual.set_process(false)
			var bounds := Rect2(unit.points[0],Vector2.ZERO)
			for point: Vector2 in unit.points: bounds=bounds.expand(point)
			bounds=bounds.grow(250.0)
			sim.state.view_center=bounds.get_center()
			sim.state.camera_zoom=minf(1280.0/bounds.size.x,720.0/bounds.size.y)*0.85
		session.view.get_node("RunPresentation")._process(0.0)
		await _snapshot(sim,form,"before",0.0)
		sim.combat.damage_enemy(hit_row,10.0,{"cause":&"shot"})
		await _snapshot(sim,form,"hit",0.0)
		metadata[-1].target_id=actor.table.id[target]
		metadata[-1].target_hp=actor.table.hp[target]
		metadata[-1].feedback=actor.hit_feedback.sample(actor.table.id[target])
		actor.hit_feedback.tick(0.045)
		await _snapshot(sim,form,"later",0.045)
		actor.hit_feedback.tick(0.13)
		await _snapshot(sim,form,"reset",0.175)
		actor.table.guard[target]=1.0
		sim.combat.damage_enemy(hit_row,10.0,{"cause":&"shot"})
		await _snapshot(sim,form,"blocked",0.175)
	var file:=FileAccess.open(output.path_join("frames.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"identity_start":identity_start,"identity_end":_identity(),"frames":metadata},"\t"))
	print("[draco_hit_feedback_capture] frames=",metadata.size())
	get_tree().quit()

func _identity() -> Dictionary:
	var result: Dictionary=super._identity()
	for path in ["res://scripts/actors/boss_actor.gd","res://scripts/bosses/boss_hit_feedback.gd","res://scripts/bosses/flow/runner.gd","res://scripts/runtime/run_session.gd","res://scripts/runtime/systems/boss_system.gd","res://scripts/runtime/systems/combat_system.gd","res://shaders/boss_hit_feedback.gdshader","res://shaders/picaro.gdshader"]:
		result[path]=FileAccess.get_sha256(path)
	return result
