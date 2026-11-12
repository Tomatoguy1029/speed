extends Control

signal back_requested
signal rotation_changed(radians: float)
signal scroll_changed(offset: float)

const CYAN := Color("5bc8db")
const ORIGIN := Vector2(198, 195)
const SYMBOL_ORBIT := Vector2(112, 84)
const SYMBOL_OFFSET := Vector2(-1, -0.5)
const INNER_ORBIT_RATE := -2.0
const INNER_LARGE_ORBIT_RATE := -1.0
const INNER_TURN_SPEED := 60.0
const SELECTION_TURN_DURATION := 0.65
# 外周の内側の縁（半径149px）と小円（半径45.5px）の両方に内接する寸法。
const INNER_ORBIT_RADIUS := (149.0 - 45.5) * 0.5
# 大円の公転半径と揃え、オオイヌ選択時に小円の中心を星図の中心へ合わせる。
const INNER_ORBIT_OFFSET := Vector2(0, -INNER_ORBIT_RADIUS)
const INNER_LARGE_RING_SCALE := (149.0 - INNER_ORBIT_RADIUS) / 101.0
const SELECTION_RECT := Rect2(141, 207, 112, 59)
const SYMBOL_ANGLES := [90.0, 0.0, 270.0, 180.0]
const DRAGON_INDEX := 4
const DRAGON_ORIGIN := Vector2(77, 270)
const DRAGON_RECT := Rect2(95, 130, 45, 152)
const DRAGON_FRAME_CORNER := Vector2(81, 131)
const DRAGON_ART := preload("res://assets/ui/map/dragon_dragon.png")
const DRAGON_SCROLL := 280.0
const DRAG_THRESHOLD := 4.0
const REVEAL_SETTINGS := preload("res://data/map_reveal_settings.tres")
const STAR_PHASES := [
	preload("res://assets/ui/map/stars_phase1.png"),
	preload("res://assets/ui/map/stars_phase2.png"),
	preload("res://assets/ui/map/stars_phase3.png"),
	preload("res://assets/ui/map/stars_phase4.png"),
	preload("res://assets/ui/map/stars_phase5.png"),
]
const PREVIEW_ART := [
	preload("res://assets/ui/map/preview_unicorn.png"),
	preload("res://assets/ui/map/preview_centaurus.png"),
	preload("res://assets/ui/map/preview_dog.png"),
	preload("res://assets/ui/map/preview_snake.png"),
]
const PREVIEW_STARS := [
	preload("res://assets/ui/map/preview_unicorn_stars.png"),
	preload("res://assets/ui/map/preview_centaurus_stars.png"),
	preload("res://assets/ui/map/preview_dog_stars.png"),
	preload("res://assets/ui/map/preview_snake_stars.png"),
]
const SYMBOL_TEXTURES := [
	preload("res://assets/ui/map/symbols/unicorn.tres"),
	preload("res://assets/ui/map/symbols/centaurus.tres"),
	preload("res://assets/ui/map/symbols/dog.tres"),
	preload("res://assets/ui/map/symbols/snake.tres"),
]
var _stars: Array[TextureButton] = []
var _star_phases: Array[TextureRect] = []
var _inner1: Sprite2D
var _inner2: Sprite2D
var _preview: TextureRect
var _preview_stars: TextureRect
var _selection_frame: TextureRect
var _heading: Label
var _status: Label
var _launch: Button
var _back: Button
var _final_stage: Button
var _map_content: Control
var _page_button: Button
var _page_arrow: TextureRect
var _dragon_page: Control
var _dragon_frame: TextureRect
var _dragon_preview: TextureRect
var _scroll: Tween
var _launch_requested := false
## 制作プレビューでは選択と演出だけを使う。
var navigation_enabled := true
var _selected := 0
var _last_orbit_selection := 0
var _angle := 0.0
var _ring_angle := 0.0
var _turn: Tween
var _projection: Node2D
var _origin := ORIGIN
var _flatten := 0.5
var _details: Control
var _detail_art: TextureRect
var _detail_fade: Tween
var _detail_material: ShaderMaterial
var _monitor_material: ShaderMaterial
# プレビューでは複製した Resource を渡し、本番の調整値を保存せず比較できる。
var reveal_settings: Resource = REVEAL_SETTINGS
var _transition_progress := 0.0
var _debug_unlock: Button
var _dragging := false
var _pointer_down := false
var _press_position := Vector2.ZERO
var _last_pointer := Vector2.ZERO
var _last_drag_angle := 0.0
var _radial_drag := true
var _pressed_star := -1

