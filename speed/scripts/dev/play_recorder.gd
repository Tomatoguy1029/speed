## プレイの記録（開発版だけ。設計書 14.3）。Ctrl+F9 で記録を入・切し、プレイ中ならその場で開始する。
## 待機中に始めたランを、終わる（クリア・やられた・やめた）まで1つのファイルに書く。待機は Ctrl+F9 で切るまで続き、
## 次のランは別のファイルにする。実験場のランは記録しない。
## ファイルは書類フォルダの SPEED/recordings/stage<番号>_<日時>.jsonl。1行に1つの記録（JSON）で、メモリにためずに書き出す。
## 記録を閉じたら、保存したファイル名を画面の隅に少しのあいだ出す。性能は実時間窓で集約し、全フレームは保存しない。
extends Node

## まとめた数を書く間隔（ランの時計の秒）
const INTERVAL := 3.0
const PERF_INTERVAL_US := 3000000
## 保存したファイル名を出しておく時間（実秒）
const SAVED_NOTICE := 5.0
const IDENTITY := preload("res://scripts/dev/recording_identity.gd")
const Phase := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.Phase
var _real_start_us := 0

## 0=off, 1=action/damage, 2=decision candidates (default). Applied at recording start.
@export_range(0, 2) var combat_level := 2
@export var combat_events_per_second := 120
@export var combat_max_events := 30000
@export var combat_max_bytes := 33554432
const COMBAT_LINE_BYTES := 16384
const COMBAT_TYPES := ["boss_decision", "boss_action", "boss_effect", "boss_phase", "combat_damage"]
var _combat_config: Dictionary = {}
var _combat_emitted := 0
var _combat_bytes := 0
var _combat_rate_dropped := 0
var _combat_size_dropped := 0
var _combat_window := -1
var _combat_window_count := 0
var _combat_sequence_gaps := 0
var _combat_transport_missing := false
var _combat_effect_dropped_start := 0
var _ending := false
var _recording_id := ""
var _io_failed := false
var armed := false
## C++ランの通知と、録画区間の読み取り専用集計。
var _cpp_session_id := 0
var _cpp_time := 0.0
var _cpp_next_sample := 0.0
var _cpp_record_previous := {}
var _cpp_measurement_previous: Dictionary = {}
var _cpp_strong_finished: Dictionary = {}
var _cpp_event_sequence := 0
var _cpp_perf_previous := {}
var _cpp_perf_last_us := 0
var _cpp_perf_frames := 0
var _cpp_perf_elapsed_us := 0
var _cpp_perf_ui := {}
var _cpp_perf_playing := false
var _cpp_perf_bonus := false
## 記録中のランのセッション（木から出たら記録を閉じる）
var _session: RunSession = null
## 性能の区間のあいだに録画が書いた行数と、その時間（マイクロ秒）
var _self_lines := 0
var _self_write_us := 0
var _file: FileAccess = null
## 録画開始以前の供給を観測区間へ混ぜず、基準XPと実取得XPを別々に集計する。
var _xp_start_summary: Dictionary = {}
var _last_xp_summary: Dictionary = {}
var _label: Label
## 保存したファイル名の表示の残り時間と、その文字
var _saved_t := 0.0
var _saved_text := ""

## 記録を置くフォルダ（書類フォルダの SPEED/recordings。書類フォルダが分からなければユーザーデータの中）。
static func folder() -> String:
	var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if docs == "":
		return ProjectSettings.globalize_path("user://recordings")
	return docs.path_join("SPEED").path_join("recordings")

func _recording_directory() -> String:
	return folder()

func _ready() -> void:
	var level_setting := OS.get_environment("SPEED_COMBAT_LOG_LEVEL")
	if level_setting.is_valid_int(): combat_level = clampi(int(level_setting), 0, 2)
	if not OS.is_debug_build():
		set_process(false)
		set_process_input(false)
		return
	add_to_group("cpp_recorders")
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	preload("res://scripts/ui/canvas_order.gd").register(layer,2)
	_label = Label.new()
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = -360.0
	_label.offset_right = -10.0
	_label.offset_top = -26.0
	_label.offset_bottom = -6.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 0.8))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	layer.add_child(_label)

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	# Godot の埋め込み実行は F9/F10 を停止・コマ送りに使う。
	if not key.ctrl_pressed or key.alt_pressed or key.shift_pressed or key.meta_pressed:
		return
	if key.keycode == KEY_F9:
		_set_armed(not armed)
	elif key.keycode == KEY_F10 and armed:
		DirAccess.make_dir_recursive_absolute(folder())
		OS.shell_open(folder())

