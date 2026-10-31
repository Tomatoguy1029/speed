## 本番と同じカード部品・文言解決で再生する制作面。抽選・付与・ゲーム保存を呼ばない。
extends Control

signal card_chosen(index: int)
signal next_requested
const CARD := preload("res://scripts/ui/reward_card_view.gd")
const HUD := preload("res://scripts/ui/hud.gd")
const BADGE := preload("res://gyms/combo_badge.gd")
const CARD_ART_SHADER := preload("res://shaders/combo_card_art.gdshader")
const SHADERS := [preload("res://shaders/combo_iris.gdshader"), preload("res://shaders/combo_star_iris.gdshader"), preload("res://shaders/combo_shatter.gdshader")]
const AUTHORING := preload("res://gyms/combo_shatter_authoring.gd")
const DESIGN := Vector2(640, 360)
const EXAMPLES := [
	{"kind": &"weapon", "id": &"W01", "level": 2},
	{"kind": &"trait", "id": &"T07", "level": 3},
	{"kind": &"weapon", "id": &"W03", "level": 2},
]
var settings: ComboTransitionSettings
var _settings_by_kind: Dictionary = {}
var _kind := 0
var _clock := 0.0
var _selected := 1
var _canvas := Control.new()
var _old_view := SubViewport.new()
var _new_view := SubViewport.new()
var _foreground_view := SubViewport.new()
var _old_output := TextureRect.new()
var _new_output := TextureRect.new()
var _foreground_output := TextureRect.new()
var _dim := ColorRect.new()
var _flash := ColorRect.new()
var _faces := MeshInstance2D.new()
var _edges := MeshInstance2D.new()
var _materials: Array[ShaderMaterial] = []
var _card: Button
var _badge
var _new_background_dim: ColorRect
var _choices: Array[Button] = []
var _shape_key := ""
var _active := true
var _background := ColorRect.new()
var _selecting := false

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(220, 140)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_background.color = Color("#060b14")
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	_canvas.size = DESIGN
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	for viewport in [_old_view, _new_view, _foreground_view]:
		viewport.size = Vector2i(DESIGN)
		viewport.disable_3d = true
		viewport.transparent_bg = true
		viewport.world_2d = World2D.new()
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(viewport)
	_old_view.gui_disable_input = false
	_new_view.gui_disable_input = true
	_foreground_view.gui_disable_input = true
	_old_output.texture = _old_view.get_texture()
	_new_output.texture = _new_view.get_texture()
	_foreground_output.texture = _foreground_view.get_texture()
	for output in [_old_output, _new_output]:
		output.size = DESIGN
		output.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		output.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(output)
	_dim.size = DESIGN
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_dim)
	_canvas.move_child(_new_output, -1)
	_canvas.add_child(_faces)
	_canvas.add_child(_edges)
	_foreground_output.size = DESIGN
	_foreground_output.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foreground_output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_foreground_output)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)
	resized.connect(_layout)
	gui_input.connect(_input_on_surface)
	_layout()

func _layout() -> void:
	var factor := maxf(0.01, minf(size.x / DESIGN.x, size.y / DESIGN.y))
	_canvas.position = ((size - DESIGN * factor) / 2.0).round()
	_canvas.scale = Vector2.ONE * factor

func configure(values: Dictionary, kind: int, rebuild_scene := true) -> void:
	_settings_by_kind = values
	_kind = kind
	settings = values[kind]
	if rebuild_scene:
		_build_scenes()
	_materials.clear()
	_new_output.material = null
	if kind == 2:
		var key := str([settings.focus, settings.rim_width, settings.ray_count, settings.band_count, settings.pattern_seed, settings.angle_jitter, settings.radius_jitter, settings.ring_gap, settings.radius_distribution])
		if _shape_key != key or _faces.mesh == null:
			var meshes: Dictionary = AUTHORING.new().build(settings)
			_faces.mesh = meshes.faces
			_edges.mesh = meshes.edges
			_shape_key = key
		for node in [_faces, _edges]:
			var material := ShaderMaterial.new()
			material.shader = SHADERS[2]
			settings.apply_to(material)
			material.set_shader_parameter("edge_pass", node == _edges)
			material.set_shader_parameter("source_scene", _old_view.get_texture())
			node.material = material
			_materials.append(material)
	else:
		var material := ShaderMaterial.new()
		material.shader = SHADERS[kind]
		settings.apply_to(material)
		_new_output.material = material
		_materials.append(material)
	set_time(_clock)

