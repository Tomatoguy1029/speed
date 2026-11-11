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
func create_run(overrides := {}) -> RunSession:
	var before := Time.get_ticks_usec()
	var prepared := GameManager.run_start_content.duplicate(true)
	var start_time := GameManager.run_start_time
	var source := GameManager.run_start_source
	var timeline := OS.is_debug_build() and source == "timeline"
	if not timeline:
		var path := "res://.content/run/stage_%d.json" % GameManager.run_stage
		var index = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		prepared = {"index":path,"signature":index.get("input_sha256","")} if index is Dictionary else {}
	GameManager.run_start_time = 0.0
	GameManager.run_start_source = "stage_start"
	GameManager.run_start_content = {}
	var options := {"runtime":"cpp","cpp_index":prepared.get("index",""),"cpp_signature":prepared.get("signature",""),
		"cpp_profile":ProfileManager.for_cpp(false),"seed":randi(),"endless":GameManager.run_endless,"cpp_source":source,
		"cpp_start":{"equipment":[],"lab_mode":false}}
	if OS.is_debug_build() and overrides.get("seed") is int: options.seed = overrides.seed
	# 操作練習は、ステージ1の通常の出撃で、まだ終えていないときだけ付ける。
	if not timeline and GameManager.run_stage == 1 and not GameManager.run_endless and not SaveManager.has_done_tutorial():
		options.cpp_start.tutorial = true
	if timeline: options.cpp_start.scenario = {"kind":"timeline","params":{"time":start_time}}
	var session := _register(RunSession.new(),options)
	session.loading_timings["stage_and_profile_ms"] = (Time.get_ticks_usec()-before)/1000.0
	current_id = session.id
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
		if s.bridge != null: s.bridge.command(String(name),args)

## RunSession が木から出るときに呼ぶ。
func unregister(s: RunSession) -> void:
	_sessions.erase(s.id)
	if _sessions.is_empty(): ContentManager.release_runtime_definitions()
	if current_id == s.id:
		current_id = -1

func _register(s: RunSession, options: Dictionary) -> RunSession:
	s.id = _next_id
	_next_id += 1
	_sessions[s.id] = s
	session_created.emit(s)
	return s

## 手動で作ったSessionも同じ単調なランIDへ登録する。
func ensure_registered(s: RunSession) -> bool:
	if s.id>0: return _sessions.get(s.id)==s
	if _next_id<=0 or _next_id==9223372036854775807: return false
	return _register(s,{"runtime":"cpp"})!=null
