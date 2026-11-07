## 確定済みの報酬だけを順番に見せる。付与・抽選はゲーム側で完了している。
extends Control

signal active_changed(active: bool)
## 英雄の力の獲得演出が終わった（飛ばした場合も）。
signal acquire_finished

## 英雄の力の獲得演出（フィールドで星座に絵が重なり機体へ流れ込む。hero_acquire.gd）の長さ。この間は画面を暗くせず、力の説明は出さない
@export_range(0.5, 4.0, 0.05) var ult_acquire_seconds := 4.3
@export_range(1.0, 8.0, 0.1) var ult_details_seconds := 3.0

const DESIGN_SIZE := Vector2(800, 450)
const BONUS_SIZE := Vector2(640, 360)
const CARD_VIEW := preload("res://scripts/ui/reward_card_view.gd")
const CONTINUATION_FX := preload("res://scripts/ui/continuation_fx.gd")
const COMPOSITE := preload("res://assets/ui/rewards/continuation_composite.gdshader")
const SNAPSHOT := preload("res://assets/ui/rewards/continuation_snapshot.gdshader")
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _elapsed := 0.0
var _canvas: Control
var _ult_viewport: SubViewport
var _ult_output: TextureRect
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
var _heading: Label
var _dim: ColorRect
## 今の獲得演出の終わりを知らせたか
var _acquire_told := false
var _ult_block: PanelContainer
var _ult_name: Label
var _ult_desc: Label
var _ult_key: Label
## 制作画面が明示注入する表示だけの再生面。配布用の設定や抽選経路を参照しない。
var _authoring_surface: Control

func attach_authoring_surface(surface: Control) -> bool:
	if not OS.has_feature("editor"): return false
	if not _queue.is_empty() or not _current.is_empty() or _authoring_surface != null: return false
	_authoring_surface = surface
	for child in get_children():
		if child is CanvasItem: child.hide()
	_bonus_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_ult_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
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
	_dim = ColorRect.new()
	_dim.color = Color(0.015, 0.025, 0.045, 0.82)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_build_ult_canvas()
	_heading = _label(Rect2(100, 58, 600, 36), 20, Color("#efcb70"))
	_build_bonus()
	_build_ult_block()
	hide()

func _build_ult_canvas() -> void:
	# 800×450 の差し替え契約を保ち、HUDと同じ画素密度へ描いてから最近傍拡大する。
	_ult_viewport = SubViewport.new()
	_ult_viewport.size = Vector2i(BONUS_SIZE)
	_ult_viewport.transparent_bg = true
	_ult_viewport.world_2d = World2D.new()
	_ult_viewport.use_hdr_2d = get_viewport().use_hdr_2d
	_ult_viewport.gui_disable_input = true
	_ult_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_ult_viewport)
	_canvas = Control.new()
	_canvas.size = DESIGN_SIZE
	_canvas.scale = BONUS_SIZE / DESIGN_SIZE
	_canvas.theme = get_theme()
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ult_viewport.add_child(_canvas)
	_ult_output = TextureRect.new()
	_ult_output.texture = _ult_viewport.get_texture()
	_ult_output.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ult_output.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ult_output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ult_output)
	_ult_output.hide()

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

func _build_ult_block() -> void:
	_ult_block = PanelContainer.new()
	_ult_block.position = Vector2(80, 150)
	_ult_block.size = Vector2(640, 220)
	_ult_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0f1424")
	style.border_color = Color("#efcb70")
	style.anti_aliasing = false
	style.set_border_width_all(1)
	style.border_width_left = 4
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_ult_block.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_ult_block)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 14)
	_ult_block.add_child(column)
	_ult_name = Label.new()
	_ult_desc = Label.new()
	_ult_key = Label.new()
	for label in [_ult_name, _ult_desc, _ult_key]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(label)
	_ult_name.add_theme_font_size_override("font_size", 30)
	_ult_name.add_theme_color_override("font_color", Color("#efcb70"))
	_ult_desc.add_theme_font_size_override("font_size", 21)
	_ult_desc.add_theme_color_override("font_color", Color("#d5dbea"))
	_ult_key.add_theme_font_size_override("font_size", 16)
	_ult_key.add_theme_color_override("font_color", Color("#5bc8db"))
	_ult_block.hide()

func _label(area: Rect2, font_size: int, color: Color, parent: Control = null) -> Label:
	var label := Label.new()
	label.position = area.position
	label.size = area.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.01, 0.03, 0.05, 0.95))
	label.add_theme_constant_override("shadow_offset_y", 1 if parent != null else 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_canvas if parent == null else parent).add_child(label)
	return label

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
	_bonus_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_ult_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
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
	_ult_block.hide()
	if _queue.is_empty():
		_current = {}
		_continuation.reset()
		_bonus_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_ult_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		hide()
		active_changed.emit(false)
		return
	_current = _queue.pop_front()
	_elapsed = 0.0
	_acquire_told = false
	show()
	active_changed.emit(true)
	var ult: bool = _current.type == &"hero_freed"
	# 継続画面は自分の層で暗くする
	_dim.modulate.a = 0.0
	_heading.modulate.a = 0.0 if ult else 1.0
	_canvas.visible = ult
	_ult_output.visible = ult
	_ult_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if ult else SubViewport.UPDATE_DISABLED
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
	AudioManager.play(&"levelup", -5.0, 1.0 + 0.12 * (step - 1))

func _begin_ult() -> void:
	var definition: HeroDef = ContentManager.heroes.get(_current.id)
	_heading.text = tr("hud.ult_granted")
	_heading.add_theme_color_override("font_color", Color("#efcb70"))
	_ult_name.text = "%s — %s" % [definition.display_name, tr("hero.%s.power" % definition.id)]
	_ult_desc.text = tr("hero.%s.desc" % definition.id)
	_ult_key.text = tr("hud.ult_key").format({key = OS.get_keycode_string(InputActions.key_of(&"hero"))})
	AudioManager.play(&"levelup", -4.0, 0.65)

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
	var factor := minf(size.x / BONUS_SIZE.x, size.y / BONUS_SIZE.y)
	_ult_output.position = ((size - BONUS_SIZE * factor) * 0.5).round()
	_ult_output.size = BONUS_SIZE * factor
	if _current.type == &"hero_freed":
		# 獲得演出の間はフィールドを見せ、終わってから暗くして力の説明を出す
		var shown := smoothstep(ult_acquire_seconds, ult_acquire_seconds + 0.22, _elapsed)
		if _elapsed >= ult_acquire_seconds: _tell_acquired()
		_dim.modulate.a = shown
		_ult_output.visible = _elapsed >= ult_acquire_seconds
		_ult_block.visible = _ult_output.visible
		_ult_block.modulate.a = shown
		_heading.modulate.a = shown
		if _elapsed >= ult_acquire_seconds + ult_details_seconds:
			_begin_next()
		return
