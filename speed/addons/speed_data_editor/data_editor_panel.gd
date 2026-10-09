## データ編集ツールの画面（設計書 8.4）。
##
## データのフォルダ（プロジェクト設定 speed_data_editor/data_dir）の .tres を、この画面だけで分かるように見せて編集する。
##   ・左：データの種類と中身の一覧（調整値はまとまりごと、武器などは1つずつ）
##   ・右：選んだものの項目を、名前・値・単位・説明つきで縦に並べる。種類を選ぶと全件を表で比べられる
## 項目の名前・説明・単位は、各データの定義のスクリプトにある「##」の説明から読む
## （1行目＝名前、「単位：」の行＝単位、残り＝説明。クラスの説明の「---」より後は作り手のメモで、画面に出さない）。
## 辞書の中の値は、定義のスクリプトの定数「<項目名を大文字>_DOCS」（キー → [名前, 説明, 単位]）から読む。
## 値を変えると、その .tres にすぐ保存する。
## この道具は Godot 本体だけに依存する（設計書 4.1）。ゲームのデータの種類を名前で知らない。
@tool
extends VBoxContainer

const SETTING_DIR := "speed_data_editor/data_dir"
const COLOR_DIM := Color(1, 1, 1, 0.62)
const COLOR_FAINT := Color(1, 1, 1, 0.38)
const COLOR_ACCENT := Color(0.55, 0.8, 1.0)
const COLOR_SAVED := Color(0.55, 0.95, 0.6)
const COLOR_ERROR := Color(1.0, 0.5, 0.45)

var _nav: Tree
var _search: LineEdit
var _status: Label
var _form_scroll: ScrollContainer
var _form: VBoxContainer
var _table_page: VBoxContainer
var _table_head: VBoxContainer
var _table: Tree
## データの種類：{"title", "desc", "script", "docs", "items"（Resource の配列）, "single"（調整値のように1つの .tres か）, "order"}
var _cats: Array = []
## id → 表示名（辞書のキーや ID の参照を名前で見せるため）
var _names: Dictionary = {}
## 今の表：列 → [項目名, 辞書のキー]
var _columns: Array = []
var _table_cat: Dictionary = {}
var _selection: Dictionary = {}
var _base_size := 16

func _ready() -> void:
	_base_size = get_theme_default_font_size()
	add_theme_constant_override("separation", 6)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "データ編集"
	title.add_theme_font_size_override("font_size", int(_base_size * 1.25))
	bar.add_child(title)
	_search = LineEdit.new()
	_search.placeholder_text = "項目を探す（名前・説明・内部名）"
	_search.clear_button_enabled = true
	_search.custom_minimum_size = Vector2(360, 0)
	_search.text_changed.connect(func(_t): _on_search())
	bar.add_child(_search)
	var reload_button := Button.new()
	reload_button.text = "読み直す"
	reload_button.tooltip_text = "ファイルから読み直す（ほかの所で .tres を変えたとき）"
	reload_button.pressed.connect(reload)
	bar.add_child(reload_button)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(_status)
	add_child(bar)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	_nav = Tree.new()
	_nav.custom_minimum_size = Vector2(340, 0)
	_nav.hide_root = true
	_nav.select_mode = Tree.SELECT_SINGLE
	_nav.item_selected.connect(_on_nav_selected)
	split.add_child(_nav)

	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	_form_scroll = ScrollContainer.new()
	_form_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_form_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_form_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_form_scroll.add_child(margin)
	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 4)
	margin.add_child(_form)

	_table_page = VBoxContainer.new()
	_table_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_table_page.visible = false
	right.add_child(_table_page)
	_table_head = VBoxContainer.new()
	_table_page.add_child(_table_head)
	_table = Tree.new()
	_table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_table.hide_root = true
	_table.column_titles_visible = true
	_table.select_mode = Tree.SELECT_SINGLE
	_table.item_edited.connect(_on_table_edited)
	_table.item_activated.connect(_on_table_activated)
	_table_page.add_child(_table)