func _set_armed(on: bool) -> void:
	if on == armed:
		return
	armed = on
	if on:
		get_tree().node_added.connect(_on_node_added)
		for run in get_tree().get_nodes_in_group("recordable_runs"):
			if run.bridge!=null:
				_begin(run,true)
				if _cpp_session_id>0: break
			else: _on_node_added(run)
	else:
		if get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.disconnect(_on_node_added)
		_end("stopped")
	_update_label()

## ランのセッションが来たら、準備ができてから記録を始める。
func _on_node_added(node: Node) -> void:
	if node is RunSession:
		var callback := _begin.bind(node)
		if not node.started.is_connected(callback): node.started.connect(callback, CONNECT_ONE_SHOT)

func _begin(session: RunSession, during_run := false) -> void:
	if is_instance_valid(session) and session.bridge!=null:
		_begin_cpp(session,during_run)

func _xp_window(current: Dictionary, previous: Dictionary, scope: String) -> Dictionary:
	var out := {"scope": scope, "counter_color_basis": "supplied_before_absorption_collected_after_conversion"}
	for key in ["supplied", "collected", "lost", "gold_rolls"]:
		out[key] = _counter_difference(current.get(key, {}), previous.get(key, {}))
	out["collected_actual_xp"] = float(current.get("collected_actual_xp", 0.0)) - float(previous.get("collected_actual_xp", 0.0))
	for key in ["ground", "carried", "cap"]:
		out[key] = current.get(key, {})
	return out

func _counter_difference(current: Dictionary, previous: Dictionary) -> Dictionary:
	var out := {}
	for key in current:
		if current[key] is Dictionary:
			out[key] = _counter_difference(current[key], previous.get(key, {}))
		elif current[key] is int or current[key] is float:
			out[key] = current[key] - previous.get(key, 0)
	return out

func _base_xp_total(colors: Dictionary) -> float:
	var total := 0.0
	for item in colors.values():
		total += float(item.get("base_xp", 0.0))
	return total

## 空き枠は0段として、装備段数を設定上の全枠・全段で割る。選択回数・おまけとは分ける。
func _process(delta: float) -> void:
	if _saved_t > 0.0:
		_saved_t -= delta
		_update_label()
	if _cpp_session_id>0:
		_cpp_perf_tick(Time.get_ticks_usec())
		if _cpp_time>=_cpp_next_sample:
			_cpp_sample()
			_cpp_next_sample = _cpp_time+INTERVAL
		return
func _end(result: String) -> void:
	if _cpp_session_id>0 and not _ending:
		_ending = true
		if is_instance_valid(_session) and _session.bridge!=null:
			# 未通知の出来事、観測終了の出来事、終端の順に保存する。
			if not _session.bridge.collect_frame().ok: _combat_transport_missing = true
			if not _session.bridge.command("set_recording",{"active":false}).ok: _combat_transport_missing = true
			if not _session.bridge.collect_frame().ok: _combat_transport_missing = true
		_flush_cpp_performance()
		_cpp_sample()
		var ending := _cpp_record_previous.duplicate(true)
		ending.merge({"type":"end","run_id":_cpp_session_id,"recording_id":_recording_id,"t":_cpp_time,"result":result,
			"xp_reward_version":2,"xp_cumulative":_last_xp_summary,"xp_observed":_xp_window(_last_xp_summary,_xp_start_summary,"recording_total"),
			"combat_summary":_combat_summary()},true)
		ending.erase("xp")
		ending.erase("measurement_cumulative")
		ending.erase("strong_observations")
		_write(ending)
		_flush()
		_saved_text = "記録に失敗しました" if _io_failed else "保存："+_file.get_path().get_file()
		_saved_t = SAVED_NOTICE
		if _file!=null: _file.close()
		_file = null
		_cpp_session_id = 0
		if is_instance_valid(_session) and _session.bridge!=null:
			_session.bridge.unsubscribe("recorder:%d" % get_instance_id())
			if _session.bridge.before_restore.is_connected(_before_cpp_restore): _session.bridge.before_restore.disconnect(_before_cpp_restore)
		for c in _session.tree_exiting.get_connections() if is_instance_valid(_session) else []:
			if c.callable.get_object()==self: _session.tree_exiting.disconnect(c.callable)
		if is_instance_valid(_session) and _session.closing.is_connected(_end): _session.closing.disconnect(_end)
		_session = null
		_ending = false
		_update_label()
		return
