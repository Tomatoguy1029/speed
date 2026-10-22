## タイトル（仕様書 3）。「ゲームスタート」「設定」「終了」。
extends UiScreen

const TITLE_TEXTURE := preload("res://assets/ui/title/ui_title_screen.png")
const SWEEP_TEXTURE := preload("res://assets/ui/title/ui_title_screen_sweep.png")
const STARS_TEXTURE := preload("res://assets/ui/title/ui_title_screen_stars_in_ring.png")
const RADAR_SHADER := preload("res://assets/ui/title/radar.gdshader")
const MORPH_PANEL := preload("res://scripts/ui/morph_panel.gd")
const MAP_SCRIPT := preload("res://scripts/ui/constellation_map.gd")
const ART_SIZE := Vector2(1280, 720)
const MENU_CYAN := Color("5bc8db")

## 起動側から加えるメニューの操作。
var menu_accessory: Control

var _art: Control
var _radar_material: ShaderMaterial
var _elapsed := 0.0
var _title_menu: VBoxContainer
var _start_panel: Control
var _stage_button: Button
var _map: Control
var _map_progress := 0.0
var _transition: Tween
var _menu_frame: Control
var _menu_options: Control
var _menu_back: Control
var _morphing := false
var _increments_alpha := 1.0

func _ready() -> void:
	_build_title_art()
	%StartButton.pressed.connect(func(): _go(GameManager.Screen.MAIN_MENU))
	%SettingsButton.pressed.connect(func(): _go(GameManager.Screen.SETTINGS))
	%QuitButton.pressed.connect(GameManager.quit_game)
	# ブラウザ版ではアプリを終了できないので、終了ボタンを出さない
	%QuitButton.visible = not OS.has_feature("web")
	super()
	show_screen(GameManager.screen, false)
	if get_meta("morph_from_upgrade", false):
		_transition_from_upgrade()

func _build_title_art() -> void:
	$Background.color = Color.BLACK
	var viewport_container := SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.stretch_shrink = 2
	viewport_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art = viewport_container
	_art.mouse_filter = Control.MOUSE_FILTER_PASS
	_art.size = ART_SIZE
	add_child(_art)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.transparent_bg = true
	viewport.gui_disable_input = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)
	var canvas := Control.new()
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.size = ART_SIZE / 2.0
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(canvas)
	var background := TextureRect.new()
	background.texture = TITLE_TEXTURE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.size = ART_SIZE / 2.0
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_radar_material = ShaderMaterial.new()
	_radar_material.shader = RADAR_SHADER
	_radar_material.set_shader_parameter("sweep_texture", SWEEP_TEXTURE)
	_radar_material.set_shader_parameter("stars_texture", STARS_TEXTURE)
	_radar_material.set_shader_parameter("menu_stars_texture", preload("res://assets/ui/title/ui_title_screen_stars.png"))
	_radar_material.set_shader_parameter("increments_texture", preload("res://assets/ui/title/ui_title_screen_incrementsl.png"))
	_radar_material.set_shader_parameter("increments_alpha", _increments_alpha)
	_radar_material.set_shader_parameter("map_ring_texture", preload("res://assets/ui/map/ui_circle.png"))
	background.material = _radar_material
	canvas.add_child(background)
	var menu := $Center/Box as VBoxContainer
	_title_menu = menu
	menu.reparent(canvas, false)
	$Center.hide()
	menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	menu.position = Vector2(32, 158)
	menu.size = Vector2.ZERO
	menu.get_node("Logo").hide()
	menu.get_node("Spacer").hide()
	menu.add_theme_constant_override("separation", 6)
	for button: Button in [%StartButton, %SettingsButton, %QuitButton]:
		_style_menu_button(button)
	_build_start_panel(canvas)
	_map = Control.new()
	_map.set_script(MAP_SCRIPT)
	canvas.add_child(_map)
	_map.back_requested.connect(_close_start_panel)
	_map.rotation_changed.connect(func(angle: float): _radar_material.set_shader_parameter("map_angle", angle))
	_map.hide()
	resized.connect(_layout_title)
	_layout_title()