func reload() -> void:
	if _nav == null:
		return
	_cats.clear()
	_names.clear()
	var dir := str(ProjectSettings.get_setting(SETTING_DIR, ""))
	var da := DirAccess.open(dir) if dir != "" else null
	if da == null:
		_set_status("プロジェクト設定 %s のフォルダが見つからない" % SETTING_DIR, COLOR_ERROR)
		return
	for f in da.get_files():
		if f.ends_with(".tres"):
			_add_category([dir.path_join(f)], true)
	for sub in da.get_directories():
		var files: Array = []
		var sda := DirAccess.open(dir.path_join(sub))
		for f in sda.get_files():
			if f.ends_with(".tres"):
				files.append(dir.path_join(sub).path_join(f))
		if not files.is_empty():
			_add_category(files, false)
	_cats.sort_custom(func(a, b): return a.order < b.order if a.order != b.order else a.title < b.title)
	_build_nav()
	_set_status("左から調整したいものを選ぶ。値を変えるとすぐ保存される", COLOR_DIM)

func _add_category(files: Array, single: bool) -> void:
	var items: Array = []
	for path in files:
		var r := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if r != null and r.get_script() != null:
			items.append(r)
	if items.is_empty():
		return
	var script: Script = items[0].get_script()
	var docs := _parse_docs(script)
	var consts := script.get_script_constant_map()
	for r in items:
		var id = _val(r, "id")
		if id != null and str(id) != "":
			_names[str(id)] = _item_name(r)
	items.sort_custom(_item_less)
	_cats.append({"title": docs.title if docs.title != "" else script.get_global_name(), "desc": docs.desc,
		"docs": docs, "consts": consts, "items": items, "single": single,
		"order": int(consts.get("EDITOR_ORDER", 0 if single else 100)), "folder": files[0].get_base_dir().get_file()})

func _build_nav() -> void:
	_nav.clear()
	var root := _nav.create_item()
	var first: TreeItem = null
	for cat in _cats:
		var head := _nav.create_item(root)
		if cat.single:
			head.set_text(0, cat.title)
			head.set_metadata(0, {"kind": "all", "cat": cat})
			for g in cat.docs.groups:
				if g.fields.is_empty():
					continue
				var it := _nav.create_item(head)
				it.set_text(0, "%s（%d）" % [g.name, g.fields.size()])
				it.set_tooltip_text(0, g.desc)
				it.set_metadata(0, {"kind": "group", "cat": cat, "group": g})
		else:
			head.set_text(0, "%s（%d）" % [cat.title, cat.items.size()])
			head.set_metadata(0, {"kind": "table", "cat": cat})
			for r in cat.items:
				var it := _nav.create_item(head)
				it.set_text(0, _item_label(r))
				it.set_metadata(0, {"kind": "item", "cat": cat, "res": r})
			head.collapsed = true
		head.set_tooltip_text(0, cat.desc)
		head.set_custom_color(0, COLOR_ACCENT)
		if first == null:
			first = head
	if not _selection.is_empty() and _reselect(root):
		return
	if first != null:
		first.select(0)

## 読み直したあと、前に見ていたものを選び直す。
func _reselect(root: TreeItem) -> bool:
	var stack: Array = [root]
	while not stack.is_empty():
		var it: TreeItem = stack.pop_back()
		var m = it.get_metadata(0)
		if m is Dictionary and m.kind == _selection.kind and m.cat.title == _selection.cat.title:
			var same: bool = (m.kind == "group" and m.group.name == _selection.group.name) \
				or (m.kind == "item" and m.res.resource_path == _selection.res.resource_path) \
				or m.kind in ["all", "table"]
			if same:
				if it.get_parent() != null:
					it.get_parent().collapsed = false
				it.select(0)
				return true
		for c in it.get_children():
			stack.append(c)
	return false

func _on_nav_selected() -> void:
	var it := _nav.get_selected()
	if it == null:
		return
	var m: Dictionary = it.get_metadata(0)
	_selection = m
	if _search.text.strip_edges() != "":
		_search.text = ""
	_show_selection()

