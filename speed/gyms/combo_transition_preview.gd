## 制作データと再生操作を分離する。時計はこの所有者だけが実時間から進める。
## 本番ランへの設定適用・付与・抽選・ゲームsave・ベイクを行わない。
extends Control

const PATHS := ["res://data/visuals/combo_iris.tres", "res://data/visuals/combo_star_iris.tres", "res://data/visuals/combo_shatter.tres"]
const KINDS := {"combo_iris": 0, "combo_star_iris": 1, "combo_shatter": 2}
const NAMES := ["×2 Combo · Iris", "×3 Combo · Star Iris", "×4 Combo · Shatter Wipe"]
const FIELDS := preload("res://gyms/combo_transition_fields.gd")
const SAMPLE := preload("res://gyms/combo_transition_sample.gd")
const TRANSPORT := preload("res://gyms/combo_playback_controls.gd")
const GAME_CONTEXT := preload("res://gyms/game_context_preview.gd")
var preview_host: Control
var controls_host: Control
var _editing_kind := 0
var _working: Dictionary = {}
var _hashes: Dictionary = {}
var _dirty: Dictionary = {}
var _fields := VBoxContainer.new()
var _sample
var _bars: Array = []
var _normal_bar: Control
var _clock := 0.0
var _cursor := 0.0
var _frame := 0
var _fps := 60
var _speed := 1.0
var _last_tick_usec := 0
var _playing := false
var _active := true
var _auto := false
var _waiting_choice := true
var _waiting_next := false
var _choice := 1
var _sequence: Array[int] = [0]
var _sequence_index := 0
var _normal_window: Window
var _game_context
var _context_ready := false
var _closing := false
var _return_focus: WeakRef
var _return_window: Window
var _return_window_top := false
var _window_open := false
var _started := false
var _message := "制作データを保存し、調整後に本番用の最適化を依頼してください。まだ定数化していません。"

func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controls_host.add_child(scroll)
	_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_fields)
	var note := Label.new()
	note.text = "カード選択または再生で開始。再生速度は全段階共通。コマ送り・時間バーは停止して指定時刻を復元します。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_host.add_child(note)
	var actions := HFlowContainer.new()
	preview_host.add_child(actions)
	_button(actions, "通常UIで再生", _open_normal_ui)
	_button(actions, "全段階を頭から", func(): _start([0, 1, 2]))
	_button(actions, "この段階を頭から", func(): _start([_editing_kind]))
	preview_host.add_child(_make_transport())
	_sample = SAMPLE.new()
	_sample.card_chosen.connect(_chosen)
	_sample.next_requested.connect(_surface_next)
	_sample.set_active(false)
	_game_context = GAME_CONTEXT.new()
	_game_context.set_reward_surface(_sample)
	_game_context.reward_context_ready.connect(_context_became_ready)
	_game_context.reward_context_error.connect(_context_failed)
	preview_host.add_child(_game_context)
	for kind in 3:
		if not _load(kind): return
	set_section("combo_iris")

func _button(parent: Control, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)

func _make_transport(native := false) -> Control:
	var bar := TRANSPORT.new()
	bar.compact = native
	bar.allow_return = native
	bar.return_requested.connect(_request_return)
	bar.play_requested.connect(_play)
	bar.pause_requested.connect(_pause)
	bar.step_requested.connect(func(direction): _seek_frame(_frame + direction))
	bar.seek_requested.connect(func(seconds): _seek_frame(roundi(seconds * _fps)))
	bar.head_requested.connect(func(): _seek_frame(0))
	bar.range_requested.connect(_select_range)
	bar.phase_requested.connect(_jump)
	bar.speed_changed.connect(func(value): _speed = value; _reset_wall_clock(); _sync_controls())
	bar.fps_changed.connect(_change_fps)
	bar.auto_changed.connect(func(enabled):
		_auto = enabled
		_sync_controls())
	_bars.append(bar)
	return bar

func _select_range(index: int) -> void:
	if index == 0: _start([0, 1, 2])
	else: _start([index - 1])

func _ensure_context() -> bool:
	if not _active or _closing: return false
	return _game_context.ensure_reward_context()

func _context_became_ready() -> void:
	if _closing or not _active:
		_game_context.set_active(false)
		return
	_context_ready = true
	_sample.set_active(_active)
	if _working.size() == 3:
		if not _started:
			_started = true
			_sequence = [_editing_kind]
			_sequence_index = 0
			_waiting_choice = _editing_kind == 0 and not _auto
		_sample.configure(_working, _sequence[_sequence_index])
		_apply_cursor(true)
	_reset_wall_clock()

func _context_failed(message: String) -> void:
	_context_ready = false
	_sample.set_active(false)
	_pause()
	_message = message

