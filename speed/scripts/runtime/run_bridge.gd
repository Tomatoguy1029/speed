## Sessionが所有するC++ランの窓口。個別Systemの更新は公開しない。
extends RefCounted
signal before_restore
signal restored
const Phase := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.Phase
var perf := PerfLog.new()
var _core: RefCounted
var _busy := false
var _disposed := false
var _closing := false
var _run_id := 0
var _epoch := 1
var _next_command := 1
var _development := false
var _subscribers: Dictionary = {}
var _latest: Dictionary = {}
var _ui: Dictionary = {}
var _delivery: Dictionary = {}
var delivery_error: Dictionary = {}
var _metrics_record := {}
var _metrics_bytes := 0
var _latest_bytes := 0
var _delivery_bytes := 0
var _delivery_sizes := {}
var _resource_wait_started := 0
var recording_origin := {}

static func _error(code: int, field: String, message: String) -> Dictionary:
	return {"ok":false,"code":code,"field":field,"message":message,"value":null}
static func _ok(value = null) -> Dictionary:
	return {"ok":true,"code":0,"field":"","message":"","value":value}

func configure(bytes: PackedByteArray, options: Dictionary) -> Dictionary:
	if _disposed: return _error(4,"configure","破棄済みの窓口です")
	if _busy: return _error(7,"configure","更新中は再入できません")
	if _core == null:
		if not ClassDB.class_exists(&"SpeedRunCore"): return _error(2,"extension","C++拡張を読み込めません")
		_core = ClassDB.instantiate(&"SpeedRunCore")
	if not _core.has_method(&"frame_snapshot_run"):
		_core = null
		return _error(2,"extension","C++拡張を現在のコードでビルドしてください")
	_busy = true
	var result: Dictionary = _core.configure_run(bytes,options)
	_busy = false
	if result.ok:
		_run_id = options.run_id
		_epoch = result.value.epoch
		_development = options.mode == 1
		recording_origin = {"options":options.duplicate(true),"payload_sha256":result.value.bundle_hash}
		_metrics_record = perf.open(&"metrics")
	return result

func start(seed_value: int, options := {}) -> Dictionary:
	if _closing: return _error(4,"session","終了処理中です")
	if _busy: return _error(7,"start","更新中は再入できません")
	if _core == null: return _error(4,"start","設定前です")
	_busy = true
	var result: Dictionary = _core.start_run(seed_value,options)
	_busy = false
	if result.ok: recording_origin["start"] = {"seed":str(seed_value),"options":options.duplicate(true)}
	return result

func read_recording(initial := false) -> Dictionary:
	if _busy: return _error(7,"recording","更新中は読めません")
	if _core==null: return _error(4,"recording","破棄済みです")
	return _core.recording_run(initial)

static func pack_intent(intent: Intent) -> Dictionary:
	return {"has_cursor":intent.has_cursor,"cursor":intent.cursor,"stick":intent.stick,"stick_active":intent.stick_active,
		"pen":intent.pen,"press":intent.press,"alt_press":intent.alt_press,"hero_press":intent.hero_press,
		"pen_release":intent.pen_release,"touch":intent.touch,"finale_pressed":intent.press,
		"finale_released":intent.pen_release,"finale_pen":intent.pen}

func step(dt: float, input: Dictionary, viewport: Dictionary) -> Dictionary:
	if _closing: return _error(4,"session","終了処理中です")
	if _busy: return _error(7,"step","更新中は再入できません")
	if _core == null: return _error(4,"step","設定前または破棄済みです")
	_busy = true
	var began := Time.get_ticks_usec() if perf.active else 0
	var result: Dictionary = _core.step_run(dt,input,viewport)
	perf.since(&"sim",began)
	if result.ok: _collect_locked(false)
	_busy = false
	return result