func _show_selection() -> void:
	if _selection.is_empty():
		return
	var cat: Dictionary = _selection.cat
	match _selection.kind:
		"all":
			_show_form_page(cat.title, cat.desc, cat.items[0], cat, cat.docs.groups)
		"group":
			_show_form_page("%s：%s" % [cat.title, _selection.group.name], _selection.group.desc, cat.items[0], cat, [_selection.group])
		"item":
			_show_form_page(_item_name(_selection.res), "%s（%s）" % [cat.title, _selection.res.resource_path.get_file()],
				_selection.res, cat, cat.docs.groups, true)
		"table":
			_show_table(cat)

# ── 項目を縦に並べる画面 ──────────────────────────────────────────

func _clear_form() -> void:
	_table_page.visible = false
	_form_scroll.visible = true
	for c in _form.get_children():
		c.queue_free()
	_form_scroll.scroll_vertical = 0

func _show_form_page(title: String, subtitle: String, res: Resource, cat: Dictionary, groups: Array, item := false) -> void:
	_clear_form()
	_add_heading(title, subtitle)
	if item:
		_add_paragraph(cat.desc, COLOR_DIM)
	_add_spacer(6)
	var single_group := groups.size() == 1
	for g in groups:
		if g.fields.is_empty():
			continue
		if g.name != "" and not single_group:
			_add_group_title(g.name, g.desc)
		var odd := false
		for field in g.fields:
			_form.add_child(_field_row(res, cat, field, odd))
			odd = not odd

func _add_heading(title: String, subtitle: String) -> void:
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", int(_base_size * 1.6))
	_form.add_child(t)
	if subtitle != "":
		_add_paragraph(subtitle, COLOR_ACCENT)

func _add_paragraph(text: String, color: Color, target: Control = null) -> void:
	if text == "":
		return
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	(target if target != null else _form).add_child(l)

func _add_spacer(h: int) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	_form.add_child(c)

func _add_group_title(text: String, desc: String) -> void:
	_add_spacer(14)
	var t := Label.new()
	t.text = text
	t.add_theme_font_size_override("font_size", int(_base_size * 1.3))
	t.add_theme_color_override("font_color", COLOR_ACCENT)
	_form.add_child(t)
	_add_paragraph(desc, COLOR_DIM)
	var line := HSeparator.new()
	_form.add_child(line)

## 項目1つの行：名前・値・単位、その下に説明と内部名。
func _field_row(res: Resource, cat: Dictionary, field: Dictionary, odd: bool) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.045 if odd else 0.0)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var value = _val(res, field.name)
	if value is Dictionary:
		_dict_rows(box, res, cat, field, value)
		return panel
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	box.add_child(line)
	var label := Label.new()
	label.text = field.label
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", int(_base_size * 1.1))
	line.add_child(label)
	line.add_child(_editor_for(value, func(v): _save(res, field.name, "", v, field.label), field.unit))
	var unit := Label.new()
	unit.text = field.unit
	unit.custom_minimum_size = Vector2(150, 0)
	unit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unit.add_theme_color_override("font_color", COLOR_DIM)
	line.add_child(unit)
	_add_paragraph(field.desc, COLOR_DIM, box)
	var ref := _ref_text(value) if field.name != "id" else ""
	if ref != "":
		_add_paragraph("→ " + ref, COLOR_ACCENT, box)
	_add_paragraph("内部名：%s" % field.name, COLOR_FAINT, box)
	return panel

