## 装備が使う表示。装備の種類は個別の表示だけが知り、描画側は共通の入口を呼ぶ。
class_name WeaponVisual
extends RefCounted
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
var rm: RunPresentation
var behavior
var active := true
var node: Node2D
var underlay: Texture2D
var overlay: Texture2D
var overlay_order := 0
var blue_exhaust := false
var state: RunState:
	get: return rm.state
var cfg: GameConfig:
	get: return rm.cfg
func setup(render: RunPresentation, owner_behavior) -> void:
	rm = render
	behavior = owner_behavior
func tick(_dt: float) -> void:
	pass
func on_event(_event: Dictionary) -> void:
	pass
func draw_objects(_c: CanvasItem) -> void:
	pass
func draw_extra(_c: CanvasItem, _ship_pos: Vector2, _color: Color) -> void:
	pass
func finished() -> bool:
	return not active
func dispose() -> void:
	if is_instance_valid(node):
		node.queue_free()
	behavior = null
	rm = null
func attach(path: String, node_name: String, z := 0) -> void:
	node = load(path).new()
	node.name = node_name
	node.z_index = z
	node.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
	rm._layers.ship.add_child(node)
	node.modulate *= visual_color(Color.WHITE)
func _px(value: float) -> float:
	return rm._px(value)
func visual_color(original: Color) -> Color:
	return EFFECT_SETTINGS.tinted(_effect_key(), original)
func visual_number(field: String, original: float) -> float:
	return EFFECT_SETTINGS.number(_effect_key(), field, original)
func _effect_key() -> String:
	var category := "trait/" if String(behavior.def.id).begins_with("T") else "weapon/"
	return category + String(behavior.def.code_id)
