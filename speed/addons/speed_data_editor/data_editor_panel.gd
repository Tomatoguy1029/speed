## データ編集ツールの画面（設計書 8.4）。
##
## データのフォルダ（プロジェクト設定 speed_data_editor/data_dir）を読み、
##   ・サブフォルダ：1つの表（1行が1つの .tres、1列が1つの項目。辞書の値は「辞書名.キー」の列に広げる）
##   ・フォルダ直下の .tres：項目を縦に並べた表（@export_group のまとまりごとに見出し）
## として表示する。値はすべて表示し、隠さない。セルを編集すると、その .tres にすぐ保存する。
## この道具は Godot 本体だけに依存する（設計書 4.1）。
@tool
extends VBoxContainer

const SETTING_DIR := "speed_data_editor/data_dir"

var _categories: ItemList
var _tree: Tree
## 選んだ行のすべての項目を、省略せずに表示する欄
var _detail: TextEdit
var _status: Label
var _filter: LineEdit
## 表示中のカテゴリ：{"label", "files"（パスの一覧）, "single"（縦の表か）}
var _cats: Array = []
var _current := -1
## Tree の行 → 表示している .tres、列 → 項目の名前
var _row_res: Dictionary = {}
var _columns: Array = []

func _ready() -> void:
	var bar := HBoxContainer.new()
	var title := Label.new()
	title.text = "データ"
	bar.add_child(title)
	_filter = LineEdit.new()
	_filter.placeholder_text = "列・行の絞り込み（空ならすべて表示）"
	_filter.custom_minimum_size = Vector2(320, 0)
	_filter.text_changed.connect(func(_t): _show(_current))
	bar.add_child(_filter)
	var reload_button := Button.new()
	reload_button.text = "読み直す"
	reload_button.pressed.connect(reload)
	bar.add_child(reload_button)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_status)
	add_child(bar)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	_categories = ItemList.new()
	_categories.custom_minimum_size = Vector2(200, 0)
	_categories.item_selected.connect(_show)
	split.add_child(_categories)
	_tree = Tree.new()
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.column_titles_visible = true
	_tree.select_mode = Tree.SELECT_SINGLE
	_tree.item_edited.connect(_on_edited)
	_tree.item_selected.connect(_on_selected)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_tree)
	_detail = TextEdit.new()
	_detail.editable = false
	_detail.custom_minimum_size = Vector2(0, 140)
	_detail.placeholder_text = "行を選ぶと、その行のすべての項目を省略せずに表示する"
	_detail.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	right.add_child(_detail)
	split.add_child(right)

func reload() -> void:
	if _categories == null:
		return
	_cats.clear()
	_categories.clear()
	var dir := str(ProjectSettings.get_setting(SETTING_DIR, ""))
	var da := DirAccess.open(dir) if dir != "" else null
	if da == null:
		_status.text = "プロジェクト設定 %s のフォルダが見つからない" % SETTING_DIR
		return
	for f in da.get_files():
		if f.ends_with(".tres"):
			_cats.append({"label": f.get_basename(), "files": [dir.path_join(f)], "single": true})
	for sub in da.get_directories():
		var files: Array = []
		var sda := DirAccess.open(dir.path_join(sub))
		for f in sda.get_files():
			if f.ends_with(".tres"):
				files.append(dir.path_join(sub).path_join(f))
		files.sort()
		if not files.is_empty():
			_cats.append({"label": sub, "files": files, "single": false})
	for c in _cats:
		_categories.add_item("%s（%d）" % [c.label, c.files.size()])
	if not _cats.is_empty():
		_current = clampi(_current, 0, _cats.size() - 1)
		_categories.select(_current)
		_show(_current)

# ── 表示 ──────────────────────────────────────────────────────────

func _show(index: int) -> void:
	if index < 0 or index >= _cats.size():
		return
	_current = index
	_tree.clear()
	_row_res.clear()
	_columns.clear()
	var cat: Dictionary = _cats[index]
	if cat.single:
		_show_single(load(cat.files[0]))
	else:
		_show_table(cat.files)
	_status.text = "%s：%d 件" % [cat.label, cat.files.size()]

## 項目を縦に並べた表（調整値など、1つの .tres）。
func _show_single(res: Resource) -> void:
	_tree.columns = 3
	_tree.set_column_title(0, "項目")
	_tree.set_column_title(1, "値")
	_tree.set_column_title(2, "型")
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, true)
	var root := _tree.create_item()
	var group: TreeItem = root
	var f := _filter.text.strip_edges()
	for prop in res.get_property_list():
		if prop.usage & PROPERTY_USAGE_GROUP:
			group = _tree.create_item(root)
			group.set_text(0, prop.name)
			group.set_selectable(0, false)
			group.set_custom_color(0, Color(0.6, 0.8, 1.0))
			continue
		if not _is_field(prop):
			continue
		if f != "" and not String(prop.name).contains(f):
			continue
		var it := _tree.create_item(group)
		it.set_text(0, prop.name)
		_set_cell(it, 1, res.get(prop.name), prop.type)
		it.set_text(2, type_string(prop.type))
		it.set_metadata(0, [res, prop.name, ""])