## 辞書の項目：見出しのあとに、キーごとの行を並べる。
func _dict_rows(box: VBoxContainer, res: Resource, cat: Dictionary, field: Dictionary, value: Dictionary) -> void:
	var head := Label.new()
	head.text = field.label
	head.add_theme_font_size_override("font_size", int(_base_size * 1.1))
	box.add_child(head)
	_add_paragraph(field.desc, COLOR_DIM, box)
	if value.is_empty():
		_add_paragraph("（調整する値はない）", COLOR_FAINT, box)
	var docs: Dictionary = cat.consts.get(String(field.name).to_upper() + "_DOCS", {})
	for key in value:
		var d: Array = docs.get(str(key), [])
		var label: String = d[0] if d.size() > 0 else _names.get(str(key), str(key))
		var desc: String = d[1] if d.size() > 1 else ""
		var unit: String = d[2] if d.size() > 2 else ""
		var sub := VBoxContainer.new()
		sub.add_theme_constant_override("separation", 1)
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 22)
		m.add_theme_constant_override("margin_top", 4)
		m.add_child(sub)
		box.add_child(m)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		sub.add_child(line)
		var l := Label.new()
		l.text = "・" + label
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(l)
		var k = key
		line.add_child(_editor_for(value[key], func(v): _save(res, field.name, k, v, "%s：%s" % [field.label, label]), unit))
		var u := Label.new()
		u.text = unit
		u.custom_minimum_size = Vector2(150, 0)
		u.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		u.add_theme_color_override("font_color", COLOR_DIM)
		line.add_child(u)
		_add_paragraph(desc, COLOR_DIM, sub)
		_add_paragraph("内部名：%s.%s" % [field.name, key], COLOR_FAINT, sub)

## 値の型に合わせた入力欄。on_commit は新しい値を受け取る。
func _editor_for(value, on_commit: Callable, unit: String) -> Control:
	var box := HBoxContainer.new()
	box.custom_minimum_size = Vector2(300, 0)
	match typeof(value):
		TYPE_BOOL:
			var cb := CheckButton.new()
			cb.button_pressed = value
			cb.text = "オン" if value else "オフ"
			cb.toggled.connect(func(on: bool):
				cb.text = "オン" if on else "オフ"
				on_commit.call(on))
			box.add_child(cb)
		TYPE_COLOR:
			var cp := ColorPickerButton.new()
			cp.color = value
			cp.custom_minimum_size = Vector2(120, 0)
			cp.popup_closed.connect(func(): on_commit.call(cp.color))
			box.add_child(cp)
			var hex := Label.new()
			hex.text = "#" + Color(value).to_html(false)
			cp.color_changed.connect(func(c: Color): hex.text = "#" + c.to_html(false))
			box.add_child(hex)
		TYPE_ARRAY:
			# 他のデータへの参照の一覧。押すとそのデータを開く
			var flow := HFlowContainer.new()
			flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for v in value:
				var b := Button.new()
				if v is Resource:
					b.text = _item_name(v)
					var r: Resource = v
					b.tooltip_text = "開く：" + r.resource_path.get_file()
					b.pressed.connect(func(): _open_resource(r))
				else:
					b.text = str(v)
					b.disabled = true
				flow.add_child(b)
			box.add_child(flow)
		TYPE_STRING when String(value).length() > 24 or String(value).contains("\n"):
			# 長い文字（説明など）は複数行で全文を見せる
			var te := TextEdit.new()
			te.text = value
			te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			te.scroll_fit_content_height = true
			te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var cur_text := {"v": value}
			te.focus_exited.connect(func():
				if te.text != cur_text.v:
					cur_text.v = te.text
					on_commit.call(te.text))
			box.add_child(te)
		_:
			# 入力欄とボタンで同じ「今の値」を持つ（ラムダは変数を写して持つため、箱に入れる）
			var cur := {"v": value}
			var edit := LineEdit.new()
			edit.text = _to_text(value)
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.select_all_on_focus = true
			var commit := func():
				var parsed = _parse(edit.text, cur.v)
				if parsed == null:
					_set_status("「%s」は読めない値なので戻した" % edit.text, COLOR_ERROR)
					edit.text = _to_text(cur.v)
					return
				if typeof(parsed) == typeof(cur.v) and _to_text(parsed) == _to_text(cur.v):
					return
				cur.v = parsed
				edit.text = _to_text(parsed)
				on_commit.call(parsed)
			edit.text_submitted.connect(func(_t): commit.call())
			edit.focus_exited.connect(commit)
			box.add_child(edit)
			if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
				# 押すだけで少しずつ変えられるボタン
				var is_int := typeof(value) == TYPE_INT
				for step in ([-1, 1] if is_int else [-0.1, 0.1]):
					var b := Button.new()
					b.text = ("%+d" % step) if is_int else ("%+d%%" % roundi(step * 100.0))
					b.tooltip_text = "1 ずつ変える" if is_int else "今の値の 10% ずつ変える"
					var s = step
					b.pressed.connect(func():
						var now = _parse(edit.text, cur.v)
						if now == null:
							now = cur.v
						var next = now + s if is_int else snappedf(now * (1.0 + s), 0.0001)
						if not is_int and now == 0.0:
							next = s
						edit.text = _to_text(next)
						commit.call())
					box.add_child(b)
	return box

