## ツールバーに「▶ ステージ」ボタンを足すエディタプラグイン（設計書 14.1）。
##
## 押すと起動するステージを予約し、通常どおりメインシーンを実行する。予約はゲーム側が
## 起動時に1回だけ消費するので、F5（通常実行）はこれまでどおりタイトルから始まる。
@tool
extends EditorPlugin

const Request := preload("res://addons/stage_launcher/launch_request.gd")

var _button: Button = null

func _enter_tree() -> void:
	_button = Button.new()
	_button.text = "▶ ステージ"
	_button.tooltip_text = "編集中のステージを直接起動する（F5 は通常どおりタイトルから）"
	_button.pressed.connect(_on_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, _button)
	_move_next_to_main_screen_buttons()

## 既定では右端に置かれて見つけにくいので、「2D／3D／スクリプト」の並びの直後へ移す。
## エディタ内部のノードが見つからなければ、既定の位置のままにする。
func _move_next_to_main_screen_buttons() -> void:
	var bar := _button.get_parent()
	if bar == null:
		return
	var anchor := bar.get_node_or_null("EditorMainScreenButtons")
	if anchor == null:
		push_warning("Stage Launcher: ツールバーの並び替え先が見つからないので既定の位置に置く")
		return
	bar.move_child(_button, anchor.get_index() + 1)

func _exit_tree() -> void:
	if _button != null:
		remove_control_from_container(CONTAINER_TOOLBAR, _button)
		_button.queue_free()
		_button = null

func _on_pressed() -> void:
	var stage := Request.resolve(_current_scene_path())
	print("[Stage Launcher] ステージ %d で起動します" % stage)
	Request.request(stage)
	EditorInterface.play_main_scene()

## 編集中のシーンのパス。起動するのは保存済みの内容なので、先に保存する。
func _current_scene_path() -> String:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path == "":
		return ""
	EditorInterface.save_scene()
	return root.scene_file_path