func _write(record: Dictionary) -> void:
	if _file != null and not _io_failed:
		var t0 := Time.get_ticks_usec()
		var written := _write_line(record)
		# 録画そのものの重さ（書いた行数と、行を作って書く時間）
		if written: _self_lines += 1
		_self_write_us += Time.get_ticks_usec() - t0

func _write_line(record: Dictionary) -> bool:
	# 既存の区間行と出来事を同じ時計精度で並べる。
	if record.has("t"): record.t = _r(float(record.t))
	if _real_start_us > 0:
		if not record.has("real_t"):
			record.real_t = (Time.get_ticks_usec() - _real_start_us) / 1000000.0
	var line := JSON.stringify(record)
	var diagnostic: bool = record.get("type","") in COMBAT_TYPES
	var bytes := line.to_utf8_buffer().size()+1
	if diagnostic and not _reserve_combat(record,bytes): return false
	if not _store_line(line):
		_fail_io()
		return false
	if diagnostic:
		_combat_emitted += 1
		_combat_bytes += bytes
	return true

func _reset_combat_recording(state: Dictionary) -> void:
	_combat_config = {"level":clampi(combat_level,0,2),"events_per_second":clampi(combat_events_per_second,1,1000),
		"max_events":clampi(combat_max_events,1,1000000),"max_bytes":maxi(0,combat_max_bytes),"line_bytes":COMBAT_LINE_BYTES}
	_combat_emitted = 0
	_combat_bytes = 0
	_combat_rate_dropped = 0
	_combat_size_dropped = 0
	_combat_window = -1
	_combat_window_count = 0
	_combat_sequence_gaps = 0
	_combat_transport_missing = false
	_combat_effect_dropped_start = int(state.get("combat_diagnostics",{}).get("effect_tracking_dropped",0))
	_cpp_measurement_previous = {}
	_cpp_strong_finished = {}

func _reserve_combat(record: Dictionary, bytes: int) -> bool:
	if _combat_config.level==0 or (record.type=="boss_decision" and _combat_config.level<2): return false
	if bytes>_combat_config.line_bytes or _combat_bytes+bytes>_combat_config.max_bytes:
		_combat_size_dropped += 1
		return false
	var window := int((Time.get_ticks_usec()-_real_start_us)/1000000)
	if window!=_combat_window:
		_combat_window = window
		_combat_window_count = 0
	if _combat_window_count>=_combat_config.events_per_second or _combat_emitted>=_combat_config.max_events:
		_combat_rate_dropped += 1
		return false
	_combat_window_count += 1
	return true

func _combat_summary() -> Dictionary:
	var effect_dropped := maxi(0,int(_cpp_record_previous.get("combat_diagnostics",{}).get("effect_tracking_dropped",0))-_combat_effect_dropped_start)
	return {"emitted":_combat_emitted,"rate_or_count_dropped":_combat_rate_dropped,"size_dropped":_combat_size_dropped,
		"bytes":_combat_bytes,"sequence_gaps":_combat_sequence_gaps,"effect_tracking_dropped":effect_dropped,
		"transport_missing":_combat_transport_missing,"transport_complete":not _combat_transport_missing and not _io_failed and
			_combat_rate_dropped==0 and _combat_size_dropped==0 and _combat_sequence_gaps==0 and effect_dropped==0}

func _update_label() -> void:
	if _label == null:
		return
	_label.visible = armed or _saved_t > 0.0
	var text := "● REC 待機"
	if _saved_t > 0.0 and _cpp_session_id==0:
		text = _saved_text
	elif _cpp_session_id>0:
		var t := int(_cpp_time)
		text = "● REC %d:%02d" % [t / 60, t % 60]
	# 文字が変わったときだけ書き換える（毎フレーム書き換えると、文字の組み直しが毎回走る）
	if _label.text != text:
		_label.text = text

