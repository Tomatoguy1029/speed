## Sessionが所有するC++ランの窓口。個別Systemの更新は公開しない。
extends RefCounted
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
	_busy = true
	var result: Dictionary = _core.configure_run(bytes,options)
	_busy = false
	if result.ok:
		_run_id = options.run_id
		_epoch = result.value.epoch
		_development = options.mode == 1
	return result

func start(seed_value: int, options := {}) -> Dictionary:
	if _closing: return _error(4,"session","終了処理中です")
	if _busy: return _error(7,"start","更新中は再入できません")
	if _core == null: return _error(4,"start","設定前です")
	_busy = true
	var result: Dictionary = _core.start_run(seed_value,options)
	_busy = false
	return result

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
	if result.ok: _collect_locked()
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
	var frame: Dictionary = _read_locked()
	var router := source.get_object() as InputRouter
	if router!=null and frame.ok: router.drawing = frame.value.ui.draw.drawing
	var intent = source.call() if frame.ok and frame.value.ui.input_enabled else Intent.new()
	if not intent is Intent:
		_busy = false
		return _error(1,"input","Intentを返す入力元を指定してください")
	var began := Time.get_ticks_usec() if perf.active else 0
	var result: Dictionary = _core.step_run(dt,pack_intent(intent),{"logical_size":logical_size})
	perf.since(&"sim",began)
	if result.ok: _collect_locked()
	_busy = false
	return result

func command(kind: String, payload := {}) -> Dictionary:
	if _closing: return _error(4,"session","終了処理中です")
	if _busy: return _error(7,"command","更新中は再入できません")
	if _next_command == 9223372036854775807: return _error(9,"command_id","命令番号が上限です")
	var envelope := {"run_id":_run_id,"epoch":_epoch,"command_id":_next_command,"kind":kind,"payload":payload}
	_next_command += 1
	return send_envelope(envelope)

func send_envelope(envelope: Dictionary) -> Dictionary:
	if _closing: return _error(4,"session","終了処理中です")
	if _busy: return _error(7,"command","更新中は再入できません")
	if _core == null: return _error(4,"command","破棄済みです")
	_busy = true
	var result: Dictionary = _core.command_run(envelope)
	if result.ok: _collect_locked()
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
	return result

func read_frame() -> Dictionary:
	if _busy: return _error(7,"read_frame","更新中は再入できません")
	return _read_locked() if _core != null else _error(4,"read_frame","破棄済みです")

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
	if not _core.restore_checkpoint(id): return _error(5,"checkpoint","保持点がありません")
	_epoch = _core.current_epoch()
	_next_command = 1
	_ui = {}
	_latest = {}
	_delivery = {}
	delivery_error = {}
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
		_ui = {}
		_delivery = {}
		_disposed = true
	return result

## UIの差分は窓口内で合成する。外側へ戦闘の可変参照を渡さない。
func _read_locked() -> Dictionary:
	var began := Time.get_ticks_usec() if perf.active else 0
	var result: Dictionary = _core.frame_run()
	perf.since(&"output_build",began)
	began = Time.get_ticks_usec() if perf.active else 0
	if not result.ok: return result
	if not _latest.is_empty() and _latest.epoch!=result.value.epoch: _ui = {}
	_ui.merge(result.value.ui,true)
	_latest = result.value.duplicate(true)
	_latest.ui = _ui.duplicate(true)
	var snapshot := _ok(_latest.duplicate(true))
	perf.since(&"bridge_copy",began)
	return snapshot

func latest_frame() -> Dictionary:
	if _busy: return _error(7,"latest_frame","配信中は読めません")
	if _core==null: return _error(4,"latest_frame","破棄済みです")
	if _latest.is_empty(): return read_frame()
	var began := Time.get_ticks_usec() if perf.active else 0
	var snapshot := _ok(_latest.duplicate(true))
	perf.since(&"bridge_copy",began)
	return snapshot

func read_metrics() -> Dictionary:
	if _busy: return _error(7,"read_metrics","更新中は読めません")
	return _core.metrics_run() if _core!=null else _error(4,"read_metrics","破棄済みです")

func ack_frame(epoch: int, sequence: int) -> Dictionary:
	if _busy: return _error(7,"ack_frame","配信中は受領できません")
	return _core.ack_frame_run(epoch,sequence) if _core!=null else _error(4,"ack_frame","破棄済みです")

func subscribe(name: String, consumer: Callable) -> bool:
	if _busy or _disposed or name.is_empty() or not consumer.is_valid() or _subscribers.has(name): return false
	_subscribers[name] = {"consumer":consumer,"epoch":0,"sequence":0,"revision":-1}
	return true

func unsubscribe(name: String) -> bool:
	if _busy: return false
	return _subscribers.erase(name)

## 更新の成功と配信の成功を分ける。配信だけ失敗してもstepを再実行しない。
func collect_frame() -> Dictionary:
	if _busy: return _error(7,"collect_frame","配信中は再入できません")
	if _core==null: return _error(4,"collect_frame","破棄済みです")
	_busy = true
	var result := _collect_locked()
	_busy = false
	return result

func _deliver_locked() -> Dictionary:
	var sequence: int = _delivery.events.back().sequence if not _delivery.events.is_empty() else 0
	for name: String in _subscribers:
		var receiver: Dictionary = _subscribers[name]
		if receiver.epoch==_delivery.epoch and receiver.sequence>=sequence and receiver.revision>=_delivery.state_revision: continue
		var began := Time.get_ticks_usec() if perf.active else 0
		var packet: Dictionary = _delivery.duplicate(true)
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

func _collect_locked() -> Dictionary:
	if not _delivery.is_empty():
		delivery_error = _deliver_locked()
		if not delivery_error.ok: return delivery_error
	var snapshot := _read_locked()
	if not snapshot.ok:
		delivery_error = snapshot
		return snapshot
	if _subscribers.is_empty(): return snapshot
	_delivery = snapshot.value
	delivery_error = _deliver_locked()
	return snapshot if delivery_error.ok else delivery_error
