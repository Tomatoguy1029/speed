extends Control

const MENU_RECT := Rect2(49, 81, 205, 197)
const UPGRADE_RECT := Rect2(430, 70, 177, 256)
const CYAN := Color("5bc8db")
const MENU_FILL := Color("0a2228")
var show_separator := false
var separator_alpha := 1.0:
	set(value):
		separator_alpha = value
		queue_redraw()

var fill_color := MENU_FILL:
	set(value):
		fill_color = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := roundf(size.x)
	var h := roundf(size.y)
	# 外周は2px、四隅の1pxだけを欠く。サイズを変えても線幅を保つ。
	draw_rect(Rect2(1, 0, w - 2, h), CYAN)
	draw_rect(Rect2(0, 1, w, h - 2), CYAN)
	draw_rect(Rect2(Vector2(2, 2), Vector2(w - 4, h - 4)), fill_color)
	if show_separator:
		draw_line(Vector2(14, 54), Vector2(w - 11, 54), Color(CYAN, separator_alpha), 1.0)
