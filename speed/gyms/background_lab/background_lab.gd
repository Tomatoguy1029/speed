## 開発版のメインメニューから開く、背景の配置・外観編集画面。
extends Control
const UI := preload("res://gyms/enemy_lab/lab_ui.gd")
const CANVAS := preload("res://gyms/background_lab/background_canvas.gd")
const ASSETS := "res://assets/pixel/background"

var items: Array[BackgroundPlacement] = []
var background_color: Color
var selected := -1
var canvas: CANVAS
var _stage: OptionButton
var _parallax_preview: CheckButton
var _assets: ItemList
var _placed: ItemList
var _fields: Dictionary = {}
var _color: ColorPickerButton
var _background_color: ColorPickerButton
var _status: Label
var _details: Label
var _save: Button
var _undo_button: Button
var _redo_button: Button
var _delete_button: Button
var _duplicate_button: Button
var _front: Button
var _back: Button
var _confirm: ConfirmationDialog
var _pending: Callable
var _source: StageDef
var _source_hash := ""
var _saved_key := ""
var _undo: Array = []
var _redo: Array = []
var _updating := false

func _ready() -> void:
	theme = UI.theme()
	var backdrop := ColorRect.new()
	backdrop.color = Color("#0c1420")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	UI.button(top, tr("bg.back"), func(): _request(_leave), "back")
	var title := _label(top, tr("bg.title"))
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage = OptionButton.new()
	for i in range(1, ContentManager.stage_count() + 1):
		_stage.add_item(tr("bg.stage").format({"n": i}), i)
	top.add_child(_stage)
	_stage.item_selected.connect(_change_stage)
	_undo_button = UI.button(top, tr("bg.undo"), _undo_edit, "undo", true)
	_redo_button = UI.button(top, tr("bg.redo"), _redo_edit, "redo", true)
	_save = UI.button(top, tr("bg.save"), _save_stage, "save")
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 200
	split.add_child(left)
	_label(left, tr("bg.assets"))
	_assets = ItemList.new()
	_assets.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_assets.fixed_icon_size = Vector2i(72, 48)
	left.add_child(_assets)
	for file in DirAccess.get_files_at(ASSETS):
		if file.ends_with(".png"):
			var path := ASSETS.path_join(file)
			var index := _assets.add_item(_asset_name(path), load(path))
			_assets.set_item_metadata(index, path)
	_assets.item_activated.connect(func(_index: int): _add_asset())
	UI.button(left, tr("bg.add"), _add_asset, "plus")
	_label(left, tr("bg.placed"))
	_placed = ItemList.new()
	_placed.fixed_icon_size = Vector2i(32, 32)
	_placed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_placed)
	_placed.item_selected.connect(select)
	var order := HBoxContainer.new()
	left.add_child(order)
	_back = UI.button(order, tr("bg.send_back"), _reorder.bind(-1))
	_front = UI.button(order, tr("bg.bring_front"), _reorder.bind(1))
	var right_split := HSplitContainer.new()
	split.add_child(right_split)
	var workspace := VBoxContainer.new()
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_split.add_child(workspace)
	var tools := HBoxContainer.new()
	workspace.add_child(tools)
	UI.button(tools, tr("bg.start"), func(): canvas.center = Vector2.ZERO; canvas.zoom = 0.65; canvas.queue_redraw())
	UI.button(tools, tr("bg.focus"), func(): _parallax_preview.button_pressed = false; canvas.focus_item(), "focus")
	var guides := CheckButton.new()
	guides.text = tr("bg.guides")
	guides.button_pressed = true
	guides.toggled.connect(func(on: bool): canvas.guides = on; canvas.queue_redraw())
	tools.add_child(guides)
	_parallax_preview = CheckButton.new()
	_parallax_preview.text = tr("bg.parallax_preview")
	_parallax_preview.toggled.connect(func(on: bool): canvas.finish_drag(); canvas.parallax_preview = on; canvas.queue_redraw())
	tools.add_child(_parallax_preview)
	canvas = CANVAS.new()
	canvas.editor = self
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.add_child(canvas)
	var help := _label(workspace, tr("bg.help"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 260
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_split.add_child(scroll)
	var inspector := VBoxContainer.new()
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inspector)
	_label(inspector, tr("bg.background_color"))
	_background_color = ColorPickerButton.new()
	_background_color.edit_alpha = false
	_background_color.custom_minimum_size.y = 36
	_background_color.color_changed.connect(_set_background_color)
	inspector.add_child(_background_color)
	var stars := CheckButton.new()
	stars.text = tr("bg.stars")
	stars.button_pressed = true
	stars.toggled.connect(func(on: bool): canvas.show_stars = on; canvas.queue_redraw())
	inspector.add_child(stars)
	_label(inspector, tr("bg.properties")).add_theme_font_size_override("font_size", 18)
	_details = _label(inspector, "")
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for field in [["x", -100000, 100000, 1], ["y", -100000, 100000, 1], ["scale", 0.05, 10, 0.05], ["rotation", -180, 180, 1], ["opacity", 0, 1, 0.01], ["parallax", 0, 1, 0.05]]:
		_label(inspector, tr("bg." + field[0]))
		var number := SpinBox.new()
		number.min_value = field[1]
		number.max_value = field[2]
		number.step = field[3]
		number.value_changed.connect(_edit.bind(field[0]))
		inspector.add_child(number)
		_fields[field[0]] = number
	_label(inspector, tr("bg.color"))
	_color = ColorPickerButton.new()
	_color.edit_alpha = false
	_color.custom_minimum_size.y = 36
	_color.color_changed.connect(_set_color)
	inspector.add_child(_color)
	_duplicate_button = UI.button(inspector, tr("bg.duplicate"), _duplicate)
	_delete_button = UI.button(inspector, tr("bg.delete"), _delete_item)
	_status = _label(root, "")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm = ConfirmationDialog.new()
	_confirm.title = tr("bg.unsaved_title")
	_confirm.dialog_text = tr("bg.discard")
	_confirm.ok_button_text = tr("bg.discard_button")
	_confirm.cancel_button_text = tr("bg.cancel")
	_confirm.confirmed.connect(func(): _pending.call())
	add_child(_confirm)
	if _assets.item_count > 0: _assets.select(0)
	_load_stage(mini(4, ContentManager.stage_count()))

func _label(parent: Node, value: String) -> Label:
	var label := Label.new()
	label.text = value
	parent.add_child(label)
	return label

func _asset_name(path: String) -> String:
	var name := path.get_file().get_basename()
	var key := "bg.asset." + name
	var translated := tr(key)
	return translated if translated != key else name

func snapshot() -> Dictionary:
	var result: Array = []
	for item in items: result.append(item.copy())
	return {"items": result, "background_color": background_color}

func _key() -> String:
	var values := []
	for item in items:
		values.append([item.texture.resource_path if item.texture != null else "", item.offset, item.scale, item.rotation_degrees, item.tint, item.parallax])
	return var_to_str([background_color, values])

func remember(before: Dictionary) -> void:
	_undo.append(before)
	if _undo.size() > 50: _undo.pop_front()
	_redo.clear()
	refresh()

func _request(action: Callable) -> void:
	canvas.finish_drag()
	if _key() != _saved_key:
		_pending = action
		_confirm.popup_centered()
	else:
		action.call()

func _leave() -> void:
	if get_tree().current_scene == self:
		get_tree().quit()
	else:
		GameManager.back()

func _change_stage(index: int) -> void:
	var next := _stage.get_item_id(index)
	_stage.select(_stage.get_item_index(_source.index))
	if next != _source.index: _request(_load_stage.bind(next))

func _load_stage(index: int) -> void:
	var source: StageDef = ContentManager.stage(index)
	_source = ResourceLoader.load(source.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageDef
	_source_hash = FileAccess.get_sha256(_source.resource_path)
	background_color = _source.background_color
	items.clear()
	for item in _source.backgrounds:
		var copy := item.copy()
		preload("res://tools/content/prepare_background.gd").measure(copy)
		items.append(copy)
	selected = -1
	_undo.clear()
	_redo.clear()
	_stage.select(_stage.get_item_index(index))
	_parallax_preview.button_pressed = false
	canvas.center = Vector2.ZERO
	canvas.zoom = 0.65
	_saved_key = _key()
	refresh()

func select(index: int) -> void:
	selected = index
	refresh(false)

func refresh(rebuild := true) -> void:
	_updating = true
	_background_color.color = background_color
	if rebuild:
		_placed.clear()
		for item in items: _placed.add_item(_asset_name(item.texture.resource_path), item.texture)
	_placed.deselect_all()
	if selected >= 0:
		_placed.select(selected)
		var item := items[selected]
		_fields.x.set_value_no_signal(item.offset.x)
		_fields.y.set_value_no_signal(item.offset.y)
		_fields.scale.set_value_no_signal(item.scale)
		_fields.rotation.set_value_no_signal(item.rotation_degrees)
		_fields.opacity.set_value_no_signal(item.tint.a)
		_fields.parallax.set_value_no_signal(item.parallax)
		_color.color = Color(item.tint, 1.0)
		_details.text = tr("bg.dimensions").format({"w": int(item.bounds().size.x * item.scale), "h": int(item.bounds().size.y * item.scale)})
	else:
		_details.text = tr("bg.select")
	for number: SpinBox in _fields.values(): number.editable = selected >= 0
	_color.disabled = selected < 0
	_duplicate_button.disabled = selected < 0
	_delete_button.disabled = selected < 0
	_front.disabled = selected < 0 or selected >= items.size() - 1
	_back.disabled = selected <= 0
	_undo_button.disabled = _undo.is_empty()
	_redo_button.disabled = _redo.is_empty()
	_save.disabled = _key() == _saved_key
	_status.text = tr("bg.status").format({"n": items.size(), "state": tr("bg.dirty") if _key() != _saved_key else tr("bg.saved")})
	_updating = false
	canvas.queue_redraw()

func _add_asset() -> void:
	var chosen := _assets.get_selected_items()
	if chosen.is_empty(): return
	var before := snapshot()
	var item := BackgroundPlacement.new()
	item.texture = load(_assets.get_item_metadata(chosen[0]))
	preload("res://tools/content/prepare_background.gd").measure(item)
	item.offset = canvas.center
	items.append(item)
	selected = items.size() - 1
	remember(before)

func _edit(value: float, field: String) -> void:
	if _updating or selected < 0: return
	var item := items[selected]
	var before := snapshot()
	match field:
		"x": item.offset.x = value
		"y": item.offset.y = value
		"scale": item.scale = value
		"rotation": item.rotation_degrees = value
		"opacity": item.tint.a = value
		"parallax": item.parallax = value
	remember(before)

func _set_color(value: Color) -> void:
	if _updating or selected < 0: return
	var before := snapshot()
	items[selected].tint = Color(value, items[selected].tint.a)
	remember(before)

func _set_background_color(value: Color) -> void:
	if _updating: return
	var before := snapshot()
	background_color = Color(value, 1.0)
	remember(before)

func _duplicate() -> void:
	if selected < 0: return
	var before := snapshot()
	var item := items[selected].copy()
	item.offset += Vector2(40, 40)
	items.append(item)
	selected = items.size() - 1
	remember(before)

func _delete_item() -> void:
	if selected < 0: return
	var before := snapshot()
	items.remove_at(selected)
	selected = mini(selected, items.size() - 1)
	remember(before)

func _reorder(direction: int) -> void:
	if selected < 0 or selected + direction < 0 or selected + direction >= items.size(): return
	var before := snapshot()
	var target := selected + direction
	var item := items[selected]
	items[selected] = items[target]
	items[target] = item
	selected = target
	remember(before)

func _undo_edit() -> void:
	if _undo.is_empty(): return
	_redo.append(snapshot())
	_restore(_undo.pop_back())
	selected = mini(selected, items.size() - 1)
	refresh()

func _redo_edit() -> void:
	if _redo.is_empty(): return
	_undo.append(snapshot())
	_restore(_redo.pop_back())
	selected = mini(selected, items.size() - 1)
	refresh()

func _restore(value: Dictionary) -> void:
	items.assign(value.items)
	background_color = value.background_color

func _save_stage() -> void:
	canvas.finish_drag()
	for number: SpinBox in _fields.values():
		if number.editable: number.apply()
	var path := _source.resource_path
	if FileAccess.get_sha256(path) != _source_hash:
		_status.text = tr("bg.external_change")
		return
	var saved := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageDef
	if saved == null:
		_status.text = tr("bg.failed")
		return
	saved.backgrounds.assign(snapshot().items)
	saved.background_color = background_color
	var error := ResourceSaver.save(saved, path)
	if error != OK:
		_status.text = tr("bg.failed") + " " + error_string(error)
		return
	_source_hash = FileAccess.get_sha256(path)
	_saved_key = _key()
	refresh()
	_status.text = tr("bg.saved_stage")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if event.ctrl_pressed and event.keycode == KEY_Z:
		if event.shift_pressed: _redo_edit()
		else: _undo_edit()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_DELETE and canvas.has_focus():
		_delete_item()
		get_viewport().set_input_as_handled()
