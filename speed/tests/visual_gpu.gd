## Metal/Forward+の実描画を保存し、元画像の組み立てと生成物をGPU上で比較する。
extends Node
const TRANSFORM := preload("res://tools/content/visual_transforms.gd")
var failed := 0
var folder := "/tmp/speed-gpu-review"

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("この確認は実GPUが必要")
		get_tree().quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1100, 800))
	DirAccess.make_dir_recursive_absolute(folder)
	print("[visual_gpu] ", RenderingServer.get_video_adapter_name(), " / ", RenderingServer.get_current_rendering_method())
	check(await _looks() == 22, "全外観の描画を完了")
	check(await _backgrounds() == 2, "背景比較を完了")
	check(await _runs() == 4, "開始・遷移・再起動を完了")
	check(await _live(), "ライブ塗装のGPU描画を完了")
	print("[visual_gpu] ", failed, " failures")
	get_tree().quit(1 if failed else 0)

func _viewport(size: Vector2i) -> SubViewport:
	var view := SubViewport.new()
	view.size = size
	view.world_2d = World2D.new()
	view.use_hdr_2d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	return view

func _image(view: SubViewport) -> Image:
	for i in 4:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var result := view.get_texture().get_image()
	result.convert(Image.FORMAT_RGBA8)
	return result

func _sprite(parent: Node, texture: Texture2D, position: Vector2, scale: float, shader: Shader, angle := 0.0) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = position
	sprite.scale = Vector2.ONE * scale
	sprite.rotation = angle
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = Color(0, 0, 0, 1)
	var material := ShaderMaterial.new()
	material.shader = shader
	sprite.material = material
	parent.add_child(sprite)

func _look_view(source: EnemyLook, base: Texture2D, armor: Texture2D, paint: Texture2D) -> SubViewport:
	var view := _viewport(Vector2i(256, 160))
	var ground := ColorRect.new()
	ground.size = Vector2(256, 160)
	ground.color = Color("142333")
	view.add_child(ground)
	for i in 2:
		var light := DirectionalLight2D.new()
		light.rotation_degrees = -45.0 if i == 0 else 135.0
		light.energy = 1.1 if i == 0 else 0.6
		light.height = 0.25
		view.add_child(light)
	var size := base.get_size()
	var scale := minf(100.0 / size.x, 110.0 / size.y)
	for i in 2:
		var position := Vector2(64 + 128 * i, 94)
		var angle := 0.0 if i == 0 else 0.3
		_sprite(view, base, position, scale, load("res://shaders/pixel_sprite.gdshader"), angle)
		var canvas := CanvasTexture.new()
		canvas.diffuse_texture = armor if i == 0 else paint
		canvas.normal_texture = source.normal
		_sprite(view, canvas, position, scale, load("res://shaders/pixel_armor.gdshader"), angle)
	return view

func _looks() -> int:
	var atlas := Image.create(1024, 1760, false, Image.FORMAT_RGBA8)
	var reference: Node = load("res://tests/visual_bakes.gd").new()
	var n := 0
	for name in ContentManager.visual_index.look_names:
		var source := load("res://data/visuals/looks/" + name + ".tres") as EnemyLook
		var baked := RunPresentation.load_look(StringName(name))
		var layout: Dictionary = load("res://.content/dev/armor_" + name + ".res").get_meta("data")
		var colors := {layout.key: {str(layout.regions.keys()[0]): "4ac8e2"}}
		var live := TRANSFORM.live_look(baked, colors)
		var before := _look_view(source, ImageTexture.create_from_image(reference._reference_base(source)), source.armor, ImageTexture.create_from_image(TRANSFORM.painted_image(source.armor, colors)))
		var after := _look_view(baked, baked.base_texture(), baked.painted_armors[baked.colors_key({})], live.painted_armors[live.colors_key(colors)])
		for pair in [[before, "reference"], [after, "baked"]]:
			var label := Label.new()
			label.text = name
			label.position = Vector2(5, 5)
			pair[0].add_child(label)
		var expected: Image = await _image(before)
		var actual: Image = await _image(after)
		# 同じラベルを使い、通常・塗装・回転・法線照明・透過を全画素照合する。
		check(expected.get_data() == actual.get_data(), "GPU外観一致: " + name)
		var at := Vector2i((n % 2) * 512, (n / 2) * 160)
		atlas.blit_rect(expected, Rect2i(0, 0, 256, 160), at)
		atlas.blit_rect(actual, Rect2i(0, 0, 256, 160), at + Vector2i(256, 0))
		before.free()
		after.free()
		n += 1
	reference.free()
	atlas.save_png(folder.path_join("enemy-atlas.png"))
	print("[visual_gpu] ", n, " enemy looks compared")
	return n