func _style_menu_button(button: Button) -> void:
	var empty_style := StyleBoxEmpty.new()
	empty_style.content_margin_left = 8.0
	empty_style.content_margin_right = 8.0
	button.custom_minimum_size = Vector2(0, 32)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 20)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		button.add_theme_stylebox_override(state, empty_style)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", MENU_CYAN)
	button.add_theme_color_override("font_pressed_color", MENU_CYAN)
	button.add_theme_color_override("font_hover_pressed_color", MENU_CYAN)
	button.draw.connect(_draw_menu_corners.bind(button))
	button.mouse_entered.connect(button.queue_redraw)
	button.mouse_exited.connect(button.queue_redraw)

func _build_start_panel(canvas: Control) -> void:
	_start_panel = Control.new()
	_start_panel.size = ART_SIZE / 2.0
	_start_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_start_panel)
	_menu_frame = MORPH_PANEL.new()
	_menu_frame.position = MORPH_PANEL.MENU_RECT.position
	_menu_frame.size = MORPH_PANEL.MENU_RECT.size
	_start_panel.add_child(_menu_frame)
	_menu_options = Control.new()
	_menu_options.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_panel.add_child(_menu_options)
	_menu_back = Control.new()
	_menu_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_panel.add_child(_menu_back)
	var fill := TextureRect.new()
	fill.texture = preload("res://assets/ui/title/ui_title_screen_back_button_infil.png")
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_back.add_child(fill)
	fill.hide()
	var back_art := TextureRect.new()
	back_art.texture = preload("res://assets/ui/title/ui_title_screen_back_button.png")
	back_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_back.add_child(back_art)
	var back := Button.new()
	back.position = Vector2(7, 7)
	back.size = Vector2(71, 30)
	back.tooltip_text = tr("common.back")
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		back.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	back.mouse_entered.connect(fill.show)
	back.mouse_exited.connect(fill.hide)
	back.focus_entered.connect(fill.show)
	back.focus_exited.connect(fill.hide)
	back.pressed.connect(_close_start_panel)
	_menu_back.add_child(back)
	var labels := ["ステージセレクト", "機体強化", "コーデックス"]
	var destinations := [GameManager.Screen.STAGE_SELECT, GameManager.Screen.UPGRADE, GameManager.Screen.ENCYCLOPEDIA]
	for i in labels.size():
		var button := Button.new()
		button.text = labels[i]
		_style_menu_button(button)
		button.position = Vector2(56, [88, 138, 188][i])
		_menu_options.add_child(button)
		button.pressed.connect(_go.bind(destinations[i]))
		if i == 0:
			_stage_button = button

func show_start_panel(open: bool) -> void:
	_start_panel.visible = open
	_title_menu.visible = not open
	_radar_material.set_shader_parameter("panel_open", open)
	if open:
		_stage_button.grab_focus.call_deferred()
	else:
		%StartButton.grab_focus.call_deferred()

func show_screen(screen: GameManager.Screen, animate := true) -> void:
	var mapping := screen == GameManager.Screen.STAGE_SELECT
	var returning_from_map := animate and not mapping and _map_progress > 0.0
	if mapping:
		_set_increments_alpha(0.0)
	elif not returning_from_map:
		_set_increments_alpha(1.0)
	if _transition != null:
		_transition.kill()
	show_start_panel(screen == GameManager.Screen.MAIN_MENU)
	_start_panel.modulate.a = 0.0 if returning_from_map else 1.0
	_start_panel.process_mode = Node.PROCESS_MODE_DISABLED if returning_from_map else Node.PROCESS_MODE_INHERIT
	_title_menu.visible = screen == GameManager.Screen.TITLE
	_map.visible = mapping or _map_progress > 0.0
	_map.process_mode = Node.PROCESS_MODE_DISABLED
	if animate and (mapping or _map_progress > 0.0):
		_transition = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_transition.tween_method(_set_map_progress, _map_progress, 1.0 if mapping else 0.0, 1.2)
		_transition.tween_callback(func():
			_map.visible = mapping
			_map.process_mode = Node.PROCESS_MODE_INHERIT
			if mapping:
				_map.focus_selection()
		)
		if returning_from_map:
			_transition.tween_property(_start_panel, "modulate:a", 1.0, 0.25)
			_transition.parallel().tween_method(_set_increments_alpha, 0.0, 1.0, 0.35)
			_transition.tween_callback(func():
				_start_panel.process_mode = Node.PROCESS_MODE_INHERIT
				if _start_panel.visible:
					_stage_button.grab_focus()
			)
	else:
		_set_map_progress(1.0 if mapping else 0.0)
		_map.visible = mapping
		_map.process_mode = Node.PROCESS_MODE_INHERIT
		if mapping:
			_map.focus_selection.call_deferred()

