## マウスとタッチの入力を集め、更新ごとに Intent にまとめる（設計書 9）。
##
## ラン中だけ World の子として置く（世界座標でカーソルの位置を得るため）。
## UI が受け取らなかった入力だけを使うので、3択のカードなどを押しても描画は始まらない。
class_name InputRouter
extends Node2D

var stick_dead_zone := 8.0
var stick_radius := 70.0

var _press := false
var _alt_press := false
var _pen_release := false
var _touch := false
var _stick_index := -1
var _stick_origin := Vector2.ZERO
var _stick_now := Vector2.ZERO
var _pen_index := -1
var _pen_screen := Vector2.ZERO
var _mouse_screen := Vector2.ZERO
var _mouse_seen := false
## RunManager が描画中かどうかを伝える（タッチの指を、スティックにするかペンにするかの判断に使う）
var drawing := false

## カーソルの位置は、UI の上でも追い続ける（動きのイベントから得る）。
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_mouse_screen = event.position
		_mouse_seen = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_press = true
		_touch = false
	elif event.is_action_pressed(&"draw_alt"):
		_alt_press = true
	elif event is InputEventScreenTouch:
		_touch = true
		if event.pressed:
			if drawing:
				_pen_index = event.index
				_pen_screen = event.position
				_press = true
			elif _stick_index == -1:
				_stick_index = event.index
				_stick_origin = event.position
				_stick_now = event.position
		else:
			if event.index == _stick_index:
				_stick_index = -1
			if event.index == _pen_index:
				_pen_index = -1
				_pen_release = true
	elif event is InputEventScreenDrag:
		if event.index == _stick_index:
			_stick_now = event.position
		elif event.index == _pen_index:
			_pen_screen = event.position

## 「描く」ボタン（タッチ用）から呼ぶ。
func press_draw_button() -> void:
	_alt_press = true

## 1回の更新ぶんの意図を作り、押した瞬間の記録を消す。
func poll() -> Intent:
	var it := Intent.new()
	it.touch = _touch
	if _touch:
		it.stick_active = _stick_index != -1
		it.stick = _stick_now - _stick_origin if it.stick_active else Vector2.ZERO
		var screen_to_world := get_canvas_transform().affine_inverse()
		it.pen = screen_to_world * _pen_screen
		it.cursor = it.pen
		it.has_cursor = _pen_index != -1
	else:
		var screen := _mouse_screen if _mouse_seen else get_viewport().get_mouse_position()
		it.has_cursor = true
		it.cursor = get_canvas_transform().affine_inverse() * screen
		it.pen = it.cursor
	it.press = _press
	it.alt_press = _alt_press
	it.pen_release = _pen_release
	_press = false
	_alt_press = false
	_pen_release = false
	return it
