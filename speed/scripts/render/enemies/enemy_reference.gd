## 承認済みの敵FXを同じ前後の論理画素層へ渡す。
extends RefCounted

const COMPOSITE := preload("res://shaders/fx_reference_composite.gdshader")
const PHOENIX := preload("res://scripts/render/enemies/phoenix_reference.gd")
const BEAMER := preload("res://scripts/render/enemies/beamer_reference.gd")
const LYNX := preload("res://scripts/render/enemies/lynx_reference.gd")
const BITE := preload("res://scripts/render/enemies/bite_reference.gd")
const CROSS := preload("res://scripts/render/enemies/cross_reference.gd")
const CRAB := preload("res://scripts/render/enemies/crab_reference.gd")
const RULER := preload("res://scripts/render/enemies/ruler_reference.gd")
const DOLPHIN := preload("res://scripts/render/enemies/dolphin_reference.gd")
const AURIGA := preload("res://scripts/render/enemies/auriga_reference.gd")
const TELESCOPE := preload("res://scripts/render/enemies/telescope_reference.gd")
const RETICLE := preload("res://scripts/render/enemies/reticle_reference.gd")
const AQUARIUS := preload("res://scripts/render/enemies/aquarius_reference.gd")
const SOLDIER := preload("res://scripts/render/enemies/soldier_reference.gd")
const CEPHEUS := preload("res://scripts/render/enemies/cepheus_reference.gd")
const CORONA := preload("res://scripts/render/enemies/corona_reference.gd")
const AQUILA := preload("res://scripts/render/enemies/aquila_reference.gd")

var _parent: Node2D
var _scope: ContentResourceScope
var _visuals: Dictionary
var _phoenix = PHOENIX.new()
var _beamer = BEAMER.new()
var _lynx = LYNX.new()
var _bite = BITE.new()
var _cross = CROSS.new()
var _crab = CRAB.new()
var _ruler = RULER.new()
var _dolphin = DOLPHIN.new()
var _auriga = AURIGA.new()
var _telescope = TELESCOPE.new()
var _reticle = RETICLE.new()
var _aquarius = AQUARIUS.new()
var _soldier = SOLDIER.new()
var _cepheus = CEPHEUS.new()
var _corona = CORONA.new()
var _aquila = AQUILA.new()
var _last_world_time := -1.0
var _ghost_layers := {}
var _ghosts: Array[Sprite2D] = []
var _ghost_copies: Array[BackBufferCopy] = []

## parent は前面の表示層。鳳凰の影は本体より奥にある専用の親へ置く。
func setup(parent: Node2D, scope: ContentResourceScope, visuals: Dictionary, shadow_parent: Node2D) -> void:
	_parent = parent
	_scope = scope
	_visuals = visuals
	_phoenix.setup_shadow(shadow_parent)
	_telescope.setup(parent)
	_aquarius.setup(parent, scope)
	_cepheus.setup(parent, scope, visuals)
	_corona.setup(parent, scope, visuals)
	_aquila.setup(parent, scope, visuals)