func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := _artwork(preload("res://assets/ui/map/selection_screen_ui.png"), self)
	var frame_material := ShaderMaterial.new()
	frame_material.shader = preload("res://assets/ui/map/selection_frame.gdshader")
	frame.material = frame_material
	for texture: Texture2D in STAR_PHASES:
		var layer := _artwork(texture, self)
		layer.modulate.a = 0.4
		_star_phases.append(layer)
	_update_star_phases()
	_map_content = Control.new()
	_map_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map_content)
	var projection := Node2D.new()
	_projection = projection
	projection.position = ORIGIN
	projection.scale = Vector2(1, 0.5)
	_map_content.add_child(projection)
	_inner1 = _ring(projection, preload("res://assets/ui/map/ui_inner_circle1.png"))
	_inner1.offset = Vector2(48, 1)
	_inner1.scale = Vector2.ONE * INNER_LARGE_RING_SCALE
	_inner2 = _ring(projection, preload("res://assets/ui/map/ui_inner_circle2.png"))
	_inner2.offset = Vector2(61, 35)
	_inner2.scale = Vector2.ONE * 0.7
	var ring_material := ShaderMaterial.new()
	ring_material.shader = preload("res://assets/ui/map/orbit_ring.gdshader")
	_inner1.material = ring_material
	_inner2.material = ring_material
	for i in SYMBOL_TEXTURES.size():
		var star := TextureButton.new()
		star.name = "Constellation%d" % (i + 1)
		star.texture_normal = SYMBOL_TEXTURES[i]
		star.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		star.pressed.connect(select_constellation.bind(i))
		star.focus_entered.connect(_on_stage_focus.bind(i))
		_map_content.add_child(star)
		_stars.append(star)
	_selection_frame = TextureRect.new()
	_selection_frame.texture = preload("res://assets/ui/map/selection_highlight.png")
	_selection_frame.position = SELECTION_RECT.position
	_selection_frame.size = SELECTION_RECT.size
	_selection_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_selection_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_frame.z_index = 15
	_map_content.add_child(_selection_frame)
	var back_fill := Polygon2D.new()
	back_fill.polygon = PackedVector2Array([Vector2(9, 9), Vector2(46, 9), Vector2(74, 34), Vector2(9, 34)])
	back_fill.color = Color("1f323d")
	add_child(back_fill)
	back_fill.hide()
	_artwork(preload("res://assets/ui/map/selection_screen_back_button.png"), self)
	var back := _button("", Vector2(7, 7), Vector2(74, 30))
	_back = back
	_transparent_button(back)
	back.mouse_entered.connect(back_fill.show)
	back.mouse_exited.connect(back_fill.hide)
	back.focus_entered.connect(back_fill.show)
	back.focus_exited.connect(back_fill.hide)
	back.pressed.connect(func(): back_requested.emit())
	_details = Control.new()
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.size = size
	add_child(_details)
	_detail_art = _artwork(preload("res://assets/ui/map/selection_screen_decorations.png"), self)
	_detail_material = ShaderMaterial.new()
	_detail_material.shader = preload("res://assets/ui/map/information_reveal.gdshader")
	_detail_art.material = _detail_material
	# 元絵と星は640x360の同じ座標で重ね、右窓の中で再配置しない。
	_preview_stars = _artwork(PREVIEW_STARS[0], _details)
	_preview = _artwork(PREVIEW_ART[0], _details)
	_heading = _label(Vector2(444, 188), Vector2(152, 38), 14)
	_status = _label(Vector2(444, 235), Vector2(152, 24), 10)
	_launch = _button(tr("stage_select.launch"), Vector2(431, 293), Vector2(175, 34))
	_transparent_button(_launch)
	for content: Control in [_heading, _status, _launch]:
		content.reparent(_details)
	_launch.pressed.connect(_start)
	if OS.is_debug_build() or SaveManager.is_review_build():
		_debug_unlock = _button(tr("stage_select.unlock_all"), Vector2(444, 260), Vector2(150, 26))
		if SaveManager.is_review_build(): _debug_unlock.text = tr("review.unlock_all")
		_debug_unlock.toggle_mode = true
		_debug_unlock.add_theme_font_size_override("font_size", 10)
		_debug_unlock.reparent(_details)
		_debug_unlock.toggled.connect(func(_enabled: bool):
			_refresh_stage_visibility()
			_reveal_details()
		)
	if ContentManager.stage_count() > DRAGON_INDEX:
		_build_dragon_page()
	get_window().focus_exited.connect(func():
		if _dragging:
			select_constellation(_nearest_visible_star(_angle))
		_cancel_drag()
	)
	var monitor := ColorRect.new()
	monitor.size = size
	monitor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monitor.z_index = 100
	_monitor_material = ShaderMaterial.new()
	_monitor_material.shader = preload("res://assets/ui/map/monitor.gdshader")
	monitor.material = _monitor_material
	add_child(monitor)
	_refresh_stage_visibility()
	_apply_rotation(0.0)
	_apply_ring_rotation(0.0)
	_hide_details()
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			_cancel_drag()
			_hide_details()
	)

