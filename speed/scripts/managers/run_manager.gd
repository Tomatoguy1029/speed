## ランの窓口。Autoload（設計書 4.3）。
##
## 画面・実験場・道具からのランの開始・命令・終了を受け、id で RunSession へ振り分ける。
## 通常のゲームのランは「今のラン」として1つ持つ。実験場は独立したランを複数作る。
extends Node

var _sessions: Dictionary = {}
var _next_id := 1
## 通常のゲームの今のラン（なければ -1）
var current_id := -1

## 通常のゲームのランを作る。ステージとモードは GameManager の選択から読む。
## 返したセッションを、呼び出し側が画面として木に入れたあと start する。
func create_run() -> RunSession:
	var options := {"stage_index": GameManager.run_stage, "endless": GameManager.run_endless,
		"stage": ConfigManager.stage(GameManager.run_stage)}
	if OS.is_debug_build():
		options.start_time = GameManager.run_start_time
		options.start_source = GameManager.run_start_source
	GameManager.run_start_time = 0.0
	GameManager.run_start_source = "stage_start"
	var session := _register(RunSession.new())
	current_id = session.id
	session.add_to_group("recordable_runs")
	session.sim.finished.connect(GameManager.finish_run)
	session.sim.aborted.connect(GameManager.abort_run)
	session.ready.connect(func(): session.start(options, true), CONNECT_ONE_SHOT)
	return session

## 実験場・道具のランを作り、parent の下で始める。
func create_session(parent: Node, options: Dictionary, with_view: bool) -> RunSession:
	var session := _register(RunSession.new())
	parent.add_child(session)
	session.start(options, with_view)
	return session

## 通常のゲームの今のラン。
func current() -> RunSession:
	return _sessions.get(current_id)

func session(id: int) -> RunSession:
	return _sessions.get(id)

## 命令を渡す。破棄したランへの命令は無視する。
func command(id: int, name: StringName, args := {}) -> void:
	var s: RunSession = _sessions.get(id)
	if s != null:
		s.sim.command(name, args)

## RunSession が木から出るときに呼ぶ。
func unregister(s: RunSession) -> void:
	_sessions.erase(s.id)
	if current_id == s.id:
		current_id = -1

func _register(s: RunSession) -> RunSession:
	s.id = _next_id
	_next_id += 1
	_sessions[s.id] = s
	return s
