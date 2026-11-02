## みなみのかんむり座の見た目（渦と、抱えた敵・投げた敵）。
extends EnemyVisual

## 冠は撃つ前の予告を渦の輪で見せるので、前の方の光は描かない。
func draw_marks(_c: CanvasItem, _t: EnemyTable, _i: int) -> void:
	pass

func draw_layer(c: CanvasItem, view: Rect2) -> void:
	behavior.vortex.draw(c, run.enemies, view)

static func draw_frame(c: CanvasItem, owners: PackedFloat64Array, members: PackedFloat64Array) -> void:
	preload("res://scripts/render/enemies/corona_vortex.gd").draw_frame(c,owners,members)
