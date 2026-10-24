## 透過で区切られた装甲片を上下左右の4近傍で分け、種類ごとの塗装を作る。
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
	var key := "%s|%dx%d|%s" % [texture.resource_path, width, height, digest.finish().hex_encode()]
	var result := {"image": image, "width": width, "height": height, "labels": labels,
		"regions": regions, "shades": shades, "key": key}
	_layouts[id] = result
	return result

static func painted_image(texture: Texture2D, palettes: Dictionary) -> Image:
	var data := layout(texture)
	var image: Image = data.image.duplicate()
	var colors: Dictionary = palettes.get(data.key, {})
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

static func prepare_look(source: EnemyLook, palettes: Array[Dictionary]) -> EnemyLook:
	var result := source.duplicate() as EnemyLook
	result.prepared = true
	result.source_path = source.resource_path
	result.painted_armors = {}
	result.previews = {}
	var data := layout(source.armor)
	result.armor_key = data.key
	if source.decorations != null:
		var image := source.base.get_image().duplicate()
		image.blend_rect(source.decorations.get_image(), Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
		result.base = ImageTexture.create_from_image(image)
	result.decorations = null
	if source.split_other != null: result.split_other = prepare_look(source.split_other, palettes)
	for palette in palettes:
		var armor_id := result.colors_key(palette)
		if not result.painted_armors.has(armor_id):
			result.painted_armors[armor_id] = source.armor if armor_id.is_empty() else ImageTexture.create_from_image(painted_image(source.armor, palette))
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
