## ランの窓口。Autoload（設計書 4.3）。
##
## 画面・実験場・道具からのランの開始・命令・終了を受け、id で RunSession へ振り分ける。
## 通常のゲームのランは「今のラン」として1つ持つ。実験場は独立したランを複数作る。
extends Node

signal session_created(session: RunSession)

var _sessions: Dictionary = {}
var _next_id := 1
## 通常のゲームの今のラン（なければ -1）
var current_id := -1

## 通常のゲームのランを作る。ステージとモードは GameManager の選択から読む。
## 資源の読み込みを開始して返す。呼び出し側が木へ入れると描画の準備を進める。
func create_run() -> RunSession:
	var before := Time.get_ticks_usec()
	var options := {"stage_index": GameManager.run_stage, "endless": GameManager.run_endless,
		"stage": ContentManager.runtime_stage(GameManager.run_stage), "profile": ProfileManager.for_run(false)}
	if OS.is_debug_build():
		options.start_time = GameManager.run_start_time
		options.start_source = GameManager.run_start_source
	GameManager.run_start_time = 0.0
	GameManager.run_start_source = "stage_start"
	var session := _register(RunSession.new(), options)
	session.loading_timings["stage_and_profile_ms"] = (Time.get_ticks_usec() - before) / 1000.0
	current_id = session.id
	session.sim.finished.connect(GameManager.finish_run)
	session.sim.aborted.connect(GameManager.abort_run)
	# 暗転中にもI/Oを進める。描画準備は木に入ってから行う。
	session.start_loading(options)
	return session

## 実験場・道具のランを作り、parent の下で始める。
func create_session(parent: Node, options: Dictionary, with_view: bool) -> RunSession:
	var session := _register(RunSession.new(), options)
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
	if _sessions.is_empty(): ContentManager.release_runtime_definitions()
	if current_id == s.id:
		current_id = -1

func _register(s: RunSession, options: Dictionary) -> RunSession:
	s.sim.options = options
	s.id = _next_id
	_next_id += 1
	_sessions[s.id] = s
	session_created.emit(s)
	return s
