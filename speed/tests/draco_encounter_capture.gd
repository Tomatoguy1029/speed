## 非表示の独立ウィンドウ内SubViewportで実際のGPU描画を保存する。
## ユーザーのエディター・実行中ラン・セーブは使わない。
extends Node
const STEP := 1.0 / 120.0
const IDS: Array[StringName] = [&"bite", &"tail_sweep", &"star_fan", &"tail_slam", &"meteor", &"breath", &"charge", &"leap", &"rifts", &"picaro_wall", &"clones", &"inhale", &"spiral"]
var output := "/tmp/draco-qa-evidence/render"
var metadata: Array = []
var pilot := false
var cinematics_only := false
var stage_template: RuntimeStage
var identity_start: Dictionary
var viewport: SubViewport
var camera: Camera2D
var session: RunSession
var overlay: Node2D

class ColliderOverlay:
	extends Node2D
	var actor
	func _draw() -> void:
		if actor == null or not actor.has_body(): return
		var rows: Array = [actor.body]
		rows.append_array(actor.body_rows)
		for row: int in rows:
			if actor.table.alive[row] == 0 or actor.table.dead[row] != 0: continue
			draw_arc(actor.table.pos[row], actor.table.r[row], 0.0, TAU, 40, Color(0.2,1.0,0.6,0.7), 1.5, false)
		for point: Vector2 in actor.telegraph_points: draw_circle(point, 5.0, Color.YELLOW)

func _ready() -> void:
	get_window().set_flag(Window.FLAG_NO_FOCUS, true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-output="): output = arg.trim_prefix("--capture-output=")
		if arg == "--capture-pilot": pilot = true
		if arg == "--capture-cinematics-only": cinematics_only = true
	DirAccess.make_dir_recursive_absolute(output)
	stage_template = ContentManager.runtime_stage(5)
	identity_start = _identity()
	viewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	for index in (1 if pilot else 3):
		var size: Vector2i = [Vector2i(1280,720), Vector2i(900,900), Vector2i(720,1280)][index]
		viewport.size = size
		if not cinematics_only:
			for id in ([&"bite", &"spiral"] if pilot else IDS):
				await _capture_attack(id, size, [0.0, PI * 0.5, PI * 0.25][index])
		if not pilot: await _capture_cinematics(size)
	var file := FileAccess.open(output.path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(), "identity_start":identity_start, "identity_end":_identity(), "frames": metadata}, "\t"))
	file.close()
	print("[draco_encounter_capture] frames=", metadata.size(), " output=", output)
	get_tree().quit()

func _fresh(size: Vector2i, with_hud := false) -> RunSimulation:
	if session != null:
		session.free()
		session = null
	var stage: RuntimeStage = stage_template.duplicate(true)
	stage.boss_enabled = false
	session = RunManager.create_session(viewport, {"lab": true, "stage": stage, "stage_index":5, "seed": 5205, "hud":with_hud, "view_size": Vector2(size)}, true)
	session.auto_step = false
	var sim := session.sim
	var prepared := ContentManager.prepare_resources(stage.resources.paths, false)
	session.resources = prepared
	sim.ctx.resources = prepared
	sim.state.lab_mode = false # 実験場の独自fit倍率を外し、通常ランのカメラで描く。
	sim.field.bodies.clear()
	sim.field.rocks.clear()
	sim.state.phase = RunState.Phase.PLAY
	sim.state.ship_hp = 100000.0
	sim.state.ship_vel = Vector2.ZERO
	sim.state.ship_shield_t = 0.0
	sim.state.ship_invuln = 0.0
	sim.state.ship_pos = Vector2(300,0)
	sim.state.enemy_aim = sim.state.ship_pos
	sim.state.view_center = Vector2.ZERO
	sim.state.camera_zoom = minf(size.x,size.y) / 1100.0
	sim.state.view_half = Vector2(size) * 0.5 / sim.state.camera_zoom
	sim.ship.invincible = false
	sim.bosses.spawn(load("res://data/bosses/draco.tres"), Vector2.ZERO)
	var actor = sim.bosses.actor
	actor.entrance.cancel()
	actor.mode = &"idle"
	actor.selection_enabled = false
	actor.phase = 3
	actor.table.guard[actor.body] = 0.0
	overlay = ColliderOverlay.new()
	overlay.actor = actor
	overlay.z_index = 200
	overlay.visible = false
	session.view.get_node("World").add_child(overlay)
	camera = session.view.get_node("World/Camera2D")
	return sim