func set_section(section: String) -> void:
	if not KINDS.has(section): return
	_editing_kind = KINDS[section]
	if not _working.has(_editing_kind) and not _load(_editing_kind): return
	FIELDS.populate(_fields, _settings(), _changed)
	if _working.size() == 3:
		if not _started: _start([_editing_kind])
		else: _rebuild_at_current_time()

func _settings() -> ComboTransitionSettings:
	return _working.get(_editing_kind)

func _play_settings() -> ComboTransitionSettings:
	return _working[_sequence[_sequence_index]]

func _load(kind: int) -> bool:
	var loaded := ResourceLoader.load(PATHS[kind], "", ResourceLoader.CACHE_MODE_IGNORE) as ComboTransitionSettings
	if loaded == null:
		_message = "読み込めません: " + PATHS[kind]
		return false
	var error := loaded.validation_error()
	if loaded.kind != kind or not error.is_empty():
		_message = "設定を読み込めません: " + (error if not error.is_empty() else "種類と保存先が一致しません。")
		return false
	_working[kind] = loaded.duplicate(true)
	_hashes[kind] = FileAccess.get_md5(PATHS[kind])
	_dirty[kind] = false
	return true

func _changed(key: String, value: Variant) -> void:
	var before: Variant = _settings().get(key)
	if before == value: return
	_settings().set(key, value)
	var error := _settings().validation_error()
	if not error.is_empty():
		_settings().set(key, before)
		_message = error
		return
	_dirty[_editing_kind] = true
	if _working.size() == 3: _rebuild_at_current_time()
	_message = "未保存の制作データ: " + PATHS[_editing_kind]

func _rebuild_at_current_time() -> void:
	# 停止中の値変更・再読込は、現在の段階とローカル時刻を維持する。
	_clock = minf(_clock, _play_settings().duration())
	_cursor = _offset_frames(_sequence_index) / float(_fps) + _clock
	_sample.configure(_working, _sequence[_sequence_index])
	_apply_cursor(true)
	_reset_wall_clock()

func _span_frames(index: int) -> int:
	var s: ComboTransitionSettings = _working[_sequence[index]]
	# 終端の静止コマを1枚含む。境界も整数コマにして、前後移動を可逆にする。
	return maxi(1, ceili(s.duration() * _fps) + 1)

func _offset_frames(index: int) -> int:
	var offset := 0
	for i in index: offset += _span_frames(i)
	return offset

func _last_frame() -> int:
	return _offset_frames(_sequence.size()) - 1

func _apply_cursor(force := false) -> void:
	if _working.size() != 3: return
	_cursor = clampf(_cursor, 0.0, _last_frame() / float(_fps))
	var frame := clampi(floori(_cursor * _fps + 0.000001), 0, _last_frame())
	var index := 0
	var offset := 0
	while index + 1 < _sequence.size() and frame >= offset + _span_frames(index):
		offset += _span_frames(index)
		index += 1
	var changed := index != _sequence_index
	var moved := frame != _frame
	_sequence_index = index
	_frame = frame
	_clock = minf((frame - offset) / float(_fps), _play_settings().duration())
	if changed: _sample.configure(_working, _sequence[index])
	if force or changed or moved:
		_sample.set_selecting(_waiting_choice)
		_sample.set_time(_clock)
	_sync_controls()

func _start(sequence: Array[int]) -> void:
	if _working.size() != 3: return
	if not _ensure_context(): return
	_started = true
	_sequence = sequence
	_sequence_index = 0
	_cursor = 0.0
	_clock = 0.0
	_frame = 0
	_playing = true
	_waiting_next = false
	_waiting_choice = _sequence[0] == 0 and not _auto
	_sample.configure(_working, _sequence[0])
	_sample.select_choice(_choice)
	_apply_cursor(true)
	_reset_wall_clock()

func _chosen(index: int) -> void:
	if _working.size() != 3 or _sequence[_sequence_index] != 0 or not _waiting_choice: return
	_choice = index
	_sample.select_choice(index)
	_cursor = _play_settings().selection_seconds
	_waiting_choice = false
	_waiting_next = false
	_playing = true
	_apply_cursor(true)
	_reset_wall_clock()

func _play() -> void:
	if _working.size() != 3: return
	if not _ensure_context(): return
	if _waiting_choice:
		_chosen(_choice)
		return
	var end_frame := _offset_frames(_sequence_index + 1) - 1
	if (_waiting_next or _frame >= end_frame) and _sequence_index + 1 < _sequence.size() and _clock >= _play_settings().motion_end_at():
		_next()
		return
	if _frame >= _last_frame(): _seek_frame(0)
	_waiting_next = false
	_playing = true
	_reset_wall_clock()
	_sync_controls()

func _pause() -> void:
	_playing = false
	_waiting_next = false
	_reset_wall_clock()
	_sync_controls()