## 押下を消費するpollも再入防止の範囲内で一度だけ呼ぶ。
func poll_and_step(dt: float, source: Callable, logical_size: Vector2) -> Dictionary:
	if _closing: return _error(4,"session","終了処理中です")
	if _busy: return _error(7,"input","入力の取得中は再入できません")
	if _core == null: return _error(4,"input","破棄済みです")
	_busy = true
	if not source.is_valid():
		_busy = false
		return _error(1,"input","入力元がありません")
	# 成功した更新と命令の出力を既に保持している。入力には可否と描線中だけを読む。
	# 初回・復帰直後・配信失敗では従来どおり本体から読み直す。
	var frame: Dictionary = _read_locked(false) if _latest.is_empty() or (not delivery_error.is_empty() and not delivery_error.ok) else _ok(_latest)
	var router := source.get_object() as InputRouter
	if router!=null and frame.ok: router.drawing = frame.value.ui.draw.drawing
	var intent = source.call() if frame.ok and frame.value.ui.input_enabled else Intent.new()
	if not intent is Intent:
		_busy = false
		return _error(1,"input","Intentを返す入力元を指定してください")
	var began := Time.get_ticks_usec() if perf.active else 0
	var result: Dictionary = _core.step_run(dt,pack_intent(intent),{"logical_size":logical_size})
	perf.since(&"sim",began)
	if result.ok: _collect_locked(false)
	_busy = false
	return result

func _recording_stop(kind: String, payload: Dictionary) -> bool:
	return kind == "set_recording" and payload.size() == 1 and payload.get("active") is bool and payload.active == false

func command(kind: String, payload := {}) -> Dictionary:
	if _closing and not _recording_stop(kind,payload): return _error(4,"session","終了処理中です")
	if _busy: return _error(7,"command","更新中は再入できません")
	if _next_command == 9223372036854775807: return _error(9,"command_id","命令番号が上限です")
	var envelope := {"run_id":_run_id,"epoch":_epoch,"command_id":_next_command,"kind":kind,"payload":payload}
	_next_command += 1
	return send_envelope(envelope)

## 単独ボス制作試行も、通常の命令番号・版・再入検査へ通す。
func boss_trial(entity_id: int, action: String, fields: Dictionary = {}) -> Dictionary:
	if fields.has("entity_id") or fields.has("action"): return _error(1,"boss_trial","試行対象と操作は専用の引数で指定してください")
	var payload := fields.duplicate(true)
	payload.entity_id = entity_id
	payload.action = action
	return command("dev_boss_trial",payload)

func send_envelope(envelope: Dictionary) -> Dictionary:
	if _closing and (not envelope.get("payload",{}) is Dictionary or not _recording_stop(str(envelope.get("kind","")),envelope.get("payload",{}))): return _error(4,"session","終了処理中です")
	if _busy: return _error(7,"command","更新中は再入できません")
	if _core == null: return _error(4,"command","破棄済みです")
	_busy = true
	var result: Dictionary = _core.command_run(envelope)
	if result.ok: _collect_locked(false)
	_busy = false
	if result.ok and envelope.get("run_id") == _run_id and envelope.get("epoch") == _epoch and envelope.get("command_id",0) < 9223372036854775807:
		_next_command = maxi(_next_command,int(envelope.command_id)+1)
	return result

func read_render(view: Rect2, alpha := 1.0) -> Dictionary:
	if _busy: return _error(7,"read_render","更新中は再入できません")
	if _core==null: return _error(4,"read_render","破棄済みです")
	var began := Time.get_ticks_usec() if perf.active else 0
	var result: Dictionary = _core.render_run(view,alpha)
	perf.since(&"output_build",began)
	if result.ok: _metrics_bytes += _packed_bytes(result.value)
	return result

func read_frame() -> Dictionary:
	if _busy: return _error(7,"read_frame","更新中は再入できません")
	return _read_locked() if _core != null else _error(4,"read_frame","破棄済みです")

func read_lab() -> Dictionary:
	if _busy: return _error(7,"lab","更新中は実験の状態を読めません")
	if _core==null: return _error(4,"lab","開始していないランです")
	return _core.lab_state_run()

