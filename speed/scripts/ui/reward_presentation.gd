## 確定済みの報酬だけを順番に見せる。付与・抽選はゲーム側で完了している。
extends Control

signal active_changed(active: bool)
## 英雄の力の獲得演出が終わった（飛ばした場合も）。
signal acquire_finished

## 英雄の力の獲得演出（フィールドで星座に絵が重なり機体へ流れ込む。hero_acquire.gd）の長さ。この間は画面を暗くせず、力の説明は出さない
@export_range(0.5, 4.0, 0.05) var ult_acquire_seconds := 4.3

const DETAILS := preload("res://scripts/ui/hero_details.gd")
const BONUS_SIZE := Vector2(640, 360)
const CARD_VIEW := preload("res://scripts/ui/reward_card_view.gd")
const CONTINUATION_FX := preload("res://scripts/ui/continuation_fx.gd")
const COMPOSITE := preload("res://assets/ui/rewards/continuation_composite.gdshader")
const SNAPSHOT := preload("res://assets/ui/rewards/continuation_snapshot.gdshader")
var _ult_details: Control
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _elapsed := 0.0
var _bonus_viewport: SubViewport
var _bonus_output: TextureRect
var _continuation: Node2D
var _composite: ShaderMaterial
## 画面の写し（3択・割る直前の画面）と、連鎖ごとのカード
var _snap_viewport: SubViewport
var _snap_image: TextureRect
var _card_viewports: Array[SubViewport] = []
## HUD の実アイコン追加処理を受け取り、表示先だけを継続画面へ変える。
var add_module_icon: Callable
## 3択で選んだカードの画面上の範囲。HUD が選んだ時に渡す。
var picked_rect := Rect2()
## 今の獲得演出の終わりを知らせたか
var _acquire_told := false
## 制作画面が明示注入する表示だけの再生面。配布用の設定や抽選経路を参照しない。
var _authoring_surface: Control

func attach_authoring_surface(surface: Control) -> bool:
	if not OS.has_feature("editor"): return false
	if not _queue.is_empty() or not _current.is_empty() or _authoring_surface != null: return false
	_authoring_surface = surface
	for child in get_children():
		if child is CanvasItem: child.hide()
	_bonus_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	show()
	return true

func detach_authoring_surface() -> Control:
	var surface := _authoring_surface
	_authoring_surface = null
	if surface != null: remove_child(surface)
	hide()
	return surface

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_build_bonus()
	hide()


func _build_bonus() -> void:
	# 試作と同じ 640×360 の層へ描き、画面とはsRGB上で重ねる。層の中の加算・半透明もsRGBで計算する。
	_snap_viewport = SubViewport.new()
	_snap_viewport.size = Vector2i(BONUS_SIZE)
	_snap_viewport.world_2d = World2D.new()
	_snap_viewport.use_hdr_2d = false
	_snap_viewport.gui_disable_input = true
	_snap_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_snap_viewport)
	_snap_image = TextureRect.new()
	_snap_image.size = BONUS_SIZE
	_snap_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_snap_image.stretch_mode = TextureRect.STRETCH_SCALE
	var snap_material := ShaderMaterial.new()
	snap_material.shader = SNAPSHOT
	_snap_image.material = snap_material
	_snap_viewport.add_child(_snap_image)
	for i in 3:
		var card_viewport := SubViewport.new()
		card_viewport.size = Vector2i(145, 193)
		card_viewport.transparent_bg = true
		card_viewport.use_hdr_2d = false
		card_viewport.gui_disable_input = true
		card_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(card_viewport)
		_card_viewports.append(card_viewport)
	_bonus_viewport = SubViewport.new()
	_bonus_viewport.size = Vector2i(BONUS_SIZE)
	_bonus_viewport.transparent_bg = true
	_bonus_viewport.world_2d = World2D.new()
	_bonus_viewport.use_hdr_2d = false
	_bonus_viewport.gui_disable_input = true
	_bonus_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_bonus_viewport)
	_continuation = CONTINUATION_FX.new()
	_bonus_viewport.add_child(_continuation)
	_continuation.font = get_theme_default_font()
	var bold := FontVariation.new()
	bold.base_font = _continuation.font
	bold.variation_embolden = 0.6
	_continuation.bold_font = bold
	_bonus_output = TextureRect.new()
	_bonus_output.texture = _bonus_viewport.get_texture()
	_bonus_output.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bonus_output.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bonus_output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_composite = ShaderMaterial.new()
	_composite.shader = COMPOSITE
	_composite.set_shader_parameter("layer_pixels", _bonus_viewport.get_texture())
	_bonus_output.material = _composite
	add_child(_bonus_output)
	_bonus_output.hide()

## 前のフレームの画面全体（HUD・前の継続画面を含む）を 640×360 のsRGBへ写す。
func _capture_screen() -> Texture2D:
	_snap_image.texture = get_tree().root.get_texture()
	_snap_image.material.set_shader_parameter("linear_source", get_tree().root.use_hdr_2d)
	_snap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	return _snap_viewport.get_texture()

func _render_card(index: int, info: Dictionary, definition: Resource) -> Texture2D:
	var card_viewport := _card_viewports[index]
	for child in card_viewport.get_children():
		card_viewport.remove_child(child)
		child.queue_free()
	var card := CARD_VIEW.create(info, -1, 145, 10, definition)
	card.theme = get_theme()
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_viewport.add_child(card)
	card_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	return card_viewport.get_texture()

