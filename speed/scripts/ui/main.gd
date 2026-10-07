## 起動時のシーンのルート。GameManager の画面に合わせて、表示する画面のシーンを差し替える。
##
## エディタのツールバー（addons/stage_launcher）からステージの直接起動が予約されていれば、
## タイトルを飛ばしてそのステージを始める。予約はエディタから実行したときだけ読み、
## 1回読んだら消す（F5 は通常どおりタイトルから始まる。設計書 14.1）。
extends Node

const SCREENS := {
	GameManager.Screen.TITLE: "res://scenes/app/title.tscn",
	GameManager.Screen.SETTINGS: "res://scenes/app/settings.tscn",
	GameManager.Screen.MAIN_MENU: "res://scenes/app/main_menu.tscn",
	GameManager.Screen.STAGE_SELECT: "res://scenes/app/stage_select.tscn",
	GameManager.Screen.UPGRADE: "res://scenes/app/upgrade.tscn",
	GameManager.Screen.ENCYCLOPEDIA: "res://scenes/app/encyclopedia.tscn",
	GameManager.Screen.RUN: "res://scenes/run/run.tscn",
	GameManager.Screen.RESULT: "res://scenes/app/result.tscn",
}

var _current: Node = null

func _ready() -> void:
	GameManager.screen_changed.connect(_show)
	if OS.has_feature("editor"):
		var stage := StageLaunchRequest.consume()
		if stage > 0:
			print("[Main] ステージ %d を直接起動" % stage)
			GameManager.reset_to_main_menu()
			GameManager.start_run(stage)
			return
	_show(GameManager.screen)

func _show(screen: GameManager.Screen) -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	var scene := load(SCREENS[screen]) as PackedScene
	_current = scene.instantiate()
	add_child(_current)