func read_encounter() -> Dictionary:
	if _busy: return _error(7,"encounter","更新中は配置の状態を読めません")
	if _core==null: return _error(4,"encounter","開始していないランです")
	return _core.encounter_state_run()

func query_route(points: PackedVector2Array, parameters := {}) -> Dictionary:
	if _busy: return _error(7,"route","更新中は経路を判定できません")
	if _core==null: return _error(4,"route","開始していないランです")
	return _core.query_route_run(points,parameters)

## 編集の間だけ停止し、編集直前の版を照合する。固定tickと元の停止状態を保つ。
## replacementは通常生成器が検証した戦闘バイナリで、ResourceをC++へ渡さない。
func replace_definition(definition_id: String, replacement: PackedByteArray, edit_kind := "parameter") -> Dictionary:
	var frame := read_frame()
	if not frame.ok: return frame
	var was_paused: bool = frame.value.ui.phase==Phase.Paused
	if not was_paused:
		var paused := command("pause",{"paused":true})
		if not paused.ok: return paused
	frame = read_frame()
	var result := command("dev_edit",{"kind":edit_kind,"payload":{"definition_id":definition_id,"expected_revision":frame.value.state_revision,"replacement":replacement}}) if frame.ok else frame
	if not was_paused:
		var resumed := command("pause",{"paused":false})
		if result.ok and not resumed.ok: return resumed
	return result

## 制作中の配置・時間帯も、生成と現在版を照合して一度で適用する。
func replace_scenario(kind: String, params: Dictionary, replacement: PackedByteArray) -> Dictionary:
	var frame := read_frame()
	if not frame.ok: return frame
	var paused: bool = frame.value.ui.phase==Phase.Paused
	if not paused:
		var stopped := command("pause",{"paused":true})
		if not stopped.ok: return stopped
	frame = read_frame()
	var payload: Dictionary = params.duplicate(true)
	payload.replacement = replacement
	payload.expected_revision = frame.value.state_revision if frame.ok else -1
	var result := command("dev_set_scenario",{"kind":kind,"params":payload}) if frame.ok else frame
	if not paused:
		var resumed := command("pause",{"paused":false})
		if result.ok and not resumed.ok: return resumed
	return result

func checkpoint() -> Dictionary:
	if _closing: return _error(4,"session","終了処理中です")
	if _busy: return _error(7,"checkpoint","更新中は保持できません")
	if _core == null or not _development: return _error(4,"checkpoint","開発中のランだけを保持できます")
	var id: int = _core.hold_checkpoint()
	return _ok(id) if id>0 else _error(8,"checkpoint","状態の保持に失敗しました")

func restore(id: int) -> Dictionary:
	if _closing: return _error(4,"session","終了処理中です")
	if _busy: return _error(7,"restore","更新中は復帰できません")
	if _core == null or not _development: return _error(4,"restore","開発中のランだけ復帰できます")
	before_restore.emit()
	if not _core.restore_checkpoint(id):
		restored.emit()
		return _error(5,"checkpoint","保持点がありません")
	_epoch = _core.current_epoch()
	_next_command = 1
	_ui = {}
	_latest = {}
	_latest_bytes = 0
	_delivery_bytes = 0
	_delivery_sizes = {}
	_delivery = {}
	delivery_error = {}
	restored.emit()
	return _ok({"epoch":_epoch})

func release_checkpoint(id: int) -> Dictionary:
	if _busy: return _error(7,"release_checkpoint","更新中は解除できません")
	if _core == null or not _development: return _error(4,"checkpoint","開発中のランだけ解除できます")
	return _ok() if _core.release_checkpoint(id) else _error(5,"checkpoint","保持点がありません")

## 記録の終端を届ける間は読取だけを許す。
func begin_close() -> Dictionary:
	if _busy: return _error(7,"close","配信中は終了処理を始められません")
	_closing = true
	return _ok()