## ID を指す値なら、その名前を返す。
func _ref_text(value) -> String:
	if typeof(value) in [TYPE_STRING, TYPE_STRING_NAME] and _names.has(str(value)):
		var n: String = _names[str(value)]
		return n if n != str(value) else ""
	return ""

func _open_resource(r: Resource) -> void:
	for cat in _cats:
		if r in cat.items:
			_select_in_nav(func(m): return m.kind == "item" and m.res == r)
			return

func _select_in_nav(match_meta: Callable) -> void:
	var stack: Array = [_nav.get_root()]
	while not stack.is_empty():
		var it: TreeItem = stack.pop_back()
		var m = it.get_metadata(0)
		if m is Dictionary and match_meta.call(m):
			if it.get_parent() != null:
				it.get_parent().collapsed = false
			it.select(0)
			_nav.scroll_to_item(it)
			return
		for c in it.get_children():
			stack.append(c)

# ── 探す ──────────────────────────────────────────────────────────

func _on_search() -> void:
	var q := _search.text.strip_edges().to_lower()
	if q == "":
		_show_selection()
		return
	_clear_form()
	_add_heading("「%s」を探した結果" % _search.text.strip_edges(), "")
	var hits := 0
	for cat in _cats:
		for res in cat.items:
			var shown := false
			for g in cat.docs.groups:
				for field in g.fields:
					if not _field_matches(field, q, cat, _val(res, field.name)):
						continue
					if not shown:
						var where: String = cat.title if cat.single else "%s：%s" % [cat.title, _item_name(res)]
						_add_group_title(where, "")
						shown = true
					_form.add_child(_field_row(res, cat, field, false))
					hits += 1
	if hits == 0:
		_add_paragraph("見つからなかった。", COLOR_DIM)
	_set_status("%d 件" % hits, COLOR_DIM)

func _field_matches(field: Dictionary, q: String, cat: Dictionary, value) -> bool:
	var text := ("%s %s %s %s" % [field.label, field.desc, field.unit, field.name]).to_lower()
	if text.contains(q):
		return true
	if value is Dictionary:
		var docs: Dictionary = cat.consts.get(String(field.name).to_upper() + "_DOCS", {})
		for key in value:
			var d: Array = docs.get(str(key), [])
			if ("%s %s" % [key, " ".join(d)]).to_lower().contains(q):
				return true
	return false

# ── 全件を比べる表 ────────────────────────────────────────────────