func _backgrounds() -> int:
	var source := ContentManager.stage(4)
	var stage := ContentManager.runtime_stage(4)
	var scope := ContentManager.prepare_resources(stage.resources.paths, false)
	for camera in [Vector2.ZERO, Vector2(900, -600)]:
		var views: Array[SubViewport] = []
		for prepared in [false, true]:
			var view := _viewport(Vector2i(900, 560))
			var lens := Camera2D.new()
			lens.position = camera
			lens.zoom = Vector2.ONE * 0.16
			view.add_child(lens)
			var items: Array = stage.backgrounds if prepared else source.backgrounds
			for item: BackgroundPlacement in items:
				var sprite := Sprite2D.new()
				sprite.texture = scope.resources[item.texture_path] if prepared else item.texture
				sprite.region_enabled = true
				sprite.region_rect = item.bounds() if prepared else Rect2(item.texture.get_image().get_used_rect())
				sprite.position = item.position_at(camera)
				sprite.scale = Vector2.ONE * item.scale
				sprite.rotation_degrees = item.rotation_degrees
				sprite.modulate = item.display_tint()
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				view.add_child(sprite)
			views.append(view)
		var before: Image = await _image(views[0])
		var after: Image = await _image(views[1])
		check(before.get_data() == after.get_data(), "GPU背景・視差一致: " + str(camera))
		after.save_png(folder.path_join("background-" + ("start" if camera == Vector2.ZERO else "moved") + ".png"))
		for view in views: view.free()
	scope.cancel()
	return 2

func _runs() -> int:
	for index in [1, 4, 4, 5]:
		GameManager.run_stage = index
		var session := RunManager.create_run()
		session.auto_step = false
		add_child(session)
		await session.started
		await get_tree().process_frame
		session.view.get_node("Hud").hide()
		var render := session.view.get_node("RunPresentation") as RunPresentation
		if index == 4:
			var origin := session.sim.state.ship_pos
			render.view_override = {"center": origin + Vector2(200, -250), "zoom": 0.25}
			for i in 8:
				var type: StringName = [&"phoenix", &"crab", &"aquarius", &"lynx", &"ruler", &"dolphin", &"marlin", &"pulser"][i]
				# 通常出現予定外の敵は別途Scopeで準備し、GPUの実バッチで代表表示する。
				var look := RunPresentation.load_look(type)
				if look != null: session.resources.provide(look.resource_path, look)
				session.sim.enemies.spawn(session.sim.enemies.def_of(type), origin + Vector2((i % 4 - 1.5) * 650, (i / 4 - 0.5) * 700))
		for frame in 12:
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		if index == 4: get_viewport().get_texture().get_image().save_png(folder.path_join("stage-4.png"))
		var scope := session.resources
		session.free()
		await get_tree().process_frame
		check(scope.cancelled and scope.resources.is_empty(), "GPUステージ終了・再起動でScopeを解放")

	return 4

func _live() -> bool:
	var definition := (ContentManager.definition(&"enemies", &"phoenix") as EnemyDef).duplicate(true) as EnemyDef
	var session := RunManager.create_session(self, {"lab": true, "stage_index": 4,
		"enemies": {&"phoenix": definition}, "live_visuals": TRANSFORM.live_look}, true)
	session.auto_step = false
	session.sim.state.phase = RunState.Phase.PAUSED
	session.view.get_node("Hud").hide()
	var render := session.view.get_node("RunPresentation") as RunPresentation
	var origin := session.sim.state.ship_pos
	render.view_override = {"center": origin + Vector2(500, 0), "zoom": 0.9}
	session.sim.enemies.spawn(definition, origin + Vector2(500, 0))
	var images: Array[Image] = []
	for edited in [false, true]:
		if edited:
			var layout: Dictionary = load("res://.content/dev/armor_phoenix.res").get_meta("data")
			definition.armor_colors = {layout.key: {str(layout.regions.keys()[0]): "ff24d4"}}
			render._apply_lighting()
		for frame in 8:
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		var picture := get_viewport().get_texture().get_image()
		picture.convert(Image.FORMAT_RGBA8)
		picture.save_png(folder.path_join("live-" + ("after" if edited else "before") + ".png"))
		images.append(picture)
	check(images[0].get_data() != images[1].get_data(), "ライブ塗装の変更を実画面へ反映")
	var scope := session.resources
	session.free()
	await get_tree().process_frame
	check(scope.cancelled and scope.resources.is_empty(), "ライブSessionのScopeを解放")
	return true