func _root(viewport: SubViewport, opaque := true) -> Control:
	for child in viewport.get_children():
		viewport.remove_child(child)
		child.queue_free()
	var root := Control.new()
	root.size = DESIGN
	root.theme = load("res://assets/ui/theme.tres")
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(root)
	if opaque:
		var background := ColorRect.new()
		background.size = DESIGN
		background.color = Color("#060b14")
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(background)
	return root

func _definition(event: Dictionary) -> Resource:
	return ContentManager.catalog.find(&"traits" if event.kind == &"trait" else &"weapons", event.id)

func _card_view(event: Dictionary, index := 0) -> Button:
	var definition := _definition(event)
	var info := HUD.card_info(event, ContentManager.cfg.trait_max_stacks)
	return CARD.create(info, index, 144.0, 10, definition)

func _build_scenes() -> void:
	var old := _root(_old_view)
	var incoming := _root(_new_view)
	var foreground := _root(_foreground_view, false)
	_choices.clear()
	if _kind == 0:
		var title := Label.new()
		title.position = Vector2(89, 61)
		title.size = Vector2(464, 20)
		title.text = tr("hud.levelup_title")
		title.add_theme_font_size_override("font_size", 10)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		old.add_child(title)
		for i in 3:
			var event := {"kind": &"weapon", "id": StringName("W%02d" % (i + 1)), "level": 2}
			var button := _card_view(event, i)
			button.position = Vector2(89 + i * 160, 83)
			button.pressed.connect(func(): _selected = i; card_chosen.emit(i))
			old.add_child(button)
			_choices.append(button)
		var reroll := Button.new()
		reroll.position = Vector2(265, 288)
		reroll.size = Vector2(112, 29)
		reroll.add_theme_font_size_override("font_size", 9)
		reroll.text = tr("hud.reroll").format({"n": 0, "key": "R"})
		CARD.apply_art(reroll, Rect2(265, 288, 112, 29))
		reroll.disabled = true
		old.add_child(reroll)
	else:
		var previous: ComboTransitionSettings = _settings_by_kind[_kind - 1]
		var prior := _result(old, previous, _kind - 1)
		_pose_card(prior.card, previous, previous.landing_at() + 1.0)
		prior.badge.set_age(10.0)
	_new_background_dim = ColorRect.new()
	_new_background_dim.size = DESIGN
	_new_background_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	incoming.add_child(_new_background_dim)
	var result := _result(foreground, settings, _kind)
	_card = result.card
	_badge = result.badge
	_old_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_new_view.render_target_update_mode = SubViewport.UPDATE_ONCE

func _result(parent: Control, value: ComboTransitionSettings, kind: int) -> Dictionary:
	var button := _card_view(EXAMPLES[kind])
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.focus_mode = Control.FOCUS_NONE
	button.pivot_offset = button.size / 2.0
	var card_material := ShaderMaterial.new()
	card_material.shader = CARD_ART_SHADER
	card_material.set_shader_parameter("card_frame_color", value.card_frame_color)
	card_material.set_shader_parameter("card_fill_color", value.card_fill_color)
	button.material = card_material
	for child in button.get_children():
		if child is Label:
			child.add_theme_font_size_override("font_size", value.card_font_size)
			child.add_theme_color_override("font_color", value.card_text_color)
			child.modulate.a = value.card_text_opacity
		elif child is TextureRect:
			child.pivot_offset = child.size / 2.0
			child.scale = Vector2.ONE * value.card_icon_scale
			child.modulate.a = value.card_icon_opacity
	parent.add_child(button)
	var badge := BADGE.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.configure(value, kind + 2)
	badge.position = value.badge_position * DESIGN
	badge.modulate.a = value.badge_opacity
	parent.add_child(badge)
	return {"card": button, "badge": badge}

