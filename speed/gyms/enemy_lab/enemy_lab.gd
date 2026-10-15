## デバッグ専用の敵・ルート実験場。
extends Control

const SESSION := preload("res://gyms/enemy_lab/lab_session.gd")
const CANVAS := preload("res://gyms/enemy_lab/lab_canvas.gd")
const INSPECTOR := preload("res://gyms/enemy_lab/lab_inspector.gd")

var session
var canvas
var inspector
var _palette: VBoxContainer
var _filter: LineEdit
var _status: Label
var _result: Label
var _seek: HSlider
var _play: Button
var _seed: SpinBox
var _stage: OptionButton
var _empty: CheckButton
var _auto: CheckButton
var _count: SpinBox
var _level: SpinBox
var _updating := false
var _scrubbing := false
var _busy := false
var _branch: OptionButton
var _left: Control
var _right: Control
var _messages: Label

func _ready() -> void:
	if not OS.is_debug_build():
		GameManager.reset_to_main_menu()
		return
	theme = Theme.new()
	theme.default_font_size = 15
	session = SESSION.new()
	add_child(session)
	_build_ui()
	session.changed.connect(_refresh)
	session.seek_progress.connect(func(v): _messages.text = "再構築中 %d%%" % roundi(v * 100))
	await session.reset()
	_refresh()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label

func _spin(parent: Node, minimum: float, maximum: float, value: float) -> SpinBox:
	var box := SpinBox.new()
	box.min_value = minimum
	box.max_value = maximum
	box.value = value
	parent.add_child(box)
	return box

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#101825")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	add_child(margin)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var top := HFlowContainer.new()
	layout.add_child(top)
	_button(top, "戻る", func(): GameManager.reset_to_main_menu())
	_label(top, "敵・ルート実験場")
	_label(top, "Seed")
	_seed = _spin(top, 0, 2147483647, 932)
	_stage = OptionButton.new()
	for n in range(1, ConfigManager.stage_count() + 1):
		_stage.add_item("ステージ %d" % n, n)
	top.add_child(_stage)
	_empty = CheckButton.new()
	_empty.text = "空のフィールド"
	_empty.button_pressed = true
	top.add_child(_empty)
	_auto = CheckButton.new()
	_auto.text = "通常の自動出現"
	top.add_child(_auto)
	_button(top, "新しい実験", _reset)
	var toolbar := HFlowContainer.new()
	layout.add_child(toolbar)
	_play = _button(toolbar, "▶ 再生", _toggle_play)
	_button(toolbar, "❚❚ 停止", func(): session.playing = false)
	_button(toolbar, "1コマ", func(): session.playing = false; session.step(); _refresh())
	_button(toolbar, "開始へ", func(): await session.seek(0); _refresh())
	var speeds := OptionButton.new()
	for value in [0.25, 0.5, 1.0, 2.0, 4.0]:
		speeds.add_item("×%s" % value)
	speeds.selected = 2
	speeds.item_selected.connect(func(i): session.speed = [0.25, 0.5, 1.0, 2.0, 4.0][i])
	toolbar.add_child(speeds)
	for item in [["選択・移動", 0], ["敵を配置", 1], ["線を編集", 2], ["自機で試遊", 3]]:
		_button(toolbar, item[0], _set_mode.bind(item[1]))
	_button(toolbar, "線を消す", func(): canvas.route.clear(); canvas.result.clear(); canvas.queue_redraw())
	_button(toolbar, "線の結果を確認", _evaluate)
	_button(toolbar, "敵を消す", func(): session.perform("clear"))
	var ranges := CheckButton.new()
	ranges.text = "攻撃範囲"
	ranges.button_pressed = true
	ranges.toggled.connect(func(on): canvas.show_ranges = on)
	toolbar.add_child(ranges)
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(middle)
	_left = VBoxContainer.new()
	_left.custom_minimum_size.x = 210
	middle.add_child(_left)
	_filter = LineEdit.new()
	_filter.placeholder_text = "敵の名前・IDで検索"
	_filter.text_changed.connect(func(_v): _fill_palette())
	_left.add_child(_filter)
	var row := HBoxContainer.new()
	_left.add_child(row)
	_label(row, "数")
	_count = _spin(row, 1, 10000, 1)
	_label(row, "Lv")
	_level = _spin(row, 1, 100, 1)
	_count.value_changed.connect(func(v): canvas.spawn_count = int(v))
	_level.value_changed.connect(func(v): canvas.spawn_level = v)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left.add_child(scroll)
	_palette = VBoxContainer.new()
	_palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_palette)
	canvas = CANVAS.new()
	canvas.session = session
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(canvas)
	_right = VBoxContainer.new()
	middle.add_child(_right)
	inspector = INSPECTOR.new()
	inspector.session = session
	inspector.canvas = canvas
	inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right.add_child(inspector)
	canvas.picked.connect(func(_i): inspector.refresh(true))
	canvas.route_edited.connect(func(): _result.text = "編集中：線の結果を確認してください")
	var bottom := HBoxContainer.new()
	layout.add_child(bottom)
	_button(bottom, "敵パレット", func(): _left.visible = not _left.visible)
	_button(bottom, "情報パネル", func(): _right.visible = not _right.visible)
	_status = _label(bottom, "")
	_branch = OptionButton.new()
	bottom.add_child(_branch)
	_branch.item_selected.connect(_select_branch)
	_seek = HSlider.new()
	_seek.min_value = 0
	_seek.max_value = 1
	_seek.step = 1
	_seek.custom_minimum_size.y = 24
	layout.add_child(_seek)
	_seek.drag_started.connect(func(): session.playing = false; _scrubbing = true)
	_seek.drag_ended.connect(func(_change): _scrubbing = false; await session.seek(roundi(_seek.value)); _refresh())
	_result = _label(layout, "線編集：クリックで点を追加、点をドラッグ、右クリックで最後の点を削除")
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_messages = _label(layout, "中ボタン：移動　ホイール：拡大縮小　配置してから再生してください")
	_fill_palette()

