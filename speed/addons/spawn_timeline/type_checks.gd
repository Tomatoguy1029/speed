## インスペクターで、敵の種類の一覧（type ID の配列）をチェックボックスで選べるようにする。
##   ステージの敵（enemies）：プロジェクト設定 spawn_timeline/enemy_dir にある、すべての敵から選ぶ
##   出現のクリップの種類の組み合わせ（types）：出現タイムラインで開いているステージの敵から選ぶ
##   敵の組み合わせのシーンの置ける種類（types）：すべての敵から選ぶ
## この道具は Godot 本体だけに依存する（設計書 4.1）。中身はプロパティ名で読み書きする。
@tool
extends EditorInspectorPlugin

## 敵の定義を置いたフォルダを書くプロジェクト設定
const SETTING_ENEMIES := "spawn_timeline/enemy_dir"

## 出現タイムラインのパネル（開いているステージを持つ）
var timeline

func _can_handle(object: Object) -> bool:
	return object != null and (object.get("types") is Array or object.get("enemies") is Array)

func _parse_property(object: Object, _type: Variant.Type, name: String, _hint_type: PropertyHint, _hint_string: String,
		_usage_flags: int, _wide: bool) -> bool:
	if name == "enemies" and object.get("clips") != null:
		# 敵の数が多いので、初めは折りたたむ
		add_property_editor(name, Checks.new(_all_enemies(), true))
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

## type ID の配列を、チェックボックスの並びで編集する。見出しのボタンで折りたためる（開閉はプロパティごとに覚える）。
class Checks extends EditorProperty:
	## プロパティ名 → 開いているか
	static var _open: Dictionary = {}
	var _options: Array
	var _boxes: Array[CheckBox] = []
	var _updating := false
	var _toggle: Button
	var _grid: GridContainer
	var _folded_default := false

	func _init(options: Array, folded: bool) -> void:
		_options = options
		_folded_default = folded
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
		var grid := _grid
		for opt in options:
			var box := CheckBox.new()
			box.text = str(opt[1])
			box.toggled.connect(_on_toggled)
			grid.add_child(box)
			_boxes.append(box)

	func _update_property() -> void:
		var current: Array = get_edited_object().get(get_edited_property())
		_updating = true
		for k in _options.size():
			_boxes[k].button_pressed = current.has(_options[k][0])
		_updating = false
		_show_fold(current.size())

	func _is_open() -> bool:
		return bool(_open.get(get_edited_property(), not _folded_default))

	func _on_fold() -> void:
		_open[get_edited_property()] = not _is_open()
		var current: Array = get_edited_object().get(get_edited_property())
		_show_fold(current.size())

	func _show_fold(chosen: int) -> void:
		_grid.visible = _is_open()
		_toggle.text = "%s %d種類を選択中" % ["▼" if _is_open() else "▶", chosen]

	func _on_toggled(_pressed: bool) -> void:
		if _updating:
			return
		var value: Array[StringName] = []
		for k in _options.size():
			if _boxes[k].button_pressed:
				value.append(StringName(_options[k][0]))
		emit_changed(get_edited_property(), value)
