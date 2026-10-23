## エディターdockとプレイ中の両方で使う、ステージだけの敵調整。
@tool
extends VBoxContainer

const IO := preload("res://scripts/dev/stage_enemy_edit.gd")
const FIELDS := preload("res://scripts/dev/stage_enemy_fields.gd")
static var _saved_split := 200
static var _saved_nav_split := 160
signal tuning_changed(values: Dictionary)
signal saved(stage: StageDef)

var stage_path := ""
var values: Dictionary = {}
var baseline: Dictionary = {}
var _cfg: GameConfig
var _source: StageDef
var _enemy: EnemyDef
var _id := ""
var _ids: Array[String] = []
var _stage_picker: OptionButton
var _enemy_list: ItemList
var _split: HSplitContainer
var _nav_split: VSplitContainer
var _nav: VBoxContainer
var _editor: VBoxContainer
var _tree: Tree
var _tree_items: Dictionary = {}
var _heading: Label
var _hint: Label
var _scroll: ScrollContainer
var _nav_button: Button
var _category := "すべて"
var _collapsed: Dictionary = {}
var _compact := false
var _wide := false
var _nav_open := false
var _definitions: Dictionary = {}
var _names: Dictionary = {}
var _rows_queued := false
var _enemy_search: LineEdit
var _search: LineEdit
var _rows: VBoxContainer
var _status: Label
var _save_button: Button
var _reset_enemy: Button
var _stages: Array[String] = []
var _row_controls: Dictionary = {}
var _live := false

func _ready() -> void:
	var toolbar := HFlowContainer.new()
	add_child(toolbar)
	_stage_picker = OptionButton.new()
	_stage_picker.tooltip_text = "調整するステージ"
	FIELDS.focus_control(_stage_picker)
	toolbar.add_child(_stage_picker)
	for file in DirAccess.get_files_at("res://data/stages"):
		if not file.ends_with(".tres"): continue
		_stages.append("res://data/stages/" + file)
		_stage_picker.add_item(file.trim_suffix(".tres"))
	_stage_picker.item_selected.connect(func(index): open_stage(_stages[index]))
	_nav_button = _button(toolbar, "敵・分類", func():
		_nav_open = not _nav_open
		_layout())
	_save_button = _button(toolbar, "Save", _save)
	_button(toolbar, "再読込", reload_stage).tooltip_text = "未保存の試行を破棄し、保存済み設定に戻す"
	_reset_enemy = MenuButton.new()
	_reset_enemy.text = "共通値へ ↶"
	FIELDS.focus_control(_reset_enemy)
	toolbar.add_child(_reset_enemy)
	_reset_enemy.get_popup().add_item("この敵の上書きを解除", 0)
	_reset_enemy.get_popup().add_item("全敵の上書きを解除", 1)
	_reset_enemy.get_popup().id_pressed.connect(func(id):
		if id == 0: values.erase(_id)
		else: values.clear()
		_changed()
		_refresh_rows())
	_button(toolbar, "?", func(): _hint.text = "共通値は基準、現在値はこのステージの設定。↶で継承へ戻し、Saveで保存。XP・成長・武器は共通設定。")
	_split = HSplitContainer.new()
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_theme_constant_override("autohide", 0)
	_split.add_theme_constant_override("minimum_grab_thickness", 12)
	add_child(_split)
	_nav = VBoxContainer.new()
	_nav.custom_minimum_size.x = 150
	_split.add_child(_nav)
	_enemy_search = LineEdit.new()
	_enemy_search.placeholder_text = "敵名 / IDを検索"
	_enemy_search.tooltip_text = "調整する敵を検索"
	FIELDS.focus_control(_enemy_search)
	_enemy_search.text_changed.connect(func(_text): _refresh_enemies())
	_nav.add_child(_enemy_search)
	_nav_split = VSplitContainer.new()
	_nav_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_nav_split.add_theme_constant_override("autohide", 0)
	_nav_split.add_theme_constant_override("minimum_grab_thickness", 10)
	_nav.add_child(_nav_split)
	_enemy_list = ItemList.new()
	_enemy_list.custom_minimum_size.y = 64
	_enemy_list.item_selected.connect(func(index):
		_select_enemy(_ids[index])
		if _compact:
			_nav_open = false
			_layout())
	FIELDS.focus_control(_enemy_list)
	_nav_split.add_child(_enemy_list)
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.custom_minimum_size.y = 64
	FIELDS.focus_control(_tree)
	_tree.item_selected.connect(func():
		_category = _tree.get_selected().get_metadata(0)
		_refresh_rows()
		if _compact:
			_nav_open = false
			_layout())
	_nav_split.add_child(_tree)
	_editor = VBoxContainer.new()
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor.resized.connect(_layout)
	_split.add_child(_editor)
	_heading = FIELDS.text(_editor, "", true)
	_heading.add_theme_font_size_override("font_size", 18)
	_heading.max_lines_visible = 2
	_search = LineEdit.new()
	_search.placeholder_text = "項目を検索（威力・間隔・射程…）"
	FIELDS.focus_control(_search)
	_search.text_changed.connect(func(_text): _refresh_rows())
	_editor.add_child(_search)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_editor.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 8)
	_scroll.add_child(_rows)
	_hint = FIELDS.text(self, "項目名にカーソルを重ねると説明を表示。区切りをドラッグして領域を調整。", true)
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.max_lines_visible = 2
	_status = FIELDS.text(self, "", true)
	_status.add_theme_font_size_override("font_size", 13)
	_status.max_lines_visible = 1
	resized.connect(_layout)
	_split.dragged.connect(func(offset): _saved_split = offset)
	_nav_split.dragged.connect(func(offset): _saved_nav_split = offset)
	_split.split_offset = _saved_split
	_nav_split.split_offset = _saved_nav_split
	for split in [_split, _nav_split]:
		split.get_drag_area_controls()[0].tooltip_text = "ドラッグして領域の大きさを変える"
	if _live:
		_stage_picker.disabled = true
		_stage_picker.select(_stages.find(stage_path))
		_refresh_enemies()
		_changed()
	elif not stage_path.is_empty(): open_stage(stage_path)
	elif not _stages.is_empty(): open_stage(_stages[0])
	_layout.call_deferred()