func _show_table(cat: Dictionary) -> void:
	_form_scroll.visible = false
	_table_page.visible = true
	_table_cat = cat
	for c in _table_head.get_children():
		c.queue_free()
	var m := MarginContainer.new()
	for side in ["left", "right", "top"]:
		m.add_theme_constant_override("margin_" + side, 14)
	var head := VBoxContainer.new()
	m.add_child(head)
	_table_head.add_child(m)
	var t := Label.new()
	t.text = cat.title
	t.add_theme_font_size_override("font_size", int(_base_size * 1.6))
	head.add_child(t)
	_add_paragraph(cat.desc, COLOR_DIM, head)
	_add_paragraph("全件を並べて比べる表。セルを押すと直接変えられる。行をダブルクリックすると、その1件を説明つきで開く。列の名前にマウスを乗せると説明が出る。", COLOR_FAINT, head)

	_table.clear()
	_columns.clear()
	var items: Array = cat.items
	for g in cat.docs.groups:
		for field in g.fields:
			if field.name in ["display_name", "description"]:
				continue
			var v = _val(items[0], field.name)
			if v is Dictionary:
				var keys: Array = []
				for r in items:
					for k in _val(r, field.name):
						if not keys.has(k):
							keys.append(k)
				for k in keys:
					_columns.append([field, k])
			else:
				_columns.append([field, null])
	_table.columns = _columns.size() + 1
	_table.set_column_title(0, "名前")
	_table.set_column_expand(0, false)
	var docs_by_field := {}
	for i in _columns.size():
		var field: Dictionary = _columns[i][0]
		var key = _columns[i][1]
		var title: String = field.label
		var tip: String = "%s\n%s\n単位：%s\n内部名：%s" % [field.label, field.desc, field.unit, field.name]
		if key != null:
			if not docs_by_field.has(field.name):
				docs_by_field[field.name] = cat.consts.get(String(field.name).to_upper() + "_DOCS", {})
			var d: Array = docs_by_field[field.name].get(str(key), [])
			title = d[0] if d.size() > 0 else _names.get(str(key), str(key))
			tip = "%s（%s）\n%s\n単位：%s\n内部名：%s.%s" % [title, field.label, d[1] if d.size() > 1 else "",
				d[2] if d.size() > 2 else "", field.name, key]
		_table.set_column_title(i + 1, title)
		_table.set_column_title_tooltip_text(i + 1, tip)
		_table.set_column_expand(i + 1, false)
	var root := _table.create_item()
	for r in items:
		var it := _table.create_item(root)
		it.set_text(0, _item_name(r))
		it.set_metadata(0, r)
		for i in _columns.size():
			var field: Dictionary = _columns[i][0]
			var key = _columns[i][1]
			var v = _val(r, field.name)
			if key != null:
				if v.has(key):
					_set_cell(it, i + 1, v[key])
				else:
					it.set_text(i + 1, "—")
					it.set_tooltip_text(i + 1, "この行にはない値")
			else:
				_set_cell(it, i + 1, v)
	_fit_columns()

func _set_cell(it: TreeItem, col: int, value) -> void:
	match typeof(value):
		TYPE_BOOL:
			it.set_cell_mode(col, TreeItem.CELL_MODE_CHECK)
			it.set_checked(col, bool(value))
			it.set_editable(col, true)
		TYPE_ARRAY:
			var names: Array = []
			for v in value:
				names.append(_item_name(v) if v is Resource else str(v))
			it.set_text(col, ", ".join(names))
			it.set_tooltip_text(col, "1件を開いて変える")
			return
		TYPE_COLOR:
			it.set_text(col, "#" + Color(value).to_html(false))
			it.set_custom_bg_color(col, Color(value).darkened(0.4))
			it.set_editable(col, true)
		_:
			it.set_text(col, _to_text(value))
			it.set_editable(col, true)
	it.set_tooltip_text(col, it.get_text(col))

func _fit_columns() -> void:
	var font := get_theme_default_font()
	for col in _table.columns:
		var w := font.get_string_size(_table.get_column_title(col), HORIZONTAL_ALIGNMENT_LEFT, -1, _base_size).x
		var it := _table.get_root().get_first_child() if _table.get_root() != null else null
		while it != null:
			w = maxf(w, font.get_string_size(it.get_text(col), HORIZONTAL_ALIGNMENT_LEFT, -1, _base_size).x)
			it = it.get_next()
		_table.set_column_custom_minimum_width(col, int(clampf(w + 30.0, 70.0, 360.0)))

func _on_table_edited() -> void:
	var it := _table.get_edited()
	var col := _table.get_edited_column()
	var res: Resource = it.get_metadata(0)
	var field: Dictionary = _columns[col - 1][0]
	var key = _columns[col - 1][1]
	var old = _val(res, field.name) if key == null else _val(res, field.name)[key]
	var value = it.is_checked(col) if typeof(old) == TYPE_BOOL else _parse(it.get_text(col), old)
	if value == null:
		_set_status("「%s」は読めない値なので戻した" % it.get_text(col), COLOR_ERROR)
		it.set_text(col, _to_text(old))
		return
	if typeof(value) != TYPE_BOOL:
		it.set_text(col, _to_text(value))
	_save(res, field.name, key if key != null else "", value, _table.get_column_title(col))

func _on_table_activated() -> void:
	var it := _table.get_selected()
	if it != null:
		_open_resource(it.get_metadata(0))

