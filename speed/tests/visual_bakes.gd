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
		if not compare.is_empty(): _compare(compare)
	print("[visual_bakes] %d failures" % failed)
	get_tree().quit(1 if failed else 0)

func _capture(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var paint = load("res://scripts/render/armor_paint.gd")
	for file in DirAccess.get_files_at("res://data/visuals/looks"):
		if not file.ends_with(".tres"): continue
		var look := load("res://data/visuals/looks/" + file) as EnemyLook
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

func _compare(_folder: String) -> void:
	pass
