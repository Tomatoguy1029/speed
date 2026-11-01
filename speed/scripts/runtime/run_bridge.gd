## Sessionが所有するC++ランの窓口。個別Systemの更新は公開しない。
extends RefCounted
var _core: RefCounted
var _busy := false
var _disposed := false
var _run_id := 0
var _epoch := 1
var _next_command := 1
var _development := false

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
	if _busy: return _error(7,"step","更新中は再入できません")
	if _core == null: return _error(4,"step","設定前または破棄済みです")
	_busy = true
	var result: Dictionary = _core.step_run(dt,input,viewport)
	_busy = false
	return result

## 押下を消費するpollも再入防止の範囲内で一度だけ呼ぶ。
func poll_and_step(dt: float, source: Callable, logical_size: Vector2) -> Dictionary:
	if _busy: return _error(7,"input","入力の取得中は再入できません")
	if _core == null: return _error(4,"input","破棄済みです")
	_busy = true
	if not source.is_valid():
		_busy = false
		return _error(1,"input","入力元がありません")
	var frame: Dictionary = _core.frame_run()
	var intent = source.call() if frame.ok and frame.value.ui.input_enabled else Intent.new()
	if not intent is Intent:
		_busy = false
		return _error(1,"input","Intentを返す入力元を指定してください")
	var result: Dictionary = _core.step_run(dt,pack_intent(intent),{"logical_size":logical_size})
	_busy = false
	return result

func command(kind: String, payload := {}) -> Dictionary:
	if _busy: return _error(7,"command","更新中は再入できません")
	if _next_command == 9223372036854775807: return _error(9,"command_id","命令番号が上限です")
	var envelope := {"run_id":_run_id,"epoch":_epoch,"command_id":_next_command,"kind":kind,"payload":payload}
	_next_command += 1
	return send_envelope(envelope)

func send_envelope(envelope: Dictionary) -> Dictionary:
	if _busy: return _error(7,"command","更新中は再入できません")
	if _core == null: return _error(4,"command","破棄済みです")
	_busy = true
	var result: Dictionary = _core.command_run(envelope)
	_busy = false
	if result.ok and envelope.get("run_id") == _run_id and envelope.get("epoch") == _epoch and envelope.get("command_id",0) < 9223372036854775807:
		_next_command = maxi(_next_command,int(envelope.command_id)+1)
	return result

func read_frame() -> Dictionary:
	if _busy: return _error(7,"read_frame","更新中は再入できません")
	return _core.frame_run() if _core != null else _error(4,"read_frame","破棄済みです")

func checkpoint() -> Dictionary:
	if _busy: return _error(7,"checkpoint","更新中は保持できません")
	if _core == null or not _development: return _error(4,"checkpoint","開発中のランだけを保持できます")
	var id: int = _core.hold_checkpoint()
	return _ok(id) if id>0 else _error(8,"checkpoint","状態の保持に失敗しました")

func restore(id: int) -> Dictionary:
	if _busy: return _error(7,"restore","更新中は復帰できません")
	if _core == null or not _development: return _error(4,"restore","開発中のランだけ復帰できます")
	if not _core.restore_checkpoint(id): return _error(5,"checkpoint","保持点がありません")
	_epoch = _core.current_epoch()
	_next_command = 1
	return _ok({"epoch":_epoch})

func release_checkpoint(id: int) -> Dictionary:
	if _busy: return _error(7,"release_checkpoint","更新中は解除できません")
	if _core == null or not _development: return _error(4,"checkpoint","開発中のランだけ解除できます")
	return _ok() if _core.release_checkpoint(id) else _error(5,"checkpoint","保持点がありません")

func dispose() -> Dictionary:
	if _busy: return _error(7,"dispose","更新中は破棄できません")
	if _core == null:
		_disposed = true
		return _ok()
	var result: Dictionary = _core.dispose_run()
	if result.ok:
		_core = null
		_disposed = true
	return result
