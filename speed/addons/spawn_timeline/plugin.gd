## 出現タイムラインのエディター拡張（設計書 14.2）。インスペクターで開いたリソースのうち、
## 時間帯の配列 phases と出現のクリップの配列 clips を持つもの（ステージ）を、下のパネルのトラックで編集する。
## この道具は Godot 本体だけに依存する（設計書 4.1）。中身はプロパティ名で読み書きし、攻撃の組み合わせの表の
## 場所はプロジェクト設定 spawn_timeline/attack_rules から読む。
@tool
extends EditorPlugin

const Timeline := preload("res://addons/spawn_timeline/timeline.gd")

var _panel: Control = null

func _enter_tree() -> void:
	_panel = Timeline.new()
	_panel.undo_redo = get_undo_redo()
	add_control_to_bottom_panel(_panel, "出現タイムライン")

func _exit_tree() -> void:
	if _panel != null:
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null

func _handles(object: Object) -> bool:
	return Timeline.is_stage(object)

func _edit(object: Object) -> void:
	# クリップをインスペクターで開いてもステージの表示は残す
	if Timeline.is_stage(object):
		_panel.set_stage(object as Resource)

func _make_visible(visible: bool) -> void:
	if visible and _panel != null:
		make_bottom_panel_item_visible(_panel)
