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
## この表示が描くので、描画側の既定の処理（死亡の破片・輪・ビーム）を行わない出来事なら true。
func claims(_event: Dictionary) -> bool:
	return false
func draw_objects(_c: CanvasItem) -> void:
	pass
func draw_extra(_c: CanvasItem, _ship_pos: Vector2, _color: Color) -> void:
	pass
func finished() -> bool:
	return not active
func dispose() -> void:
	if is_instance_valid(node):
		node.queue_free()
	if is_instance_valid(_painter):
		_painter.queue_free()
	if is_instance_valid(_fires):
		_fires.queue_free()
	if is_instance_valid(_blasts):
		_blasts.queue_free()
	behavior = null
	rm = null

var _painter: PixelPainter
var _world_time := -1.0
## ドット単位の演出を描く束。初めて使うときに演出の層へ置く。演出の層の明るさ上げは打ち消し、試作の色で描く。
func painter() -> PixelPainter:
	if _painter == null:
		_painter = PixelPainter.new()
		_painter.setup_painter(1.82 * cfg.character_scale)
		_painter.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
		rm._layers.fx.add_child(_painter)
	_painter.modulate = RenderPipeline.plain_color(rm._layers.fx, visual_color(Color.WHITE))
	return _painter
var _fires: FireBursts
## ドット単位の炎の爆発。初めて使うときに演出の層へ置く。進めるのは各表示の tick（fires().step）。
func fires() -> FireBursts:
	if _fires == null:
		_fires = FireBursts.new()
		_fires.setup(1.82 * cfg.character_scale)
		_fires.key = _effect_key()
		_fires.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
		_fires.modulate = RenderPipeline.plain_color(rm._layers.fx)
		rm._layers.fx.add_child(_fires)
	return _fires
var _blasts: BlastBursts
## ドット単位の爆発。初めて使うときに演出の層へ置く。進めるのは各表示の tick（blasts().step）。
func blasts() -> BlastBursts:
	if _blasts == null:
		_blasts = BlastBursts.new()
		_blasts.setup(1.82 * cfg.character_scale)
		_blasts.key = _effect_key()
		_blasts.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
		_blasts.modulate = RenderPipeline.plain_color(rm._layers.fx)
		rm._layers.fx.add_child(_blasts)
	return _blasts
## 前回から進んだ世界秒。ヒットストップや停止の間は 0。
func world_dt() -> float:
	var now := state.world_time
	var dt := 0.0 if _world_time < 0.0 else maxf(0.0, now - _world_time)
	_world_time = now
	return dt
## 戦闘エフェクトツールで調整した shader の値を当てる。
func tune(mat: ShaderMaterial) -> void:
	ShaderTuning.apply(mat, _effect_key())
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
