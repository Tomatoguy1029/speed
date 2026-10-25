## 固定画像の使用範囲は制作時に求める。背景エディターも同じ変換を呼ぶ。
@tool
extends RefCounted

static func measure(item: BackgroundPlacement) -> void:
	if item.texture != null:
		item.texture_path = item.texture.resource_path
		item.used_rect = Rect2(item.texture.get_image().get_used_rect())

static func compile(source: BackgroundPlacement) -> BackgroundPlacement:
	var result := source.copy()
	measure(result)
	result.texture = null
	return result
