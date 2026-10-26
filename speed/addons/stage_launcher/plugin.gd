## ツールバーからステージ・実験場・ビジュアル編集を起動する（設計書 14.1）。
##
## 押すと起動するステージを予約し、通常どおりメインシーンを実行する。予約はゲーム側が
## 起動時に1回だけ消費するので、F5（通常実行）はこれまでどおりタイトルから始まる。
@tool
extends EditorPlugin

const Request := preload("res://addons/stage_launcher/launch_request.gd")
const LAB_SCENE := "res://gyms/enemy_lab/enemy_lab.tscn"
const MENU_NAME := "SPEED"
const SCENES := {
	"lab": LAB_SCENE,
	"visual": "res://gyms/visual_editor.tscn",
	"fire_scene": "res://gyms/pixel_fire_preview.tscn",
	"background": "res://gyms/background_lab/background_lab.tscn",
	"boss_trial": "res://gyms/boss_flow_trial.tscn",
	"hydra_trial": "res://gyms/hydra_trial.tscn",
	"art": "res://tools/preview_pixel_assets.tscn",
	"performance": "res://gyms/perf_enemies/perf_enemies.tscn",
	"profile": "res://tools/profile_run.tscn",
}
const EDITOR_TOOLS := [
	["データ編集", "speed_data_editor", "open_window"],
	["ボス行動", "speed_boss_flow", "open_editor"],
	["出現タイムライン・編成", "speed_spawn_timeline", "open_timeline"],
	["ステージ敵調整", "speed_stage_enemy_tuning", "open_dock"],
]

var _button: Button = null
var _lab_button: Button = null
var _visual_button: Button = null
var _menu: PopupMenu
var _actions: Array[Array] = []

func _enter_tree() -> void:
	add_to_group("speed_stage_launcher")
	_button = Button.new()
	_button.text = "▶ ステージ"
	_button.tooltip_text = "編集中のステージを直接起動する（F5 は通常どおりタイトルから）"
	_button.pressed.connect(_on_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, _button)
	_lab_button = Button.new()
	_lab_button.text = "▶ 実験場"
	_lab_button.tooltip_text = "敵・ルート実験場を直接起動する（編集中のシーンに関係なく起動）"
	_lab_button.pressed.connect(_on_lab_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, _lab_button)
	_visual_button = Button.new()
	_visual_button.text = "▶ ビジュアル編集"
	_visual_button.tooltip_text = "炎・オーラ・後光・マップを共通画面で調整する"
	_visual_button.pressed.connect(func(): EditorInterface.play_custom_scene("res://gyms/visual_editor.tscn"))
	add_control_to_container(CONTAINER_TOOLBAR, _visual_button)
	_menu = PopupMenu.new()
	_menu.about_to_popup.connect(_rebuild_menu)
	_menu.id_pressed.connect(_dispatch_menu)
	add_tool_submenu_item(MENU_NAME, _menu)
	_move_next_to_main_screen_buttons()

## Godot の既存「プロジェクト → ツール」内に、登録済みの入口だけを並べる。
## 他の plugin が無効なら項目を出さない。実行画面は保存・終了を既存の実装に任せる。
func _rebuild_menu() -> void:
	_menu.clear()
	_actions.clear()
	_menu.add_separator("編集")
	for entry in EDITOR_TOOLS:
		if not get_tree().get_nodes_in_group(entry[1]).is_empty():
			_add_action(entry[0], ["plugin", entry[1], entry[2]])
	_menu.add_separator("起動・試遊")
	_add_action("編集中のステージを起動", ["stage"])
	for entry in [["敵・ルート実験場", "lab"], ["ボス技試遊", "boss_trial"], ["Hydra 試遊", "hydra_trial"]]:
		_add_scene(entry[0], entry[1])
	_menu.add_separator("見た目")
	for entry in [["ビジュアル編集（炎・オーラ・後光・マップ）", "visual"], ["背景編集", "background"], ["ピクセル素材確認", "art"]]:
		_add_scene(entry[0], entry[1])
	if ResourceLoader.exists(SCENES.fire_scene):
		_add_action("ピクセル炎（2D編集）", ["edit_scene", "fire_scene"])
	_menu.add_separator("計測")
	for entry in [["敵描画性能実験", "performance"], ["ラン性能計測", "profile"]]:
		_add_scene(entry[0], entry[1])

func _add_scene(label: String, key: String) -> void:
	if ResourceLoader.exists(SCENES[key]):
		_add_action(label, ["scene", key])

func _add_action(label: String, action: Array) -> void:
	var id := _actions.size()
	_actions.append(action)
	_menu.add_item(label, id)

func _dispatch_menu(id: int) -> void:
	if id < 0 or id >= _actions.size(): return
	var action: Array = _actions[id]
	match action[0]:
		"stage": _on_pressed()
		"scene": EditorInterface.play_custom_scene(SCENES[action[1]])
		"edit_scene": EditorInterface.open_scene_from_path(SCENES[action[1]])
		"plugin":
			var owners := get_tree().get_nodes_in_group(action[1])
			if owners.is_empty():
				push_warning("SPEED ツールは現在無効です: %s" % action[1])
				return
			owners[0].call(action[2])

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
	remove_tool_menu_item(MENU_NAME)
	_menu = null
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
	print("[Stage Launcher] 敵・ルート実験場を起動します")
	EditorInterface.play_custom_scene(LAB_SCENE)

## 編集中のシーンのパス。起動するのは保存済みの内容なので、先に保存する。
func _current_scene_path() -> String:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path == "":
		return ""
	EditorInterface.save_scene()
	return root.scene_file_path
