## 星別の試遊倍率はC++ランの値だけを更新する。画像・定義の再生成や保存は行わない。
extends VBoxContainer
signal resume_requested
var cpp_session: RunSession
var _boxes: Array[SpinBox] = []
var _sliders: Array[HSlider] = []
var _status: Label

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	theme = Theme.new()
	theme.default_font_size = 16
	add_theme_constant_override("separation", 6)
	var description := Label.new()
	description.text = "星ごとの停止時間（このランだけ）\n1倍: 保存された種類別の設定 / 0倍: 停止なし\n現在の敵と、これから出現する敵へ即時反映。\nボス・星のない障害物は対象外。"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 14)
	add_child(description)
	for rank in range(1, 11):
		var row := HBoxContainer.new()
		add_child(row)
		var label := Label.new()
		label.text = "★%d" % rank
		label.custom_minimum_size.x = 44
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 10
		slider.step = 0.05
		slider.value = 1
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		_sliders.append(slider)
		var box := SpinBox.new()
		box.min_value = 0
		box.max_value = 10
		box.step = 0.05
		box.value = 1
		box.suffix = "倍"
		box.custom_minimum_size.x = 112
		box.get_line_edit().add_to_group("stage_enemy_tuning_input")
		row.add_child(box)
		_boxes.append(box)
		slider.value_changed.connect(_change.bind(rank))
		box.value_changed.connect(_change.bind(rank))
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 14)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	var reset := Button.new()
	reset.text = "星別の倍率をすべて1倍に戻す"
	reset.pressed.connect(_reset)
	add_child(reset)
	var resume := Button.new()
	resume.text = "閉じて試す（P）"
	resume.pressed.connect(func(): resume_requested.emit())
	add_child(resume)

func refresh() -> void:
	if cpp_session == null or cpp_session.bridge == null: return
	var current: Dictionary = cpp_session.bridge.read_lab()
	if not current.ok:
		_status.text = current.message
		return
	if not current.value.has("debug_rank_hitstop"):
		_status.text = "C++ライブラリを更新してゲームを起動し直してください。"
		for box in _boxes: box.editable = false
		for slider in _sliders: slider.editable = false
		return
	for index in 10:
		_set_display(index, current.value.debug_rank_hitstop[index])
	_status.text = "倍率は種類別の設定に掛かり、共通の累積上限内で停止します。" if current.value.hitstop_enabled else "設定画面でヒットストップがOFFです。ONにするとこの倍率で停止します。"

func _set_display(index: int, value: float) -> void:
	_boxes[index].set_value_no_signal(value)
	_sliders[index].set_value_no_signal(value)

func _change(value: float, rank: int) -> void:
	if cpp_session == null or cpp_session.bridge == null: return
	var result: Dictionary = cpp_session.bridge.command("dev_edit", {"kind":"debug_action", "payload":{"action":"rank_hitstop", "args":{"rank":rank, "multiplier":value}}})
	if result.ok:
		_set_display(rank - 1, value)
	else:
		refresh()
		_status.text = result.message

func _reset() -> void:
	for rank in range(1, 11):
		if not is_equal_approx(_boxes[rank - 1].value, 1): _change(1, rank)
