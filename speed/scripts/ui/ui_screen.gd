## 画面の共通の土台。戻る操作（Esc と「戻る」ボタン）で前の画面へ戻る（仕様書 3）。
class_name UiScreen
extends Control

## false の画面（タイトル）では戻る操作を受け付けない
@export var can_go_back := true
## ほかの画面の上に重ねて開いたとき（ポーズ中の設定）に、戻る操作で呼ぶ処理。空なら前の画面へ戻る
var close_fn: Callable

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
	if close_fn.is_valid():
		close_fn.call()
	else:
		GameManager.back()

## キーボードでも操作できるよう、最初のボタンにフォーカスを置く。
func _focus_first() -> void:
	for node in find_children("*", "BaseButton", true, false):
		var b := node as BaseButton
		if b.visible and not b.disabled:
			b.grab_focus.call_deferred()
			return