func dispose() -> Dictionary:
	if _busy: return _error(7,"dispose","更新中は破棄できません")
	if _core == null:
		_disposed = true
		return _ok()
	var result: Dictionary = _core.dispose_run()
	if result.ok:
		_core = null
		_subscribers.clear()
		_latest = {}
		_latest_bytes = 0
		_delivery_bytes = 0
		_delivery_sizes = {}
		_ui = {}
		_delivery = {}
		_disposed = true
	return result

## 現在UIは窓口だけが所有する。外側へ戦闘の可変参照を渡さない。
func _read_locked(public_copy := true) -> Dictionary:
	var began := Time.get_ticks_usec() if perf.active else 0
	var result: Dictionary = _core.frame_snapshot_run()
	perf.since(&"output_build",began)
	began = Time.get_ticks_usec() if perf.active else 0
	if not result.ok: return result
	preload("res://scripts/runtime/post_max_card_view.gd").format_frame(result.value)
	for event: Dictionary in result.value.events:
		if event.type=="text":
			var entry: ContentEntry = ContentManager.catalog.find(&"weapons",StringName(event.payload.get("text","")))
			if entry!=null: event.payload.text = entry.get_display_name()
	# 完全読取なのでUI全体を置き換える。再送中の古い封筒は書き換えない。
	_ui = result.value.ui
	# 本体が返した外側DictionaryとUIは窓口だけが所有する。
	# 公開読取と各購読者への深い複製は返却/配信の境界で行う。
	_latest = result.value
	_latest.ui = _ui
	_latest_bytes = _packed_bytes(_latest)
	perf.since(&"bridge_copy",began)
	return _copy_latest() if public_copy else _ok(_latest)

func _copy_latest() -> Dictionary:
	var began := Time.get_ticks_usec() if perf.active else 0
	var snapshot := _ok(_latest.duplicate(true))
	_metrics_bytes += _latest_bytes
	perf.since(&"bridge_copy",began)
	return snapshot

func latest_frame() -> Dictionary:
	if _busy: return _error(7,"latest_frame","配信中は読めません")
	if _core==null: return _error(4,"latest_frame","破棄済みです")
	if _latest.is_empty(): return read_frame()
	return _copy_latest()

func read_metrics() -> Dictionary:
	if _busy: return _error(7,"read_metrics","更新中は読めません")
	if _core==null: return _error(4,"read_metrics","破棄済みです")
	var result: Dictionary = _core.metrics_run()
	if result.ok:
		var timing: Dictionary = result.value.timings
		result.value["clocks"] = _core.inspect()
		timing["bridge_copy"] = _metrics_record.get(&"bridge_copy",[0,0,0]).duplicate()
		var wait: Array = _metrics_record.get(&"resource_wait",[0,0,0]).duplicate()
		if _resource_wait_started>0:
			var current := Time.get_ticks_usec()-_resource_wait_started
			wait[0] += current
			wait[2] = maxi(wait[2],current)
		timing["resource_wait"] = wait
		result.value["packed_bytes"] = _metrics_bytes
		result.value["packed_bytes_kind"] = "logical_payload"
	return result

func begin_resource_wait() -> void:
	if _resource_wait_started==0: _resource_wait_started = Time.get_ticks_usec()

func end_resource_wait() -> void:
	if _resource_wait_started==0: return
	perf.add(&"resource_wait",Time.get_ticks_usec()-_resource_wait_started)
	_resource_wait_started = 0

## Packed配列の論理量。参照共有やエンジン内部の物理コピー量は含めない。
func _packed_bytes(value: Variant) -> int:
	return _core.packed_payload_bytes(value)

func ack_frame(epoch: int, sequence: int) -> Dictionary:
	if _busy: return _error(7,"ack_frame","配信中は受領できません")
	return _core.ack_frame_run(epoch,sequence) if _core!=null else _error(4,"ack_frame","破棄済みです")

