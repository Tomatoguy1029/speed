## インスペクターで、敵の種類の一覧（type ID の配列）をチェックボックスで選べるようにする。
##   ステージの敵（enemies）：プロジェクト設定 spawn_timeline/enemy_dir にある、すべての敵から選ぶ
##   出現のクリップの種類の組み合わせ（types）：出現タイムラインで開いているステージの敵から選ぶ
##   敵の組み合わせのシーンの置ける種類（types）：すべての敵から選ぶ
##   出現のクリップの使う並び（layouts）：クリップのフォーメーションの配置から選ぶ（「ファイル名/配置のノード名」）
## この道具は Godot 本体だけに依存する（設計書 4.1）。中身はプロパティ名で読み書きする。
@tool
extends EditorInspectorPlugin

## 敵の定義を置いたフォルダを書くプロジェクト設定
const SETTING_ENEMIES := "spawn_timeline/enemy_dir"

## 出現タイムラインのパネル（開いているステージを持つ）
var timeline

func _can_handle(object: Object) -> bool:
	return object != null and (object.get("types") is Array or object.get("enemies") is Array or object.get("layouts") is Array)

func _parse_property(object: Object, _type: Variant.Type, name: String, _hint_type: PropertyHint, _hint_string: String,
		_usage_flags: int, _wide: bool) -> bool:
	if name == "enemies" and object.get("clips") != null:
		# 敵の数が多いので、初めは折りたたむ
		add_property_editor(name, Checks.new(_all_enemies(), true))
		return true
	if name == "enemy_attack_values" and object.get("clips") != null:
		add_property_editor(name, EnemyValues.new(func() -> Array:
			var options := []
			var ids: Array = object.get("enemies").duplicate()
			for id in object.get("enemy_attack_values"):
				if not ids.has(StringName(id)):
					ids.append(StringName(id))
			for id in ids:
				options.append([StringName(id), _display_name(StringName(id))])
			return options), false, "Enemy attack values")
		return true
	if name == "formation_values" and object.get("formations") != null:
		# 辞書はFormationsのoverride欄で編集する。保存名は互換性のため維持する。
		return true
	if name == "layouts" and object.get("formations") != null:
		# フォーメーションを足したり、シーンの配置を変えたりしたら、選べる並びも変わる
		var clip := object
		add_property_editor(name, Checks.new([], false, func() -> Array: return _layout_options(clip), "すべての並びを使う", "個の並びを使う", "formation_values"), false, "Formations")
		return true
	if name == "formations" and object.get("groups") != null:
		add_property_editor(name, Assets.new(), false, "Spawn assets")
		return true
	if name == "groups" and object.get("formations") != null:
		add_property_editor(name, IntegerField.new(), false, "Group counts")
		return true
	if name == "types":
		var options := _all_enemies()
		# クリップは、開いているステージの敵の中から選ぶ
		if object.get("formations") != null and timeline != null and timeline.stage != null:
			var stage_enemies: Array = timeline.stage.get("enemies")
			if not stage_enemies.is_empty():
				options = []
				for id in stage_enemies:
					options.append([StringName(id), _display_name(StringName(id))])
		add_property_editor(name, Checks.new(options, false))
		return true
	return false

## フォーメーションのシーンのパス → [変更の時刻, to_dataの配置一覧]
var _layout_cache: Dictionary = {}

## クリップのフォーメーションの配置：[[「ファイル名/配置の名前」, 表示名], …]。配置は、置き場所（markers）を持つ子のノード。
func _layout_options(clip: Object) -> Array:
	var out := []
	var scenes = clip.get("formations")
	if scenes == null:
		return out
	for scene in scenes:
		if not scene is PackedScene or scene.resource_path == "":
			continue
		var path: String = scene.resource_path
		var stamp := FileAccess.get_modified_time(path)
		if not _layout_cache.has(path) or _layout_cache[path][0] != stamp:
			var layouts := []
			var root := (scene as PackedScene).instantiate()
			if root.has_method("to_data"):
				layouts = root.to_data().get("layouts", [])
			root.free()
			_layout_cache[path] = [stamp, layouts]
		var base := path.get_file().get_basename()
		for layout: Dictionary in _layout_cache[path][1]:
			var n := str(layout.name)
			var stage: Resource = timeline.stage if timeline != null else null
			var total: float = clip.automatic_value(stage, layout) if stage != null else -1.0
			out.append([StringName(base + "/" + n), "%s：%s" % [base, n], total])
	return out

