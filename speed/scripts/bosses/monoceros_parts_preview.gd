extends Node2D

const FRAME_NAMES := ["長い脚", "中間の脚（縮む）", "短い脚（縮む）", "真下の脚", "短い脚（戻る）", "中間の脚（戻る）"]
const PartsVisual = preload("res://scripts/bosses/monoceros_parts.gd")
const DEFAULT_GAIT = preload("res://data/visuals/monoceros_gait.tres")
@onready var _parts: PartsVisual = $Parts

var _durations: Array[float] = []
var _elapsed_ms := 0.0
var _playing := true
var _sliders: Array[HSlider] = []
var _cycle_label: Label
var _phase_label: Label
var _panel: PanelContainer


func _ready() -> void:
	_parts.gait = DEFAULT_GAIT.duplicate()
	for index in _parts.gait.get_frame_count(&"run"):
		_durations.append(DEFAULT_GAIT.get_frame_duration(&"run", index) * 1000.0)
	_build_controls()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_update_pose()


func _process(delta: float) -> void:
	if _playing:
		_elapsed_ms = fmod(_elapsed_ms + delta * 1000.0, _cycle_ms())
	_update_pose()


func _cycle_ms() -> float:
	var total := 0.0
	for duration in _durations:
		total += duration
	return total


func _update_pose() -> void:
	_parts.show_gait(_elapsed_ms / 1000.0)
	var first := _parts.frame_at(_elapsed_ms / 1000.0)
	var opposite := _parts.frame_at((_elapsed_ms + _cycle_ms() * 0.5) / 1000.0)
	_cycle_label.text = "1周：%.0f ms（%.2f 秒）" % [_cycle_ms(), _cycle_ms() / 1000.0]
	_phase_label.text = "左前・右後：%s\n右前・左後：%s" % [FRAME_NAMES[first], FRAME_NAMES[opposite]]


func _build_controls() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_panel = PanelContainer.new()
	canvas.add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "走りのタイミング調整"
	column.add_child(title)
	var description := Label.new()
	description.text = "長い → 中間 → 短い → 真下\n→ 短い → 中間 → 最初へ\n各コマの表示時間を調整します。\n対角の脚は半周期ずらします。"
	column.add_child(description)
	for index in FRAME_NAMES.size():
		var label := Label.new()
		label.text = "%s：%.0f ms" % [FRAME_NAMES[index], _durations[index]]
		column.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 10
		slider.max_value = 600
		slider.step = 10
		slider.value = _durations[index]
		slider.custom_minimum_size.y = 28
		slider.value_changed.connect(func(value: float) -> void:
			_durations[index] = value
			_parts.gait.set_frame(&"run", index, _parts.gait.get_frame_texture(&"run", index), value / 1000.0)
			label.text = "%s：%.0f ms" % [FRAME_NAMES[index], value]
		)
		column.add_child(slider)
		_sliders.append(slider)
	_cycle_label = Label.new()
	column.add_child(_cycle_label)
	_phase_label = Label.new()
	column.add_child(_phase_label)
	var pause := CheckButton.new()
	pause.text = "再生"
	pause.button_pressed = true
	pause.toggled.connect(func(enabled: bool) -> void: _playing = enabled)
	column.add_child(pause)
	var reset := Button.new()
	reset.text = "表示時間を初期値に戻す"
	reset.pressed.connect(func() -> void:
		for index in _sliders.size():
			_sliders[index].value = DEFAULT_GAIT.get_frame_duration(&"run", index) * 1000.0
		_elapsed_ms = 0.0
	)
	column.add_child(reset)
	var note := Label.new()
	note.text = "設定はこの画面の実行中だけ有効です。"
	note.add_theme_font_size_override("font_size", 13)
	column.add_child(note)


func _layout() -> void:
	var size := get_viewport_rect().size
	var panel_width := minf(340.0, maxf(270.0, size.x * 0.35))
	_panel.position = Vector2(maxf(8.0, size.x - panel_width - 12.0), 12.0)
	_panel.size = Vector2(panel_width, maxf(80.0, size.y - 24.0))
	var zoom_factor := maxf(0.25, minf(2.0, minf((size.x - panel_width - 40.0) / 145.0, (size.y - 40.0) / 310.0)))
	$Camera2D.zoom = Vector2.ONE * zoom_factor
	$Camera2D.position = Vector2(panel_width / (2.0 * zoom_factor), 10.0)