func _seek_frame(frame: int) -> void:
	if _working.size() != 3: return
	if not _ensure_context(): return
	_playing = false
	_waiting_choice = false
	_waiting_next = false
	_cursor = clampi(frame, 0, _last_frame()) / float(_fps)
	_apply_cursor(true)
	_reset_wall_clock()

func _change_fps(value: int) -> void:
	if value not in [30, 60, 120] or _working.size() != 3: return
	var local_time := _clock
	_fps = value
	_cursor = _offset_frames(_sequence_index) / float(_fps) + roundi(local_time * _fps) / float(_fps)
	_apply_cursor(true)
	_reset_wall_clock()

func _surface_next() -> void:
	# ユーザーが一時停止した画面をクリックしても、再生を再開しない。
	if not _playing and not _waiting_next: return
	_next()

func _next() -> void:
	if _working.size() != 3 or _clock < _play_settings().motion_end_at(): return
	if _sequence_index + 1 >= _sequence.size():
		_pause()
		_message = "再生完了。コマ戻し・時間バー・先頭へで見直せます。"
		return
	_waiting_choice = false
	_waiting_next = false
	var next_settings: ComboTransitionSettings = _working[_sequence[_sequence_index + 1]]
	_cursor = _offset_frames(_sequence_index + 1) / float(_fps) + next_settings.selection_seconds
	_playing = true
	_apply_cursor(true)
	_reset_wall_clock()

func _jump(phase: String) -> void:
	if _working.size() != 3: return
	var s := _play_settings()
	var time := 0.0
	match phase:
		"dim": time = s.selection_seconds + s.dim_delay
		"opening": time = s.opening_at()
		"peak": time = s.card_at() + s.card_zoom_seconds
		"landing": time = s.landing_at()
		"hold": time = s.motion_end_at()
		"crack": time = s.opening_at() + s.opening_seconds * s.crack_fraction * 0.98
	_seek_frame(_offset_frames(_sequence_index) + roundi(time * _fps))

func _reset_wall_clock() -> void:
	_last_tick_usec = Time.get_ticks_usec()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var elapsed := maxf(0.0, (now - _last_tick_usec) / 1000000.0)
	_last_tick_usec = now
	if not _active or not _context_ready or _working.size() != 3 or not _playing or _waiting_choice: return
	# Engine.time_scaleや制作Resourceの速度から独立した、1つの実時間時計。
	var target := _cursor + elapsed * _speed
	var end_frame := _offset_frames(_sequence_index + 1) - 1
	if not _auto and target >= end_frame / float(_fps):
		_cursor = end_frame / float(_fps)
		_playing = false
		_waiting_next = _sequence_index + 1 < _sequence.size()
	else:
		_cursor = minf(target, _last_frame() / float(_fps))
		if _cursor >= _last_frame() / float(_fps): _playing = false
	_apply_cursor()

func _sync_controls() -> void:
	if _working.size() != 3: return
	var s := _play_settings()
	var phase := "選択前"
	if _waiting_choice: phase = "カード選択待ち（再生でも開始可）"
	elif _clock < s.selection_seconds + s.dim_delay: phase = "選択前 / 暗転待ち"
	elif _clock < s.selection_seconds + s.dim_delay + s.cover_seconds: phase = "暗転"
	elif _clock < s.opening_at(): phase = "暗いまま待機"
	elif _clock < s.card_at(): phase = "移行 / カード待ち"
	elif _clock < s.card_at() + s.card_zoom_seconds: phase = "移行 / ズーム"
	elif _clock < s.landing_at(): phase = "張り付き"
	elif _clock < s.motion_end_at(): phase = "移行の完了待ち"
	else: phase = "保持"
	if _clock >= s.flash_at() and _clock < s.flash_at() + s.flash_seconds: phase += " ＋フラッシュ"
	if not _playing and not _waiting_choice: phase += " / 停止"
	var state := {"playing": _playing and not _waiting_choice, "frame": _frame, "last_frame": _last_frame(), "speed": _speed, "fps": _fps, "auto": _auto, "kind": s.kind, "range": 0 if _sequence.size() > 1 else _sequence[0] + 1, "name": NAMES[_sequence[_sequence_index]], "phase": phase}
	for bar in _bars: bar.sync(state)