## すべての敵：[[type ID, 表示名], …]
func _all_enemies() -> Array:
	var out := []
	var dir := str(ProjectSettings.get_setting(SETTING_ENEMIES, ""))
	if dir == "":
		return out
	var files := DirAccess.get_files_at(dir)
	files.sort()
	for f in files:
		if f.ends_with(".tres"):
			var id := StringName(f.get_basename())
			out.append([id, _display_name(id)])
	return out

func _display_name(id: StringName) -> String:
	var dir := str(ProjectSettings.get_setting(SETTING_ENEMIES, ""))
	var path := dir.path_join(String(id) + ".tres")
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	var shown := str(res.get("display_name")) if res != null and res.get("display_name") != null else ""
	return "%s（%s）" % [shown, id] if shown != "" else String(id)

## 名前（type ID・並びの名前）の配列を、チェックボックスの並びで編集する。見出しのボタンで折りたためる（開閉はプロパティごとに覚える）。
## source を渡すと、表示を更新するたびに選べるものを読み直す。
class Checks extends EditorProperty:
	## プロパティ名 → 開いているか
	static var _open: Dictionary = {}
	var _options: Array
	var _boxes: Array[CheckBox] = []
	var _numbers: Array[SpinBox] = []
	var _overrides: Array[CheckBox] = []
	var _totals: Array[Label] = []
	var _values_property := ""
	var _updating := false
	var _toggle: Button
	var _grid: GridContainer
	var _folded_default := false
	var _source: Callable
	## 何も選んでいないときの見出しと、選んだ数につける言葉
	var _none_text := ""
	var _unit := "種類を選択中"
	var _refresh_left := 0.0

	func _process(dt: float) -> void:
		# 他のインスペクターで編集したstage値と保存した配置にも追従する。
		_refresh_left -= dt
		if _values_property != "" and _refresh_left <= 0.0 and get_edited_object() != null:
			_refresh_left = 0.5
			if _source.is_valid() and _source.call() != _options:
				_update_property()

	func _init(options: Array, folded: bool, source := Callable(), none_text := "", unit := "種類を選択中", values_property := "") -> void:
		_folded_default = folded
		_source = source
		_none_text = none_text
		_unit = unit
		_values_property = values_property
		_toggle = Button.new()
		_toggle.flat = true
		_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_toggle.pressed.connect(_on_fold)
		add_child(_toggle)
		add_focusable(_toggle)
		_grid = GridContainer.new()
		_grid.columns = 2
		add_child(_grid)
		set_bottom_editor(_grid)
		_set_options(options)

	func _set_options(options: Array) -> void:
		_options = options
		for child in _grid.get_children():
			_grid.remove_child(child)
			child.queue_free()
		_boxes.clear()
		_numbers.clear()
		_overrides.clear()
		_totals.clear()
		var table := _values_property != ""
		_grid.columns = 4 if table else 2
		if table:
			_grid.add_theme_constant_override("h_separation", 0)
			_grid.add_theme_constant_override("v_separation", 0)
			for title in ["使用", "並び", "Auto", "Override"]:
				var heading := Label.new()
				heading.text = title
				heading.tooltip_text = "Auto：個体valueの合計。Override：群れ全体が共有するvalue。"
				_table_cell(heading, -1)
		for k in options.size():
			var opt: Array = options[k]
			var box := CheckBox.new()
			box.toggled.connect(_on_toggled)
			_boxes.append(box)
			if not table:
				box.text = str(opt[1])
				_grid.add_child(box)
				continue
			box.tooltip_text = "この並びを使用する"
			box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_table_cell(box, k)
			var label := Label.new()
			label.text = str(opt[1])
			label.tooltip_text = label.text
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			_table_cell(label, k, true)
			var total := Label.new()
			total.text = str(opt[2]) if float(opt[2]) >= 0.0 else "ステージを開く"
			total.tooltip_text = "選んだ種類のvalue × この配置の体数。使用OFFの並びも比較用に表示する。"
			_table_cell(total, k)
			_totals.append(total)
			var shared := HBoxContainer.new()
			var override := CheckBox.new()
			override.tooltip_text = "ON：群れが指定valueを1回分共有。OFF：各個体がstageのvalueを消費。保存済みのvalueはON。"
			override.toggled.connect(_on_override_toggled.bind(str(opt[0]), float(opt[2])))
			shared.add_child(override)
			_overrides.append(override)
			var number := SpinBox.new()
			number.min_value = 0.001
			number.max_value = 2147483647
			number.step = 0.5
			number.alignment = HORIZONTAL_ALIGNMENT_RIGHT
			number.custom_minimum_size.x = 72 * EditorInterface.get_editor_scale()
			number.tooltip_text = "群れ全体が共有する正のvalue（0.5刻みで調整）"
			number.value_changed.connect(_on_value_changed.bind(str(opt[0])))
			shared.add_child(number)
			_table_cell(shared, k)
			_numbers.append(number)

	func _table_cell(control: Control, row: int, expand := false) -> void:
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_FILL
		var style := StyleBoxFlat.new()
		var base := EditorInterface.get_base_control().get_theme_color("base_color", "Editor")
		style.bg_color = base.darkened(0.15 if row < 0 else (0.04 if row % 2 == 0 else 0.1))
		style.border_color = base.lightened(0.16)
		style.border_width_bottom = 1
		var ui := EditorInterface.get_editor_scale()
		style.content_margin_left = 6 * ui
		style.content_margin_right = 6 * ui
		style.content_margin_top = 3 * ui
		style.content_margin_bottom = 3 * ui
		cell.add_theme_stylebox_override("panel", style)
		cell.add_child(control)
		_grid.add_child(cell)

	func _update_property() -> void:
		if _source.is_valid():
			var options: Array = _source.call()
			if options != _options:
				_set_options(options)
		var current := _current()
		_updating = true
		var values: Dictionary = get_edited_object().get(_values_property) if _values_property != "" else {}
		for k in _options.size():
			_boxes[k].set_pressed_no_signal(current.has(_options[k][0]) or (_values_property != "" and current.is_empty()))
			if _values_property != "":
				var key := String(_options[k][0])
				var overridden := values.has(key)
				_overrides[k].set_pressed_no_signal(overridden)
				_numbers[k].editable = overridden
				_numbers[k].set_value_no_signal(float(values.get(key, maxf(0.5, float(_options[k][2])))))
				_totals[k].modulate.a = 1.0 if _boxes[k].button_pressed else 0.45
		_updating = false
		_show_fold(current.size())

	func _is_open() -> bool:
		return bool(_open.get(get_edited_property(), not _folded_default))

	func _on_fold() -> void:
		_open[get_edited_property()] = not _is_open()
		_show_fold(_current().size())

	## 今の値（エディターでまだ値がなければ空）。
	func _current() -> Array:
		var value = get_edited_object().get(get_edited_property())
		return value if value is Array else []

	func _show_fold(chosen: int) -> void:
		_grid.visible = _is_open()
		set_bottom_editor(_grid if _is_open() else null)
		update_minimum_size()
		queue_sort()
		queue_redraw()
		var arrow := "▼" if _is_open() else "▶"
		_toggle.text = "%s %s" % [arrow, _none_text] if chosen == 0 and _none_text != "" else "%s %d%s" % [arrow, chosen, _unit]

	func _on_toggled(_pressed: bool) -> void:
		if _updating:
			return
		var value: Array[StringName] = []
		for k in _options.size():
			if _boxes[k].button_pressed:
				value.append(StringName(_options[k][0]))
		if _values_property != "" and value.is_empty() and not _options.is_empty():
			_update_property()
			return
		emit_changed(get_edited_property(), value)

	func _on_value_changed(value: float, key: String) -> void:
		if _updating:
			return
		var values: Dictionary = get_edited_object().get(_values_property).duplicate()
		if not values.has(key) or is_equal_approx(value, float(values[key])):
			return
		values[key] = value
		emit_changed(_values_property, values)

	func _on_override_toggled(pressed: bool, key: String, automatic: float) -> void:
		if _updating:
			return
		var values: Dictionary = get_edited_object().get(_values_property).duplicate()
		if pressed:
			values[key] = maxf(0.5, automatic)
		else:
			values.erase(key)
		emit_changed(_values_property, values)

