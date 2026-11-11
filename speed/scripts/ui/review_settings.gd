## 審査版だけのラン内カスタム設定。セーブや編集元へ書き込まない。
extends PanelContainer
signal finished
var session: RunSession
var _controls: RefCounted
var _body: VBoxContainer
var _status: Label
var _buttons: Array[Button] = []
var _busy := false
var _tabs: TabContainer
var _margin: MarginContainer
var _meta_grid: GridContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color("080e18")
	add_theme_stylebox_override("panel", backdrop)
	add_theme_font_size_override("font_size", 20)
	_controls = preload("res://scripts/runtime/review_controls.gd").new()
	_controls.session = session
	var margin := MarginContainer.new()
	_margin = margin
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var title := Label.new()
	title.text = tr("review.title")
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	var hint := Label.new()
	hint.text = tr("review.run_only")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var back := Button.new()
	back.text = tr("common.back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.custom_minimum_size = Vector2(160, 44)
	back.pressed.connect(func():
		if not _busy: finished.emit())
	column.add_child(back)
	resized.connect(_layout)
	_rebuild()
	_layout()
	back.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if not _busy: finished.emit()

func _heading(key: String) -> void:
	var label := Label.new()
	label.text = tr(key)
	label.add_theme_font_size_override("font_size", 22)
	_body.add_child(label)

func _button(parent: Node, key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = tr(key)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.custom_minimum_size.y = 38
	button.pressed.connect(action)
	parent.add_child(button)
	_buttons.append(button)
	return button

func _layout() -> void:
	var side := maxi(24, int((size.x - 1040) * 0.5))
	_margin.add_theme_constant_override("margin_left", side)
	_margin.add_theme_constant_override("margin_right", side)
	if is_instance_valid(_meta_grid): _meta_grid.columns = 2 if size.x >= 800 else 1

func _page(key: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, tr(key))
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	margin.add_child(_body)

func _field(row: Container, key: String, input: Control, width: float) -> void:
	var field := VBoxContainer.new()
	field.custom_minimum_size.x = width
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	var label := Label.new()
	label.text = tr(key)
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = Color("91a6ba")
	field.add_child(label)
	field.add_child(input)

func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_body.add_child(row)
	return row

func _rebuild() -> void:
	var selected := maxi(0, _tabs.current_tab)
	for child in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	_meta_grid = null
	_buttons.clear()
	var response: Dictionary = session.bridge.read_frame()
	if not response.ok: return
	var ui: Dictionary = response.value.ui
	var catalog: Dictionary = session.bridge.command("review_catalog")
	if not catalog.ok:
		_status.text = tr("review.unavailable")
		return
	var limits: Dictionary = catalog.value.limits
	_page("review.equipment")
	for kind: String in ["weapon", "trait"]:
		if kind == "trait": _body.add_child(HSeparator.new())
		_heading("review." + kind)
		var count := Label.new()
		count.text = tr("review.slots").format({"used": ui.get(kind + "_levels", []).size(), "max": catalog.value.get(kind + "_slots", 0)})
		var summary := Label.new()
		var names := PackedStringArray()
		for item: Dictionary in ui.get(kind + "_levels", []):
			var definition: ContentEntry = ContentManager.catalog.table(&"weapons" if kind == "weapon" else &"traits").get(StringName(item.id))
			names.append("%s Lv.%d" % [definition.get_display_name() if definition != null else item.id, item.level])
		summary.text = count.text + "　　" + tr("review.current").format({"items": " / ".join(names) if not names.is_empty() else tr("review.none")})
		count.free()
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(summary)
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 16)
		_body.add_child(row)
		var target := OptionButton.new()
		var table: Dictionary = ContentManager.catalog.table(&"weapons" if kind == "weapon" else &"traits")
		for entry: ContentEntry in ContentManager.sorted(table):
			if not session.cpp_resources.equipment.has(kind + ":" + String(entry.id)): continue
			target.add_item(entry.get_display_name())
			target.set_item_metadata(target.item_count - 1, String(entry.id))
		_field(row, "review.target", target, 250)
		var owned := OptionButton.new()
		owned.add_item(tr("review.add"))
		owned.set_item_metadata(0, "")
		for item: Dictionary in ui.get(kind + "_levels", []):
			var entry: ContentEntry = table.get(StringName(item.id))
			owned.add_item("%s Lv.%d" % [entry.get_display_name() if entry != null else item.id, item.level])
			owned.set_item_metadata(owned.item_count - 1, String(item.id))
		_field(row, "review.slot", owned, 300)
		var level := SpinBox.new()
		level.min_value = 1
		level.max_value = limits.get(String(target.get_selected_metadata()), 1)
		level.value = 1
		level.tooltip_text = tr("review.level")
		_field(row, "review.level", level, 100)
		target.item_selected.connect(func(_index: int): level.max_value = limits.get(String(target.get_selected_metadata()), 1))
		var actions := _row()
		actions.alignment = BoxContainer.ALIGNMENT_END
		_button(actions, "review.apply_equipment", func():
			await _equipment(kind, String(target.get_selected_metadata()), int(level.value), String(owned.get_selected_metadata())))
		var remove := _button(actions, "review.remove", func():
			await _equipment(kind, String(owned.get_selected_metadata()), 0, ""))
		remove.disabled = true
		owned.item_selected.connect(func(index: int):
			remove.disabled = index == 0
			var id: String = owned.get_item_metadata(index)
			for i in target.item_count:
				if target.get_item_metadata(i) == id:
					target.select(i)
					level.max_value = limits.get(id, 1)
			for item: Dictionary in ui.get(kind + "_levels", []):
				if item.id == id: level.value = item.level)
	_page("review.hero")
	_heading("review.hero")
	var heroes := OptionButton.new()
	heroes.add_item(tr("review.none"))
	heroes.set_item_metadata(0, "")
	for entry: ContentEntry in ContentManager.sorted(ContentManager.catalog.table(&"heroes")):
		heroes.add_item(entry.get_display_name())
		heroes.set_item_metadata(heroes.item_count - 1, String(entry.id))
		if String(entry.id) == String(ui.get("hero", {}).get("power", "")): heroes.select(heroes.item_count - 1)
	var hero_row := _row()
	heroes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_row.add_child(heroes)
	_button(hero_row, "review.apply", func(): _command("review_hero", {"id": String(heroes.get_selected_metadata())}))
	_page("review.meta")
	_heading("review.meta")
	_meta_grid = GridContainer.new()
	_meta_grid.add_theme_constant_override("h_separation", 32)
	_meta_grid.add_theme_constant_override("v_separation", 8)
	_body.add_child(_meta_grid)
	var boxes := {}
	for entry: ContentEntry in ContentManager.sorted(ContentManager.catalog.table(&"meta_upgrades")):
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_meta_grid.add_child(row)
		var label := Label.new()
		label.text = entry.get_display_name()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var spin := SpinBox.new()
		spin.custom_minimum_size.x = 100
		spin.max_value = entry.costs.size()
		spin.value = session.review_meta_levels.get(String(entry.id), SaveManager.run_meta_level(entry.id))
		row.add_child(spin)
		boxes[String(entry.id)] = spin
	_button(_body, "review.apply", func():
		var levels := {}
		for id: String in boxes: levels[id] = int(boxes[id].value)
		var ordered := PackedInt32Array()
		for entry: ContentEntry in ContentManager.sorted(ContentManager.catalog.table(&"meta_upgrades")): ordered.append(levels[String(entry.id)])
		var result: Dictionary = session.bridge.command("review_meta", {"levels": ordered, "profile": ProfileManager.for_cpp(true, levels)})
		if result.ok: session.review_meta_levels = levels
		_show_result(result))
	_page("review.helpers")
	_heading("review.invincible")
	var invincible := CheckButton.new()
	invincible.text = tr("review.invincible")
	invincible.button_pressed = bool(ui.get("invincible", false))
	invincible.toggled.connect(func(value: bool): _command("review_invincible", {"value": value}))
	_body.add_child(invincible)
	_body.add_child(HSeparator.new())
	_button(_body, "review.boss", func(): _command("review_boss", {}))
	_tabs.current_tab = mini(selected, _tabs.get_tab_count() - 1)
	_layout()

func _equipment(kind: String, id: String, level: int, replace: String) -> void:
	if _busy: return
	_busy = true
	_status.text = tr("review.preparing")
	for button in _buttons: button.disabled = true
	var result: Dictionary = await _controls.apply_equipment(kind, id, level, replace)
	_busy = false
	_show_result(result)

func _command(kind: String, payload: Dictionary) -> void:
	if _busy: return
	_show_result(session.bridge.command(kind, payload))

func _show_result(result: Dictionary) -> void:
	_status.text = tr("review.applied") if result.ok else String(result.get("message", tr("review.unavailable")))
	_rebuild()
