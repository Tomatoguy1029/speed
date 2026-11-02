## 装備の値型フレームを描く表示部品。
class_name WeaponVisual
extends RefCounted
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
var active := true
var node: Node2D
var _painter: PixelPainter
var _fires: FireBursts
var _blasts: BlastBursts

func dispose() -> void:
	if is_instance_valid(node):
		node.queue_free()
	if is_instance_valid(_painter):
		_painter.queue_free()
	if is_instance_valid(_fires):
		_fires.queue_free()
	if is_instance_valid(_blasts):
		_blasts.queue_free()

func tune(mat: ShaderMaterial) -> void:
	ShaderTuning.apply(mat, _effect_key())
func visual_color(original: Color) -> Color:
	return EFFECT_SETTINGS.tinted(_effect_key(), original)
func visual_number(field: String, original: float) -> float:
	return EFFECT_SETTINGS.number(_effect_key(), field, original)
func _effect_key() -> String:
	var code := get_script().resource_path.get_file().get_basename()
	var category := "trait/" if code in ["fullCharge","rampage","runUp","critBeam","killSonic","fullBurst","vortex","duplicator"] else "weapon/"
	return category+code
