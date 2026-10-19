## 出現タイムラインのエディター拡張（設計書 14.2）。インスペクターで開いたリソースのうち、
## 時間帯の配列 phases と出現のクリップの配列 clips を持つもの（ステージ）を、トラックで編集する。
## タイムラインは、エディターの下のパネルと、上部の画面のタブ「出現タイムライン」（大きく表示）の両方に出す。
## ステージの敵とクリップの種類の組み合わせは、インスペクターのチェックボックスで選ぶ（type_checks.gd）。
## この道具は Godot 本体だけに依存する（設計書 4.1）。中身はプロパティ名で読み書きし、敵の定義のフォルダは
## プロジェクト設定 spawn_timeline/enemy_dir から読む。
@tool
extends EditorPlugin

const Timeline := preload("res://addons/spawn_timeline/timeline.gd")
const TypeChecks := preload("res://addons/spawn_timeline/type_checks.gd")
const TITLE := "出現タイムライン"

var _panel: Control = null
var _main: Control = null
var _checks: EditorInspectorPlugin = null

func _enter_tree() -> void:
	_panel = Timeline.new()
	_panel.undo_redo = get_undo_redo()
	_panel.open_large.connect(func() -> void: EditorInterface.set_main_screen_editor(TITLE))
	add_control_to_bottom_panel(_panel, TITLE)
	_main = Timeline.new()
	_main.undo_redo = get_undo_redo()
	_main.large = true
	_main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main.hide()
	EditorInterface.get_editor_main_screen().add_child(_main)
	_checks = TypeChecks.new()
	_checks.timeline = _panel
	add_inspector_plugin(_checks)
	# 開いたステージは、インスペクターの対象が変わったときに拾う（上部の画面へ勝手に切り替えないように _handles は使わない）
	EditorInterface.get_inspector().edited_object_changed.connect(_on_inspected)

func _exit_tree() -> void:
	if EditorInterface.get_inspector().edited_object_changed.is_connected(_on_inspected):
		EditorInterface.get_inspector().edited_object_changed.disconnect(_on_inspected)
	if _checks != null:
		remove_inspector_plugin(_checks)
		_checks = null
	if _main != null:
		_main.queue_free()
		_main = null
	if _panel != null:
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null

func _on_inspected() -> void:
	var object := EditorInterface.get_inspector().get_edited_object()
	# クリップや曲線をインスペクターで開いてもステージの表示は残す
	if Timeline.is_stage(object):
		_panel.set_stage(object as Resource)
		_main.set_stage(object as Resource)
		make_bottom_panel_item_visible(_panel)

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return TITLE

func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("Animation", "EditorIcons")

func _make_visible(visible: bool) -> void:
	if _main != null:
		_main.visible = visible
		if visible:
			_main.refresh()