func _open_normal_ui() -> void:
	if _working.size() != 3 or _closing: return
	if is_instance_valid(_normal_window):
		_normal_window.show()
		_normal_window.grab_focus()
		return
	_pause()
	_return_window = get_window()
	_return_window_top = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, _return_window.get_window_id())
	var focus := get_viewport().gui_get_focus_owner()
	_return_focus = weakref(focus) if focus != null else null
	_normal_window = Window.new()
	_normal_window.title = "SPEED — 実ステージと通常HUDで報酬を再生"
	_normal_window.force_native = true
	_normal_window.exclusive = false
	_normal_window.transient = false
	_normal_window.popup_window = false
	_normal_window.min_size = Vector2i(480, 420)
	_normal_window.theme = load("res://assets/ui/theme.tres")
	_normal_window.visible = false
	# 表示や資源準備より先に、全ての終了入口を接続する。
	_normal_window.close_requested.connect(_request_return)
	_normal_window.window_input.connect(_normal_window_input)
	add_child(_normal_window)
	var surface := VBoxContainer.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_normal_window.add_child(surface)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#171b24")
	for side in ["left", "right", "top", "bottom"]: style.set("content_margin_" + side, 6.0)
	panel.add_theme_stylebox_override("panel", style)
	surface.add_child(panel)
	_normal_bar = _make_transport(true)
	panel.add_child(_normal_bar)
	# 実ステージviewportと、その通常HUDへ接続済みの報酬面を一緒に移す。
	_game_context.get_parent().remove_child(_game_context)
	surface.add_child(_game_context)
	_window_open = true
	var usable := DisplayServer.screen_get_usable_rect(_return_window.current_screen)
	_normal_window.min_size = _normal_window.min_size.min(usable.size)
	_normal_window.size = Vector2i(_return_window.size * 0.9).min(Vector2i(1280, 800)).min(usable.size).max(_normal_window.min_size)
	_normal_window.position = usable.position + (usable.size - _normal_window.size) / 2
	_return_window.always_on_top = false
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false, _return_window.get_window_id())
	# popup系はtransientへ変えるため使わない。親の編集UIを非モーダルで操作できる。
	_normal_window.show()
	_normal_window.grab_focus()
	_start([0, 1, 2])

func _normal_window_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_normal_window.set_input_as_handled()
		_request_return()

func _request_return() -> void:
	if _closing or not is_instance_valid(_normal_window): return
	_closing = true
	_pause()
	_sample.set_active(false)
	_game_context.set_active(false)
	_normal_window.hide()
	_finish_return.call_deferred()

func _finish_return() -> void:
	# GUIの入力配送中にviewport/HUDを破棄しない。未保存Resourceはこの所有者へ保持する。
	_game_context.release_reward_context()
	_context_ready = false
	if _game_context.get_parent() != null: _game_context.get_parent().remove_child(_game_context)
	_game_context.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	preview_host.add_child(_game_context)
	preview_host.move_child(_game_context, 3)
	_game_context.set_idle_ui_active(_active)
	_bars.erase(_normal_bar)
	_normal_bar = null
	var previous_window := _normal_window
	_normal_window = null
	_window_open = false
	if is_instance_valid(previous_window): previous_window.queue_free()
	if is_instance_valid(_return_window):
		_return_window.always_on_top = _return_window_top
		_return_window.grab_focus()
	var focus: Control = _return_focus.get_ref() as Control if _return_focus != null else null
	if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus()
	_return_focus = null
	_return_window = null
	_closing = false
	_reset_wall_clock()
	_sync_controls()

func editing_state() -> Dictionary:
	var paths: Array[String] = []
	for kind in _dirty:
		if _dirty[kind]: paths.append(PATHS[kind])
	return {"path": PATHS[_editing_kind], "dirty_paths": paths, "busy": false, "message": _message}

func is_section_dirty(section: String) -> bool:
	return _dirty.get(KINDS.get(section, -1), false)

func save_current() -> void:
	var s := _settings()
	if s == null: return
	var error := s.validation_error()
	if not error.is_empty(): _message = error; return
	var path: String = PATHS[_editing_kind]
	if FileAccess.get_md5(path) != _hashes[_editing_kind]:
		_message = "保存先が外部で変更されました。未保存値を控え、再読込してから保存してください: " + path
		return
	var result := ResourceSaver.save(s.duplicate(true), path)
	if result != OK: _message = "保存に失敗しました: " + error_string(result); return
	_hashes[_editing_kind] = FileAccess.get_md5(path)
	_dirty[_editing_kind] = false
	_message = "制作データを保存しました。まだ本番用へ定数化していません。"

func reload_current() -> void:
	if not _load(_editing_kind): return
	FIELDS.populate(_fields, _settings(), _changed)
	if _working.size() == 3: _rebuild_at_current_time()
	_message = "保存済みの制作データを再読込しました。"

func set_active(active: bool) -> void:
	_active = active
	_reset_wall_clock()
	if not active and is_instance_valid(_normal_window): _request_return()
	if _game_context != null:
		if active and not _context_ready: _game_context.set_idle_ui_active(true)
		else: _game_context.set_active(active)
	if _sample != null: _sample.set_active(active and _context_ready)

func _exit_tree() -> void:
	_playing = false
	if is_instance_valid(_return_window): _return_window.always_on_top = _return_window_top
	if is_instance_valid(_normal_window): _normal_window.queue_free()
