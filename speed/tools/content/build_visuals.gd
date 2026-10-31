## 固定外観・塗装・装甲領域と外観名の索引を、共通生成入口から保存する。
@tool
extends RefCounted
const TRANSFORM := preload("res://tools/content/visual_transforms.gd")

static func build(output: String) -> Error:
	var mask_error := _validate_landmark_masks()
	if mask_error != OK: return mask_error
	var biter_error := _validate_biter_parts()
	if biter_error != OK: return biter_error
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
	return _build_meteor_pieces(output) if error == OK else error

## 制作工程のCPUベイカーが保存した固定素材を、正規ビルドでも検査する。
## サイズ・塗装の値は実行時の本体と共有し、透過形状の入力だけを固定する。
static func _validate_landmark_masks() -> Error:
	var masks := ResourceLoader.load("res://assets/effects/landmark/masks.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Resource
	if masks == null or masks.get_meta("bake_version", 0) != 1: return ERR_INVALID_DATA
	for path: String in masks.get_meta("inputs", {}):
		if FileAccess.get_sha256(path) != masks.get_meta("inputs")[path]:
			push_error("目印マスクの入力が変わりました。tools/art/bake_landmark_masks.pyでベイク: " + path)
			return ERR_INVALID_DATA
	var candidates: Array = masks.get_meta("candidates", [])
	for entry: Dictionary in masks.get_meta("masks", {}).values():
		if entry.texture == null or FileAccess.get_sha256(entry.file) != entry.mask_sha256:
			push_error("目印マスクの生成物が欠落・不一致: " + str(entry.file))
			return ERR_INVALID_DATA
	var current: Array[String] = []
	for file in DirAccess.get_files_at("res://data/enemies"):
		if not file.ends_with(".tres"): continue
		var definition := load("res://data/enemies/" + file) as EnemyDef
		if definition.rank >= 2 and definition.rank <= 5: current.append(file.get_basename())
		var expected: String = masks.get_meta("fallback_shapes", {}).get(file.get_basename(), "")
		if not expected.is_empty() and String(definition.shape) != expected: return ERR_INVALID_DATA
	current.sort()
	if current != candidates:
		push_error("目印候補が変わりました。tools/art/bake_landmark_masks.pyでベイクしてください。")
		return ERR_INVALID_DATA
	var aliases := {}
	for file in DirAccess.get_files_at("res://data/stages"):
		if not file.begins_with("stage_") or not file.ends_with(".tres"): continue
		var stage := load("res://data/stages/" + file) as StageDef
		for id: String in stage.enemy_looks:
			if id in candidates: aliases[id + ":" + file.get_basename()] = stage.enemy_looks[id]
	if aliases != masks.get_meta("stage_aliases", {}):
		push_error("目印候補の外観が変わりました。tools/art/bake_landmark_masks.pyでベイクしてください。")
		return ERR_INVALID_DATA
	return OK

static func _validate_biter_parts() -> Error:
	var parts := ResourceLoader.load("res://data/visuals/biter_parts.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Resource
	if parts == null or parts.get_meta("bake_version", 0) != 1: return ERR_INVALID_DATA
	for group in ["inputs", "outputs"]:
		for path: String in parts.get_meta(group, {}):
			if FileAccess.get_sha256(path) != parts.get_meta(group)[path]:
				push_error("噛みつく雑魚の分割素材をtools/art/bake_biter_parts.pyで更新してください: " + path)
				return ERR_INVALID_DATA
	return OK

## 隣の破片が切り出し矩形へ入り込む部分を、制作時に除く。
static func _build_meteor_pieces(output: String) -> Error:
	var frames := load("res://data/visuals/meteor_pieces.tres").duplicate(true) as SpriteFrames
	for animation in frames.get_animation_names():
		for i in frames.get_frame_count(animation):
			var source := frames.get_frame_texture(animation, i) as AtlasTexture
			var image := source.get_image()
			var seen := {}
			var groups: Array = []
			for y in image.get_height():
				for x in image.get_width():
					var point := Vector2i(x, y)
					if seen.has(point) or image.get_pixelv(point).a == 0.0: continue
					var group: Array[Vector2i] = [point]
					seen[point] = true
					var next := 0
					while next < group.size():
						var current := group[next]
						next += 1
						for dy in range(-1, 2):
							for dx in range(-1, 2):
								var neighbor := current + Vector2i(dx, dy)
								if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= image.get_width() or neighbor.y >= image.get_height(): continue
								if seen.has(neighbor) or image.get_pixelv(neighbor).a == 0.0: continue
								seen[neighbor] = true
								group.append(neighbor)
					groups.append(group)
			if groups.is_empty(): return ERR_INVALID_DATA
			groups.sort_custom(func(a, b): return a.size() > b.size())
			var isolated := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
			for k in groups.size():
				# 原画の微小な離れドットも残す。
				if k != 0 and groups[k].size() > 2: continue
				for point in groups[k]: isolated.set_pixelv(point, image.get_pixelv(point))
			var piece := AtlasTexture.new()
			piece.atlas = ImageTexture.create_from_image(isolated)
			piece.region = Rect2(Vector2.ZERO, source.region.size)
			piece.set_meta("offset", source.region.get_center() - source.atlas.get_size() * 0.5)
			frames.set_frame(animation, i, piece)
	return ResourceSaver.save(frames, output.path_join("meteor_pieces.res"))
