## 固定済みアルファと現在のパーツ変換から、描画された縁を調べる。
## 元 centaurus.js cenCut：画面上の不透明度 > 60、ワールド長1刻み。
extends RefCounted

const MASKS := preload("res://assets/effects/boss_contact/centaurus_masks.tres")

static func _sheet(sprite: Sprite2D, sheets: Dictionary) -> Dictionary:
	var texture: Texture2D = sprite.texture
	if texture == null: return {}
	var region := Rect2(Vector2.ZERO, texture.get_size())
	if texture is AtlasTexture:
		region = texture.region
		texture = texture.atlas
	if texture is CanvasTexture: texture = texture.diffuse_texture
	if texture == null or not sheets.has(texture.resource_path): return {}
	var source := sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, sprite.texture.get_size())
	var frame_size := source.size / Vector2(sprite.hframes, sprite.vframes)
	var frame := Vector2(sprite.frame % sprite.hframes, floori(float(sprite.frame) / sprite.hframes))
	return {"mask":sheets[texture.resource_path], "rect":sprite.get_rect(),
		"origin":region.position + source.position + frame * frame_size, "size":frame_size,
		"inverse":sprite.global_transform.affine_inverse(), "flip_h":sprite.flip_h, "flip_v":sprite.flip_v}

static func _opaque(sheet: Dictionary, at: Vector2) -> bool:
	var local: Vector2 = sheet.inverse * at
	var rect: Rect2 = sheet.rect
	if not rect.has_point(local): return false
	var uv := (local-rect.position) / rect.size
	if sheet.flip_h: uv.x = 1.0-uv.x
	if sheet.flip_v: uv.y = 1.0-uv.y
	var size: Vector2 = sheet.size
	var px := clampi(floori(uv.x*size.x),0,int(size.x)-1)
	var py := clampi(floori(uv.y*size.y),0,int(size.y)-1)
	var point: Vector2 = sheet.origin + Vector2(px,py)
	var mask: Dictionary = sheet.mask
	var x := floori(point.x)
	var y := floori(point.y)
	if x < 0 or y < 0 or x >= int(mask.width) or y >= int(mask.height): return false
	var index: int = y*int(mask.width)+x
	var bits: PackedByteArray = mask.bits
	return (int(bits[index >> 3]) & (1 << (index & 7))) != 0

static func _visible_alpha(sprite: Sprite2D) -> float:
	if not sprite.is_visible_in_tree(): return 0.0
	var alpha := sprite.self_modulate.a
	var current: CanvasItem = sprite
	while current != null:
		alpha *= current.modulate.a
		current = current.get_parent() as CanvasItem
	return alpha

static func cut(parts: Array[Dictionary], boss_position: Vector2, radius: float, from: Vector2, direction: Vector2) -> Dictionary:
	if direction.length_squared() <= 0.000001: return {}
	var unit := direction.normalized()
	var sheets: Dictionary = MASKS.get_meta("sheets", {})
	var sprites: Array[Dictionary] = []
	for pair: Dictionary in parts:
		var sprite: Sprite2D = pair.source
		if _visible_alpha(sprite)*255.0 <= 60.0: continue
		var sheet := _sheet(sprite, sheets)
		# 未準備の素材を見落としたまま、別の部位の縁を採用しない。
		if sheet.is_empty(): return {}
		sprites.append(sheet)
	if sprites.is_empty(): return {}
	var extent := radius * 2.0
	var along := (boss_position-from).dot(unit)
	var start := from-unit*ceilf(maxf(0.0,extent-along))
	var steps := ceili(maxf(0.0,(boss_position-start).dot(unit)+extent))
	var first := Vector2.ZERO
	var last := Vector2.ZERO
	var found := false
	for d in range(steps+1):
		var point := start+unit*d
		var raster := (point-boss_position+Vector2.ONE*extent).floor()
		if raster.x < 0.0 or raster.y < 0.0 or raster.x >= ceilf(extent*2.0) or raster.y >= ceilf(extent*2.0): continue
		var sample := boss_position-Vector2.ONE*extent+raster+Vector2(0.5,0.5)
		for sprite: Dictionary in sprites:
			if not _opaque(sprite,sample): continue
			if not found: first = point
			last = point
			found = true
			break
	return {"enter":first,"exit":last} if found else {}