## 項目の省略は全件、空配列は受信なし。通知を選んでも受領は元の通知列を基準にする。
func subscribe(name: String, consumer: Callable, ui_fields: Variant = null, event_types: Variant = null) -> bool:
	if _busy or _disposed or name.is_empty() or not consumer.is_valid() or _subscribers.has(name): return false
	var selections := []
	for requested: Variant in [ui_fields,event_types]:
		var fields: Variant=null
		if requested!=null:
			if not requested is Array and not requested is PackedStringArray: return false
			fields=PackedStringArray()
			for key: Variant in requested:
				if not key is String and not key is StringName: return false
				if str(key).is_empty(): return false
				if str(key) not in fields: fields.append(str(key))
		selections.append(fields)
	_subscribers[name] = {"consumer":consumer,"ui_fields":selections[0],"event_types":selections[1],"epoch":0,"sequence":0,"revision":-1}
	_delivery_sizes.erase(name)
	return true

func unsubscribe(name: String) -> bool:
	if _busy: return false
	_delivery_sizes.erase(name)
	return _subscribers.erase(name)

## 更新の成功と配信の成功を分ける。配信だけ失敗してもstepを再実行しない。
func collect_frame() -> Dictionary:
	if _busy: return _error(7,"collect_frame","配信中は再入できません")
	if _core==null: return _error(4,"collect_frame","破棄済みです")
	_busy = true
	var result := _collect_locked()
	_busy = false
	return result

## コピーする前にUIと通知を選ぶ。通知の順序と、結果・資源要求を含む共通の封筒を保つ。
func _copy_delivery(fields: Variant, event_types: Variant) -> Dictionary:
	if fields==null and event_types==null: return _delivery.duplicate(true)
	var source: Dictionary=_delivery.duplicate()
	if fields!=null:
		var selected := {}
		for key: String in fields:
			if _delivery.ui.has(key): selected[key]=_delivery.ui[key]
		source.ui=selected
	if event_types!=null:
		var selected_events := []
		if not event_types.is_empty():
			for event: Dictionary in _delivery.events:
				if str(event.type) in event_types: selected_events.append(event)
		source.events=selected_events
	return source.duplicate(true)

func _delivery_size(name: String, receiver: Dictionary, packet: Dictionary) -> int:
	if receiver.ui_fields==null and receiver.event_types==null: return _delivery_bytes
	if not _delivery_sizes.has(name): _delivery_sizes[name]=_packed_bytes(packet)
	return int(_delivery_sizes[name])

func _deliver_locked() -> Dictionary:
	var sequence: int = _delivery.events.back().sequence if not _delivery.events.is_empty() else 0
	for name: String in _subscribers:
		var receiver: Dictionary = _subscribers[name]
		if receiver.epoch==_delivery.epoch and receiver.sequence>=sequence and receiver.revision>=_delivery.state_revision: continue
		var began := Time.get_ticks_usec() if perf.active else 0
		var packet: Dictionary = _copy_delivery(receiver.ui_fields,receiver.event_types)
		_metrics_bytes += _delivery_size(name,receiver,packet)
		perf.since(&"bridge_copy",began)
		if not receiver.consumer.is_valid() or receiver.consumer.call(packet)!=true:
			return _error(8,"subscriber", "通知を受け取れません: %s" % name)
		receiver.epoch = _delivery.epoch
		receiver.sequence = sequence
		receiver.revision = _delivery.state_revision
	if sequence>0:
		var response: Dictionary = _core.ack_frame_run(_delivery.epoch,sequence)
		if not response.ok: return response
	_delivery = {}
	return _ok()

func _collect_locked(public_copy := true) -> Dictionary:
	if not _delivery.is_empty():
		delivery_error = _deliver_locked()
		if not delivery_error.ok: return delivery_error
	var snapshot := _read_locked(false)
	if not snapshot.ok:
		delivery_error = snapshot
		return snapshot
	if _subscribers.is_empty(): return _copy_latest() if public_copy else _ok()
	_delivery = snapshot.value
	_delivery_bytes = _latest_bytes
	_delivery_sizes = {}
	delivery_error = _deliver_locked()
	if not delivery_error.ok: return delivery_error
	return _copy_latest() if public_copy else _ok()
