## 接触判定を持たない、ステージ開始地点を基準とする背景の配置。
@tool
class_name BackgroundPlacement
extends Resource

@export var texture: Texture2D
@export var offset := Vector2.ZERO
@export_range(0.05, 10.0, 0.05) var scale := 1.0
@export_range(-180.0, 180.0, 1.0) var rotation_degrees := 0.0
## RGBは色、Aは明るさ。元画像のアルファは保ち、背後の星を遮る。
@export var tint := Color(0.55, 0.65, 0.75, 0.7)
@export_storage var texture_path := ""
@export_storage var used_rect := Rect2()

func display_tint() -> Color:
	return Color(tint.r * tint.a, tint.g * tint.a, tint.b * tint.a, 1.0)

func bounds() -> Rect2:
	return used_rect

func copy() -> BackgroundPlacement:
	var result := BackgroundPlacement.new()
	result.texture = texture
	result.offset = offset
	result.scale = scale
	result.rotation_degrees = rotation_degrees
	result.tint = tint
	result.texture_path = texture_path
	result.used_rect = used_rect
	return result
