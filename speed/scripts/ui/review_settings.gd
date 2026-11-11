## 審査版だけのラン内カスタム設定。セーブや編集元へ書き込まない。
extends PanelContainer
signal finished
var session: RunSession
var _controls: RefCounted
var _body: VBoxContainer
var _status: Label
var _buttons: Array[Button] = []
var _busy := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_controls = preload("res://scripts/runtime/review_controls.gd").new()
	_controls.session = session
	var margin := MarginContainer.new()
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
	var scroll := ScrollContainer.new()
	set_meta("guide_scroll", scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var back := Button.new()
	back.text = tr("common.back")
	back.pressed.connect(func():
		if not _busy: finished.emit())
	column.add_child(back)
	_rebuild()
	back.grab_focus()
	var guide := preload("res://scripts/ui/review_guide.gd").new()
	add_child(guide)
	guide.settings.call_deferred(self)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if not _busy: finished.emit()

func _heading(key: String) -> void:
	var label := Label.new()
	label.text = tr(key)
	label.add_theme_font_size_override("font_size", 22)
	_body.add_child(label)
	set_meta("guide_" + key.trim_prefix("review."), label)

func _button(parent: Node, key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = tr(key)
	button.pressed.connect(action)
	parent.add_child(button)
	_buttons.append(button)
	return button

func _row() -> VBoxContainer:
	var row := VBoxContainer.new()
	_body.add_child(row)
	return row

func _rebuild() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_buttons.clear()
	var response: Dictionary = session.bridge.read_frame()
	if not response.ok: return
	var ui: Dictionary = response.value.ui
	var catalog: Dictionary = session.bridge.command("review_catalog")
	if not catalog.ok:
		_status.text = tr("review.unavailable")
		return
	var limits: Dictionary = catalog.value.limits
	for kind: String in ["weapon", "trait"]:
		_heading("review." + kind)
		var count := Label.new()
		count.text = tr("review.slots").format({"used": ui.get(kind + "_levels", []).size(), "max": catalog.value.get(kind + "_slots", 0)})
		_body.add_child(count)
		var row := _row()
		var target := OptionButton.new()
		var table: Dictionary = ContentManager.catalog.table(&"weapons" if kind == "weapon" else &"traits")
		for entry: ContentEntry in ContentManager.sorted(table):
			if not session.cpp_resources.equipment.has(kind + ":" + String(entry.id)): continue
			target.add_item(entry.get_display_name())
			target.set_item_metadata(target.item_count - 1, String(entry.id))
		row.add_child(target)
		var owned := OptionButton.new()
		owned.add_item(tr("review.add"))
		owned.set_item_metadata(0, "")
		for item: Dictionary in ui.get(kind + "_levels", []):
			var entry: ContentEntry = table.get(StringName(item.id))
			owned.add_item("%s Lv.%d" % [entry.get_display_name() if entry != null else item.id, item.level])
			owned.set_item_metadata(owned.item_count - 1, String(item.id))
		row.add_child(owned)
		var level := SpinBox.new()
		level.min_value = 1
		level.max_value = limits.get(String(target.get_selected_metadata()), 1)
		level.value = 1
		level.tooltip_text = tr("review.level")
		row.add_child(level)
		target.item_selected.connect(func(_index: int): level.max_value = limits.get(String(target.get_selected_metadata()), 1))
		_button(row, "review.apply_equipment", func():
			await _equipment(kind, String(target.get_selected_metadata()), int(level.value), String(owned.get_selected_metadata())))
		var remove := _button(row, "review.remove", func():
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
	_heading("review.hero")
	var heroes := OptionButton.new()
	heroes.add_item(tr("review.none"))
	heroes.set_item_metadata(0, "")
	for entry: ContentEntry in ContentManager.sorted(ContentManager.catalog.table(&"heroes")):
		heroes.add_item(entry.get_display_name())
		heroes.set_item_metadata(heroes.item_count - 1, String(entry.id))
		if String(entry.id) == String(ui.get("hero", {}).get("power", "")): heroes.select(heroes.item_count - 1)
	_body.add_child(heroes)
	_button(_body, "review.apply", func(): _command("review_hero", {"id": String(heroes.get_selected_metadata())}))
	_heading("review.meta")
	var boxes := {}
	for entry: ContentEntry in ContentManager.sorted(ContentManager.catalog.table(&"meta_upgrades")):
		var row := _row()
		var label := Label.new()
		label.text = entry.get_display_name()
		row.add_child(label)
		var spin := SpinBox.new()
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
	var invincible := CheckButton.new()
	invincible.text = tr("review.invincible")
	invincible.button_pressed = bool(ui.get("invincible", false))
	invincible.toggled.connect(func(value: bool): _command("review_invincible", {"value": value}))
	_body.add_child(invincible)
	set_meta("guide_invincible", invincible)
	set_meta("guide_boss", _button(_body, "review.boss", func(): _command("review_boss", {})))

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
