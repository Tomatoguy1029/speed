## 最終武器欄に並ぶ伝説のモジュール。モジュールの画像を枠に収めて描く。
extends Control
static var _art: Dictionary = {}
var module_id: StringName

## モジュールの画像。定義の preview_texture を一度だけ読む。
static func art(id: StringName) -> Texture2D:
	if not _art.has(id):
		var entry: ContentEntry = ContentManager.catalog.find(&"legendary_modules",id)
		var definition: LegendaryModuleDef = load(entry.path) if entry!=null else null
		_art[id] = definition.preview_texture if definition!=null else null
	return _art[id]

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	var texture := art(module_id)
	if texture==null: return
	var scale_ := minf(size.x/texture.get_width(),size.y/texture.get_height())
	draw_texture_rect(texture,Rect2((size-texture.get_size()*scale_)*0.5,texture.get_size()*scale_),false)