func _tick(sim: RunSimulation, dt := STEP) -> void:
	sim.state.time += dt
	sim.state.world_time += dt
	sim.state.sim_time += dt
	sim.state.ship_invuln = maxf(0.0, sim.state.ship_invuln - dt)
	sim.state.ship_hurt = maxf(0.0, sim.state.ship_hurt - dt)
	sim.enemies.tick(dt, dt)
	sim.bosses.tick(dt, dt)
	sim.combat.rebuild_grid()
	sim.projectiles.tick(dt, dt)
	sim.enemies.cleanup()
	sim._update_camera(STEP)
	sim.flush_events()
	_advance_visuals(sim, dt)

func _advance_visuals(sim: RunSimulation, dt: float) -> void:
	if session != null and session.view != null:
		session.view.get_node("RunPresentation")._process(dt)
		var hud := session.view.get_node_or_null("Hud/HudRoot")
		if hud != null: hud._process(dt)

func _snapshot(sim: RunSimulation, key: String, beat: String, time: float) -> void:
	var actor = sim.bosses.actor
	actor._update_body()
	actor._presentation.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := output.path_join(key + "_" + beat + ".png")
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Actual renderer returned no pixels for " + path)
		get_tree().quit(2)
		return
	image.save_png(path)
	metadata.append({"path":path, "beat":beat, "t":time, "size":[viewport.size.x,viewport.size.y], "mode":actor.mode, "head":[actor.table.pos[actor.body].x,actor.table.pos[actor.body].y], "body_width":actor.body_width, "head_scale":actor.head_scale, "head_radius":actor.table.r[actor.body], "body_radius":actor.table.r[actor.body_rows[0]], "player_hp":sim.state.ship_hp, "camera_center":[sim.state.view_center.x,sim.state.view_center.y], "camera_zoom":sim.state.camera_zoom})
	if beat in ["warn", "impact"]:
		overlay.visible = true
		overlay.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(output.path_join(key + "_" + beat + "_colliders.png"))
		overlay.visible = false

func _capture_attack(id: StringName, size: Vector2i, angle: float) -> void:
	var sim := _fresh(size)
	var actor = sim.bosses.actor
	var direction := Vector2.from_angle(angle)
	var distance := 300.0 if id in [&"bite",&"charge",&"leap",&"tail_slam"] else 650.0
	sim.state.ship_pos = direction * distance
	if id == &"tail_sweep": sim.state.ship_pos = -direction * 800.0
	if id in [&"spiral",&"rifts",&"inhale",&"clones",&"picaro_wall"]: sim.state.ship_pos = direction * 300.0
	sim.state.enemy_aim = sim.state.ship_pos + direction.orthogonal() * 600.0
	actor.table.facing[actor.body] = angle
	actor.start_attack(id)
	var warn := float(actor.rule().warn)
	var active := float(actor.rule().active)
	var recover := float(actor.rule().recover)
	var targets := [warn * 0.5, warn * 0.95, warn + active * 0.2, warn + active * 0.6, warn + active * 0.95, warn + active + recover * 0.5, warn + active + recover + 0.2]
	if id == &"rifts": targets = [warn * 0.5,warn * 0.95,warn + 0.15,warn + 0.55,warn + 0.9,warn + active + recover * 0.5,warn + active + recover + 0.2]
	if id == &"spiral": targets = [warn * 0.5,warn * 0.95,warn + 1.2,warn + 2.75,warn + 4.15,warn + active + recover * 0.5,warn + active + recover + 0.2]
	var names := ["tell", "warn", "attack", "impact", "late", "recover", "after"]
	var time := 0.0
	var key := "%s_%dx%d" % [id, size.x, size.y]
	for index in (4 if pilot else targets.size()):
		while time < targets[index]:
			_tick(sim)
			time += STEP
		await _snapshot(sim, key, names[index], time)

