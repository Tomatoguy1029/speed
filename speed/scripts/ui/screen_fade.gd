## シーンをまたぐ短い暗転。押下中の入力は離すまで次の画面へ渡さない。
extends CanvasLayer

var _veil := ColorRect.new()
var _active := false
var _held: Dictionary = {}
var _discard: Dictionary = {}

func _ready() -> void:
	layer = 128
	_veil.color = Color.BLACK
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.modulate.a = 0.0
	_veil.hide()

func cover(seconds: float) -> void:
	_active = true
	_discard.merge(_held)
	_veil.show()
	await _animate(1.0, seconds)

func reveal(seconds: float) -> void:
	await _animate(0.0, seconds)
	_veil.hide()
	_active = false

func _animate(alpha: float, seconds: float) -> void:
	if seconds <= 0.0:
		_veil.modulate.a = alpha
		return
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_veil, "modulate:a", alpha, seconds)
	await tween.finished

func _input(event: InputEvent) -> void:
	var id := _input_id(event)
	var blocked := _active or _discard.has(id)
	if id != "" and not event is InputEventScreenDrag:
		if event.is_pressed():
			_held[id] = true
			if _active:
				_discard[id] = true
		else:
			_held.erase(id)
			_discard.erase(id)
	if blocked:
		get_viewport().set_input_as_handled()

func _input_id(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		# ホイールには release が来ないため、押しっぱなしとして記録しない。
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return ""
		return "mouse:%d:%d" % [event.device, event.button_index]
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return "touch:%d:%d" % [event.device, event.index]
	if event is InputEventKey:
		return "key:%d:%d" % [event.device, event.physical_keycode if event.physical_keycode != 0 else event.keycode]
	if event is InputEventJoypadButton:
		return "joy:%d:%d" % [event.device, event.button_index]
	if event is InputEventAction:
		return "action:%s" % event.action
	return ""
