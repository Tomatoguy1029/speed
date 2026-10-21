## 敵の組み合わせのシーンの、出現位置1つ。シーンの原点に機体がいて、機体は上（y の負の向き）を向いている前提で置く。
## 向き（y の負の向き）は、エディターが自動で原点（機体）の方へ向ける。出すときは、配置の中心と正面をこの点と向きにそろえる。
@tool
class_name FormationEntry
extends Node2D

## 出すときにこの出現位置を選ぶ重み（大きいほどよく選ばれる）
@export var weight := 1.0

func _ready() -> void:
	set_notify_transform(true)
	_face_origin()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_face_origin()
		if get_parent() is CanvasItem:
			(get_parent() as CanvasItem).queue_redraw()

## 位置 pos から、正面（y の負の向き）を原点へ向ける回転。
static func facing_origin(pos: Vector2) -> float:
	return (-pos).angle() + PI / 2.0

## 正面（y の負の向き）を原点へ向ける。
func _face_origin() -> void:
	if position.length_squared() < 1.0:
		return
	var want := facing_origin(position)
	if not is_equal_approx(rotation, want):
		set_notify_transform(false)
		rotation = want
		set_notify_transform(true)

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var col := Color(1.0, 0.75, 0.35, 0.95)
	draw_circle(Vector2.ZERO, 10.0, Color(col, 0.35))
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 20, col, 2.0)
	draw_line(Vector2.ZERO, Vector2(0, -60), col, 2.0)
	draw_line(Vector2(0, -60), Vector2(-8, -48), col, 2.0)
	draw_line(Vector2(0, -60), Vector2(8, -48), col, 2.0)
	draw_set_transform(Vector2.ZERO, -rotation)
	draw_string(ThemeDB.fallback_font, Vector2(14, -14), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
	draw_set_transform(Vector2.ZERO)