## 画面上の範囲を継続画面の 640×360 の座標へ直す。
func _to_bonus(area: Rect2) -> Rect2:
	var factor := minf(size.x / BONUS_SIZE.x, size.y / BONUS_SIZE.y)
	var origin := global_position + (size - BONUS_SIZE * factor) * 0.5
	return Rect2((area.position - origin) / factor, area.size / factor)


func enqueue_bonus(event: Dictionary) -> void:
	_queue.append(event.duplicate())
	if _current.is_empty():
		_begin_next()

func enqueue_ult(event: Dictionary) -> void:
	# 同じフレームで複数の報酬があっても通知順を維持し、付与処理には触れない。
	_queue.append(event.duplicate())
	if _current.is_empty():
		_begin_next()

## 最終勝利への切替用。獲得済みの報酬には触れず、表示だけを閉じる。
func cancel() -> void:
	_queue.clear()
	if is_acquiring(): _tell_acquired()
	_current = {}
	_clear_ult_details()
	_bonus_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	hide()
	active_changed.emit(false)

## 結果の次送りは HUD が新しい押下として受けた時だけ呼ぶ。
func is_bonus_active() -> bool:
	return not _current.is_empty() and _current.type == &"level_bonus"

## 画面切替とカードの着地が終わり、止まっている間だけ次へ進む。
func advance_bonus() -> void:
	if is_bonus_active() and _continuation.is_holding():
		_begin_next()

func is_active() -> bool:
	return not _current.is_empty()

## 英雄の力の獲得演出の最中か。
func is_acquiring() -> bool:
	return not _current.is_empty() and _current.type == &"hero_freed" and _elapsed < ult_acquire_seconds

## 獲得演出の英雄と経過秒。演出の最中でなければ空。
func acquire_state() -> Dictionary:
	if not is_acquiring(): return {}
	return {"id": StringName(_current.id), "time": _elapsed, "seconds": ult_acquire_seconds}

## 獲得演出を飛ばして力の説明へ進む。
func skip_acquire() -> void:
	if not is_acquiring(): return
	_elapsed = ult_acquire_seconds
	_tell_acquired()

func _tell_acquired() -> void:
	if _acquire_told: return
	_acquire_told = true
	acquire_finished.emit()

func _begin_next() -> void:
	_clear_ult_details()
	if _queue.is_empty():
		_current = {}
		_continuation.reset()
		_bonus_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		hide()
		active_changed.emit(false)
		return
	_current = _queue.pop_front()
	_elapsed = 0.0
	_acquire_told = false
	show()
	active_changed.emit(true)
	var ult: bool = _current.type == &"hero_freed"
	_bonus_output.visible = not ult
	_bonus_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if ult else SubViewport.UPDATE_ALWAYS
	if ult:
		_begin_ult()
		return
	var step := clampi(int(_current.count), 1, 3)
	var weapon: bool = _current.kind == &"weapon"
	var definition := ContentManager.catalog.find(&"weapons" if weapon else &"traits", _current.id)
	var title: String = definition.get_display_name() if definition != null else String(_current.id)
	var info := {"tag": tr("card.weapon_up" if weapon else "card.trait_up"), "name": title,
		"desc": "Lv%d → Lv%d" % [int(_current.level) - 1, int(_current.level)]}
	var card := _render_card(step - 1, info, definition)
	_continuation.heading = tr("hud.continuation")
	_continuation.hint = tr("hud.continuation_next")
	_continuation.count_format = tr("hud.continuation_count")
	if step == 1:
		_continuation.reset()
		_continuation.select_snapshot = _capture_screen()
		_continuation.picked_rect = _to_bonus(picked_rect) if picked_rect.size.x > 0.0 else Rect2()
		picked_rect = Rect2()
	_continuation.begin(step, card, _capture_screen() if step == 3 else null)
	AudioManager.play(&"growth.level.levelup_step", 1.0 + 0.12 * (step - 1))

func _begin_ult() -> void:
	AudioManager.play(&"growth.level.levelup_step", 0.65)

func _clear_ult_details() -> void:
	if _ult_details == null: return
	_ult_details.hide()
	_ult_details.queue_free()
	_ult_details = null

func _show_ult_details() -> void:
	var definition: HeroDef = ContentManager.heroes.get(_current.id)
	_ult_details = DETAILS.new()
	_ult_details.constellation_name = definition.display_name
	_ult_details.power_name = tr("hero.%s.power" % definition.id)
	_ult_details.description = tr("hero.%s.desc" % definition.id)
	add_child(_ult_details)
	_ult_details.closed.connect(_begin_next)

func _process(delta: float) -> void:
	if _authoring_surface != null: return
	if not is_active():
		return
	_elapsed += delta
	if is_bonus_active():
		var factor := minf(size.x / BONUS_SIZE.x, size.y / BONUS_SIZE.y)
		_bonus_output.position = (size - BONUS_SIZE * factor) * 0.5
		_bonus_output.size = BONUS_SIZE * factor
		_composite.set_shader_parameter("linear_target", get_viewport().use_hdr_2d)
		return
	if _current.type == &"hero_freed" and _elapsed >= ult_acquire_seconds:
		_tell_acquired()
		if _ult_details == null: _show_ult_details()
