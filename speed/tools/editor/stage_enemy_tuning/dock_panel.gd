## エディターの細いドック用。保存・差分・ライブ値の規則は共通パネルを使う。
@tool
extends "res://scripts/dev/stage_enemy_panel.gd"

var _enemy_picker: OptionButton
var _category_picker: OptionButton

func _ready() -> void:
	_category = "耐久・装甲"
	var toolbar := HFlowContainer.new()
	add_child(toolbar)
	_stage_picker = OptionButton.new()
	_stage_picker.tooltip_text = "調整するステージ"
	toolbar.add_child(_stage_picker)
	for file in DirAccess.get_files_at("res://data/stages"):
		if not file.ends_with(".tres"): continue
		_stages.append("res://data/stages/" + file)
		_stage_picker.add_item(file.trim_suffix(".tres"))
	_stage_picker.item_selected.connect(func(index): open_stage(_stages[index]))
	_save_button = _button(toolbar, "保存", _save)
	_button(toolbar, "再読込", reload_stage).tooltip_text = "未保存の試行を破棄する"
	_reset_enemy = MenuButton.new()
	_reset_enemy.text = "上書きを解除"
	toolbar.add_child(_reset_enemy)
	_reset_enemy.get_popup().add_item("この敵の上書きを解除", 0)
	_reset_enemy.get_popup().add_item("全敵の上書きを解除", 1)
	_reset_enemy.get_popup().id_pressed.connect(func(id):
		if id == 0: values.erase(_id)
		else: values.clear()
		_changed()
		_refresh_rows())
	_enemy_search = LineEdit.new()
	_enemy_search.placeholder_text = "敵を検索（名前 / ID）"
	_enemy_search.text_changed.connect(func(_text): _refresh_enemies())
	add_child(_enemy_search)
	_enemy_picker = OptionButton.new()
	_category_picker = OptionButton.new()
	for item in [["敵", _enemy_picker], ["分類", _category_picker]]:
		var line := HBoxContainer.new()
		add_child(line)
		FIELDS.text(line, item[0])
		var picker: OptionButton = item[1]
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.fit_to_longest_item = false
		picker.clip_text = true
		line.add_child(picker)
	_enemy_picker.item_selected.connect(func(index): _select_enemy(_ids[index]))
	_category_picker.item_selected.connect(func(index):
		_category = _category_picker.get_item_metadata(index)
		_refresh_rows())
	_search = LineEdit.new()
	_search.placeholder_text = "選択した分類の項目を検索"
	_search.text_changed.connect(func(_text): _refresh_rows())
	add_child(_search)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size.y = 120
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 8)
	_scroll.add_child(_rows)
	_status = FIELDS.text(self, "")
	_status.clip_text = true
	# 共通のデータ処理が持つ選択状態を使い、二列のナビゲーションは表示しない。
	_enemy_list = ItemList.new()
	_tree = Tree.new()
	_heading = Label.new()
	_hint = Label.new()
	for control in [_enemy_list, _tree, _heading, _hint]:
		control.hide()
		add_child(control)
	if not stage_path.is_empty(): open_stage(stage_path)
	elif not _stages.is_empty(): open_stage(_stages[0])

func _layout() -> void:
	_wide = false
	_compact = true

func _refresh_enemies() -> void:
	super._refresh_enemies()
	_enemy_picker.clear()
	for id in _ids:
		_enemy_picker.add_item(_names[id])
		_enemy_picker.set_item_tooltip(_enemy_picker.item_count - 1, "%s / %s" % [_names[id], id])
	if _id in _ids: _enemy_picker.select(_ids.find(_id))

func _select_enemy(id: String) -> void:
	super._select_enemy(id)
	var index := _ids.find(id)
	if index >= 0 and index < _enemy_picker.item_count: _enemy_picker.select(index)

func _refresh_tree() -> void:
	super._refresh_tree()
	_category_picker.clear()
	var found := false
	for family in FIELDS.GROUPS:
		for category in FIELDS.GROUPS[family]:
			if not _tree_items.has(category): continue
			_category_picker.add_item(_tree_items[category].get_text(0))
			_category_picker.set_item_metadata(_category_picker.item_count - 1, category)
			if category == _category:
				_category_picker.select(_category_picker.item_count - 1)
				found = true
	if not found and _category_picker.item_count > 0:
		_category_picker.select(0)
		_category = _category_picker.get_item_metadata(0)

func _update_tree_counts() -> void:
	super._update_tree_counts()
	for index in _category_picker.item_count:
		var category: String = _category_picker.get_item_metadata(index)
		if _tree_items.has(category): _category_picker.set_item_text(index, _tree_items[category].get_text(0))

func _refresh_rows() -> void:
	super._refresh_rows()
	for index in _category_picker.item_count:
		if _category_picker.get_item_metadata(index) == _category: _category_picker.select(index)
	for section in _rows.get_children():
		if section is Container and section.get_child_count() > 0 and section.get_child(0) is Button:
			section.get_child(0).clip_text = true
	for controls in _row_controls.values():
		controls[0].remove_theme_font_size_override("font_size")
		controls[1].text = "解除"
		controls[3].text = "上書きする"
		for child in controls[4].get_parent().get_children():
			if child is Label and child.text.begins_with("共通値（参照） "):
				child.text = child.text.replace("共通値（参照） ", "共通値: ")
	if _enemy == null: FIELDS.text(_rows, "一致する敵がありません。検索条件を変更してください。", true)
