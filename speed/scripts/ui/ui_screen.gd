## 画面の共通の土台。戻る操作（Esc と「戻る」ボタン）で前の画面へ戻る（仕様書 2.1）。
class_name UiScreen
extends Control

## false の画面（タイトル）では戻る操作を受け付けない
@export var can_go_back := true

func _ready() -> void:
	var back := get_node_or_null("%BackButton") as Button
	if back != null:
		back.pressed.connect(_on_back)
	_focus_first()

func _unhandled_input(event: InputEvent) -> void:
	if can_go_back and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()

func _on_back() -> void:
	AudioManager.play(&"ui")
	GameManager.back()

## キーボードでも操作できるよう、最初のボタンにフォーカスを置く。
func _focus_first() -> void:
	for node in find_children("*", "BaseButton", true, false):
		var b := node as BaseButton
		if b.visible and not b.disabled:
			b.grab_focus.call_deferred()
			return