func _set_map_progress(value: float) -> void:
	_map_progress = value
	_radar_material.set_shader_parameter("map_progress", value)
	_map.modulate.a = smoothstep(0.55, 1.0, value)
	_map.set_transition(value)

func _set_increments_alpha(value: float) -> void:
	_increments_alpha = value
	_radar_material.set_shader_parameter("increments_alpha", value)

func _close_start_panel() -> void:
	if _morphing:
		return
	AudioManager.play(&"ui")
	GameManager.back()

func _unhandled_input(event: InputEvent) -> void:
	if (_start_panel.visible or GameManager.screen == GameManager.Screen.STAGE_SELECT) and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_start_panel()
	else:
		super(event)

func _draw_menu_corners(button: Button) -> void:
	if not button.is_hovered():
		return
	var bounds := Rect2(Vector2.ONE, button.size - Vector2.ONE * 2.0)
	for corner: Vector2 in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
		var inward := Vector2(1 if corner.x == bounds.position.x else -1, 1 if corner.y == bounds.position.y else -1)
		button.draw_line(corner, corner + Vector2(inward.x * 9.0, 0), MENU_CYAN, 1.0)
		button.draw_line(corner, corner + Vector2(0, inward.y * 9.0), MENU_CYAN, 1.0)

func _layout_title() -> void:
	var factor := minf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	_art.scale = Vector2.ONE * factor
	_art.position = (size - ART_SIZE * factor) * 0.5

func _process(delta: float) -> void:
	_elapsed += delta
	_radar_material.set_shader_parameter("elapsed", _elapsed)

func _go(screen: GameManager.Screen) -> void:
	if _morphing:
		return
	AudioManager.play(&"ui")
	GameManager.goto(screen)

func can_morph_to_upgrade() -> bool:
	return _start_panel.visible and not _morphing

func transition_to_upgrade() -> void:
	_morphing = true
	_menu_options.hide()
	_menu_back.hide()
	var accessory := menu_accessory
	if accessory != null:
		accessory.hide()
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_menu_frame, "position", MORPH_PANEL.UPGRADE_RECT.position, 0.7)
	tween.tween_property(_menu_frame, "size", MORPH_PANEL.UPGRADE_RECT.size, 0.7)
	tween.tween_property(_menu_frame, "fill_color", Color.BLACK, 0.7)
	tween.tween_method(func(value: float): _radar_material.set_shader_parameter("upgrade_progress", value), 0.0, 1.0, 0.7)
	await tween.finished

func _transition_from_upgrade() -> void:
	_morphing = true
	_menu_options.hide()
	_menu_back.hide()
	_menu_frame.position = MORPH_PANEL.UPGRADE_RECT.position
	_menu_frame.size = MORPH_PANEL.UPGRADE_RECT.size
	_menu_frame.fill_color = Color.BLACK
	_radar_material.set_shader_parameter("upgrade_progress", 1.0)
	var accessory := menu_accessory
	if accessory != null:
		accessory.hide()
	_transition = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_property(_menu_frame, "position", MORPH_PANEL.MENU_RECT.position, 0.7)
	_transition.tween_property(_menu_frame, "size", MORPH_PANEL.MENU_RECT.size, 0.7)
	_transition.tween_property(_menu_frame, "fill_color", MORPH_PANEL.MENU_FILL, 0.7)
	_transition.tween_method(func(value: float): _radar_material.set_shader_parameter("upgrade_progress", value), 1.0, 0.0, 0.7)
	_transition.chain().tween_callback(func():
		_menu_options.show()
		_menu_back.show()
		_morphing = false
		if accessory != null:
			accessory.show()
		_stage_button.grab_focus()
	)