# ── 保存 ──────────────────────────────────────────────────────────

func _save(res: Resource, prop: String, key, value, label: String) -> void:
	var old_text := ""
	if str(key) == "":
		old_text = _to_text(_val(res, prop))
		res.set(prop, value)
	else:
		var d: Dictionary = _val(res, prop).duplicate()
		old_text = _to_text(d.get(key))
		d[key] = value
		res.set(prop, d)
	var err := ResourceSaver.save(res, res.resource_path)
	if err == OK:
		_set_status("保存した：%s ／ %s　%s → %s" % [_item_name(res), label, old_text, _to_text(value)], COLOR_SAVED)
	else:
		_set_status("保存できなかった（エラー %d）：%s" % [err, res.resource_path], COLOR_ERROR)

func _set_status(text: String, color: Color) -> void:
	_status.text = text
	_status.tooltip_text = text
	_status.add_theme_color_override("font_color", color)

# ── データの読み方 ────────────────────────────────────────────────

## 定義のスクリプトの「##」の説明を読む。
## 戻り値：{"title", "desc", "groups": [{"name", "desc", "fields": [{"name", "label", "desc", "unit"}]}]}
func _parse_docs(script: Script) -> Dictionary:
	var out := {"title": "", "desc": "", "groups": [{"name": "", "desc": "", "fields": []}]}
	var src := FileAccess.get_file_as_string(script.resource_path)
	var buf: Array = []
	var export_re := RegEx.create_from_string("^@export(?:_\\w+)?(?:\\([^)]*\\))?\\s+var\\s+(\\w+)")
	var group_re := RegEx.create_from_string("^@export_group\\(\"([^\"]*)\"")
	for raw in src.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("##"):
			buf.append(line.substr(2).strip_edges())
			continue
		if line.begins_with("class_name"):
			var lines: Array = []
			for b in buf:
				if b == "---":
					break
				lines.append(b)
			if not lines.is_empty():
				out.title = lines[0]
				out.desc = "\n".join(lines.slice(1)).strip_edges()
		else:
			var gm := group_re.search(line)
			if gm != null:
				out.groups.append({"name": gm.get_string(1), "desc": " ".join(buf), "fields": []})
			else:
				var em := export_re.search(line)
				if em != null:
					out.groups[-1].fields.append(_field_doc(em.get_string(1), buf))
		buf = []
	return out

func _field_doc(prop: String, lines: Array) -> Dictionary:
	var f := {"name": prop, "label": prop, "desc": "", "unit": ""}
	var desc: Array = []
	for i in lines.size():
		var l: String = lines[i]
		if i == 0:
			f.label = l
		elif l.begins_with("単位："):
			f.unit = l.substr(3).strip_edges()
		else:
			desc.append(l)
	f.desc = "\n".join(desc)
	return f

func _val(res: Resource, prop: String):
	return res.get(prop)

func _item_name(r: Resource) -> String:
	var n = _val(r, "display_name")
	if n != null and str(n) != "":
		return str(n)
	return r.resource_path.get_file().get_basename()

func _item_label(r: Resource) -> String:
	var n := _item_name(r)
	var id = _val(r, "id")
	if id != null and str(id) != "" and str(id) != n:
		return "%s（%s）" % [n, id]
	return n

func _item_less(a: Resource, b: Resource) -> bool:
	for key in ["order", "index", "start"]:
		var va = _val(a, key)
		var vb = _val(b, key)
		if va != null and vb != null and va != vb:
			return va < vb
	return a.resource_path < b.resource_path

func _to_text(value) -> String:
	if value is PackedInt32Array or value is PackedFloat32Array or value is Array:
		return ", ".join(Array(value).map(func(v): return str(v)))
	if value is Color:
		return "#" + value.to_html(false)
	return str(value)

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
			if text.begins_with("#") and Color.html_is_valid(text):
				return text
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
		TYPE_ARRAY:
			var arr: Array = []
			for part in text.split(",", false):
				var p := part.strip_edges()
				if p.is_valid_float():
					arr.append(float(p))
				else:
					return null
			return arr
	return null