static func _r(v: float) -> float:
	return snappedf(v, 0.01)

func _open_failed() -> void:
	_session = null
	_saved_text = "記録ファイルを開けませんでした"
	_saved_t = SAVED_NOTICE
	push_warning(_saved_text)
	_update_label()

## Seams also allow deterministic short-write / flush-failure tests without a real full disk.
func _store_line(line: String) -> bool:
	return _file.store_line(line) and _file.get_error() == OK

func _flush_file() -> bool:
	_file.flush()
	return _file.get_error() == OK

func _flush() -> void:
	if _file != null and not _io_failed and not _flush_file(): _fail_io()

func _fail_io() -> void:
	if _io_failed: return
	_io_failed = true
	push_warning("プレイ記録の書き込みに失敗しました。記録を終了します。")
	call_deferred("_end", "io_error")

func _exit_tree() -> void:
	_end("quit")

## 記録中だけ購読し、ほかの購読者の通知の所有権を奪わない。
func attach_cpp(session: RunSession) -> void:
	if session.bridge!=null and _cpp_session_id==session.id:
		if not session.bridge.subscribe("recorder:%d" % get_instance_id(),consume_cpp_frame,["run_time","phase","presentation_frozen","bonus_remaining"]):
			_combat_transport_missing = true

func _before_cpp_restore() -> void:
	var session := _session
	if not is_instance_valid(session) or session.bridge==null: return
	session.bridge.restored.connect(_resume_cpp_recording.bind(session),CONNECT_ONE_SHOT)
	_end("restore")

func _resume_cpp_recording(session: RunSession) -> void:
	if armed and is_instance_valid(session) and session.bridge!=null:
		_begin_cpp(session,true)

func _begin_cpp(session: RunSession, during_run: bool) -> void:
	if not armed or _cpp_session_id==session.id or session.is_queued_for_deletion() or not session.is_in_group("recordable_runs"): return
	var snapshot: Dictionary = session.bridge.read_frame()
	if not snapshot.ok: return
	var state: Dictionary = session.bridge.read_recording(true)
	if not state.ok: return
	_end("quit")
	var directory := _recording_directory()
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:
		_open_failed()
		return
	var stamp := Time.get_datetime_string_from_system().replace(":","").replace("-","").replace("T","_")
	var base := directory.path_join("cpp_run%d_%s" % [session.id,stamp])
	var path := base+".jsonl"
	var suffix := 1
	while FileAccess.file_exists(path):
		path = "%s_%d.jsonl" % [base,suffix]
		suffix += 1
	_file = FileAccess.open(path,FileAccess.WRITE)
	if _file==null:
		_open_failed()
		return
	_session = session
	_cpp_session_id = session.id
	_reset_combat_recording(state.value)
	if not session.bridge.before_restore.is_connected(_before_cpp_restore): session.bridge.before_restore.connect(_before_cpp_restore)
	if not session.closing.is_connected(_end): session.closing.connect(_end)
	_cpp_time = snapshot.value.ui.run_time
	_cpp_perf_ui = snapshot.value.ui
	_cpp_perf_playing = _cpp_performance_playing()
	_cpp_perf_bonus = float(_cpp_perf_ui.get("bonus_remaining",0.0))>0.0
	_cpp_perf_previous = _cpp_metrics()
	_cpp_perf_last_us = Time.get_ticks_usec()
	_cpp_perf_frames = 0
	_cpp_perf_elapsed_us = 0
	_io_failed = false
	_real_start_us = Time.get_ticks_usec()
	_recording_id = "%d-%d" % [session.id,_real_start_us]
	_cpp_record_previous = state.value
	_xp_start_summary = state.value.xp.duplicate(true)
	_last_xp_summary = _xp_start_summary.duplicate(true)
	_cpp_next_sample = _cpp_time+INTERVAL
	_cpp_event_sequence = 0
	if during_run:
		_cpp_event_sequence = int(_cpp_perf_previous.get("events_emitted",0))
		for event: Dictionary in snapshot.value.events: _cpp_event_sequence = maxi(_cpp_event_sequence,int(event.sequence))
	attach_cpp(session)
	var identity: Dictionary = state.value.identity.duplicate(true)
	identity["implementation_revision"] = OS.get_environment("SPEED_BUILD_REVISION")
	identity["implementation_version"] = "cpp_api%d_state%d" % [identity.abi_version,identity.state_schema_version]
	identity["xp_reward_config_sha256"] = IDENTITY.digest(state.value.xp_config)
	var recording_start: Dictionary = state.value.duplicate(true)
	recording_start.erase("measurement_cumulative")
	recording_start.erase("strong_observations")
	_write({"type":"start","format":"cpp_events_v2","version":2,"schema_version":4,"measurement_version":3,"combat_version":1,"xp_reward_version":2,
		"stage":identity.stage_id,"start_time":_cpp_time,"run_id":session.id,"recording_id":_recording_id,"epoch":snapshot.value.epoch,"tick":snapshot.value.tick,
		"missing_prefix":during_run,"during_run":during_run,"event_sequence_at_start":_cpp_event_sequence,"engine_version":Engine.get_version_info().string,"interval":INTERVAL,
		"identity":identity,"run_start":session.bridge.recording_origin.duplicate(true),"recording_start":recording_start,
		"xp_config":state.value.xp_config,"xp_cumulative_at_start":_xp_start_summary,"equipment_progress":state.value.equipment_progress,
		"combat_config":_combat_config.duplicate(),"perf_excludes_ui_pause":true,"perf_interval_real":PERF_INTERVAL_US/1000000.0})
	if during_run:
		var existing: Dictionary = state.value.existing.duplicate(true)
		existing.merge({"type":"xp_existing","t":_cpp_time,"world_t":state.value.world_t,"xp_reward_version":2,"origin":"unobserved"},true)
		_write(existing)
	if not session.bridge.command("set_recording",{"active":not _io_failed,"level":_combat_config.level}).ok:
		_combat_transport_missing = true
	_flush()
	session.tree_exiting.connect(_end.bind("quit"))
	_update_label()

