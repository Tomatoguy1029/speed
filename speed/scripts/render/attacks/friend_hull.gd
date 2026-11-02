## 元の敵の外観と丸鋸の固定形を、表示用の値だけから描く。
extends Node2D
const ROLE = preload("res://tools/content/generated/run_schema.gd").ENUMS.VisualRole
var _row: Dictionary = {}
var _texture: Texture2D
var _polygon := PackedVector2Array()
var _scope: ContentResourceScope
var _visuals: Dictionary
func setup(scope: ContentResourceScope, visuals: Dictionary) -> void:
	_scope = scope
	_visuals = visuals
func apply_frame(row: Dictionary) -> void:
	_row = row
	_texture = null
	_polygon = PackedVector2Array()
	if not row.saw and _visuals.has(row.visual_id):
		var entry: Dictionary = _visuals[row.visual_id]
		if entry.role==ROLE.EnemyLook:
			var look := _scope.resources.get(entry.path) as EnemyLook
			if look!=null: _texture = look.previews.get(entry.get("hull_preview",""))
		elif entry.role==ROLE.EnemyPolygon:
			_polygon = entry.points
		else:
			_texture = _scope.resources.get(entry.path) as Texture2D
	queue_redraw()
func _draw() -> void:
	if _row.is_empty(): return
	var row := _row
	var p: Vector2 = row.points[0]
	var radius: float = row.widths[0]
	draw_set_transform(p,row.angle)
	if row.saw:
		draw_set_transform(p,row.angle,Vector2.ONE*radius)
		draw_colored_polygon(row.hull_points,Color("d9dde6"))
	elif _texture!=null:
		var size := _texture.get_size()/maxf(_texture.get_width(),_texture.get_height())*radius*2.0
		draw_texture_rect(_texture,Rect2(-size/2.0,size),false,row.colors[0])
	elif not _polygon.is_empty():
		draw_set_transform(p,row.angle,Vector2.ONE*radius)
		draw_colored_polygon(_polygon,row.colors[0])
	else:
		draw_circle(Vector2.ZERO,radius,Color("aeb6c4")*row.colors[0])
	draw_set_transform(Vector2.ZERO)
