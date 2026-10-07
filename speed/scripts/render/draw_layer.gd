## 描画の層1つ。描く処理は持ち主（RenderManager）の関数を呼ぶ。
class_name DrawLayer
extends Node2D

var draw_fn: Callable

func _draw() -> void:
	if draw_fn.is_valid():
		draw_fn.call(self)
