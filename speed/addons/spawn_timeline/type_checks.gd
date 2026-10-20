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

## フォーメーションのシーンのパス → [変更の時刻, その配置の名前の並び]
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
			var names := []
			var root := (scene as PackedScene).instantiate()
			for child in root.get_children():
				if child.has_method("markers"):
					names.append(String(child.name))
			root.free()
			_layout_cache[path] = [stamp, names]
		var base := path.get_file().get_basename()
		for n in _layout_cache[path][1]:
			out.append([StringName(base + "/" + n), "%s：%s" % [base, n]])
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
	var _values_property := ""
	var _updating := false
	var _toggle: Button
	var _grid: GridContainer
	var _folded_default := false
	var _source: Callable
	## 何も選んでいないときの見出しと、選んだ数につける言葉
	var _none_text := ""
	var _unit := "種類を選択中"

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
		for box in _boxes:
			_grid.remove_child(box)
			box.queue_free()
		_boxes.clear()
		for number in _numbers:
			_grid.remove_child(number)
			number.queue_free()
		_numbers.clear()
		for opt in options:
			var box := CheckBox.new()
			box.text = str(opt[1])
			box.toggled.connect(_on_toggled)
			_grid.add_child(box)
			_boxes.append(box)
			if _values_property != "":
				var number := SpinBox.new()
				number.prefix = "value"
				number.min_value = 1
				number.max_value = 2147483647
				number.step = 1
				number.rounded = true
				number.custom_minimum_size.x = 110 * EditorInterface.get_editor_scale()
				number.value_changed.connect(_on_value_changed.bind(String(opt[0])))
				_grid.add_child(number)
				_numbers.append(number)

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
				_numbers[k].set_value_no_signal(maxi(1, int(values.get(String(_options[k][0]), 1))))
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
		values[key] = maxi(1, int(value))
		emit_changed(_values_property, values)

## シーンの参照は、群れの選択と別の欄で編集する。
class Assets extends EditorProperty:
	var _body := VBoxContainer.new()
	var _scenes: Array = []
	func _init() -> void:
		var add := Button.new()
		add.text = "＋ Spawn asset"
		add.pressed.connect(func() -> void:
			var value: Array[PackedScene] = []
			value.assign(get_edited_object().get(get_edited_property()))
			value.append(null)
			emit_changed(get_edited_property(), value))
		add_child(add)
		add_focusable(add)
		add_child(_body)
		set_bottom_editor(_body)
	func _update_property() -> void:
		var current: Array = get_edited_object().get(get_edited_property())
		if current == _scenes:
			return
		_scenes = current.duplicate()
		for child in _body.get_children():
			_body.remove_child(child)
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
			_body.add_child(row)
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
