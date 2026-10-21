## 画面・モード・ステージ進行の状態機械。Autoload（設計書 4.3、仕様書 3）。
##
## 画面の切り替えはこの Manager の関数を通してだけ行う。Main（scenes/app/main.tscn）は
## screen_changed を受けて、対応する画面のシーンに差し替える。
extends Node

enum Screen { TITLE, SETTINGS, MAIN_MENU, STAGE_SELECT, UPGRADE, ENCYCLOPEDIA, RUN, RESULT }

signal screen_changed(screen: Screen)
signal run_requested(stage: int, endless: bool)

var screen: Screen = Screen.TITLE
var _history: Array[Screen] = []

## 遊ぶステージとモード（ステージ選択で決まる）
var run_stage := 1
var run_endless := false
## 直前のランの結果（結果画面が表示する）
var last_result: Dictionary = {}

## 画面を移る。push が true なら、戻る操作で今の画面へ戻れるように覚えておく。
func goto(next: Screen, push := true) -> void:
	if push and screen != next and screen != Screen.RUN and screen != Screen.RESULT:
		_history.append(screen)
	screen = next
	screen_changed.emit(next)

## 前の画面へ戻る。戻り先がなければタイトル。
func back() -> void:
	var prev: Screen = _history.pop_back() if not _history.is_empty() else Screen.TITLE
	goto(prev, false)

## ラン以外の画面の履歴を、メインメニューを起点に作り直す。
func reset_to_main_menu() -> void:
	_history = [Screen.TITLE]
	goto(Screen.MAIN_MENU, false)

func start_run(stage: int, endless := false) -> void:
	run_stage = stage
	run_endless = endless
	goto(Screen.RUN, false)
	run_requested.emit(stage, endless)

## ランを最後まで終えた。結果を保存して結果画面へ（仕様書 3）。
func finish_run(result: Dictionary) -> void:
	last_result = result
	SaveManager.record_run(result)
	goto(Screen.RESULT, false)

## ランを途中でやめてメインメニューへ戻る。そのランの部品と記録は残さない（仕様書 3）。
func abort_run() -> void:
	last_result = {}
	reset_to_main_menu()

## 結果画面の「もう一回やる」。
func retry_run() -> void:
	start_run(run_stage, run_endless)

func quit_game() -> void:
	get_tree().quit()
