## 固定外観・塗装・装甲領域と外観名の索引を、共通生成入口から保存する。
@tool
extends RefCounted
const TRANSFORM := preload("res://tools/content/visual_transforms.gd")

static func build(output: String) -> Error:
	TRANSFORM._layouts.clear()
	var palettes: Array[Dictionary] = [{}]
	for file in DirAccess.get_files_at("res://data/enemies"):
		if not file.ends_with(".tres"): continue
		var definition := load("res://data/enemies/" + file) as EnemyDef
		if not definition.armor_colors.is_empty(): palettes.append(definition.armor_colors)
	var index := StageResources.new()
	for file in DirAccess.get_files_at("res://data/visuals/looks"):
		if not file.ends_with(".tres"): continue
		var source := ResourceLoader.load("res://data/visuals/looks/" + file, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyLook
		var name := file.get_basename()
		var result: EnemyLook = TRANSFORM.prepare_look(source, palettes)
		if result == null or not result.prepared or result.previews.is_empty(): return ERR_INVALID_DATA
		var path := output.path_join("look_" + name + ".res")
		var error := ResourceSaver.save(result, path)
		if error != OK: return error
		# 領域データはライブ編集専用。配布には確定した塗装画像だけを含める。
		var layout := Resource.new()
		layout.set_meta("data", TRANSFORM.layout(source.armor))
		error = ResourceSaver.save(layout, output.path_join("dev/armor_" + name + ".res"))
		if error != OK: return error
		index.look_names.append(name)
		index.look_paths[name] = path
	index.look_names.sort()
	var error := ResourceSaver.save(index, output.path_join("visual_index.tres"))
	TRANSFORM._layouts.clear()
	return error
