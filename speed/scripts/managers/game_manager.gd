## 画面・モード・ステージ進行の状態機械。Autoload（設計書 4.3、仕様書 3）。
##
## 画面の切り替えはこの Manager の関数を通してだけ行う。Main（scenes/app/main.tscn）は
## screen_changed を受けて、対応する画面のシーンに差し替える。
extends Node

enum Screen { TITLE, SETTINGS, MAIN_MENU, STAGE_SELECT, UPGRADE, ENCYCLOPEDIA, RUN, RESULT, ENEMY_LAB, BACKGROUND_LAB, INTRO }

signal screen_ready(view: Control)
## 起動側から加える画面。
var extension_screens: Dictionary = {}
var boot_request: Callable

signal screen_changed(screen: Screen)
signal run_requested(stage: int, endless: bool)

var screen: Screen = Screen.TITLE
## Main の短いフェード中は、重複する遷移要求を受け付けない。
var screen_transition_active := false
var _history: Array[Screen] = []

## 遊ぶステージとモード（ステージ選択で決まる）
var run_stage := 1
var run_endless := false
## 次のランの時計を始める時刻（開発用。出現タイムラインの「ここから試す」）。ランが始まると 0 に戻る
var run_start_time := 0.0
var run_start_source := "stage_start"
var run_start_content: Dictionary = {}
## 直前のランの結果（結果画面が表示する）
var last_result: Dictionary = {}
var _accepted_cpp_results: Dictionary = {}

## 画面を移る。push が true なら、戻る操作で今の画面へ戻れるように覚えておく。
func goto(next: Screen, push := true) -> void:
	if screen_transition_active:
		return
	if next == Screen.STAGE_SELECT and not SaveManager.has_seen_intro() and screen != Screen.INTRO:
		next = Screen.INTRO
	if screen == Screen.INTRO and next == Screen.INTRO:
		return
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

## メニュー端から、初回と同じカットシーン・操作体験を再生する。
func replay_intro() -> void:
	goto(Screen.INTRO)

## 完了と明示スキップは同じ出口を使う。戻る履歴へ導入を積まない。
func finish_intro() -> void:
	if screen != Screen.INTRO or screen_transition_active:
		return
	SaveManager.mark_intro_seen()
	_history = [Screen.TITLE, Screen.MAIN_MENU]
	goto(Screen.STAGE_SELECT, false)

func start_run(stage: int, endless := false) -> void:
	if screen_transition_active:
		return
	run_stage = stage
	run_endless = endless
	goto(Screen.RUN, false)
	run_requested.emit(stage, endless)

## ランを最後まで終えた。結果を保存して結果画面へ（仕様書 3）。
func finish_run(result: Dictionary) -> void:
	if not SaveManager.record_run(result): return
	last_result = result
	goto(Screen.RESULT, false)

## ランを途中でやめてメインメニューへ戻る。そのランの部品と記録は残さない（仕様書 3）。
func abort_run() -> void:
	var active: RunSession = RunManager.current()
	if active!=null and active.bridge!=null:
		var response: Dictionary = active.bridge.command("abort",{"reason":0})
		if response.ok:
			active.flush_cpp_result()
			return
	last_result = {}
	reset_to_main_menu()

## 結果画面の「もう一回やる」。
func retry_run() -> void:
	start_run(run_stage, run_endless)

func quit_game() -> void:
	get_tree().quit()

## C++の結果を、今の結果画面と永続保存の入力へ合わせる。
func finish_cpp_run(result: Dictionary) -> void:
	var id := int(result.get("result_id",0))
	if id<=0 or _accepted_cpp_results.has(id): return
	_accepted_cpp_results[id] = true
	if result.kind=="Abort":
		last_result = {}
		reset_to_main_menu()
		return
	var modules: Array[String] = []
	for reward: Dictionary in result.rewards:
		if int(reward.amount)>0: modules.append(str(reward.id))
	finish_run({"result_id":id,"kind":result.kind,"stage":str(result.stage_id).to_int(),"endless":result.get("endless",false),
		"cleared":result.kind=="Clear","time":result.run_time,"world_time":result.world_time,"kills":result.kills,
		"level":result.level,"coins":result.coins,"peak_speed":result.peak_speed,"modules":modules,
		"legendary":result.get("legendary",""),"weapons":result.weapons,"traits":result.traits,"last_damage":result.last_damage})