## 1行が1つの .tres の表（武器・敵など）。辞書の値は「辞書名.キー」の列に広げる。
func _show_table(files: Array) -> void:
	var resources: Array = []
	for path in files:
		var r := load(path)
		if r != null:
			resources.append(r)
	if resources.is_empty():
		return
	var f := _filter.text.strip_edges()
	# 列：ファイル名、項目、辞書のキー（全行の和集合）
	for prop in resources[0].get_property_list():
		if not _is_field(prop):
			continue
		if prop.type == TYPE_DICTIONARY:
			var keys: Array = []
			for r in resources:
				for k in r.get(prop.name):
					if not keys.has(k):
						keys.append(k)
			for k in keys:
				_columns.append([prop.name, k, TYPE_NIL])
		else:
			_columns.append([prop.name, "", prop.type])
	if f != "":
		_columns = _columns.filter(func(c): return _col_title(c).contains(f) or c[0] in ["id", "display_name", "index"])
	_tree.columns = _columns.size() + 1
	_tree.set_column_title(0, "ファイル")
	for i in _columns.size():
		_tree.set_column_title(i + 1, _col_title(_columns[i]))
		_tree.set_column_expand(i + 1, false)
		_tree.set_column_custom_minimum_width(i + 1, 110)
	_tree.set_column_custom_minimum_width(0, 160)
	var root := _tree.create_item()
	for r in resources:
		var it := _tree.create_item(root)
		it.set_text(0, r.resource_path.get_file())
		it.set_metadata(0, r)
		for i in _columns.size():
			var c: Array = _columns[i]
			if c[1] == "":
				_set_cell(it, i + 1, r.get(c[0]), c[2])
			else:
				var d: Dictionary = r.get(c[0])
				if d.has(c[1]):
					_set_cell(it, i + 1, d[c[1]], typeof(d[c[1]]))
				else:
					it.set_text(i + 1, "—")
		_row_res[it] = r
	_fit_columns()

## 列の幅を中身に合わせる（長い文字は最大 420px。全文はツールチップと下の欄に出す）。
func _fit_columns() -> void:
	var font := get_theme_default_font()
	var size := get_theme_default_font_size()
	for col in _tree.columns:
		var w := font.get_string_size(_tree.get_column_title(col), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var it := _tree.get_root().get_first_child() if _tree.get_root() != null else null
		while it != null:
			w = maxf(w, font.get_string_size(it.get_text(col), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
			it = it.get_next()
		_tree.set_column_custom_minimum_width(col, int(clampf(w + 28.0, 70.0, 420.0)))

func _on_selected() -> void:
	var it := _tree.get_selected()
	if it == null:
		return
	var lines: Array = []
	for col in _tree.columns:
		var title := _tree.get_column_title(col)
		var text := it.get_text(col)
		if it.get_cell_mode(col) == TreeItem.CELL_MODE_CHECK:
			text = "true" if it.is_checked(col) else "false"
		lines.append("%s：%s" % [title, text])
	_detail.text = "\n".join(lines)

func _col_title(c: Array) -> String:
	return c[0] if c[1] == "" else "%s.%s" % [c[0], c[1]]

func _is_field(prop: Dictionary) -> bool:
	return (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) and (prop.usage & PROPERTY_USAGE_STORAGE)

func _set_cell(it: TreeItem, col: int, value, type: int) -> void:
	match type:
		TYPE_BOOL:
			it.set_cell_mode(col, TreeItem.CELL_MODE_CHECK)
			it.set_checked(col, bool(value))
			it.set_editable(col, true)
		TYPE_ARRAY:
			# 他のデータへの参照の一覧などは、名前を並べて表示する（編集はインスペクタで行う）
			var names: Array = []
			for v in value:
				names.append(v.resource_path.get_file().get_basename() if v is Resource else str(v))
			it.set_text(col, ", ".join(names))
			it.set_tooltip_text(col, "インスペクタで編集する")
		TYPE_COLOR:
			it.set_text(col, "#" + Color(value).to_html(false))
			it.set_custom_bg_color(col, Color(value).darkened(0.4))
			it.set_editable(col, true)
		_:
			it.set_text(col, _to_text(value))
			it.set_editable(col, true)
	it.set_tooltip_text(col, it.get_text(col))

func _to_text(value) -> String:
	if value is PackedInt32Array or value is PackedFloat32Array:
		return ", ".join(Array(value).map(func(v): return str(v)))
	return str(value)

# ── 編集 ──────────────────────────────────────────────────────────

func _on_edited() -> void:
	var it := _tree.get_edited()
	var col := _tree.get_edited_column()
	var res: Resource
	var prop: String
	var key := ""
	if _cats[_current].single:
		var meta: Array = it.get_metadata(0)
		res = meta[0]
		prop = meta[1]
	else:
		res = _row_res.get(it)
		var c: Array = _columns[col - 1]
		prop = c[0]
		key = c[1]
	if res == null:
		return
	var old = res.get(prop) if key == "" else res.get(prop).get(key)
	var value = it.is_checked(col) if typeof(old) == TYPE_BOOL else _parse(it.get_text(col), old)
	if value == null:
		_status.text = "読めない値：%s" % it.get_text(col)
		it.set_text(col, _to_text(old))
		return
	if key == "":
		res.set(prop, value)
	else:
		var d: Dictionary = res.get(prop).duplicate()
		d[key] = value
		res.set(prop, d)
	var err := ResourceSaver.save(res, res.resource_path)
	_status.text = ("保存した：%s %s" % [res.resource_path.get_file(), _col_title([prop, key])]) if err == OK else ("保存できなかった（%d）" % err)

## 文字を、元の値と同じ型に直す。直せなければ null。
func _parse(text: String, old):
	text = text.strip_edges()
	match typeof(old):
		TYPE_INT:
			return int(text) if text.is_valid_int() else null
		TYPE_FLOAT:
			return float(text) if text.is_valid_float() else null
		TYPE_STRING_NAME:
			return StringName(text)
		TYPE_STRING:
			return text
		TYPE_COLOR:
			return Color.from_string(text, Color.BLACK) if Color.html_is_valid(text) else null
		TYPE_PACKED_INT32_ARRAY:
			var out := PackedInt32Array()
			for part in text.split(",", false):
				if not part.strip_edges().is_valid_int():
					return null
				out.append(int(part))
			return out
	return null
