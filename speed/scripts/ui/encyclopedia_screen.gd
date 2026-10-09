## 図鑑（仕様書 14.3）。未入手の名前・詳細は伏せ、見た目はシルエットにする。
extends UiScreen

const SECTIONS := [["武器", "weapons"], ["特性", "traits"], ["伝説のモジュール", "legendary_modules"]]

var _detail: Label
var _caption: Label
var _preview: ModulePreview
var _detail_scroll: ScrollContainer
var _list_scroll: ScrollContainer
var _grids: Array[GridContainer] = []
var _selected_group := ButtonGroup.new()

func _ready() -> void:
	_list_scroll = ScrollContainer.new()
	_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.follow_focus = true
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	_list_scroll.add_child(list)
	%Content.add_child(_list_scroll)
	_create_detail()
	var first: Button
	var first_known: Button
	var known := 0
	var total := 0
	for section in SECTIONS:
		var heading := Label.new()
		heading.text = section[0]
		heading.add_theme_font_size_override("font_size", 28)
		list.add_child(heading)
		var grid := GridContainer.new()
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		list.add_child(grid)
		_grids.append(grid)
		var table: Dictionary = ConfigManager.get(section[1])
		for def in ConfigManager.sorted(table):
			total += 1
			var has := SaveManager.is_module_known(def.id)
			known += 1 if has else 0
			var b := _entry(def, has)
			grid.add_child(b)
			if first == null:
				first = b
			if has and first_known == null:
				first_known = b
	%Heading.text = "図鑑　（%d / %d）" % [known, total]
	resized.connect(_layout)
	_list_scroll.resized.connect(_layout_grid)
	_layout()
	var initial := first_known if first_known != null else first
	if initial != null:
		initial.button_pressed = true
		initial.pressed.emit()
	super()

func _create_detail() -> void:
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	%Content.add_child(_detail_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	_detail_scroll.add_child(column)
	_preview = ModulePreview.new()
	_preview.custom_minimum_size = Vector2(0, 220)
	column.add_child(_preview)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 18)
	_caption.modulate = Color("#a6b4cb")
	column.add_child(_caption)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail)

func _entry(def: Resource, has: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(170, 140)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.toggle_mode = true
	button.button_group = _selected_group
	button.tooltip_text = def.display_name if has else "未入手"
	# 子のビジュアルを使い、名前はキーボード／アクセシビリティ用にも保持する。
	button.text = def.display_name if has else "？？？"
	button.add_theme_color_override("font_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_focus_color", Color.TRANSPARENT)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 8
	column.offset_top = 8
	column.offset_right = -8
	column.offset_bottom = -8
	button.add_child(column)
	var image := ModulePreview.new()
	image.custom_minimum_size = Vector2(0, 80)
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image.setup(def, has)
	column.add_child(image)
	var title := Label.new()
	title.text = button.text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 18)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	button.pressed.connect(_show.bind(def, has))
	return button

func _layout() -> void:
	var narrow := size.x < 900 or size.x < size.y * 1.25
	%Content.vertical = narrow
	_detail_scroll.custom_minimum_size.x = 0 if narrow else size.x * 0.34
	_detail_scroll.size_flags_stretch_ratio = 0.8 if narrow else 1.0
	_layout_grid()

func _layout_grid() -> void:
	for grid in _grids:
		grid.columns = maxi(1, int((_list_scroll.size.x - 16) / 182.0))

func _show(def: Resource, has: bool) -> void:
	_preview.setup(def, has, true)
	_detail_scroll.scroll_vertical = 0
	if not has:
		_caption.text = "未入手"
		_detail.text = "？？？\n\nまだ手に入れていない"
		return
	_caption.text = "専用ビジュアル" if def.preview_texture != null else "仮ビジュアル（専用素材未設定）" if def is LegendaryModuleDef else "効果イメージ"
	_detail.text = def.display_name + "\n" + String(def.id)
	if def.description != "":
		_detail.text += "\n\n" + def.description
