## 元の角の根元・先端を使う槍。描画順は本体の上。
extends Node2D
var root := Vector2.ZERO
var horn_tip := Vector2.ZERO
var axis := Vector2.RIGHT
var form := 0.0
var head_length := 0.0

func apply_reference(a: Vector2, b: Vector2, direction: Vector2, amount: float, length: float) -> void:
	root = a
	horn_tip = b
	axis = direction
	form = amount
	head_length = length
	queue_redraw()

func _draw() -> void:
	if form <= 0.0: return
	var head := head_length*form
	var tip := horn_tip+axis*head
	var side := axis.orthogonal()*18.0*form
	draw_line(root,horn_tip,Color("#f2b567"),12.0+28.0*form,false)
	draw_line(root,horn_tip,Color.WHITE,7.0+5.0*form,false)
	draw_colored_polygon(PackedVector2Array([tip,horn_tip+side,horn_tip-axis*head*0.35,horn_tip-side]),Color("#fff7df"))
