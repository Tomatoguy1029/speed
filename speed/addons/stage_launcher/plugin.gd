## ツールバーからステージ・実験場・ビジュアル編集を起動する（設計書 14.1）。
##
## 押すと起動するステージを予約し、通常どおりメインシーンを実行する。予約はゲーム側が
## 起動時に1回だけ消費するので、F5（通常実行）はこれまでどおりタイトルから始まる。
@tool
extends EditorPlugin

const Request := preload("res://addons/stage_launcher/launch_request.gd")
const FireInspector := preload("res://addons/stage_launcher/fire_inspector.gd")
const LAB_SCENE := "res://gyms/enemy_lab/enemy_lab.tscn"
const MENU_SEPARATORS := ["試遊", "表示制作", "計測"]
const SCENES := {
	"lab": LAB_SCENE,
	"visual": "res://gyms/visual_editor.tscn",
	"background": "res://gyms/background_lab/background_lab.tscn",
	"art": "res://tools/preview_pixel_assets.tscn",
	"performance": "res://gyms/perf_enemies/perf_enemies.tscn",
	"profile": "res://tools/profile_run.tscn",
}
var _button: Button = null
var _lab_button: Button = null
var _visual_button: Button = null
var _menu_items: Array[String] = []
var _fire_inspector: EditorInspectorPlugin
var _launch_error: AcceptDialog

func _enter_tree() -> void:
	add_to_group("speed_stage_launcher")
	_fire_inspector = FireInspector.new()
	add_inspector_plugin(_fire_inspector)
	_launch_error = AcceptDialog.new()
	_launch_error.title = "ビジュアル編集を開けません"
	add_child(_launch_error)
	_button = Button.new()
	_button.text = "▶ ステージ"
	_button.tooltip_text = "編集中のステージを直接起動する（F5 は通常どおりタイトルから）"
	_button.pressed.connect(_on_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, _button)
	_lab_button = Button.new()
	_lab_button.text = "▶ 実験場"
	_lab_button.tooltip_text = "敵・ボスの試遊とヒットストップ調整を共通の実験場で行う"
	_lab_button.pressed.connect(_on_lab_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, _lab_button)
	_visual_button = Button.new()
	_visual_button.text = "▶ ビジュアル編集"
	_visual_button.tooltip_text = "炎・オーラ・後光・マップを共通画面で調整する"
	_visual_button.pressed.connect(_on_visual_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, _visual_button)
	_register_menu_items()
	_move_next_to_main_screen_buttons()

## Godot 標準の「プロジェクト → ツール」直下へ登録する。
## エディター拡張の入口は各 plugin 自身が登録し、無効時に項目を残さない。
func _register_menu_items() -> void:
	_add_menu_item(MENU_SEPARATORS[0], _on_menu_separator)
	_add_menu_item("編集中のステージを起動", _on_pressed)
	_add_scene("実験場", "lab")
	_add_menu_item(MENU_SEPARATORS[1], _on_menu_separator)
	_add_menu_item("ビジュアル編集（炎・オーラ・後光・マップ・目印・エリート）", _on_visual_pressed)
	_add_scene("背景編集", "background")
	_add_scene("ピクセル素材確認", "art")
	_add_menu_item(MENU_SEPARATORS[2], _on_menu_separator)
	_add_scene("敵描画ベンチ", "performance")
	_add_scene("ラン処理・描画ベンチ", "profile")
	_mark_menu_separators.call_deferred()

## EditorPlugin の公開 API には区切りの登録がないため、登録した項目だけを PopupMenu の区切りに変える。
func _mark_menu_separators() -> void:
	if not is_inside_tree(): return
	for node in EditorInterface.get_base_control().find_children("*", "PopupMenu", true, false):
		var menu := node as PopupMenu
		var has_own_item := false
		for index in menu.item_count:
			if menu.get_item_text(index).begins_with("ビジュアル編集（"):
				has_own_item = true
				break
		if not has_own_item: continue
		for index in menu.item_count:
			if menu.get_item_text(index) in MENU_SEPARATORS:
				menu.set_item_as_separator(index, true)

func _on_menu_separator() -> void:
	pass

func _add_scene(label: String, key: String) -> void:
	if ResourceLoader.exists(SCENES[key]):
		_add_menu_item(label, EditorInterface.play_custom_scene.bind(SCENES[key]))

func _add_menu_item(label: String, action: Callable) -> void:
	add_tool_menu_item(label, action)
	_menu_items.append(label)

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
	bar.move_child(_lab_button, _button.get_index() + 1)
	bar.move_child(_visual_button, _lab_button.get_index() + 1)

func _exit_tree() -> void:
	if _launch_error != null:
		_launch_error.queue_free()
		_launch_error = null
	if _fire_inspector != null:
		remove_inspector_plugin(_fire_inspector)
		_fire_inspector = null
	for label in _menu_items:
		remove_tool_menu_item(label)
	_menu_items.clear()
	if _visual_button != null:
		remove_control_from_container(CONTAINER_TOOLBAR, _visual_button)
		_visual_button.queue_free()
		_visual_button = null
	if _lab_button != null:
		remove_control_from_container(CONTAINER_TOOLBAR, _lab_button)
		_lab_button.queue_free()
		_lab_button = null
	if _button != null:
		remove_control_from_container(CONTAINER_TOOLBAR, _button)
		_button.queue_free()
		_button = null

func _on_pressed() -> void:
	var stage := Request.resolve(_current_scene_path())
	print("[Stage Launcher] ステージ %d で起動します" % stage)
	Request.request(stage)
	EditorInterface.play_main_scene()

func _on_lab_pressed() -> void:
	print("[Stage Launcher] 実験場を起動します")
	EditorInterface.play_custom_scene(LAB_SCENE)

func _on_visual_pressed() -> void:
	var path: String = SCENES.visual
	if not ResourceLoader.exists(path) or ResourceLoader.load(path) == null:
		_visual_error("ビジュアル編集のシーンを読み込めません: " + path)
		return
	print("[Stage Launcher] ビジュアル編集を起動します")
	OS.set_environment("SPEED_VISUAL_EDITOR_SCREEN", str(DisplayServer.window_get_current_screen()))
	EditorInterface.play_custom_scene(path)
	await get_tree().process_frame
	if not is_inside_tree(): return
	if EditorInterface.get_playing_scene() != path:
		_visual_error("ビジュアル編集を起動できませんでした。エディターの出力を確認してください。")
		return
	# Godot の「ゲーム」タブは、別窓で実行中ならその窓へフォーカスする。
	EditorInterface.set_main_screen_editor("Game")

func _visual_error(message: String) -> void:
	push_error(message)
	if is_instance_valid(_launch_error):
		_launch_error.dialog_text = message
		_launch_error.popup_centered()

## 編集中のシーンのパス。起動するのは保存済みの内容なので、先に保存する。
func _current_scene_path() -> String:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path == "":
		return ""
	EditorInterface.save_scene()
	return root.scene_file_path
