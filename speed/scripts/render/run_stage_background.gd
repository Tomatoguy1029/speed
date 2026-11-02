## 生成済みの背景配置と画像を、表示用のカメラ値だけで動かす。
extends Node2D
var stars: InstanceBatch
var origin := Vector2.ZERO
var color := Color.BLACK
var area := Rect2()
var sprites: Array[Dictionary] = []
var fires: Array[Dictionary] = []
var static_fires: Array[PixelFire] = []

func setup(scope: ContentResourceScope, metadata: Resource, at: Vector2) -> void:
	origin = at
	color = metadata.background_color
	stars = preload("res://scripts/render/background_star_field.gd").create()
	add_child(stars)
	for placement: BackgroundPlacement in metadata.backgrounds:
		if placement.texture_path.is_empty(): continue
		var sprite := Sprite2D.new()
		sprite.texture = scope.resources[placement.texture_path]
		sprite.region_enabled = true
		sprite.region_rect = placement.bounds()
		sprite.scale = Vector2.ONE*placement.scale
		sprite.rotation_degrees = placement.rotation_degrees
		sprite.modulate = placement.display_tint()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		sprites.append({"node":sprite,"placement":placement})
	# 炎は背景画像より手前に置く。
	for placement: BackgroundPlacement in metadata.backgrounds:
		if placement.texture_path.is_empty() or placement.fire_preset_path.is_empty(): continue
		var fire := PixelFire.new()
		fire.settings = scope.resources[placement.fire_preset_path]
		fire.scale = Vector2.ONE*placement.fire_scale
		add_child(fire)
		fires.append({"node":fire,"placement":placement})
	for key in metadata.fire_uses:
		var use: Dictionary = metadata.fire_uses[key]
		var fire := PixelFire.new()
		fire.settings = scope.resources[str(use.get("preset",""))]
		fire.position = origin+use.get("offset",Vector2.ZERO)
		fire.scale = Vector2.ONE*float(use.get("scale",1.0))
		add_child(fire)
		static_fires.append(fire)

func update_frame(camera: Dictionary) -> void:
	area = Rect2(camera.center-camera.half,camera.half*2.0).grow(200.0)
	for row: Dictionary in sprites:
		row.node.position = origin+row.placement.position_at(camera.center-origin)
	for row: Dictionary in fires:
		row.node.position = origin+row.placement.position_at(camera.center-origin)+row.placement.fire_offset
	preload("res://scripts/render/background_star_field.gd").update_view(stars,camera.center,camera.half,camera.zoom)
	queue_redraw()

func _draw() -> void:
	draw_rect(area,color)

## 制作プレビューは一時停止・コマ送りの時計で炎も動かす。
func set_manual(value: bool) -> void:
	for row: Dictionary in fires: row.node.manual = value
	for fire: PixelFire in static_fires: fire.manual = value

func restart() -> void:
	for row: Dictionary in fires: row.node.restart()
	for fire: PixelFire in static_fires: fire.restart()

func advance(delta: float) -> void:
	for row: Dictionary in fires: row.node.advance(delta)
	for fire: PixelFire in static_fires: fire.advance(delta)