## 共通の封筒をそのまま保存し、他の購読者の通知列を消費しない。
func consume_cpp_frame(frame: Dictionary) -> bool:
	if _cpp_session_id==0 or frame.run_id!=_cpp_session_id: return true
	_cpp_time = frame.ui.run_time
	_cpp_perf_ui = frame.ui
	for event: Dictionary in frame.events:
		if int(event.sequence)<=_cpp_event_sequence: continue
		_combat_sequence_gaps += maxi(0,int(event.sequence)-_cpp_event_sequence-1)
		_cpp_event_sequence = int(event.sequence)
		var record: Dictionary = event.payload.duplicate(true)
		for key in ["epoch","sequence","tick","t","world_t","type"]: record[key] = event[key]
		record["run_id"] = frame.run_id
		record["recording_id"] = _recording_id
		_write(_cpp_record_value(record))
	_update_label()
	# 書込失敗は記録側で終了させる。同じ行の再試行で重複記録しない。
	return true

func _cpp_metrics() -> Dictionary:
	if _session==null or _session.bridge==null: return {}
	if _session.view!=null: return _session.view.get_node("RunPresentation").metrics_snapshot()
	var result: Dictionary = _session.bridge.read_metrics()
	return result.value if result.ok else {}

func _cpp_performance_playing() -> bool:
	return int(_cpp_perf_ui.get("phase",-1))==Phase.Play and not _cpp_perf_ui.get("presentation_frozen",true)

func _cpp_perf_tick(now: int) -> void:
	var playing := _cpp_performance_playing()
	var bonus := float(_cpp_perf_ui.get("bonus_remaining",0.0))>0.0
	if playing!=_cpp_perf_playing or bonus!=_cpp_perf_bonus:
		if playing and _cpp_perf_playing and _cpp_perf_last_us>0:
			_cpp_perf_elapsed_us += maxi(0,now-_cpp_perf_last_us)
			_cpp_perf_frames += 1
		_flush_cpp_performance()
		# 停止中の表示処理と実時間を、次の戦闘区間へ持ち込まない。
		_cpp_perf_previous = _cpp_metrics()
		_cpp_perf_frames = 0
		_cpp_perf_elapsed_us = 0
		_cpp_perf_playing = playing
		_cpp_perf_bonus = bonus
		_cpp_perf_last_us = now
		return
	if playing and _cpp_perf_last_us>0:
		_cpp_perf_elapsed_us += maxi(0,now-_cpp_perf_last_us)
		_cpp_perf_frames += 1
	_cpp_perf_last_us = now
	if _cpp_perf_elapsed_us>=PERF_INTERVAL_US: _flush_cpp_performance()

