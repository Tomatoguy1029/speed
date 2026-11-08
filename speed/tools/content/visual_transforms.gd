## 透過の4近傍または明示した領域表で装甲片を分け、種類ごとの塗装を作る。
@tool
extends RefCounted

static var _layouts: Dictionary = {}

static func layout(texture: Texture2D) -> Dictionary:
	var id := texture.get_instance_id()
	if _layouts.has(id):
		return _layouts[id]
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var width := image.get_width()
	var height := image.get_height()
	var opaque := PackedByteArray()
	var labels := PackedInt32Array()
	var shades := PackedFloat32Array()
	opaque.resize(width * height)
	labels.resize(width * height)
	labels.fill(-1)
	shades.resize(width * height)
	for pixel in labels.size():
		var color := image.get_pixel(pixel % width, pixel / width)
		opaque[pixel] = 1 if color.a > 0.0 else 0
		shades[pixel] = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
	var regions := {}
	for start in labels.size():
		if opaque[start] == 0 or labels[start] >= 0:
			continue
		var pixels := PackedInt32Array([start])
		labels[start] = start
		var cursor := 0
		var brightest := 0.001
		while cursor < pixels.size():
			var pixel := pixels[cursor]
			cursor += 1
			brightest = maxf(brightest, shades[pixel])
			var x := pixel % width
			for neighbor in [pixel - 1 if x > 0 else -1, pixel + 1 if x < width - 1 else -1,
				pixel - width, pixel + width]:
				if neighbor < 0 or neighbor >= labels.size() or opaque[neighbor] == 0 or labels[neighbor] >= 0:
					continue
				labels[neighbor] = start
				pixels.append(neighbor)
		for pixel in pixels:
			shades[pixel] = shades[pixel] / brightest if brightest > 0.001 else 1.0
		regions[start] = pixels
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(opaque)
	var alpha_hash := digest.finish().hex_encode()
	var key := "%s|%dx%d|%s" % [texture.resource_path, width, height, alpha_hash]
	var result := {"image": image, "width": width, "height": height, "labels": labels,
		"regions": regions, "shades": shades, "key": key, "parents": {}}
	var partition_path := texture.resource_path.get_basename() + ".regions.json"
	if FileAccess.file_exists(partition_path):
		_partition(result, partition_path, alpha_hash)
	_layouts[id] = result
	return result

## 領域表は画素を描き替えず、クリック・塗装の単位だけを指定する。
## 濃淡は元の連結領域を基準にし、normalize_shades指定時は分割した領域ごとを基準にする。
static func _partition(data: Dictionary, path: String, alpha_hash: String) -> void:
	var partition: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(partition is Dictionary and partition.get("alpha_sha256", "") == alpha_hash, "装甲領域表のマスクが一致しない: " + path)
	var rows: Array = partition.get("rows", [])
	assert(rows.size() == data.height, "装甲領域表の高さが一致しない: " + path)
	var labels := PackedInt32Array()
	labels.resize(data.labels.size())
	labels.fill(-1)
	var regions := {}
	var parents := {}
	for y in rows.size():
		var row: String = rows[y]
		assert(row.length() == data.width, "装甲領域表の幅が一致しない: " + path)
		for x in row.length():
			var pixel := y * int(data.width) + x
			var parent: int = data.labels[pixel]
			assert((row[x] == ".") == (parent < 0), "装甲領域表の透過が一致しない: " + path)
			if parent < 0: continue
			# 元の画素番号と重ならないIDにし、旧塗装と個別塗装を区別する。
			var region: int = data.labels.size() + row.unicode_at(x)
			assert(not parents.has(region) or parents[region] == parent, "装甲領域表が異なる元領域を結合している: " + path)
			if not regions.has(region): regions[region] = PackedInt32Array()
			var pixels: PackedInt32Array = regions[region]
			pixels.append(pixel)
			regions[region] = pixels
			parents[region] = parent
			labels[pixel] = region
	if partition.get("normalize_shades", false):
		for pixels: PackedInt32Array in regions.values():
			var brightest := 0.001
			for pixel in pixels: brightest = maxf(brightest, data.shades[pixel])
			for pixel in pixels: data.shades[pixel] = data.shades[pixel] / brightest if brightest > 0.001 else 1.0
	data.labels = labels
	data.regions = regions
	data.parents = parents

## 旧領域の塗装を個別領域へ展開する。以降の編集・解除は選択パーツだけへ作用する。
static func region_colors(data: Dictionary, palettes: Dictionary) -> Dictionary:
	var colors: Dictionary = palettes.get(data.key, {})
	if data.parents.is_empty(): return colors.duplicate()
	var result := {}
	for region in data.regions:
		var key := str(region)
		var parent := str(data.parents[region])
		if colors.has(key): result[key] = colors[key]
		elif colors.has(parent): result[key] = colors[parent]
	return result

static func painted_image(texture: Texture2D, palettes: Dictionary) -> Image:
	var data := layout(texture)
	var image: Image = data.image.duplicate()
	var colors := region_colors(data, palettes)
	for region in colors:
		var pixels: PackedInt32Array = data.regions.get(int(region), PackedInt32Array())
		var color := Color.html(colors[region])
		for pixel in pixels:
			var alpha := image.get_pixel(pixel % int(data.width), pixel / int(data.width)).a
			var shade: float = data.shades[pixel]
			image.set_pixel(pixel % int(data.width), pixel / int(data.width), Color(color.r * shade, color.g * shade, color.b * shade, alpha))
	return image