func _build_dragon_page() -> void:
	_dragon_page = Control.new()
	_dragon_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_content.add_child(_dragon_page)
	var wormhole := _artwork(preload("res://assets/ui/map/dragon_wormhole.png"), _dragon_page)
	var dragon := _artwork(DRAGON_ART, _dragon_page)
	_dragon_frame = _artwork(preload("res://assets/ui/map/dragon_select_box.png"), _dragon_page)
	for art: TextureRect in [wormhole, dragon, _dragon_frame]:
		art.size = art.texture.get_size()
		art.position = DRAGON_ORIGIN
	_final_stage = _button("", DRAGON_ORIGIN + DRAGON_RECT.position, DRAGON_RECT.size)
	_final_stage.reparent(_map_content)
	_transparent_button(_final_stage)
	_final_stage.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_final_stage.pressed.connect(select_constellation.bind(DRAGON_INDEX))
	var portrait := AtlasTexture.new()
	portrait.atlas = DRAGON_ART
	portrait.region = DRAGON_RECT
	_dragon_preview = _artwork(portrait, _details)
	_dragon_preview.position = Vector2(447, 83)
	_dragon_preview.size = Vector2(143, 92)
	_dragon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var arrow_texture := AtlasTexture.new()
	arrow_texture.atlas = preload("res://assets/ui/map/selection_screen_ui_down_buttons.png")
	arrow_texture.region = Rect2(186, 304, 25, 26)
	_page_arrow = _artwork(arrow_texture, self)
	_page_arrow.position = Vector2(186, 304)
	_page_arrow.size = arrow_texture.get_size()
	_page_button = _button("", _page_arrow.position, _page_arrow.size)
	_transparent_button(_page_button)
	_page_button.pressed.connect(func():
		select_constellation(_last_orbit_selection if _selected == DRAGON_INDEX else DRAGON_INDEX)
	)

func _set_scroll(offset: float) -> void:
	_map_content.position.y = -roundf(offset)
	scroll_changed.emit(-_map_content.position.y)

func _artwork(texture: Texture2D, parent: Control) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.size = Vector2(640, 360)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