func _flush_cpp_performance() -> void:
	if _cpp_perf_frames==0 or _session==null: return
	var current := _cpp_metrics()
	if current.is_empty(): return
	var profile := preload("res://scripts/runtime/run_metrics.gd").window(current,_cpp_perf_previous,_cpp_perf_frames,_cpp_perf_elapsed_us)
	_write({"type":"performance","run_id":_cpp_session_id,"recording_id":_recording_id,"t":_cpp_time,"bonus":_cpp_perf_bonus,"frames":_cpp_perf_frames,"profile":profile})
	_cpp_perf_previous = current
	_cpp_perf_frames = 0
	_cpp_perf_elapsed_us = 0

## 定期記録では集計だけを読み、個々の結晶は途中開始時に一度だけ写す。
func _cpp_sample() -> void:
	if _session==null or _session.bridge==null: return
	var response: Dictionary = _session.bridge.read_recording()
	if not response.ok:
		_combat_transport_missing = true
		return
	var current: Dictionary = response.value
	var window := _xp_window(current.xp,_last_xp_summary,"recording_interval")
	var record: Dictionary = current.duplicate(true)
	var measured: Dictionary = current.get("measurement_cumulative",{})
	for key in ["effective_damage","enemy_life","enemy_contacts"]:
		record[key] = _measurement_rows(measured.get(key,{}),_cpp_measurement_previous.get(key,{}))
	for key in ["kills","kills_by","dealt","damage"]:
		record[key] = _counter_difference(measured.get(key,{}),_cpp_measurement_previous.get(key,{}))
	var budget_max := float(current.get("attack_budget_used",0.0))
	var budget_changes := _counter_difference(measured.get("budget_observations",{}),_cpp_measurement_previous.get("budget_observations",{}))
	for cost in budget_changes:
		if budget_changes[cost]>0: budget_max = maxf(budget_max,float(cost))
	record["attack_budget_max"] = budget_max
	record.erase("measurement_cumulative")
	record.erase("strong_observations")
	record.merge({"type":"sample","run_id":_cpp_session_id,"recording_id":_recording_id,"xp_reward_version":2,"xp":window,
		"xp_picked_actual":window.collected_actual_xp,"xp_dropped_base":_base_xp_total(window.supplied),"xp_field_base":_base_xp_total(window.ground)},true)
	_write(record)
	_write_cpp_strong(current,_ending)
	_cpp_measurement_previous = measured.duplicate(true)
	_last_xp_summary = current.xp.duplicate(true)
	_cpp_record_previous = current

func _measurement_rows(current: Dictionary, previous: Dictionary) -> Array:
	var rows := []
	for key in current:
		var row := _counter_difference(current[key],previous.get(key,{}))
		if not row.values().any(func(value): return value!=0): continue
		for field in ["weapon_id","enemy","class","elite","cause","source","reason"]:
			if current[key].has(field): row[field] = current[key][field]
		rows.append(row)
	return rows

func _write_cpp_strong(current: Dictionary, include_alive: bool) -> void:
	var observations: Dictionary = current.get("strong_observations",{})
	for id in observations:
		if _cpp_strong_finished.has(id): continue
		var row: Dictionary = observations[id].duplicate(true)
		if row.result=="alive" and not include_alive: continue
		row.merge({"type":"strong","run_id":_cpp_session_id,"recording_id":_recording_id,"t":_cpp_time,"world_t":current.world_t,"id":id},true)
		_write(row)
		_cpp_strong_finished[id] = true

static func _cpp_record_value(value: Variant) -> Variant:
	if value is Vector2: return [value.x,value.y]
	if value is Color: return [value.r,value.g,value.b,value.a]
	if value is Dictionary:
		var out := {}
		for key in value: out[String(key)] = _cpp_record_value(value[key])
		return out
	if value is Array or value is PackedVector2Array:
		var out := []
		for item in value: out.append(_cpp_record_value(item))
		return out
	return value
