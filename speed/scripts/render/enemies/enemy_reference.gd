## 承認済みの敵FXを同じ前後の論理画素層へ渡す。
extends RefCounted

const PHOENIX := preload("res://scripts/render/enemies/phoenix_reference.gd")
const BEAMER := preload("res://scripts/render/enemies/beamer_reference.gd")
const LYNX := preload("res://scripts/render/enemies/lynx_reference.gd")

var _parent: Node2D
var _scope: ContentResourceScope
var _visuals: Dictionary
var _phoenix = PHOENIX.new()
var _beamer = BEAMER.new()
var _lynx = LYNX.new()
var _last_world_time := -1.0
var _ghost_layers := {}
var _ghosts: Array[Sprite2D] = []

## parent はカメラ変換が適用されるワールド層。影は論理画素の背面より奥に置く。
func setup(parent: Node2D, scope: ContentResourceScope, visuals: Dictionary) -> void:
	_parent = parent
	_scope = scope
	_visuals = visuals
	_phoenix.setup_shadow(parent)

func render(frame: Dictionary, events: Array, canvas, _real_dt: float, world_time: float) -> void:
	var world_dt := 0.0 if _last_world_time < 0.0 or world_time < _last_world_time else world_time - _last_world_time
	_last_world_time = world_time
	if frame.has("phoenix_fx") and frame.has("phoenix_impacts"):
		var logical_pixel_size := _parent.get_viewport().get_visible_rect().size.y / 225.0
		_phoenix.render(frame.phoenix_fx, frame.phoenix_impacts, canvas, world_dt, world_time, logical_pixel_size)
	if frame.has("beamer_fx"):
		_beamer.render(frame.beamer_fx, events, canvas, world_time)
	if frame.has("lynx_fx") and frame.has("lynx_actors"):
		_lynx.render(frame.lynx_fx, frame.lynx_actors, canvas, world_time)
	_draw_afterimages(frame.get("lynx_afterimages", []))

## 呼び出し元のフレームや配列は変更せず、移植済みの旧描画だけを除く。
func strip_legacy(frame: Dictionary) -> Dictionary:
	var result := frame.duplicate()
	var phoenix := frame.has("phoenix_fx") and frame.has("phoenix_impacts")
	var beamer := frame.has("beamer_fx")
	var lynx := frame.has("lynx_fx") and frame.has("lynx_actors")
	if phoenix:
		result.phoenix = PackedFloat64Array()
	if beamer or lynx:
		var batches: Array = []
		for source: Dictionary in frame.get("batches", []):
			var row := source.duplicate()
			if beamer: row.erase("beamer")
			if lynx: row.erase("lynx")
			batches.append(row)
		result.batches = batches
	if phoenix or beamer or lynx:
		var shapes: Array = []
		for row: Dictionary in frame.get("shapes", []):
			if phoenix and int(row.get("zone_style", -1)) == 5:
				continue
			if beamer and bool(row.get("reference_beamer", false)):
				continue
			if lynx and bool(row.get("reference_lynx", false)):
				continue
			shapes.append(row)
		result.shapes = shapes
	return result

func _draw_afterimages(rows: Array) -> void:
	for sprite in _ghosts:
		sprite.hide()
	var used := 0
	for row: Dictionary in rows:
		var visual_id := int(row.visual_id)
		if not _visuals.has(visual_id):
			continue
		var entry: Dictionary = _visuals[visual_id]
		var look := _scope.resources.get(entry.path) as EnemyLook
		if look == null or not look.previews.has(entry.hull_preview):
			continue
		var texture := look.previews[entry.hull_preview] as Texture2D
		if texture == null:
			continue
		if not _ghost_layers.has(visual_id):
			var layer := CanvasLayer.new()
			layer.layer = visual_id - 5
			layer.follow_viewport_enabled = true
			_parent.add_child(layer)
			_ghost_layers[visual_id] = layer
		var sprite: Sprite2D
		if used >= _ghosts.size():
			sprite = Sprite2D.new()
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_ghost_layers[visual_id].add_child(sprite)
			_ghosts.append(sprite)
		else:
			sprite = _ghosts[used]
			if sprite.get_parent() != _ghost_layers[visual_id]:
				sprite.reparent(_ghost_layers[visual_id])
		used += 1
		sprite.texture = texture
		sprite.position = row.pos
		sprite.rotation = float(row.angle)
		sprite.scale = Vector2.ONE * (2.0 * float(row.radius) / maxf(texture.get_width(), texture.get_height()))
		sprite.modulate = Color(1, 1, 1, float(row.alpha))
		sprite.show()
