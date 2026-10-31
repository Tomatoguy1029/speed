## 埋込み・通常UIウィンドウが共用する操作面。時計を進めず、入力だけを所有者へ渡す。
extends VBoxContainer

signal play_requested
signal pause_requested
signal step_requested(direction: int)
signal seek_requested(seconds: float)
signal head_requested
signal range_requested(index: int)
signal phase_requested(phase: String)
signal speed_changed(speed: float)
signal fps_changed(fps: int)
signal auto_changed(enabled: bool)
signal return_requested

var allow_return := false
var compact := false

const FPS := [30, 60, 120]
var _play := Button.new()
var _pause := Button.new()
var _back := Button.new()
var _forward := Button.new()
var _range := OptionButton.new()
var _speed := SpinBox.new()
var _fps := OptionButton.new()
var _auto := CheckButton.new()
var _timeline := HSlider.new()
var _status := Label.new()
var _crack: Button

func _ready() -> void:
	theme = Theme.new()
	theme.default_font_size = 14
	var actions := HFlowContainer.new()
	add_child(actions)
	if allow_return:
		var back := _button(actions, "編集に戻る（Esc）", func(): return_requested.emit())
		back.tooltip_text = "再生を停止し、表示用ランを解放して編集画面へ戻ります。未保存値は保持します。"
	_play.text = "再生"
	_play.pressed.connect(func(): play_requested.emit())
	actions.add_child(_play)
	_pause.text = "一時停止"
	_pause.pressed.connect(func(): pause_requested.emit())
	actions.add_child(_pause)
	_back.text = "1コマ戻す"
	_back.pressed.connect(func(): step_requested.emit(-1))
	actions.add_child(_back)
	_forward.text = "1コマ送る"
	_forward.pressed.connect(func(): step_requested.emit(1))
	actions.add_child(_forward)
	_button(actions, "先頭へ", func(): head_requested.emit())
	var options := HFlowContainer.new()
	var details := VBoxContainer.new()
	if compact:
		var toggle := Button.new()
		toggle.text = "段階・FPS・頭出し"
		toggle.toggle_mode = true
		toggle.toggled.connect(func(open): details.visible = open)
		actions.add_child(toggle)
		add_child(details)
		details.hide()
	else: add_child(details)
	details.add_child(options)
	for item in ["全段階", "×2 Combo · Iris", "×3 Combo · Star Iris", "×4 Combo · Shatter"]: _range.add_item(item)
	_range.item_selected.connect(func(index): range_requested.emit(index))
	options.add_child(_range)
	var speed_row: Control = actions if compact else options
	_label(speed_row, "再生速度")
	_speed.min_value = 0.1
	_speed.max_value = 3.0
	_speed.step = 0.05
	_speed.value = 1.0
	_speed.suffix = "倍"
	_speed.custom_minimum_size.x = 104
	_speed.value_changed.connect(func(value): speed_changed.emit(value))
	speed_row.add_child(_speed)
	_button(speed_row, "1倍へ", func(): speed_changed.emit(1.0))
	_label(options, "コマ基準")
	for fps in FPS: _fps.add_item("%d fps" % fps)
	_fps.select(1)
	_fps.item_selected.connect(func(index): fps_changed.emit(FPS[index]))
	options.add_child(_fps)
	_auto.text = "自動次送り"
	_auto.toggled.connect(func(enabled): auto_changed.emit(enabled))
	options.add_child(_auto)
	var jumps := HFlowContainer.new()
	details.add_child(jumps)
	for item in [["暗転", "dim"], ["開く", "opening"], ["最大", "peak"], ["着地", "landing"], ["保持", "hold"], ["割れ直前", "crack"]]:
		var button := _button(jumps, item[0], func(): phase_requested.emit(item[1]))
		if item[1] == "crack": _crack = button
	_timeline.min_value = 0.0
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline.tooltip_text = "全段階をまたいでスクラブ。操作すると停止し、指定コマの状態を再評価します。"
	_timeline.drag_started.connect(func(): pause_requested.emit())
	_timeline.value_changed.connect(func(value): seek_requested.emit(value))
	add_child(_timeline)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)

func sync(state: Dictionary) -> void:
	# 双方向の操作面を同期しても、入力signalや時計更新を再発火させない。
	_play.disabled = state.playing
	_pause.disabled = not state.playing
	_back.disabled = state.frame <= 0
	_forward.disabled = state.frame >= state.last_frame
	_range.select(state.range)
	_speed.set_value_no_signal(state.speed)
	_fps.select(FPS.find(state.fps))
	_auto.set_pressed_no_signal(state.auto)
	_crack.disabled = state.kind != 2
	_timeline.set_block_signals(true)
	_timeline.step = 1.0 / state.fps
	_timeline.max_value = state.last_frame / float(state.fps)
	_timeline.set_value_no_signal(state.frame / float(state.fps))
	_timeline.set_block_signals(false)
	_status.text = "%s · %s · %.2f倍 · コマ %d / %d（%dfps） · %.3f秒" % [state.name, state.phase, state.speed, state.frame, state.last_frame, state.fps, state.frame / float(state.fps)]
