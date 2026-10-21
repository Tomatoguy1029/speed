## 分解図から強化を選び、部品で購入する。
extends UiScreen

const ART_SIZE := Vector2(1280, 720)
const CYAN := Color("5bc8db")
const ASSETS := "res://assets/ui/upgrade/"
const MORPH_PANEL := preload("res://scripts/ui/morph_panel.gd")
const PARTS := [
	[&"atk", "power_spike", Rect2(72, 86, 156, 33), Rect2(73, 89, 105, 28)],
	[&"hp", "frame", Rect2(37, 159, 159, 47), Rect2(38, 161, 97, 28)],
	[&"charge", "charger", Rect2(16, 248, 125, 32), Rect2(17, 249, 85, 28)],
	[&"xp", "circuit", Rect2(232, 98, 156, 57), Rect2(305, 99, 82, 28)],
	[&"length", "engine_tank", Rect2(232, 172, 188, 42), Rect2(315, 173, 104, 28)],
	[&"pickup", "collector", Rect2(246, 232, 156, 29), Rect2(323, 233, 77, 28)],
	[&"speed", "booster", Rect2(246, 264, 145, 66), Rect2(312, 301, 78, 28)],
]
var _art: SubViewportContainer
var _canvas: Control
var _heading: Label
var _information: Label
var _price: Label
var _coins: Label
var _buy_button: Button
var _selected: StringName = &""
var _hovered: StringName = &""
var _materials: Dictionary = {}
var _back_fill: TextureRect
var _panel: Control
var _content: Control
var _content_tween: Tween
var _leaving := false

func _ready() -> void:
	$Background.color = Color.BLACK
	$Margin.hide()
	_build_art()
	SaveManager.save_changed.connect(_refresh_details)
	resized.connect(_layout_art)
	_layout_art()
	_refresh_details()
	super()
	if get_meta("fade_from_menu", false):
		_fade_in()

func _texture(file: String) -> Texture2D:
	return load(ASSETS + file + ".png") as Texture2D

func _image(texture: Texture2D, at := Vector2.ZERO, dimensions := Vector2(640, 360)) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.position = at
	image.size = dimensions
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(image)
	return image

func _build_art() -> void:
	_art = SubViewportContainer.new()
	_art.size = ART_SIZE
	_art.stretch = true
	_art.stretch_shrink = 2
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_art)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_art.add_child(viewport)
	_canvas = Control.new()
	_canvas.size = Vector2(640, 360)
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(_canvas)
	var background := _image(_texture("upgrade_ui"))
	var cutout := ShaderMaterial.new()
	cutout.shader = preload("res://assets/ui/upgrade/frame_cutout.gdshader")
	background.material = cutout
	_panel = MORPH_PANEL.new()
	_panel.position = MORPH_PANEL.UPGRADE_RECT.position
	_panel.size = MORPH_PANEL.UPGRADE_RECT.size
	_panel.fill_color = Color.BLACK
	_panel.z_index = 1
	_panel.show_separator = true
	_canvas.add_child(_panel)
	_image(_texture("upgrade_ui_machine_body"))
	var tooltips := _texture("upgrade_ui_tooltips")
	for part: Array in PARTS:
		_build_part(part, tooltips)
	_image(_texture("upgrade_ui_letters"))
	_back_fill = _image(_texture("upgrade_ui_back_button_infil"))
	_back_fill.hide()
	_image(_texture("upgrade_ui_back_button"))
	var back := _button(Rect2(7, 7, 74, 30))
	back.tooltip_text = tr("common.back")
	back.mouse_entered.connect(func(): _back_fill.show())
	back.mouse_exited.connect(func(): _back_fill.hide())
	back.focus_entered.connect(func(): _back_fill.show())
	back.focus_exited.connect(func(): _back_fill.hide())
	back.pressed.connect(_on_back)
	_heading = _label(Rect2(444, 80, 152, 38), 15)
	_information = _label(Rect2(444, 138, 152, 92), 12)
	_price = _label(Rect2(444, 236, 152, 28), 12)
	_coins = _label(Rect2(444, 37, 162, 16), 10)
	_buy_button = _button(Rect2(448, 275, 139, 32))
	_buy_button.add_theme_font_size_override("font_size", 12)
	_buy_button.pressed.connect(_buy)
	for detail: Control in [_heading, _information, _price]:
		detail.z_index = 2
	var buy_frame := MORPH_PANEL.new()
	buy_frame.position = Vector2(448, 275)
	buy_frame.size = Vector2(139, 32)
	buy_frame.fill_color = Color.BLACK
	buy_frame.z_index = 2
	_canvas.add_child(buy_frame)
	_buy_button.z_index = 3