## ステージの敵typeごとの個体value。辞書を複製して通知し、通常のUndo/Redoに載せる。
class EnemyValues extends EditorProperty:
	var _source: Callable
	var _options: Array = []
	var _rows := VBoxContainer.new()
	var _numbers: Array[SpinBox] = []
	var _defaults: Array[Label] = []

	func _init(source: Callable) -> void:
		_source = source
		add_child(_rows)
		set_bottom_editor(_rows)

	func _update_property() -> void:
		var options: Array = _source.call()
		if options != _options:
			_options = options
			for child in _rows.get_children():
				_rows.remove_child(child)
				child.queue_free()
			_numbers.clear()
			_defaults.clear()
			for option: Array in options:
				var row := HBoxContainer.new()
				var label := Label.new()
				label.text = str(option[1])
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				label.tooltip_text = label.text
				row.add_child(label)
				var fallback := Label.new()
				fallback.text = "仮値"
				fallback.tooltip_text = "未設定の互換用valueは1。種類別のバランスが確定したら入力する。"
				row.add_child(fallback)
				_defaults.append(fallback)
				var number := SpinBox.new()
				number.min_value = 0.001
				number.max_value = 2147483647
				number.step = 0.5
				number.value_changed.connect(_on_value_changed.bind(str(option[0])))
				row.add_child(number)
				_numbers.append(number)
				_rows.add_child(row)
		var values: Dictionary = get_edited_object().get(get_edited_property())
		for k in _options.size():
			var key := str(_options[k][0])
			_numbers[k].set_value_no_signal(float(values.get(key, 1.0)))
			_defaults[k].visible = not values.has(key)

	func _on_value_changed(value: float, key: String) -> void:
		var values: Dictionary = get_edited_object().get(get_edited_property()).duplicate()
		values[key] = value
		emit_changed(get_edited_property(), values)

