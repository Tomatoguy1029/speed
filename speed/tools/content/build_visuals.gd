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
	return _build_meteor_pieces(output) if error == OK else error

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