func _layout() -> void:
	if _split == null: return
	_compact = size.x < 660
	_nav_button.visible = _compact
	_nav.visible = not _compact or _nav_open
	_editor.visible = not _compact or not _nav_open
	_nav_button.text = "編集へ戻る" if _nav_open else "敵・分類"
	var wide := _editor.size.x >= 510
	if wide != _wide:
		_wide = wide
		_queue_rows()

func _queue_rows() -> void:
	if _rows_queued: return
	_rows_queued = true
	(func():
		_rows_queued = false
		_refresh_rows()).call_deferred()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	FIELDS.focus_control(button)
	parent.add_child(button)
	return button

func is_dirty() -> bool:
	return values != baseline

func open_stage(path: String) -> void:
	if is_dirty():
		if path != stage_path:
			_status.text = "未保存の変更があります。Saveまたは再読込後にステージを変更してください。"
			_stage_picker.select(_stages.find(stage_path))
		return
	stage_path = path
	reload_stage()

func reload_stage() -> void:
	_source = IO.read_stage(stage_path)
	if _source == null:
		_status.text = "ステージを読み込めません。"
		return
	if not _live: _cfg = ResourceLoader.load("res://data/config.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	baseline = _source.enemy_tuning.duplicate(true)
	values = baseline.duplicate(true)
	_definitions.clear()
	if stage_path not in _stages:
		_stages.append(stage_path)
		_stage_picker.add_item("stage_%d" % _source.index)
	_stage_picker.select(_stages.find(stage_path))
	_refresh_enemies()
	_changed()

func bind_run(stage: StageDef, cfg: GameConfig, tuning: Dictionary) -> void:
	_live = true
	_cfg = cfg
	_source = stage
	stage_path = "res://data/stages/stage_%d.tres" % stage.index
	baseline = stage.enemy_tuning.duplicate(true)
	values = tuning.duplicate(true)
	if _id.is_empty() and not stage.enemies.is_empty(): _id = String(stage.enemies[0])
	if not is_node_ready(): return
	_stage_picker.disabled = true
	_stage_picker.select(_stages.find(stage_path))
	_refresh_enemies()
	_changed()

func _refresh_enemies() -> void:
	_names = IO.enemy_names()
	_ids.clear()
	_enemy_list.clear()
	for id: String in _names:
		var name := "%s / %s" % [_names[id], id]
		if not _enemy_search.text.is_empty() and not name.to_lower().contains(_enemy_search.text.to_lower()): continue
		_ids.append(id)
		var index := _enemy_list.add_item(_names[id])
		_enemy_list.set_item_tooltip(index, name)
	if _ids.is_empty():
		_enemy = null
		_refresh_rows()
		return
	_select_enemy(_id if _id in _ids else _ids[0])

func _select_enemy(id: String) -> void:
	_id = id
	var index := _ids.find(id)
	if index >= 0:
		_enemy_list.select(index)
		_enemy_list.ensure_current_is_visible()
	if not _definitions.has(id): _definitions[id] = IO.definition(id)
	_enemy = _definitions[id]
	_refresh_tree()
	_queue_rows()

func _refresh_tree() -> void:
	_tree.set_block_signals(true)
	_tree.clear()
	_tree_items.clear()
	var root := _tree.create_item()
	for title in ["すべて", "変更した項目"]:
		_tree_items[title] = _tree.create_item(root)
		_tree_items[title].set_metadata(0, title)
	var available := {}
	for key in StageEnemyTuning.keys_for(_enemy): available[FIELDS.category(key)] = true
	for family in FIELDS.GROUPS:
		var categories: Array = FIELDS.GROUPS[family].filter(func(item): return available.has(item))
		if categories.is_empty(): continue
		var parent := _tree.create_item(root)
		parent.set_text(0, family)
		parent.set_metadata(0, family)
		_tree_items[family] = parent
		for category in categories:
			var item := _tree.create_item(parent)
			item.set_metadata(0, category)
			_tree_items[category] = item
	if not _tree_items.has(_category): _category = "すべて"
	_update_tree_counts()
	_tree_items[_category].select(0)
	_tree.set_block_signals(false)

func _update_tree_counts() -> void:
	for category in _tree_items:
		var count := 0
		var changed := 0
		for key in StageEnemyTuning.keys_for(_enemy):
			if not FIELDS.belongs(key, category): continue
			var overridden: bool = values.get(_id, {}).has(key)
			if category == "変更した項目" and not overridden: continue
			count += 1
			if overridden: changed += 1
		_tree_items[category].set_text(0, "%s  %d%s" % [category, count, " · 改%d" % changed if changed else ""])

func _refresh_rows() -> void:
	if _rows == null: return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_row_controls.clear()
	_reset_enemy.disabled = values.is_empty()
	if _enemy == null or _cfg == null:
		_heading.text = "一致する敵がありません"
		return
	_heading.text = "%s  /  %s\n%s" % [_enemy.display_name, _id, _category]
	var groups := {}
	for key in StageEnemyTuning.keys_for(_enemy):
		if not FIELDS.belongs(key, _category): continue
		if _category == "変更した項目" and not values.get(_id, {}).has(key): continue
		var info: Array = FIELDS.docs(key)
		if not _search.text.is_empty() and not (str(info) + key).to_lower().contains(_search.text.to_lower()): continue
		var category: String = FIELDS.category(key)
		if not groups.has(category): groups[category] = []
		groups[category].append(key)
	if groups.is_empty(): FIELDS.text(_rows, "該当する項目がありません。分類か検索条件を変更してください。", true)
	for family in FIELDS.GROUPS:
		for category in FIELDS.GROUPS[family]:
			if not groups.has(category): continue
			var section := VBoxContainer.new()
			_rows.add_child(section)
			var toggle := _button(section, "", func(): pass)
			toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
			toggle.toggle_mode = true
			toggle.button_pressed = not _collapsed.get(category, false)
			toggle.text = ("▾  " if toggle.button_pressed else "▸  ") + category + "  ·  %d項目" % groups[category].size()
			var content: Container = GridContainer.new() if _wide else VBoxContainer.new()
			if _wide:
				content.columns = 5
				for title in ["項目", "共通値", "現在値", "状態 / 差分", ""]: FIELDS.text(content, title)
			section.add_child(content)
			content.visible = toggle.button_pressed
			toggle.toggled.connect(func(open):
				_collapsed[category] = not open
				content.visible = open
				toggle.text = ("▾  " if open else "▸  ") + category + "  ·  %d項目" % groups[category].size())
			for key in groups[category]:
				var base := StageEnemyTuning.base_value(_enemy, key, _cfg)
				var value := float(values.get(_id, {}).get(key, base))
				var integer: bool = key.begins_with("params.") and _enemy.params[key.trim_prefix("params.")] is int
				_row_controls[key] = FIELDS.row(content, key, base, value, integer, _wide, _edit_value.bind(key, base), _reset_key, func(text): _hint.text = text)
				_refresh_difference(key, value, base)

func _refresh_difference(key: String, value: float, base: float) -> void:
	if not _row_controls.has(key): return
	var overridden: bool = values.get(_id, {}).has(key)
	var unsaved: bool = values.get(_id, {}).get(key, null) != baseline.get(_id, {}).get(key, null)
	var state: Label = _row_controls[key][0]
	state.text = ("* " if unsaved else "") + ("%+.2f" % (value - base) if overridden else "共通")
	state.tooltip_text = ("未保存 / " if unsaved else "保存済み / ") + ("ステージ上書き" if overridden else "共通値を使用")
	state.modulate = Color("#ffda87") if unsaved else Color.WHITE
	_row_controls[key][1].disabled = not overridden

func _edit_value(value: float, key: String, base: float) -> void:
	if not values.has(_id): values[_id] = {}
	# 共通値と同じ数値を入力したら継承に戻す。
	if is_equal_approx(value, base): values[_id].erase(key)
	else: values[_id][key] = value
	if values[_id].is_empty(): values.erase(_id)
	_refresh_difference(key, value, base)
	_changed()

func _reset_key(key: String, spin: SpinBox, base: float) -> void:
	if values.has(_id):
		values[_id].erase(key)
		if values[_id].is_empty(): values.erase(_id)
	spin.set_value_no_signal(base)
	_refresh_difference(key, base, base)
	_changed()

func _changed() -> void:
	_save_button.disabled = not is_dirty() or not (Engine.is_editor_hint() or OS.has_feature("editor"))
	_reset_enemy.disabled = values.is_empty()
	_reset_enemy.get_popup().set_item_disabled(0, not values.has(_id))
	if _enemy != null: _update_tree_counts()
	for index in _ids.size():
		var id := _ids[index]
		var count: int = values.get(id, {}).size()
		var pending: bool = values.get(id, {}) != baseline.get(id, {})
		_enemy_list.set_item_text(index, ("* " if pending else "") + _names[id] + (" · %d" % count if count else ""))
	var count := 0
	for id in values: count += values[id].size()
	_status.text = "%s · 上書き %d種 / %d項目" % ["● 未保存の試行" if is_dirty() else "保存済み", values.size(), count]
	_status.tooltip_text = stage_path + "\n固有値は次に行動が参照するときから反映。発射済み攻撃と生成済み配置を維持。"
	tuning_changed.emit(values.duplicate(true))

func _save() -> void:
	if not (Engine.is_editor_hint() or OS.has_feature("editor")):
		_status.text = "ソースへのSaveはGodotエディターからの実行で使えます。"
		return
	var result := IO.save(stage_path, values, baseline)
	if result.has("error"):
		_status.text = result.error
		return
	baseline = values.duplicate(true)
	saved.emit(result.stage)
	var error: Error = load("res://addons/content_build/builder.gd").build_all()
	_changed()
	_status.text = "保存・実行用データの生成完了" if error == OK else "保存済み / 生成失敗: %s" % error_string(error)
	_refresh_rows()
