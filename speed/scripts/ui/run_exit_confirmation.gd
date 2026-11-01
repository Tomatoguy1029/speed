## ポーズからのラン終了を確認する。終了・復帰の処理は呼び出し元へ返す。
extends Control

signal finished(confirmed: bool)

## HUD と同じ入力 ID を使い、開く前からの押下を離すまで破棄する。
var input_id: Callable
var held_inputs: Dictionary = {}
var discarded_inputs: Dictionary = {}
var input_delay := 0.3
var _accept_at := 0
var _closing := false
var _cancel: Button
var _confirm: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_accept_at = Time.get_ticks_usec() + roundi(input_delay * 1_000_000.0)
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.025, 0.045, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var layout := func(): panel.custom_minimum_size.x = minf(520.0, maxf(0.0, size.x - 48.0))
	resized.connect(layout)
	layout.call()
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	var message := Label.new()
	message.text = "hud.confirm_quit_run"
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message)
	_cancel = Button.new()
	_cancel.name = "Cancel"
	_cancel.text = "common.cancel"
	_confirm = Button.new()
	_confirm.name = "Confirm"
	_confirm.text = "common.to_main_menu"
	for button in [_confirm, _cancel]:
		button.custom_minimum_size.y = 52
		column.add_child(button)
	_cancel.pressed.connect(_from_button.bind(false))
	_confirm.pressed.connect(_from_button.bind(true))
	_cancel.grab_focus.call_deferred()

func _input(event: InputEvent) -> void:
	var id: String = input_id.call(event)
	var blocked := Time.get_ticks_usec() < _accept_at or discarded_inputs.has(id)
	# HUD と押下状態を共有し、こちらで消費した release も復帰先へ残さない。
	if id != "" and not event is InputEventScreenDrag:
		if event.is_pressed():
			held_inputs[id] = true
			if blocked: discarded_inputs[id] = true
		else:
			held_inputs.erase(id)
			discarded_inputs.erase(id)
	if _closing:
		get_viewport().set_input_as_handled()
		return
	if event.is_action(&"pause") or event.is_action(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if event.is_pressed() and not event.is_echo(): _finish(false)
		return
	if id != "" and (blocked or event.is_echo()): get_viewport().set_input_as_handled()

func _from_button(confirmed: bool) -> void:
	if Time.get_ticks_usec() >= _accept_at: _finish(confirmed)

func _finish(confirmed: bool) -> void:
	if _closing: return
	_closing = true
	_cancel.disabled = true
	_confirm.disabled = true
	finished.emit(confirmed)
