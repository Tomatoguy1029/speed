## 固定画像の移行前後を画素単位で比較し、実行用背景の依存を確認する。
extends Node

var failed := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var capture := ""
	var compare := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture = arg.trim_prefix("--capture=")
		if arg.begins_with("--compare="): compare = arg.trim_prefix("--compare=")
	if not capture.is_empty():
		_capture(capture)
	else:
		_backgrounds()
		check("look_names" in (load("res://.content/stage_4.tres") as RuntimeStage).resources, "実行用ステージは生成済み外観索引を持つ")
		check(ResourceLoader.exists("res://.content/look_phoenix.res"), "固定外観の生成物を正規ビルドが作る")
		check(_baked_looks() == ContentManager.visual_index.look_names.size(), "全外観の生成物検証が完了する")
		check(_live_render(), "ライブ塗装とSessionの破棄を検証する")
		if not compare.is_empty(): check(_compare(compare) == ContentManager.visual_index.look_names.size(), "全外観の移行前比較が完了する")
	print("[visual_bakes] %d failures" % failed)
	get_tree().quit(1 if failed else 0)

func _capture(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var paint = load("res://tools/content/visual_transforms.gd")
	for file in DirAccess.get_files_at("res://data/visuals/looks"):
		if not file.ends_with(".tres"): continue
		var look := RunPresentation.load_look(StringName(file.get_basename()))
		var name := file.get_basename()
		look.base_texture().get_image().save_png(folder.path_join(name + "_base.png"))
		var cache := {}
		RunPresentation.look_texture(look, cache).get_image().save_png(folder.path_join(name + "_preview.png"))
		var data: Dictionary = paint.layout(look.armor)
		var palette := {data.key: {str(data.regions.keys()[0]): "4ac8e2"}}
		paint.painted_image(look.armor, palette).save_png(folder.path_join(name + "_paint.png"))
		FileAccess.open(folder.path_join(name + "_layout.txt"), FileAccess.WRITE).store_string(var_to_str([data.key, data.labels, data.regions, data.shades]))

func _backgrounds() -> void:
	var source := load("res://data/stages/stage_4.tres") as StageDef
	var compiled: RuntimeStage = load("res://tools/content/build_runtime_stage.gd").compile(source)
	for i in source.backgrounds.size():
		var original := source.backgrounds[i]
		var prepared := compiled.backgrounds[i]
		check(prepared.texture == null, "RuntimeStageは背景Textureを直接保持しない")
		check("texture_path" in prepared and "used_rect" in prepared, "実行用背景は画像パスと生成済み範囲を持つ")
		check(prepared.bounds() == Rect2(original.texture.get_image().get_used_rect()), "背景の切り取り範囲を保持する")
		check(prepared.offset == original.offset and prepared.scale == original.scale and prepared.tint == original.tint, "背景の配置と明るさを保持する")
		check(prepared.parallax == original.parallax and prepared.copy().parallax == original.parallax, "背景の移動倍率を生成・複製で保持する")
		check(prepared.position_at(Vector2(900, -600)) == original.position_at(Vector2(900, -600)), "生成後も同じカメラ移動で同じ背景位置になる")

func _same_image(actual: Image, path: String) -> void:
	var expected := Image.new()
	check(expected.load(path) == OK, "比較元画像を読める: " + path)
	actual.convert(Image.FORMAT_RGBA8)
	expected.convert(Image.FORMAT_RGBA8)
	check(actual.get_size() == expected.get_size() and actual.get_data() == expected.get_data(), "画像の全画素が一致: " + path.get_file())

func _reference_base(source: EnemyLook) -> Image:
	var image := source.base.get_image().duplicate()
	if source.decorations != null:
		image.blend_rect(source.decorations.get_image(), Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	return image

func _reference_preview(source: EnemyLook) -> Image:
	var image := _reference_base(source)
	image.blend_rect(source.armor.get_image(), Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	if source.split_other != null:
		image.blend_rect(_reference_preview(source.split_other), Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	return image

func _baked_looks() -> int:
	var transform = load("res://tools/content/visual_transforms.gd")
	var count := 0
	for name in ContentManager.visual_index.look_names:
		var source := ResourceLoader.load("res://data/visuals/looks/" + name + ".tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyLook
		var baked := RunPresentation.load_look(StringName(name))
		check(baked.prepared and baked.base_texture().get_image().get_data() == _reference_base(source).get_data(), "本体を全画素で照合: " + name)
		var cache := {}
		check(RunPresentation.look_texture(baked, cache).get_image().get_data() == _reference_preview(source).get_data(), "合成画像を全画素で照合: " + name)
		var data: Dictionary = load("res://.content/dev/armor_" + name + ".res").get_meta("data")
		var pixel: int = data.regions.values()[0][0]
		var palette := {data.key: {str(data.labels[pixel]): "4ac8e2"}}
		var palettes: Array[Dictionary] = [palette]
		var prepared: EnemyLook = transform.prepare_look(source, palettes)
		var output := "/tmp/speed-painted-fixture.res"
		check(ResourceSaver.save(prepared, output) == OK, "固定塗装を生成物として保存できる")
		var restored := ResourceLoader.load(output, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyLook
		check(restored.painted_armors.has(restored.colors_key(palette)), "固定塗装を解析・再合成せず取得できる")
		check(restored.armor_key == data.key, "元の塗装キーを保持")
		check(baked.decorations == null, "本体と装甲の分離を保持")
		check(baked.base_texture().get_image().get_data() == _reference_base(source).get_data(), "プレビュー取得が本体を変更しない")
		count += 1
	print("[visual_bakes] ", ContentManager.visual_index.look_names.size(), " prepared looks, fixed palettes and source pixels checked")
	return count

func _compare(folder: String) -> int:
	var paint = load("res://tools/content/visual_transforms.gd")
	var count := 0
	for name in ContentManager.visual_index.look_names:
		var look := RunPresentation.load_look(StringName(name))
		check(look.prepared and look.decorations == null, "本体は合成済み: " + name)
		_same_image(look.base_texture().get_image(), folder.path_join(name + "_base.png"))
		var cache := {}
		_same_image(RunPresentation.look_texture(look, cache).get_image(), folder.path_join(name + "_preview.png"))
		var layout: Dictionary = load("res://.content/dev/armor_" + name + ".res").get_meta("data")
		var expected := FileAccess.get_file_as_string(folder.path_join(name + "_layout.txt"))
		check(var_to_str([layout.key, layout.labels, layout.regions, layout.shades]) == expected, "装甲の部位キー・領域・濃淡を保持: " + name)
		var palette := {layout.key: {str(layout.regions.keys()[0]): "4ac8e2"}}
		var live: EnemyLook = paint.live_look(look, palette)
		_same_image(live.painted_armors[live.colors_key(palette)].get_image(), folder.path_join(name + "_paint.png"))
		check(look.colors_key(palette) == live.colors_key(palette), "塗装の保存キーを保持: " + name)
		count += 1
	print("[visual_bakes] ", count * 3, " legacy images and ", count, " armor layouts matched")
	return count

func _live_render() -> bool:
	var transform = load("res://tools/content/visual_transforms.gd")
	var definition := (ContentManager.definition(&"enemies", &"phoenix") as EnemyDef).duplicate(true) as EnemyDef
	var session := RunManager.create_session(self, {"lab": true, "stage_index": 4,
		"enemies": {&"phoenix": definition}, "live_visuals": transform.live_look}, true)
	session.auto_step = false
	var render := session.view.get_node("RunPresentation") as RunPresentation
	var look := render.look_of(&"phoenix")
	var reference: WeakRef = weakref(look.base_texture())
	var scope := session.resources
	render._ensure_enemy_batch(&"phoenix")
	check(scope.resources.has(look.resource_path), "実験場も取得した外観をSessionのScopeで保持する")
	check(render._directional_lights[&"phoenix"][0].range_layer_min == 1 + ContentManager.visual_index.look_names.find("phoenix"), "生成済み索引の照明層順を維持する")
	var data: Dictionary = load("res://.content/dev/armor_phoenix.res").get_meta("data")
	definition.armor_colors = {data.key: {str(data.regions.keys()[0]): "4ac8e2"}}
	render._apply_lighting()
	var actual := render._armor_batches[&"phoenix"].texture as CanvasTexture
	check(actual.diffuse_texture.get_image().get_data() == transform.painted_image(look.armor, definition.armor_colors).get_data(), "変更した塗装を既存の個体へ反映する")
	check(render._enemy_texture(&"phoenix") != null, "ライブ塗装の牽引船体・サムネイルも準備する")
	look = null
	actual = null
	session.free()
	check(scope.cancelled and scope.resources.is_empty(), "Session終了で生成済み外観の保持を解除する")
	check(reference.get_ref() == null, "未使用の合成本体画像を解放する")
	return true
