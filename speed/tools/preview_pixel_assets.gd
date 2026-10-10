## 実ゲームのRendererで全スプライトを静止表示する読み込み・画面確認用。
## godot --path speed res://tools/preview_pixel_assets.tscn
## -- --capture を付けると数フレームだけ描画し、.godot/pixel-preview.pngへ保存して終了。
extends Node

func _ready() -> void:
	call_deferred("_preview")

func _preview() -> void:
	var root := get_tree().root
	var scene := load("res://scenes/run/run.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	var run := game.get_node("Managers/RunManager") as RunManager
	run.set_physics_process(false)
	var state := run.state
	game.get_node("Hud").hide()
	state.ship_pos = Vector2.ZERO
	state.ship_heading = Vector2.RIGHT
	state.view_center = Vector2.ZERO
	state.camera_zoom = 0.8
	state.view_half = root.get_visible_rect().size / (2.0 * state.camera_zoom)
	state.ship_invuln = 0.0
	run.field.dust.clear()
	run.field.planet.pos = Vector2(-650, 330)
	run.field.planet.r = 140.0
	for i in run.field.moons.size():
		run.field.moons[i].pos = Vector2(530 + 220 * i, 300)
		run.field.moons[i].r = 85.0
	run.enemies.list = []
	var ids := ["splitling", "swarm", "drifter", "darter", "gunner",
		"splitter", "missile", "armored", "titan", "battleship"]
	for i in ids.size():
		var definition := run.enemies.def_of(StringName(ids[i]))
		assert(definition != null, "敵定義がありません: " + ids[i])
		var position := Vector2(-550 + (i % 6) * 210, -220 if i < 6 else 130)
		var enemy := run.enemies.create(definition, 1.0, position, {"facing": PI / 2.0})
		if ids[i] == "gunner":
			enemy.charge = 0.8
		if ids[i] == "armored":
			enemy.elite = true
			enemy.hp *= 0.6
		run.enemies.add(enemy)
	for i in 2:
		var rock := run.enemies.create(run.enemies.def_of(&"meteor"), 1.0,
			Vector2(-180 + 140 * i, 340), {"size": 50.0})
		rock.meteor_index = i
		if i == 1:
			rock.hp *= 0.5
		run.enemies.add(rock)
	# 実ゲーム内の同じフラッシュ処理も並べて確認する。
	var flashed := run.enemies.create(run.enemies.def_of(&"drifter"), 1.0, Vector2(120, 0))
	flashed.flash = 1.0
	run.enemies.add(flashed)
	if "--damage-preview" in OS.get_cmdline_user_args():
		run.enemies.list = []
		state.phase = RunState.Phase.PLAY
		var renderer := game.get_node("Managers/RenderManager") as RenderManager
		for variant in 2:
			for stage in 4:
				var rock := run.enemies.create(run.enemies.def_of(&"meteor"), 1.0,
					Vector2(-460 + stage * 300, -150 + variant * 300), {"size": 60.0 if variant == 0 else 40.0})
				rock.meteor_index = variant
				rock.hp *= [1.0, 0.5, 0.2, 0.0][stage]
				rock.flash = 0.12 if stage > 0 else 0.0
				run.enemies.add(rock)
				if stage == 3:
					run.combat.kill_enemy(rock)
		renderer._on_events(state.events)
		state.events.clear()
		# 破片が分離した瞬間を静止確認する。
		renderer._update_fx(0.2)
		var drone = load("res://scripts/weapons/drone.gd").new()
		drone.setup(run.build, ConfigManager.weapons[&"W06"])
		drone.drones = [{"pos": Vector2(-60, 0)}, {"pos": Vector2(60, 0)}]
		run.build.weapon_behaviors[&"W06"] = drone
	if "--path-preview" in OS.get_cmdline_user_args() or "--trace-preview" in OS.get_cmdline_user_args():
		run.enemies.list = []
		state.phase = RunState.Phase.PLAY
		var points := PackedVector2Array([Vector2(-420, -160), Vector2(300, 160),
			Vector2(-300, 160), Vector2(300, -160), Vector2(-300, -160), Vector2(420, 160)])
		state.drawing = "--path-preview" in OS.get_cmdline_user_args()
		state.tracing = not state.drawing
		state.draw_points = points
		state.trace_path = points
	if "--smoothing-preview" in OS.get_cmdline_user_args():
		run.enemies.list = []
		state.phase = RunState.Phase.PLAY
		state.drawing = true
		state.tracing = false
		state.draw_limit = 10000.0
		state.draw_length = 0.0
		var raw := PackedVector2Array()
		for i in 101:
			raw.append(Vector2(-400 + i * 8, sin(i * 0.07) * 45 + sin(i * 1.7) * 2))
		state.draw_points = PackedVector2Array([raw[0]])
		for i in range(1, raw.size()):
			run.draw._extend(raw[i])
		var original := DrawLayer.new()
		original.z_index = 12
		original.draw_fn = func(c): c.draw_polyline(raw, Color("#c8f7ff"), 3.0)
		original.position.y = -160.0
		game.get_node("World").add_child(original)
	if "--exhaust-preview" in OS.get_cmdline_user_args():
		state.phase = RunState.Phase.PLAY
		var renderer := game.get_node("Managers/RenderManager") as RenderManager
		for i in 25:
			state.ship_pos = Vector2(-180 + i * 7, sin(i * 0.07) * 35)
			state.ship_heading = Vector2(7, cos(i * 0.07) * 2.45).normalized()
			state.ship_vel = state.ship_heading * 700.0
			renderer._update_exhaust(0.01)
	if "--rear-preview" in OS.get_cmdline_user_args():
		state.phase = RunState.Phase.LEVELUP
		state.ship_heading = Vector2.RIGHT
		var weapon = load("res://scripts/weapons/rear.gd").new()
		weapon.setup(run.build, ConfigManager.weapons[&"W23"])
		run.build.weapon_behaviors[&"W23"] = weapon
		for lv in range(1, 6):
			weapon.level = lv
			state.ship_pos = Vector2(0, -120 + (lv - 1) * 60)
			weapon.tick(float(weapon.p("interval_by_level")[lv - 1]), false)
		var pr := run.projectiles
		for i in pr.friend_alive.size():
			if pr.friend_alive[i] != 0:
				pr.friend_pos[i] += pr.friend_vel[i] * 0.08
		state.ship_pos = Vector2.ZERO
		var drone = load("res://scripts/weapons/drone.gd").new()
		drone.setup(run.build, ConfigManager.weapons[&"W06"])
		drone.drones = [{"pos": Vector2(-70, 0)}, {"pos": Vector2(70, 0)},
			{"pos": Vector2(0, -70)}, {"pos": Vector2(0, 70)}]
		run.build.weapon_behaviors[&"W06"] = drone
	if "--attachments-preview" in OS.get_cmdline_user_args():
		for id in [&"W01", &"W02", &"W03", &"W05", &"W07", &"W08", &"W17", &"W23"]:
			run.build._sync_behavior(true, id, ConfigManager.weapons[id], 1)
	print("PIXEL_PREVIEW_READY: ", run.enemies.list.size(), " enemies/rocks")
	if "--capture" in OS.get_cmdline_user_args():
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png("res://.godot/pixel-preview.png")
		assert(error == OK, "プレビュー画像の保存に失敗")
		print("PIXEL_PREVIEW_SAVED")
		get_tree().quit()
