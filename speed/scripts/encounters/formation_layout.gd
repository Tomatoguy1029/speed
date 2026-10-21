## 敵の組み合わせのシーンの、配置1つ（敵1体ずつの置き場所の並び）。子に FormationMarker を置く。
## このノードの位置が群れの中心、y の負の向きが群れの正面。出すときは、この中心と正面を、選んだ出現位置の
## 点と向きにそろえる。シーンの中での置き場所は編集のための位置で、出し方には関係しない。
@tool
class_name FormationLayout
extends Node2D

## 出すときにこの配置を選ぶ重み（大きいほどよく選ばれる）
@export var weight := 1.0

func _ready() -> void:
	set_notify_transform(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and get_parent() is CanvasItem:
		(get_parent() as CanvasItem).queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var col := Color(0.55, 0.85, 1.0, 0.9)
	draw_line(Vector2(-14, 0), Vector2(14, 0), col, 2.0)
	draw_line(Vector2(0, 14), Vector2(0, -40), col, 2.0)
	draw_line(Vector2(0, -40), Vector2(-7, -30), col, 2.0)
	draw_line(Vector2(0, -40), Vector2(7, -30), col, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(10, 18), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)

## 子の置き場所（配置の中心と正面からの相対）。
func markers() -> Array[FormationMarker]:
	var out: Array[FormationMarker] = []
	for c in get_children():
		if c is FormationMarker:
			out.append(c)
	return out
