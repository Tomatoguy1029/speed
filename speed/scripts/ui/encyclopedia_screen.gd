## 図鑑。タブごとの一覧とサムネイルを保持し、選択した枠と詳細だけを更新する。
extends UiScreen
const SECTIONS := [["codex.weapons","weapons"],["codex.traits","traits"],["codex.legendary","legendary_modules"]]
const ORDER := {
	"weapons":["W01","W02","W23","W25","W26","W04","W08","W17","W27","W03","W28","W29","W05","W07","W21","W22"],
	"traits":["T33","T05","T08","T14","T04","T06","T09","T32","T03","T07","T34","T10","T31","T35","T36","T11","T12","T37"]}
var _detail: Label
var _caption: Label
var _preview: ModulePreview
var _detail_scroll: ScrollContainer
var _list_scroll: ScrollContainer
var _grids: Array[GridContainer] = []
var _pages: Array[VBoxContainer] = []
var _tab_buttons: Array[Button] = []
var _first: Array[Button] = []
var _selected_group := ButtonGroup.new()
var _detail_panel: PanelContainer
var _left: VBoxContainer
var _tab := 0
var _selection: Button

func _style(rare: bool, selected := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#151320") if rare else Color("#0a1428")
	style.border_color = (Color("#ffd27a") if rare else Color("#7fe8ff")) if selected else (Color("#a8781e") if rare else Color("#3e5682"))
	style.set_border_width_all(2 if selected else 1)
	style.set_content_margin_all(6)
	style.corner_detail=1
	style.set_corner_radius_all(4)
	return style

func _ready() -> void:
	_left = VBoxContainer.new()
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	%Content.add_child(_left)
	var tabs := HBoxContainer.new()
	_left.add_child(tabs)
	for i in SECTIONS.size():
		var button := Button.new()
		button.text = tr(SECTIONS[i][0])
		button.toggle_mode = true
		button.pressed.connect(_select_tab.bind(i))
		_tab_buttons.append(button)
		tabs.add_child(button)
	_list_scroll = ScrollContainer.new()
	_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.follow_focus = true
	_left.add_child(_list_scroll)
	var page_box := VBoxContainer.new()
	page_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(page_box)
	_create_detail()
	var known := 0
	var total := 0
	for section in SECTIONS:
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page_box.add_child(page)
		_pages.append(page)
		var table: Dictionary = ContentManager.catalog.table(StringName(section[1]))
		var ids: Array = ORDER.get(section[1],table.keys())
		var grid := _grid(page)
		var comet := false
		var first: Button
		for id in ids:
			var def: Resource = table.get(StringName(id))
			if def==null: continue
			var rare := bool(def.comet_only) if "comet_only" in def else false
			if rare and not comet:
				comet = true
				var separator := HSeparator.new()
				separator.modulate = Color("#a8781e")
				page.add_child(separator)
				var label := Label.new()
				label.text = tr("codex.comet_relics")
				label.modulate = Color("#ffd27a")
				page.add_child(label)
				grid = _grid(page)
			total += 1
			var has := SaveManager.is_module_known(def.id)
			known += 1 if has else 0
			var entry := _entry(def,has,total,rare)
			grid.add_child(entry)
			if first==null: first=entry
		_first.append(first)
	%Heading.text=tr("codex.title").format({known=known,total=total})
	resized.connect(_layout)
	_list_scroll.resized.connect(_layout_grid)
	_layout()
	_select_tab(0)
	super()

func _grid(parent: Control) -> GridContainer:
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	parent.add_child(grid)
	_grids.append(grid)
	return grid

func _create_detail() -> void:
	_detail_scroll=ScrollContainer.new()
	_detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	%Content.add_child(_detail_scroll)
	_detail_panel=PanelContainer.new()
	_detail_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_detail_panel.add_theme_stylebox_override("panel",_style(false,true))
	_detail_scroll.add_child(_detail_panel)
	var column:=VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",14)
	_detail_panel.add_child(column)
	_preview=ModulePreview.new()
	_preview.custom_minimum_size=Vector2(0,300)
	column.add_child(_preview)
	_caption=Label.new()
	_caption.modulate=Color("#a6b4cb")
	column.add_child(_caption)
	_detail=Label.new()
	_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail)

func _entry(def: Resource, has: bool, number: int, rare: bool) -> Button:
	var button:=Button.new()
	button.custom_minimum_size=Vector2(144,128)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.toggle_mode=true
	button.button_group=_selected_group
	button.text=def.get_display_name() if has else tr("codex.unknown_name")
	# 名前は子のLabelで表示し、ボタン自身の文字で列の最小幅を広げない。
	button.clip_text=true
	button.tooltip_text=button.text
	for state_name in ["normal","hover"]: button.add_theme_stylebox_override(state_name,_style(rare))
	for state_name in ["pressed","focus"]: button.add_theme_stylebox_override(state_name,_style(rare,true))
	for state_name in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color","font_outline_color"]: button.add_theme_color_override(state_name,Color.TRANSPARENT)
	var column:=VBoxContainer.new()
	column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left=6
	column.offset_top=6
	column.offset_right=-6
	column.offset_bottom=-6
	button.add_child(column)
	var image:=ModulePreview.new()
	image.custom_minimum_size=Vector2(0,80)
	image.size_flags_vertical=Control.SIZE_EXPAND_FILL
	image.setup(def,has)
	column.add_child(image)
	var label:=Label.new()
	label.text="No.%02d" % number
	label.add_theme_font_size_override("font_size",12)
	label.modulate=Color("#a6b4cb")
	column.add_child(label)
	var title:=Label.new()
	title.text=button.text
	title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size",16)
	title.modulate=Color("#a6b4cb") if not has else Color("#ffd27a") if rare else Color("#e3ebf8")
	column.add_child(title)
	# 画像・番号・名前と余白の高さを確保する。フォントが変わっても下端を切らない。
	var fit_height := func(): button.custom_minimum_size.y = column.get_combined_minimum_size().y + 12.0
	column.minimum_size_changed.connect(fit_height)
	fit_height.call()
	button.pressed.connect(_show.bind(def,has,number,rare,button))
	return button

func _select_tab(index: int) -> void:
	_tab=index
	for i in _pages.size():
		_pages[i].visible=i==index
		_tab_buttons[i].button_pressed=i==index
	if _first[index]!=null:
		_first[index].button_pressed=true
		_first[index].pressed.emit()
	_layout_grid()

func _layout() -> void:
	var narrow:=size.x<820 or size.x<size.y*1.25
	%Content.vertical=narrow
	%Content.move_child(_detail_scroll,0 if narrow else 1)
	_detail_scroll.custom_minimum_size.x=0 if narrow else size.x*0.48
	_detail_scroll.size_flags_stretch_ratio=1.45
	_layout_grid()

func _layout_grid() -> void:
	for grid in _grids: grid.columns=maxi(1,int((_list_scroll.size.x-16)/152.0))

func _show(def: Resource, has: bool, number: int, rare: bool, button: Button) -> void:
	_selection=button
	_preview.setup(def,has,true)
	_detail_scroll.scroll_vertical=0
	_detail_panel.add_theme_stylebox_override("panel",_style(rare,true))
	_caption.text="No.%02d  %s%s" % [number,tr(SECTIONS[_tab][0]),("  "+tr("codex.comet_relics")) if rare else ""]
	_detail.text=(def.get_display_name()+"\n\n"+def.get_description()) if has else tr("codex.unknown_name")+"\n\n"+tr("codex.unknown_detail")