static func valid_palettes(value: Variant) -> bool:
	if not value is Dictionary or value.size() > 64:
		return false
	for key in value:
		if not key is String or key.length() > 512 or not value[key] is Dictionary or value[key].size() > 65536:
			return false
		for region in value[key]:
			var color: Variant = value[key][region]
			if not region is String or not region.is_valid_int() or int(region) < 0:
				return false
			if not color is String or color.length() != 6 or not Color.html_is_valid(color):
				return false
	return true

## 画像を外周へ余白分だけ広げる。
static func _padded(image: Image) -> Image:
	var source := image.duplicate() as Image
	if source.is_compressed(): source.decompress()
	source.convert(Image.FORMAT_RGBA8)
	var pad := EnemyLook.OUTLINE_PAD
	var result := Image.create_empty(source.get_width() + pad * 2, source.get_height() + pad * 2, false, Image.FORMAT_RGBA8)
	result.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i(pad, pad))
	return result

## 群れの中でも個体の境目が読めるよう、絵の外周に1ドットの縁を焼き込んだ下地を作る。
## 縁は下地・装甲（分離する外観は相手側も含む）を合わせた外形の、上下左右の隣だけに置く。
static func _outlined_base(base: Image, shapes: Array[Image]) -> Image:
	var result := _padded(base)
	var width := result.get_width()
	var height := result.get_height()
	var filled := PackedByteArray()
	filled.resize(width * height)
	var pad := EnemyLook.OUTLINE_PAD
	for shape in shapes:
		var image := shape.duplicate() as Image
		if image.is_compressed(): image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		for y in mini(image.get_height(), height - pad * 2):
			for x in mini(image.get_width(), width - pad * 2):
				if image.get_pixel(x, y).a > 0.0: filled[(y + pad) * width + x + pad] = 1
	for y in height:
		for x in width:
			if filled[y * width + x] == 1: continue
			if (x > 0 and filled[y * width + x - 1] == 1) or (x < width - 1 and filled[y * width + x + 1] == 1) \
					or (y > 0 and filled[(y - 1) * width + x] == 1) or (y < height - 1 and filled[(y + 1) * width + x] == 1):
				result.set_pixel(x, y, EnemyLook.OUTLINE_COLOR)
	return result

static func prepare_look(source: EnemyLook, palettes: Array[Dictionary], pair: EnemyLook = null) -> EnemyLook:
	var result := source.duplicate() as EnemyLook
	result.prepared = true
	result.source_path = source.resource_path
	result.painted_armors = {}
	result.previews = {}
	var data := layout(source.armor)
	result.armor_key = data.key
	if not source.armor_color_source_key.is_empty():
		var color_source := load(source.armor_color_source_key.get_slice("|", 0)) as Texture2D
		var color_data := layout(color_source)
		assert(color_data.key == source.armor_color_source_key, "塗装の継承元が一致しない: " + source.resource_path)
		for region in source.armor_color_regions:
			assert(data.regions.has(int(region)) and color_data.regions.has(int(source.armor_color_regions[region])), "塗装の対応領域が存在しない: " + source.resource_path)
	if source.decorations != null:
		var image := source.base.get_image().duplicate()
		image.blend_rect(source.decorations.get_image(), Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
		result.base = ImageTexture.create_from_image(image)
	result.decorations = null
	if source.split_other != null: result.split_other = prepare_look(source.split_other, palettes, source)
	var shapes: Array[Image] = [result.base.get_image(), source.armor.get_image()]
	var partner := source.split_other if source.split_other != null else pair
	if partner != null: shapes.append_array([partner.base.get_image(), partner.armor.get_image()])
	result.outlined_base = ImageTexture.create_from_image(_outlined_base(result.base.get_image(), shapes))
	result.outlined_normal = ImageTexture.create_from_image(_padded(source.normal.get_image())) if source.normal != null else null
	result.outlined_armors = {}
	for palette in palettes:
		var armor_id := result.colors_key(palette)
		if not result.painted_armors.has(armor_id):
			result.painted_armors[armor_id] = source.armor if armor_id.is_empty() else ImageTexture.create_from_image(painted_image(source.armor, result.paint_palettes(palette)))
			result.outlined_armors[armor_id] = ImageTexture.create_from_image(_padded(result.painted_armors[armor_id].get_image()))
		var preview_id := result.preview_key(palette)
		if result.previews.has(preview_id): continue
		var image := result.base.get_image().duplicate()
		image.blend_rect(result.painted_armors[armor_id].get_image(), Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
		if result.split_other != null:
			image.blend_rect(result.split_other.previews[result.split_other.preview_key(palette)].get_image(), Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
		result.previews[preview_id] = ImageTexture.create_from_image(image)
	return result

## 実験場が明示的に接続するライブ編集用経路。配布版のフォールバックには使わない。
static func live_look(look: EnemyLook, palettes: Dictionary) -> EnemyLook:
	var source := load(look.source_path) as EnemyLook
	return prepare_look(source, [{}, palettes])