func render(frame: Dictionary, events: Array, canvas, _real_dt: float, world_time: float) -> void:
	var world_dt := 0.0 if _last_world_time < 0.0 or world_time < _last_world_time else world_time - _last_world_time
	_last_world_time = world_time
	var normalized: Array = []
	for event: Dictionary in events:
		var payload: Dictionary = event.get("payload", event).duplicate()
		payload["type"] = event.get("type", "")
		for key in ["world_t", "sequence", "epoch"]:
			if event.has(key): payload[key] = event[key]
		normalized.append(payload)
	if frame.has("phoenix_fx") and frame.has("phoenix_impacts"):
		var logical_pixel_size := _parent.get_viewport().get_visible_rect().size.y / 225.0
		_phoenix.render(frame.phoenix_fx, frame.phoenix_impacts, canvas, world_dt, world_time, logical_pixel_size)
	if frame.has("beamer_fx"):
		_beamer.render(frame.beamer_fx, normalized, canvas, world_time)
	if frame.has("lynx_fx") and frame.has("lynx_actors"):
		_lynx.render(frame.lynx_fx, frame.lynx_actors, canvas, world_time)
	if frame.has("bite_fx"):
		_bite.render(frame.bite_fx, normalized, canvas, world_time)
	if frame.has("cross_actors") and frame.has("cross_beams"):
		_cross.render(frame.cross_actors, frame.cross_beams, normalized, canvas, world_time)
	if frame.has("crab_fx"):
		_crab.render(frame.crab_fx, canvas, world_time)
	if frame.has("ruler_fx"):
		_ruler.render(frame.ruler_fx, normalized, canvas, world_time)
	if frame.has("dolphin_actors") and frame.has("dolphin_waves"):
		_dolphin.render(frame.dolphin_actors, frame.dolphin_waves, normalized, canvas, world_time)
	if frame.has("auriga_trails"):
		_auriga.render(frame.auriga_trails, canvas, world_time)
	if frame.has("telescope_beams") and frame.has("telescope_actors"):
		_telescope.render(frame.telescope_actors, frame.telescope_beams, normalized, canvas, world_time)
	if frame.has("reticle_fx"):
		_reticle.render(frame.reticle_fx, normalized, canvas, world_time)
	if frame.has("aquarius_jets"):
		_aquarius.render(frame.aquarius_jets, normalized, canvas, world_time)
	if frame.has("soldier_fx") and frame.has("soldier_bolts"):
		_soldier.render(frame.soldier_fx, frame.soldier_bolts, canvas, world_time)
	if frame.has("cepheus_fx") and frame.has("cepheus_actors"):
		_cepheus.render(frame.cepheus_actors, frame.cepheus_fx, canvas, world_time)
	if frame.has("corona_selected") and frame.has("corona_thrown"):
		_corona.render(frame.corona, frame.corona_selected, frame.corona_thrown, canvas, world_time)
	if frame.has("aquila_actors") and frame.has("aquila_zones"):
		_aquila.render(frame.aquila_actors, frame.aquila_zones, normalized, canvas, world_time)
	_draw_afterimages(frame.get("lynx_afterimages", []))

## 呼び出し元のフレームや配列は変更せず、移植済みの旧描画だけを除く。
func strip_legacy(frame: Dictionary) -> Dictionary:
	var result := frame.duplicate()
	var phoenix := frame.has("phoenix_fx") and frame.has("phoenix_impacts")
	var beamer := frame.has("beamer_fx")
	var lynx := frame.has("lynx_fx") and frame.has("lynx_actors")
	var bite := frame.has("bite_fx")
	var cross := frame.has("cross_actors") and frame.has("cross_beams")
	var crab := frame.has("crab_fx")
	var ruler := frame.has("ruler_fx")
	var dolphin := frame.has("dolphin_actors") and frame.has("dolphin_waves")
	var auriga := frame.has("auriga_trails")
	var telescope := frame.has("telescope_beams") and frame.has("telescope_actors")
	var reticle := frame.has("reticle_fx")
	var aquarius := frame.has("aquarius_jets")
	var soldier := frame.has("soldier_fx") and frame.has("soldier_bolts")
	var cepheus := frame.has("cepheus_fx") and frame.has("cepheus_actors")
	var corona := frame.has("corona_selected") and frame.has("corona_thrown")
	var aquila := frame.has("aquila_actors") and frame.has("aquila_zones")
	if phoenix:
		result.phoenix = PackedFloat64Array()
	if ruler:
		result.ruler = PackedFloat64Array()
	if cepheus:
		result.cepheus = {"values":PackedFloat64Array(), "marks":PackedFloat64Array()}
	if aquila:
		result.aquila = {"values":PackedFloat64Array(), "view":frame.aquila.view}
	if corona:
		result.corona = PackedFloat64Array()
		var members: PackedFloat64Array = frame.get("corona_members", PackedFloat64Array())
		var kept := PackedFloat64Array()
		for index in range(0, members.size(), 10):
			if members[index+3] <= 0.0 and members[index+6] <= 0.0: kept.append_array(members.slice(index,index+10))
		result.corona_members = kept
	if beamer or lynx or bite or cross or crab or dolphin or telescope or reticle or aquarius or soldier:
		var batches: Array = []
		for source: Dictionary in frame.get("batches", []):
			var row := source.duplicate()
			if beamer: row.erase("beamer")
			if lynx: row.erase("lynx")
			if cross: row.erase("cross")
			if dolphin: row.erase("dolphin")
			if telescope: row.erase("sniper")
			if reticle: row.erase("reticle")
			if aquarius: row.erase("aquarius")
			if soldier: row.erase("soldier")
			if crab and row.has("crab"):
				var old_crab: PackedFloat32Array = row.crab.duplicate()
				for index in range(0, old_crab.size(), 14): old_crab[index + 4] = 0.0
				row["crab"] = old_crab
			if bite and row.has("reference_bite_indices"):
				var indices: PackedInt32Array = row.reference_bite_indices
				var old: PackedFloat32Array = row.get("gunner", PackedFloat32Array())
				var kept := PackedFloat32Array()
				for index in range(old.size() / 5):
					if not indices.has(index): kept.append_array(old.slice(index * 5, index * 5 + 5))
				row["gunner"] = kept
			batches.append(row)
		result.batches = batches
	if phoenix or beamer or lynx or bite or cross or crab or ruler or dolphin or auriga or telescope or aquarius or soldier or aquila:
		var shapes: Array = []
		for row: Dictionary in frame.get("shapes", []):
			if phoenix and int(row.get("zone_style", -1)) == 5:
				continue
			if beamer and bool(row.get("reference_beamer", false)):
				continue
			if lynx and bool(row.get("reference_lynx", false)):
				continue
			if bite and bool(row.get("reference_bite", false)):
				continue
			if cross and bool(row.get("reference_cross", false)):
				continue
			if crab and bool(row.get("reference_crab", false)):
				continue
			if ruler and bool(row.get("reference_ruler", false)):
				continue
			if dolphin and bool(row.get("reference_dolphin", false)):
				continue
			if auriga and bool(row.get("reference_auriga", false)):
				continue
			if telescope and bool(row.get("reference_telescope", false)):
				continue
			if aquarius and bool(row.get("reference_aquarius", false)):
				continue
			if soldier and bool(row.get("reference_soldier_bolt", false)):
				continue
			if aquila and bool(row.get("reference_aquila", false)):
				continue
			shapes.append(row)
		result.shapes = shapes
	return result