func _pose_card(button: Button, value: ComboTransitionSettings, time: float) -> void:
	var age := time - value.card_at()
	button.visible = age >= 0.0
	if age < 0.0: return
	var u := ComboTransitionSettings.eased(age / value.card_zoom_seconds, value.card_easing)
	var scale_factor := lerpf(value.card_start_scale, value.card_overshoot, u)
	if age >= value.card_zoom_seconds:
		var settle := ComboTransitionSettings.eased((age - value.card_zoom_seconds) / value.card_settle_seconds, value.settle_easing)
		scale_factor = lerpf(value.card_overshoot, 1.0, settle)
	var position_norm := value.card_start_position.lerp(value.card_position, u)
	button.position = position_norm * DESIGN - button.size / 2.0
	button.scale = value.card_size / button.size * scale_factor
	button.rotation = deg_to_rad(lerpf(value.card_start_rotation, value.card_rotation, u))
	button.modulate = value.card_tint
	button.modulate.a *= lerpf(value.card_start_opacity, value.card_opacity, u)

func set_time(value: float) -> void:
	_clock = value
	if settings == null: return
	var dim_start := settings.selection_seconds + settings.dim_delay
	var dim_amount := settings.background_dim * ComboTransitionSettings.eased((value - dim_start) / settings.cover_seconds, settings.dim_easing)
	_dim.color = Color(settings.dim_color, settings.dim_color.a * dim_amount)
	_background.color = Color("#060b14").lerp(settings.dim_color, settings.dim_color.a * dim_amount)
	_background.color.a = 1.0
	_new_background_dim.color = Color(settings.dim_color, settings.dim_color.a * settings.background_dim)
	var progress := clampf((value - settings.opening_at()) / settings.opening_seconds, 0.0, 1.0)
	_new_output.visible = value >= settings.opening_at()
	_old_output.visible = not (_new_output.visible and (settings.kind == 2 or progress >= 1.0))
	_dim.visible = _old_output.visible
	_faces.visible = settings.kind == 2 and _new_output.visible and progress < 1.0
	_edges.visible = _faces.visible
	var shader_progress := progress
	if settings.kind == 2:
		var eased := progress if settings.transition_easing == 0 else ComboTransitionSettings.eased(progress, settings.transition_easing - 1)
		shader_progress = pow(eased, settings.easing_power)
	for material in _materials: material.set_shader_parameter("progress", shader_progress)
	_pose_card(_card, settings, value)
	_badge.set_age(value - settings.badge_at())
	var flash_age := value - settings.flash_at()
	var strength := 0.0
	if flash_age >= 0.0 and flash_age < settings.flash_seconds:
		strength = settings.flash_strength * (1.0 - ComboTransitionSettings.eased(flash_age / settings.flash_seconds, settings.flash_easing))
	_flash.color = Color(settings.flash_color, settings.flash_color.a * strength)
	if _active:
		_foreground_view.render_target_update_mode = SubViewport.UPDATE_ONCE

func _input_on_surface(event: InputEvent) -> void:
	if settings == null: return
	if _kind == 0 and _selecting:
		if event is InputEventMouse:
			var forwarded := event.duplicate() as InputEventMouse
			forwarded.position = (event.position - _canvas.position) / _canvas.scale
			forwarded.global_position = forwarded.position
			_old_view.push_input(forwarded, true)
			_old_view.render_target_update_mode = SubViewport.UPDATE_ONCE
		if event is InputEventKey and event.pressed and not event.echo:
			var index := int(event.keycode) - KEY_1
			if index >= 0 and index < 3: card_chosen.emit(index)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		next_requested.emit()

func select_choice(index: int) -> void:
	_selected = index
	if index >= 0 and index < _choices.size(): _choices[index].grab_focus()
	_old_view.render_target_update_mode = SubViewport.UPDATE_ONCE

func set_selecting(selecting: bool) -> void:
	_selecting = selecting

func _unhandled_key_input(event: InputEvent) -> void:
	if settings == null or not is_visible_in_tree() or not _active or not (event is InputEventKey): return
	if event.pressed and not event.echo and event.keycode in [KEY_1, KEY_2, KEY_3] and _kind == 0 and _selecting:
		card_chosen.emit(int(event.keycode) - KEY_1)
		get_viewport().set_input_as_handled()

func set_active(active: bool) -> void:
	_active = active
	_old_view.render_target_update_mode = SubViewport.UPDATE_ONCE if active else SubViewport.UPDATE_DISABLED
	_new_view.render_target_update_mode = SubViewport.UPDATE_ONCE if active else SubViewport.UPDATE_DISABLED
	_foreground_view.render_target_update_mode = SubViewport.UPDATE_ONCE if active else SubViewport.UPDATE_DISABLED