func _fill_palette() -> void:
	for child in _palette.get_children():
		child.queue_free()
	var filter := _filter.text.to_lower()
	var definitions := ConfigManager.sorted(ConfigManager.enemies)
	definitions.append_array(ConfigManager.sorted(ConfigManager.bosses))
	for def in definitions:
		if def is EnemyDef and def.behavior == &"part":
			continue
		var name: String = def.display_name
		var id := String(def.id)
		if not filter.is_empty() and not (id.to_lower().contains(filter) or name.to_lower().contains(filter)):
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(200, 62)
		button.tooltip_text = "%s　%s\n選択してフィールドをクリック" % [name, id]
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		var picture := TextureRect.new()
		picture.texture = canvas.texture_for(id)
		picture.custom_minimum_size = Vector2(44, 44)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(picture)
		var label := Label.new()
		label.text = "%s\n%s" % [name, id]
		label.add_theme_font_size_override("font_size", 13)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		button.pressed.connect(func(): canvas.spawn_type = id; canvas.mode = 1; _messages.text = name + "：配置する位置をクリック")
		_palette.add_child(button)

func _set_mode(mode: int) -> void:
	canvas.mode = mode
	_messages.text = ["敵を選択してドラッグ移動", "配置する位置をクリック", "線の点を追加・移動して結果を確認", "通常の描画操作で試遊。再生を押してください"][mode]

func _toggle_play() -> void:
	session.playing = not session.playing
	_refresh()

func _reset() -> void:
	if _busy:
		return
	_busy = true
	await session.reset({"seed": int(_seed.value), "stage": _stage.selected + 1, "empty": _empty.button_pressed, "auto_spawn": _auto.button_pressed})
	canvas.route.clear()
	canvas.result.clear()
	canvas.center = session.run.state.ship_pos
	_busy = false
	_refresh()

func _select_branch(index: int) -> void:
	if index == 0 or session.seeking:
		return
	var current := {"name": "分岐 %d" % (session.branches.size() + 1), "history": session.history.duplicate(true), "end": session.furthest}
	var branch: Dictionary = session.branches[index - 1]
	session.history.assign(branch.history)
	session.furthest = int(branch.end)
	session.branches[index - 1] = current
	await session.seek(session.furthest)
	_refresh()

func _evaluate() -> void:
	_messages.text = "ルートの再生確認を接続中"

func _refresh() -> void:
	if not is_instance_valid(session.run):
		return
	_play.text = "❚❚ 再生中" if session.playing else "▶ 再生"
	_seek.max_value = maxf(1, session.furthest)
	if not _scrubbing:
		_seek.set_value_no_signal(session.tick)
	_status.text = "%.2f 秒 / %.2f 秒　世界 %.2f 秒　敵 %d体　Seed %d" % [session.tick * session.DT, session.furthest * session.DT, session.run.state.world_time, session.run.enemies.count(), int(session.spec.seed)]
	if _branch.item_count != session.branches.size() + 1:
		_branch.clear()
		_branch.add_item("現在の分岐")
		for branch in session.branches:
			_branch.add_item(branch.name)
	canvas.queue_redraw()
	inspector.refresh()

func _process(_delta: float) -> void:
	if session != null and is_instance_valid(session.run):
		_refresh()