func _draw_afterimages(rows: Array) -> void:
	for sprite in _ghosts:
		sprite.hide()
	for copy in _ghost_copies:
		copy.hide()
	var used := 0
	for row: Dictionary in rows:
		var visual_id := int(row.visual_id)
		if not _visuals.has(visual_id):
			continue
		var entry: Dictionary = _visuals[visual_id]
		var look := _scope.resources.get(entry.path) as EnemyLook
		var preview: String = entry.get("hull_preview", "")
		if look == null or not look.previews.has(preview):
			continue
		var texture := look.previews[preview] as Texture2D
		if texture == null:
			continue
		if not _ghost_layers.has(visual_id):
			var layer := CanvasLayer.new()
			layer.layer = visual_id - 5
			layer.follow_viewport_enabled = true
			_parent.add_child(layer)
			_ghost_layers[visual_id] = layer
		var sprite: Sprite2D
		var copy: BackBufferCopy
		if used >= _ghosts.size():
			copy = BackBufferCopy.new()
			copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
			_ghost_layers[visual_id].add_child(copy)
			_ghost_copies.append(copy)
			sprite = Sprite2D.new()
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var material := ShaderMaterial.new()
			material.shader = COMPOSITE
			material.set_shader_parameter("has_light",false)
			sprite.material = material
			_ghost_layers[visual_id].add_child(sprite)
			_ghosts.append(sprite)
		else:
			sprite = _ghosts[used]
			copy = _ghost_copies[used]
			if sprite.get_parent() != _ghost_layers[visual_id]:
				copy.reparent(_ghost_layers[visual_id])
				sprite.reparent(_ghost_layers[visual_id])
		used += 1
		copy.show()
		sprite.texture = texture
		sprite.material.set_shader_parameter("color_pixels",texture)
		sprite.material.set_shader_parameter("light_pixels",texture)
		sprite.material.set_shader_parameter("opacity",float(row.alpha))
		sprite.material.set_shader_parameter("linear_target",_parent.get_viewport().use_hdr_2d)
		sprite.position = row.pos
		sprite.rotation = float(row.angle)
		sprite.scale = Vector2.ONE * (2.0 * float(row.radius) / maxf(texture.get_width(), texture.get_height()))
		sprite.modulate = Color.WHITE
		sprite.show()
