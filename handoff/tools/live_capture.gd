extends SceneTree
# 検証用：本物の C++ のランと RunFrameView で、ULT の発動から終わりまでを 30fps の生の RGB で書き出す（今はペルセウス座を発動する）。
const W := 1024
const H := 768
var out_dir := ""
var frame_index := 0
var vp: SubViewport
# HDR の画面を表示と同じ変換で写すための、HDR でない画面
var shown: SubViewport
var enemy_id := "drifter"

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
	if frame_index in [45, 66, 70, 80, 90]: img.save_png(out_dir.path_join("f%02d.png" % frame_index))
	frame_index += 1

func _run() -> void:
	var guide = load("res://tests/integration/hero_guidance.gd").new()
	var behavior = load("res://tests/runtime/hero_behaviors.gd").new()
	var bridge = _fixture(guide, OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "drifter")
	behavior._cpp_rescue(bridge, "perseus")
	bridge.command("dev_ship_motion", {"position": Vector2.ZERO, "velocity": Vector2.ZERO})
	for p in [Vector2(-300, -200), Vector2(-120, 180), Vector2(60, -220), Vector2(240, 150), Vector2(360, -60), Vector2(-380, 80), Vector2(180, -80), Vector2(-140, -40), Vector2(330, 250)]:
		bridge.command("dev_spawn", {"definition_id": enemy_id, "position": p})
	vp = SubViewport.new()
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
	var first: Dictionary = behavior._cpp_read(bridge)
	view.setup(scope, visuals, first.ui.character_scale)
	# 本物のゲームと同じく、ステージ2の背景を世界の奥に置く
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
	var rect := Rect2(-W * 0.5, -H * 0.5, W, H)
	var seen: int = guide._cpp_events.size()
	var press := Intent.new()
	press.hero_press = true
	for i in 130:
		var intent: Intent = press if i == 5 else Intent.new()
		for k in 4:
			bridge.step(1.0 / 120.0, bridge.pack_intent(intent if k == 0 else Intent.new()), {"logical_size": Vector2(W, H)})
		var read: Dictionary = bridge.read_frame()
		bridge.collect_frame()
		if not read.ok: break
		# このテスト用のランでは出来事は購読先へ届くので、画面へ渡し直す
		read.value.events = guide._cpp_events.slice(seen)
		seen = guide._cpp_events.size()
		view.receive_frame(read.value)
		view.apply_frame(bridge.read_render(rect, 1.0).value)
		view.update_effects(read.value, 1.0 / 30.0)
		background.update_frame(read.value.camera)
		await process_frame
		await _save()
	bridge.dispose()
	quit()

# hero_guidance.gd の英雄のランと同じ組み立てで、雑魚の種類だけ差し替える
func _fixture(guide, id: String):
	enemy_id = id
	var cfg: GameConfig = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	cfg.landmark_first_window = Vector2(0,1)
	cfg.landmark_second_window = Vector2(0,1)
	var actor: EnemyDef = load("res://data/enemies/%s.tres" % id).duplicate(true)
	actor.rank = 2
	actor.max_alive = 2
	actor.speed = 0.0
	var stage := RuntimeStage.new()
	stage.index = 2
	var phase := PhaseDef.new()
	phase.mix = {actor.id:1.0}
	stage.phases = [phase]
	var builder = load("res://tools/content/build_run_content.gd")
	var package: Dictionary = builder.chase_package(actor,cfg,stage)
	var records: Dictionary = package.records
	guide._cpp_visuals.assign(package.visuals)
	records.PopulationDefinition[0].active = true
	records.PopulationPhase = [{"id":1,"external_id":"hero","start":0.0,"pop_from":1.0,"pop_to":1.0,"rate":1.0,"xp_bonus":1.0,"surge_interval":1.0,"surge_pop":0.0,"surge_ranged":0.0,"surge_elite":0.0,"wave_interval":0.0,"attack_budget":0,"wave_type":0}]
	records.PopulationType = [{"id":1,"enemy":1,"rank":2.0,"maximum":2.0,"ranged":false}]
	records.PopulationMix = [{"id":1,"phase":1,"enemy":1,"weight":1.0}]
	var bytes: PackedByteArray = builder.Schema.write_content(records,"0".repeat(64).hex_decode())
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	bridge.configure(bytes,{"api_version":1,"run_id":280,"mode":1,"stage_id":"2","profile":{},"settings":{"hitstop":false}})
	bridge.subscribe("hero-test",func(frame): guide._cpp_events.append_array(frame.events); return true)
	bridge.start(5,{"lab_mode":true})
	return bridge