func _fade_in() -> void:
	_group_content()
	_content.modulate.a = 0.0
	_content_tween = create_tween()
	_content_tween.tween_property(_content, "modulate:a", 1.0, 0.45)

func _group_content() -> void:
	if _content != null:
		return
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.size = Vector2(640, 360)
	_canvas.add_child(_content)
	for child in _canvas.get_children():
		if child != _content and child != _panel:
			child.reparent(_content, false)

func transition_to_menu() -> void:
	_leaving = true
	if _content_tween != null:
		_content_tween.kill()
	_group_content()
	_content_tween = create_tween().set_parallel(true)
	_content_tween.tween_property(_content, "modulate:a", 0.0, 0.3)
	_content_tween.tween_property(_panel, "separator_alpha", 0.0, 0.3)
	await _content_tween.finished

func _on_back() -> void:
	if not _leaving:
		super()

func _build_part(part: Array, tooltips: Texture2D) -> void:
	var id: StringName = part[0]
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/ui/upgrade/highlight.gdshader")
	_materials[id] = material
	var outline := AtlasTexture.new()
	outline.atlas = tooltips
	outline.region = part[2]
	var box := _image(outline, part[2].position, part[2].size)
	box.material = material
	var box_button := _button(part[3])
	_connect_part(box_button, id)
	var texture := _texture("upgrade_ui_parts_" + part[1])
	var bounds := texture.get_image().get_used_rect()
	var cropped := AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = bounds
	var button := TextureButton.new()
	button.name = "Part_" + String(id)
	button.texture_normal = cropped
	button.material = material
	button.position = bounds.position
	var mask := BitMap.new()
	mask.create_from_image_alpha(texture.get_image().get_region(bounds))
	# 各行の輪郭の間も判定に含め、線画の内部をクリックできるようにする。
	for y in bounds.size.y:
		var first := bounds.size.x
		var last := -1
		for x in bounds.size.x:
			if mask.get_bit(x, y):
				first = mini(first, x)
				last = x
		if last >= first:
			mask.set_bit_rect(Rect2i(first, y, last - first + 1, 1), true)
	mask.grow_mask(3, Rect2i(Vector2i.ZERO, bounds.size))
	button.texture_click_mask = mask
	_canvas.add_child(button)
	_connect_part(button, id)

func _connect_part(button: BaseButton, id: StringName) -> void:
	button.pressed.connect(_select.bind(id))
	button.mouse_entered.connect(_hover.bind(id))
	button.mouse_exited.connect(_hover.bind(&""))
	button.focus_entered.connect(_hover.bind(id))
	button.focus_exited.connect(_hover.bind(&""))

func _button(bounds: Rect2) -> Button:
	var button := Button.new()
	button.position = bounds.position
	button.size = bounds.size
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_color_override("font_hover_color", CYAN)
	_canvas.add_child(button)
	return button

func _label(bounds: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.position = bounds.position
	label.size = bounds.size
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(label)
	return label

func _hover(id: StringName) -> void:
	_hovered = id
	_refresh_highlights()

func _refresh_highlights() -> void:
	for id: StringName in _materials:
		_materials[id].set_shader_parameter("highlighted", id == _hovered or id == _selected)

func _select(id: StringName) -> void:
	if _leaving:
		return
	_selected = id
	AudioManager.play(&"ui")
	_refresh_highlights()
	_refresh_details()

func _refresh_details() -> void:
	_coins.text = tr("common.parts").format({n = SaveManager.coins()})
	var def := ConfigManager.meta_upgrades.get(_selected) as MetaUpgradeDef
	_buy_button.disabled = true
	if def == null:
		_heading.text = tr("upgrade.select_part")
		_information.text = ""
		_price.text = ""
		_buy_button.text = tr("upgrade.action")
		return
	var level := SaveManager.meta_level(def.id)
	var maxed := level >= def.costs.size()
	_heading.text = tr("upgrade.part.%s" % def.id)
	_information.text = tr("upgrade.details").format({desc = def.get_description(), lv = level, max = def.costs.size()})
	_price.text = tr("upgrade.max") if maxed else tr("upgrade.price").format({n = def.costs[level]})
	_buy_button.text = tr("upgrade.max") if maxed else tr("upgrade.action")
	_buy_button.disabled = maxed or SaveManager.coins() < def.costs[level]

func _buy() -> void:
	if _leaving:
		return
	var def := ConfigManager.meta_upgrades.get(_selected) as MetaUpgradeDef
	if def != null and SaveManager.buy_upgrade(def):
		AudioManager.play(&"levelup")
	_refresh_details()

func _layout_art() -> void:
	var factor := minf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	_art.scale = Vector2.ONE * factor
	_art.position = (size - ART_SIZE * factor) * 0.5
