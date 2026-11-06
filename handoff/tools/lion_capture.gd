extends SceneTree
# 検証用：本物の C++ のランと RunFrameView の上で、機体をゆるやかな S 字に走らせ、機体を隠して獅子（leo_lion.gd）を重ねる。カメラは機体を追う。
# しし座の力はまだ C++ にないので、獅子は機体の位置と向きを追うだけ。30fps の生の RGB で書き出す。
# 使い方：--script res://lion_capture.gd -- <出力フォルダ> [敵の種類] [秒]
const W := 1024
const H := 768
const SPEED := 400.0
## 向きの振れ幅（ラジアン）と、振れの速さ（ラジアン毎秒）
const WEAVE := 0.45
const WEAVE_RATE := 1.1
var out_dir := ""
var frame_index := 0
var shown: SubViewport

func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _save() -> void:
	await RenderingServer.frame_post_draw
	var img := shown.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var f := FileAccess.open(out_dir.path_join("%04d.raw" % frame_index), FileAccess.WRITE)
	f.store_buffer(img.get_data())
	if frame_index % 20 == 0: img.save_png(out_dir.path_join("f%03d.png" % frame_index))
	frame_index += 1

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var live = load("res://live_capture.gd").new()
	var guide = load("res://tests/integration/hero_guidance.gd").new()
	var behavior = load("res://tests/runtime/hero_behaviors.gd").new()
	var bridge = live._fixture(guide, args[1] if args.size() > 1 else "drifter")
	var seconds := float(args[2]) if args.size() > 2 else 0.0
	for p in [Vector2(350, -190), Vector2(600, 220), Vector2(850, -230), Vector2(1100, 200), Vector2(1350, -200), Vector2(1600, 230), Vector2(1850, -180)]:
		bridge.command("dev_spawn", {"definition_id": live.enemy_id, "position": p})
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.world_2d = World2D.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.use_hdr_2d = true
	root.add_child(vp)
	shown = SubViewport.new()
	shown.size = Vector2i(W, H)
	shown.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(shown)
	var rect_view := TextureRect.new()
	rect_view.texture = vp.get_texture()
	var conv := ShaderMaterial.new()
	conv.shader = load("res://capture_srgb.gdshader")
	rect_view.material = conv
	rect_view.size = Vector2(W, H)
	shown.add_child(rect_view)
	var camera := Camera2D.new()
	vp.add_child(camera)
	var scope := ContentResourceScope.new()
	for path in ["res://.content/hero_aura.res", "res://.content/meteor_pieces.res", "res://assets/pixel/airship_flame.png", "res://assets/pixel/airship_spark.png", "res://assets/pixel/airship_armor.png", "res://assets/pixel/airship_mine.png", "res://assets/pixel/xp_crystal_facets.tres", "res://assets/effects/elite_death/masks.tres", "res://assets/effects/landmark/masks.tres", "res://data/visuals/landmark_aura_material.tres", "res://assets/effects/landmark/elite_contacts.tres", "res://data/visuals/elite_runtime.tres", "res://assets/pixel/airship_turret_base.png", "res://assets/pixel/airship_turret.png"]:
		scope.provide(path, load(path))
	for visual: Dictionary in guide._cpp_visuals:
		if not String(visual.get("path", "")).is_empty(): scope.provide(visual.path, load(visual.path))
	var visuals: Array[Dictionary] = []
	visuals.assign(guide._cpp_visuals)
	var view = load("res://scripts/render/run_frame_view.gd").new()
	vp.add_child(view)
	bridge.step(1.0 / 120.0, bridge.pack_intent(Intent.new()), {"logical_size": Vector2(W, H)})
	var first: Dictionary = behavior._cpp_read(bridge)
	view.setup(scope, visuals, first.ui.character_scale)
	var stage: Resource = load("res://.content/stage_2.tres")
	for placement in stage.backgrounds:
		if not placement.texture_path.is_empty(): scope.provide(placement.texture_path, load(placement.texture_path))
		if not placement.fire_preset_path.is_empty(): scope.provide(placement.fire_preset_path, load(placement.fire_preset_path))
	for key in stage.fire_uses:
		var preset := str(stage.fire_uses[key].get("preset", ""))
		if not preset.is_empty(): scope.provide(preset, load(preset))
	var background = load("res://scripts/render/run_stage_background.gd").new()
	background.z_index = -10
	view.add_child(background)
	background.setup(scope, stage, first.ui.ship.ship_pos)
	var lion = load("res://scripts/render/equipment/leo_lion.gd").new()
	view._ship_layer_parent.add_child(lion)
	lion.setup(1.82 * float(first.ui.character_scale))
	var frames := int(round((seconds if seconds > 0.0 else 5.0) * 30.0))
	var pos := Vector2.ZERO
	var seen: int = guide._cpp_events.size()
	for i in frames:
		var t := float(i) / 30.0
		var vel := Vector2.from_angle(WEAVE * sin(t * WEAVE_RATE)) * SPEED
		pos += vel / 30.0
		camera.position = pos
		var rect := Rect2(pos - Vector2(W, H) * 0.5, Vector2(W, H))
		bridge.command("dev_ship_motion", {"position": pos, "velocity": vel})
		for k in 4:
			bridge.step(1.0 / 120.0, bridge.pack_intent(Intent.new()), {"logical_size": Vector2(W, H)})
		var read: Dictionary = bridge.read_frame()
		bridge.collect_frame()
		if not read.ok: break
		read.value.events = guide._cpp_events.slice(seen)
		seen = guide._cpp_events.size()
		view.receive_frame(read.value)
		view.apply_frame(bridge.read_render(rect, 1.0).value)
		view.update_effects(read.value, 1.0 / 30.0)
		# 撮影ではカメラを機体に合わせているので、背景も同じ中心で描く
		var view_camera: Dictionary = read.value.camera.duplicate()
		view_camera.center = pos
		background.update_frame(view_camera)
		# 機体と噴射を隠し、獅子を重ねる
		for id in [17, 18]:
			if view._layers.has(id): view._layers[id].visible = false
		view._flame.visible = false
		view._spark.visible = false
		lion.tick(1.0 / 30.0, pos, vel.angle(), 1.0, 1.0)
		await process_frame
		await _save()
	print("frames ", frame_index)
	bridge.dispose()
	quit()