func _capture_cinematics(size: Vector2i) -> void:
	var sim := _fresh(size, true)
	var actor = sim.bosses.actor
	var key := "entrance_%dx%d" % [size.x,size.y]
	actor.table.pos[actor.body] = Vector2(250,-300)
	actor.table.facing[actor.body] = -PI * 0.7
	sim.state.ship_pos = Vector2(-300,200)
	sim._update_camera(STEP)
	actor.entrance.begin()
	var time := 0.0
	for target in [1.0,3.4,4.85,6.4,7.55,8.6]:
		while time < target:
			_tick(sim)
			time += STEP
		await _snapshot(sim, key, str(target).replace(".","p"), time)
	actor.entrance.cancel()
	actor.mode = &"idle"
	actor.phase = 1
	actor.table.hp[actor.body] = actor.table.max_hp[actor.body] * 0.69
	actor.on_body_damaged()
	key = "phase2_%dx%d" % [size.x,size.y]
	time = 0.0
	for target in [0.5,1.7,3.5,5.5,8.5,12.0]:
		while time < target:
			_tick(sim)
			time += STEP
		await _snapshot(sim, key, str(target).replace(".","p"), time)
	actor.cancel_attack()
	actor.cycle.cancel()
	actor.phase = 3
	actor.handle_body_defeat({})
	key = "finale_%dx%d" % [size.x,size.y]
	for stage in [&"release",&"combine",&"pose",&"input",&"strikes",&"last",&"sight",&"split",&"explode"]:
		for frame in 2400:
			var intent := Intent.new()
			if actor.finale.stage == &"input" and stage != &"input":
				intent.has_cursor = true
				intent.press = not actor.finale.began
				intent.pen_release = actor.finale.began
				intent.pen = actor.finale.center + Vector2(-100,100)
			actor.advance_finale(STEP,intent)
			sim.flush_events()
			_advance_visuals(sim, STEP)
			if actor.finale.stage == stage: break
		var beat_times := {&"release":1.3, &"combine":1.2, &"pose":0.9, &"input":0.2, &"strikes":0.4, &"last":0.18, &"sight":1.0, &"split":0.35, &"explode":0.25}
		while actor.finale.time < float(beat_times[stage]) and actor.finale.stage == stage:
			actor.advance_finale(STEP, Intent.new())
			sim.flush_events()
			_advance_visuals(sim, STEP)
		await _snapshot(sim, key, stage, actor.finale.time)

func _identity() -> Dictionary:
	var result := {"engine":Engine.get_version_info().string}
	for directory in ["res://scripts/bosses", "res://data/bosses/draco_moves", "res://data/bosses/ai"]:
		for file in DirAccess.get_files_at(directory):
			if file.ends_with(".uid"): continue
			if directory.ends_with("/bosses") and not (file.begins_with("draco") and file.ends_with(".gd")): continue
			if directory.ends_with("/ai") and not file.begins_with("draco"): continue
			var path: String = directory.path_join(file)
			result[path] = FileAccess.get_sha256(path)
	for path in ["res://data/bosses/draco.tres", "res://.content/boss_draco.tres", "res://scripts/render/run_presentation.gd", "res://scripts/runtime/run_simulation.gd", "res://scripts/ui/hud.gd"]: result[path] = FileAccess.get_sha256(path)
	return result