## シーンの参照は、群れの選択と別の欄で編集する。
class Assets extends EditorProperty:
	static var _open := false
	var _toggle := Button.new()
	var _body := VBoxContainer.new()
	var _rows := VBoxContainer.new()
	var _scenes: Array = []
	func _init() -> void:
		_toggle.flat = true
		_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_toggle.pressed.connect(_on_fold)
		add_child(_toggle)
		add_focusable(_toggle)
		add_child(_body)
		_body.add_child(_rows)
		var add := Button.new()
		add.text = "＋ Spawn asset"
		add.pressed.connect(func() -> void:
			var value: Array[PackedScene] = []
			value.assign(get_edited_object().get(get_edited_property()))
			value.append(null)
			emit_changed(get_edited_property(), value))
		_body.add_child(add)
		add_focusable(add)
		_show_fold()
	func _on_fold() -> void:
		_open = not _open
		_show_fold()
	func _show_fold() -> void:
		_toggle.text = "%s %d個のシーン" % ["▼" if _open else "▶", _scenes.size()]
		_body.visible = _open
		set_bottom_editor(_body if _open else null)
		update_minimum_size()
		queue_sort()
		queue_redraw()
	func _update_property() -> void:
		var current: Array = get_edited_object().get(get_edited_property())
		if current == _scenes:
			_show_fold()
			return
		_scenes = current.duplicate()
		for child in _rows.get_children():
			_rows.remove_child(child)
			child.queue_free()
		for k in current.size():
			var row := HBoxContainer.new()
			var picker := EditorResourcePicker.new()
			picker.base_type = "PackedScene"
			picker.edited_resource = current[k]
			picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			picker.resource_changed.connect(_replace.bind(k))
			picker.resource_selected.connect(func(resource: Resource, _inspect: bool) -> void:
				if resource != null and resource.resource_path != "":
					EditorInterface.open_scene_from_path(resource.resource_path))
			row.add_child(picker)
			var remove := Button.new()
			remove.text = "−"
			remove.tooltip_text = "シーンの登録を外す"
			remove.pressed.connect(_remove.bind(k))
			row.add_child(remove)
			_rows.add_child(row)
		_show_fold()
	func _replace(resource: Resource, index: int) -> void:
		var value: Array[PackedScene] = []
		value.assign(get_edited_object().get(get_edited_property()))
		value[index] = resource as PackedScene
		emit_changed(get_edited_property(), value)
	func _remove(index: int) -> void:
		var value: Array[PackedScene] = []
		value.assign(get_edited_object().get(get_edited_property()))
		value.remove_at(index)
		emit_changed(get_edited_property(), value)

class IntegerField extends EditorProperty:
	var _number := SpinBox.new()
	func _init() -> void:
		_number.min_value = 1
		_number.max_value = 2147483647
		_number.step = 1
		_number.rounded = true
		add_child(_number)
		add_focusable(_number.get_line_edit())
		_number.value_changed.connect(func(value: float) -> void: emit_changed(get_edited_property(), int(value)))
	func _update_property() -> void:
		_number.set_value_no_signal(int(get_edited_object().get(get_edited_property())))
