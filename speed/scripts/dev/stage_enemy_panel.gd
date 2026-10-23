## エディターdockとプレイ中の両方で使う、ステージだけの敵調整。
@tool
extends VBoxContainer

const IO := preload("res://scripts/dev/stage_enemy_edit.gd")
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
var _enemy_picker: OptionButton
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
	_stage_picker = OptionButton.new()
	_stage_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_stage_picker)
	for file in DirAccess.get_files_at("res://data/stages"):
		if not file.ends_with(".tres"): continue
		_stages.append("res://data/stages/" + file)
		_stage_picker.add_item(file.trim_suffix(".tres"))
	_stage_picker.item_selected.connect(func(index): open_stage(_stages[index]))
	var note := Label.new()
	note.text = "共通値 → ステージ上書き（変更した項目だけ保存）\nHPは標準サイズ。XP・成長・武器は共通設定。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	_enemy_search = LineEdit.new()
	_enemy_search.placeholder_text = "敵を検索（名前 / ID）"
	_enemy_search.text_changed.connect(func(_text): _refresh_enemies())
	add_child(_enemy_search)
	_enemy_picker = OptionButton.new()
	_enemy_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_picker.item_selected.connect(func(index): _select_enemy(_ids[index]))
	add_child(_enemy_picker)
	_search = LineEdit.new()
	_search.placeholder_text = "数値項目を検索（射程、間隔、damage…）"
	_search.text_changed.connect(func(_text): _refresh_rows())
	add_child(_search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	var actions := HFlowContainer.new()
	add_child(actions)
	_save_button = _button(actions, "Save", _save)
	_button(actions, "再読込・試行を破棄", reload_stage)
	_reset_enemy = _button(actions, "この敵を共通値へ", func():
		values.erase(_id)
		_changed()
		_refresh_rows())
	_button(actions, "全敵を共通値へ", func():
		values.clear()
		_changed()
		_refresh_rows())
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	if not stage_path.is_empty(): open_stage(stage_path)
	elif not _stages.is_empty(): open_stage(_stages[0])

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
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
	_stage_picker.select(_stages.find(stage_path))
	_refresh_enemies()
	_changed()

func bind_run(stage: StageDef, cfg: GameConfig, tuning: Dictionary) -> void:
	_live = true
	_cfg = cfg
	open_stage("res://data/stages/stage_%d.tres" % stage.index)
	values = tuning.duplicate(true)
	_stage_picker.disabled = true
	_refresh_rows()
	_changed()

func _refresh_enemies() -> void:
	_ids.clear()
	_enemy_picker.clear()
	# 全ての定義を選べるので、分裂体・部位・増援も同じ編集経路で扱える。
	for file in DirAccess.get_files_at("res://data/enemies"):
		if not file.ends_with(".tres"): continue
		var id := file.trim_suffix(".tres")
		var base := IO.definition(id)
		if base == null: continue
		var name := "%s / %s" % [base.display_name, id]
		if not _enemy_search.text.is_empty() and not name.to_lower().contains(_enemy_search.text.to_lower()): continue
		_ids.append(id)
		_enemy_picker.add_item(name)
	if _ids.is_empty():
		_id = ""
		_enemy = null
		_refresh_rows()
		return
	var index := maxi(0, _ids.find(_id))
	_enemy_picker.select(index)
	_select_enemy(_ids[index])

func _select_enemy(id: String) -> void:
	_id = id
	_enemy_picker.select(_ids.find(id))
	_enemy = IO.definition(id)
	_refresh_rows()

func _refresh_rows() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_row_controls.clear()
	_reset_enemy.disabled = _id.is_empty() or not values.has(_id)
	if _enemy == null or _cfg == null: return
	for key in StageEnemyTuning.keys_for(_enemy):
		var title := StageEnemyTuning.label(key)
		if not _search.text.is_empty() and not (title + key).to_lower().contains(_search.text.to_lower()): continue
		var base := StageEnemyTuning.base_value(_enemy, key, _cfg)
		var column := VBoxContainer.new()
		_rows.add_child(column)
		var label := Label.new()
		label.text = title
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if key.begins_with("params."):
			var docs: Array = EnemyDef.PARAMS_DOCS.get(key.trim_prefix("params."), [])
			if docs.size() >= 3: label.tooltip_text = "%s\n単位: %s" % [docs[1], docs[2]]
		column.add_child(label)
		var row := HBoxContainer.new()
		column.add_child(row)
		var common := Label.new()
		common.text = "共通 %s →" % String.num(base, 4)
		row.add_child(common)
		var spin := SpinBox.new()
		spin.min_value = minf(base, StageEnemyTuning.minimum(key))
		spin.max_value = maxf(base, 100000.0)
		spin.step = 1.0 if key.begins_with("params.") and _enemy.params[key.trim_prefix("params.")] is int else 0.01
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value = float(values.get(_id, {}).get(key, base))
		row.add_child(spin)
		var reset := _button(row, "↶", _reset_key.bind(key, spin, base))
		reset.tooltip_text = "この項目の上書きを外して共通値を使う"
		var difference := Label.new()
		column.add_child(difference)
		_row_controls[key] = [difference, reset]
		_refresh_difference(key, spin.value, base)
		spin.value_changed.connect(_edit_value.bind(key, base))

func _refresh_difference(key: String, value: float, base: float) -> void:
	var overridden: bool = values.get(_id, {}).has(key)
	_row_controls[key][0].text = "ステージ差分 %+.4f" % (value - base) if overridden else "共通値を使用"
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
	_reset_enemy.disabled = not values.has(_id)
	_status.text = "%s\n%s%s" % [stage_path, "未保存の試行" if is_dirty() else "保存済みの設定", "。固有値は行動が次に参照するときから反映。発射済み攻撃・生成済みの配置は維持。" if _live else ""]
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
	_status.text += "\n保存・実行用データの生成完了。" if error == OK else "\n保存済み。実行用データの生成に失敗: %s" % error_string(error)
