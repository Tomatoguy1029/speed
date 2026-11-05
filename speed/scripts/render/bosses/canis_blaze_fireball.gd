## 固定試作が使うpixelFX fireball原画像。猟犬本体より奥に重ねる。
extends Node2D

const SHEET := preload("res://assets/effects/reference/canis/fireball.png")
const FRAME_SIZE := Vector2(136,56)
const PIVOT := Vector2(112,28)
var _sprites := {}

func apply_frame(burning: Array, clock: float) -> void:
	var live := {}
	for row: Dictionary in burning:
		var id := int(row.actor)
		live[id] = true
		if not _sprites.has(id):
			var sprite := Sprite2D.new()
			sprite.texture = SHEET
			sprite.region_enabled = true
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.offset = FRAME_SIZE*0.5-PIVOT
			add_child(sprite)
			_sprites[id] = sprite
		var sprite: Sprite2D = _sprites[id]
		var frame := posmod(floori((clock+id*0.13)*30.0),36)
		sprite.region_rect = Rect2(Vector2(frame%4,floori(float(frame)/4.0))*FRAME_SIZE,FRAME_SIZE)
		sprite.position = row.position
		sprite.rotation = float(row.facing)
		sprite.scale = Vector2(float(row.radius)*7.0/100.0,float(row.radius)*3.2/18.0)
		sprite.modulate.a = 0.88
	for id in _sprites.keys():
		if not live.has(id):
			_sprites[id].queue_free()
			_sprites.erase(id)