func _transparent_button(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_color_override("font_hover_color", CYAN)

func _hide_details() -> void:
	if _detail_fade != null:
		_detail_fade.kill()
	_set_detail_line(0.0)
	_set_detail_light(0.0)

func _reveal_details() -> void:
	if _transition_progress < 1.0 or not is_visible_in_tree():
		return
	_hide_details()
	_apply_reveal_settings()
	_detail_fade = create_tween()
	_detail_fade.tween_method(_set_detail_line, 0.0, 1.0, reveal_settings.line_duration)
	_detail_fade.tween_interval(reveal_settings.information_delay)
	_detail_fade.tween_method(_set_detail_light, 0.0, 1.0, reveal_settings.fade_duration)

func _apply_reveal_settings() -> void:
	for parameter: String in ["spectrum_speed", "spectrum_base_height", "spectrum_motion", "spectrum_correlation", "spectrum_peak_frequency", "spectrum_peak_strength", "orbit_speed"]:
		_detail_material.set_shader_parameter(parameter, reveal_settings.get(parameter))
	_monitor_material.set_shader_parameter("crt_strength", reveal_settings.crt_strength)

func _set_detail_line(progress: float) -> void:
	var line_progress := 1.0 - pow(1.0 - progress, reveal_settings.line_ease)
	_detail_material.set_shader_parameter("line_progress", line_progress)

func _set_detail_light(progress: float) -> void:
	var alpha := smoothstep(0.0, 1.0, progress)
	var glow: float = sin(progress * PI) * reveal_settings.glow_strength
	_selection_frame.modulate.a = alpha
	_details.modulate = Color(1.0 + glow, 1.0 + glow, 1.0 + glow, alpha)
	_detail_material.set_shader_parameter("information_alpha", alpha)
	_detail_material.set_shader_parameter("glow", glow)

func _ring(parent: Node2D, texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sprite)
	return sprite

func _button(text: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 16)
	add_child(button)
	return button

func _label(at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label

func select_constellation(index: int) -> void:
	if index < 0 or index >= _visible_stage_count():
		return
	if _selected < DRAGON_INDEX and index == DRAGON_INDEX:
		_last_orbit_selection = _selected
	if index != _selected:
		AudioManager.play(&"ui.map.stage_pick")
	if _turn != null:
		_turn.kill()
	_hide_details()
	_select(index)
	var target_scroll := DRAGON_SCROLL if index == DRAGON_INDEX else 0.0
	if _scroll != null:
		_scroll.kill()
	if target_scroll != -_map_content.position.y:
		_scroll = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_scroll.tween_method(_set_scroll, -_map_content.position.y, target_scroll, 0.55)
	_focus_selected()
	if index >= SYMBOL_TEXTURES.size():
		_reveal_details()
		return
	var target := _angle + wrapf(90.0 - SYMBOL_ANGLES[index] - _angle, -180.0, 180.0)
	# 外側と内側を同じTweenで動かし、移動距離によらず停止フレームを揃える。
	_turn = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_turn.tween_method(_apply_rotation, _angle, target, SELECTION_TURN_DURATION)
	_turn.tween_method(_apply_ring_rotation, _ring_angle, target, SELECTION_TURN_DURATION)
	_turn.chain().tween_callback(_reveal_details)

func _on_stage_focus(index: int) -> void:
	if not _pointer_down and index != _selected:
		select_constellation(index)

## 回転中の星座を実際の左右位置でたどる。
func _horizontal_neighbor(direction: int) -> int:
	var from_x := _stars[_selected].get_global_rect().get_center().x
	var nearest := _selected
	var nearest_distance := INF
	var wrapped := _selected
	var wrap_edge := INF
	for i in _stars.size():
		if i == _selected or not _stars[i].visible:
			continue
		var x := _stars[i].get_global_rect().get_center().x
		var distance := (x - from_x) * direction
		# 同じ縦軸の星座を、浮動小数の誤差で左右の隣と見なさない。
		if distance > 0.5 and distance < nearest_distance:
			nearest = i
			nearest_distance = distance
		if x * direction < wrap_edge:
			wrapped = i
			wrap_edge = x * direction
	return nearest if nearest != _selected else wrapped

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _transition_progress < 1.0:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	# 下は解放済みのステージ5へ移動し、上で直前の星座へ戻る。
	if event.is_action(&"ui_left") or event.is_action(&"ui_up") or event.is_action(&"ui_right") or event.is_action(&"ui_down"):
		get_viewport().set_input_as_handled()
		if event.is_pressed() and not event.is_echo():
			_cancel_drag()
			if event.is_action(&"ui_left") or event.is_action(&"ui_right"):
				if _selected != DRAGON_INDEX:
					select_constellation(_horizontal_neighbor(-1 if event.is_action(&"ui_left") else 1))
			elif event.is_action(&"ui_down") and _visible_stage_count() > DRAGON_INDEX:
				select_constellation(DRAGON_INDEX)
			elif event.is_action(&"ui_up") and _selected == DRAGON_INDEX:
				select_constellation(_last_orbit_selection)
			else:
				var step := -1 if event.is_action(&"ui_up") else 1
				select_constellation(posmod(_selected + step, _visible_stage_count()))
		return
	# 戻るにフォーカスがあるときは標準の決定を使い、それ以外は選択中の出撃。
	if event.is_action(&"ui_accept") and focus != _back and (focus == null or focus != _page_button) and (focus == null or focus != _debug_unlock):
		get_viewport().set_input_as_handled()
		if event.is_pressed() and not event.is_echo():
			_start()
		return
	if _selected == DRAGON_INDEX or (_scroll != null and _scroll.is_running()):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed:
			var star := _star_at(point)
			var offset := (point - _origin) / Vector2(1.0, _flatten)
			if star < 0 and offset.length() > 175.5:
				return
			_pointer_down = true
			_dragging = false
			_pressed_star = star
			_press_position = point
			_last_pointer = point
			_last_drag_angle = offset.angle()
			_radial_drag = offset.length() >= 20.0
			if star >= 0:
				_stars[star].grab_focus()
		elif _pointer_down:
			if _dragging:
				select_constellation(_nearest_visible_star(_angle))
			elif _pressed_star >= 0 and _star_at(point) == _pressed_star:
				select_constellation(_pressed_star)
			_cancel_drag()
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pointer_down:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if not _dragging and point.distance_to(_press_position) >= DRAG_THRESHOLD:
			_dragging = true
			if _turn != null:
				_turn.kill()
			_hide_details()
		if _dragging:
			var offset := (point - _origin) / Vector2(1.0, _flatten)
			var delta_angle := (point.x - _last_pointer.x) * 0.7
			if _radial_drag:
				delta_angle = rad_to_deg(wrapf(offset.angle() - _last_drag_angle, -PI, PI)) if offset.length() >= 20.0 else 0.0
			var angle := _angle + delta_angle
			_select(_nearest_visible_star(angle))
			_apply_rotation(angle)
			_last_drag_angle = offset.angle()
			_last_pointer = point
		get_viewport().set_input_as_handled()

func _star_at(point: Vector2) -> int:
	var found := -1
	for i in _stars.size():
		var star := _stars[i]
		if star.visible and Rect2(star.position, star.size * star.scale).has_point(point):
			if found < 0 or star.z_index > _stars[found].z_index:
				found = i
	return found

func _cancel_drag() -> void:
	_pointer_down = false
	_dragging = false
	_pressed_star = -1

func _select(index: int) -> void:
	_selected = index
	var stage := index + 1
	_heading.text = tr("stage.%d.name" % stage)
	_preview.texture = PREVIEW_ART[index] if index < PREVIEW_ART.size() else null
	_preview_stars.texture = PREVIEW_STARS[index] if index < PREVIEW_STARS.size() else null
	_selection_frame.visible = index < SYMBOL_TEXTURES.size()
	var selection_corner := SELECTION_RECT.position
	if index == DRAGON_INDEX:
		selection_corner = DRAGON_ORIGIN + DRAGON_FRAME_CORNER - Vector2(0, DRAGON_SCROLL)
	_detail_material.set_shader_parameter("selection_corner", selection_corner + Vector2(0.5, 0.5))
	if _final_stage != null:
		var dragon_selected := index == DRAGON_INDEX
		_dragon_preview.visible = dragon_selected
		_dragon_frame.visible = dragon_selected
		_final_stage.focus_mode = Control.FOCUS_ALL if dragon_selected else Control.FOCUS_NONE
		_page_arrow.flip_v = dragon_selected
		_page_arrow.position.y = 60.0 if dragon_selected else 304.0
		_page_button.position = _page_arrow.position
		_page_button.tooltip_text = "星図に戻る" if dragon_selected else tr("stage.5.name")
		for star in _stars:
			star.focus_mode = Control.FOCUS_NONE if dragon_selected else Control.FOCUS_ALL
	_launch.disabled = not navigation_enabled
	_status.text = tr("stage_select.debug") if _debug_unlock != null and _debug_unlock.button_pressed else tr("stage_select.available")
	_apply_rotation(_angle)

func _apply_rotation(degrees: float) -> void:
	_angle = degrees
	var radians := deg_to_rad(degrees)
	rotation_changed.emit(radians)
	for i in _stars.size():
		var angle := deg_to_rad(degrees + SYMBOL_ANGLES[i])
		var depth := sin(angle)
		var factor := 0.85 + depth * 0.15
		var star := _stars[i]
		star.scale = Vector2.ONE * factor
		star.position = _origin + SYMBOL_OFFSET + Vector2(cos(angle), depth * _flatten) * SYMBOL_ORBIT - SYMBOL_TEXTURES[i].get_size() * factor * 0.5
		star.z_index = roundi(10 + depth * 4)
		star.modulate = Color.WHITE if i == _selected else Color(0.55, 0.55, 0.55)

func _process(delta: float) -> void:
	# 選択中は外側の回転と同期し、ドラッグ中だけ角度へ追従させる。
	if (_turn == null or not _turn.is_running()) and _ring_angle != _angle:
		_apply_ring_rotation(move_toward(_ring_angle, _angle, INNER_TURN_SPEED * delta))

func _apply_ring_rotation(degrees: float) -> void:
	_ring_angle = degrees
	var radians := deg_to_rad(degrees)
	# 大円は星図中心に対して、1段階ごとに12時→9時→6時→3時へ進む。
	_inner1.position = INNER_ORBIT_OFFSET.rotated(radians * INNER_LARGE_ORBIT_RATE)
	_inner1.rotation = -radians * 5.0
	# 小円は大円の内側を半周し、ステージ1・3で12時、2・4で6時に来る。
	_inner2.position = _inner1.position + INNER_ORBIT_OFFSET.rotated(radians * INNER_ORBIT_RATE)
	_inner2.rotation = radians * 35.0 / 30.0

func set_transition(progress: float) -> void:
	_transition_progress = progress
	if progress < 1.0:
		_cancel_drag()
		_hide_details()
	_origin = Vector2(462, 176).lerp(ORIGIN, progress)
	_flatten = lerpf(1.0, 0.5, progress)
	_projection.position = _origin
	_projection.scale.y = _flatten
	_apply_rotation(_angle)

func _update_star_phases() -> void:
	# 通常進行では最高クリア地点までがクリア済み。最終段階は5枚を重ねる。
	var visible_count := clampi(int(SaveManager.data.cleared_stage) + 1, 1, _star_phases.size())
	for i in _star_phases.size():
		_star_phases[i].visible = i < visible_count

func _visible_stage_count() -> int:
	var count := mini(ContentManager.stage_count(), SYMBOL_TEXTURES.size() + 1)
	if _debug_unlock != null and _debug_unlock.button_pressed:
		return count
	return clampi(int(SaveManager.data.cleared_stage) + 1, 1, count)

func _refresh_stage_visibility() -> void:
	var count := _visible_stage_count()
	for i in _stars.size():
		_stars[i].visible = i < count
	if _final_stage != null:
		_final_stage.visible = count > DRAGON_INDEX
		_page_button.visible = _final_stage.visible
		_page_arrow.visible = _final_stage.visible
		_dragon_page.visible = _final_stage.visible
	if _selected >= count:
		select_constellation(0)
	else:
		_select(_selected)

func _nearest_visible_star(degrees: float) -> int:
	var nearest := 0
	var distance := INF
	for i in mini(_visible_stage_count(), _stars.size()):
		var offset := absf(wrapf(90.0 - SYMBOL_ANGLES[i] - degrees, -180.0, 180.0))
		if offset < distance:
			nearest = i
			distance = offset
	return nearest

func focus_selection() -> void:
	_update_star_phases()
	_refresh_stage_visibility()
	_launch_requested = false
	_focus_selected()
	_reveal_details()

func _focus_selected() -> void:
	if _selected < _stars.size():
		_stars[_selected].grab_focus()
	elif _final_stage != null:
		_final_stage.grab_focus()

func _start() -> void:
	if not navigation_enabled or _launch_requested or GameManager.screen_transition_active or (_turn != null and _turn.is_running()) or (_scroll != null and _scroll.is_running()):
		return
	if _selected < _visible_stage_count():
		_launch_requested = true
		AudioManager.play(&"ui.common.confirm")
		GameManager.start_run(_selected + 1)
