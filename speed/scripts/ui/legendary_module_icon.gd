## 部品図だけを描き、図鑑や武器の専用素材を読み込まない最終武器アイコン。
extends Control
var module_id: StringName
func _ready() -> void: mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	draw_set_transform(size*0.5,0.0,Vector2.ONE*minf(size.x,size.y)/180.0)
	preload("res://scripts/ui/legendary_module_geometry.gd").draw(self,String(module_id),Color("#ffe99a"))
	draw_set_transform(Vector2.ZERO)
