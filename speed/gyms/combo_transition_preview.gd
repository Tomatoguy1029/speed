## 制作データを編集し、通常報酬UIの独立ウィンドウで同じ再生面を確認する。
## 本番ランへの設定適用・付与・抽選・ゲームsave・ベイクを行わない。
extends Control

const PATHS := ["res://data/visuals/combo_iris.tres", "res://data/visuals/combo_star_iris.tres", "res://data/visuals/combo_shatter.tres"]
const KINDS := {"combo_iris": 0, "combo_star_iris": 1, "combo_shatter": 2}
const NAMES := ["×2 · Iris", "×3 · Star Iris", "×4 · Shatter Wipe"]
const FIELDS := preload("res://gyms/combo_transition_fields.gd")
const SAMPLE := preload("res://gyms/combo_transition_sample.gd")
var preview_host: Control
var controls_host: Control
var _editing_kind := 0
var _working: Dictionary = {}
var _hashes: Dictionary = {}
var _dirty: Dictionary = {}
var _fields := VBoxContainer.new()
var _sample
var _slider := HSlider.new()
var _phase := Label.new()
var _crack_jump: Button
var _auto := CheckButton.new()
var _clock := 0.0
var _playing := false
var _active := true
var _waiting_choice := true
var _sequence: Array[int] = [0]
var _sequence_index := 0
var _normal_window: Window
var _normal_presentation
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
	note.text = "通常UIのカードを選択して再生。保持中のクリックで次の段階へ。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_host.add_child(note)
	var actions := HFlowContainer.new()
	preview_host.add_child(actions)
	_button(actions, "通常UIで再生", _open_normal_ui)
	_button(actions, "全段階を頭から", func(): _start([0, 1, 2]))
	_button(actions, "この段階を頭から", func(): _start([_editing_kind]))
	_button(actions, "停止 / 再開", func(): _playing = not _playing)
	_auto.text = "自動選択・次送り"
	_auto.tooltip_text = "OFFでは実カードを選んで開始し、保持中にクリックして次へ進みます。"
	_auto.toggled.connect(func(enabled):
		if enabled:
			_waiting_choice = false
			_playing = true
			if _sample != null:
				_sample.set_selecting(false)
				if _working.size() == 3 and _sequence[_sequence_index] == 0: _sample.select_choice(1))
	actions.add_child(_auto)
	_sample = SAMPLE.new()
	_sample.card_chosen.connect(_chosen)
	_sample.next_requested.connect(_next)
	preview_host.add_child(_sample)
	var jumps := HFlowContainer.new()
	preview_host.add_child(jumps)
	for entry in [["暗転", "dim"], ["開く", "opening"], ["最大", "peak"], ["着地", "landing"], ["保持", "hold"], ["割れ直前", "crack"]]:
		_button(jumps, entry[0], func(): _jump(entry[1]))
	_crack_jump = jumps.get_child(5) as Button
	_crack_jump.tooltip_text = "Shatter Wipeの割れが飛び散る直前で止めます。"
	_slider.min_value = 0.0
	_slider.step = 0.01
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.value_changed.connect(func(value):
		if _working.size() != 3: return
		_clock = value
		_playing = false
		_waiting_choice = false
		_sample.set_selecting(false)
		_sample.set_time(value)
		_update_transport())
	preview_host.add_child(_slider)
	_phase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_host.add_child(_phase)
	for kind in 3:
		if not _load(kind): return
	set_section("combo_iris")

func _button(parent: Control, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)

func set_section(section: String) -> void:
	if not KINDS.has(section): return
	_editing_kind = KINDS[section]
	if not _working.has(_editing_kind) and not _load(_editing_kind): return
	FIELDS.populate(_fields, _settings(), _changed)
	if _working.size() == 3:
		if not _started: _start([_editing_kind])
		else:
			_sample.configure(_working, _sequence[_sequence_index])
			_sample.set_time(_clock)

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
	if _working.size() == 3:
		_sample.configure(_working, _sequence[_sequence_index])
		_clock = minf(_clock, _play_settings().duration())
		_sample.set_time(_clock)
		_update_transport()
	_message = "未保存の制作データ: " + PATHS[_editing_kind]

func _start(sequence: Array[int]) -> void:
	if _working.size() != 3: return
	_started = true
	_sequence = sequence
	_sequence_index = 0
	_clock = 0.0
	_playing = true
	_waiting_choice = _sequence[0] == 0 and not _auto.button_pressed
	_sample.configure(_working, _sequence[0])
	_sample.set_selecting(_waiting_choice)
	if _sequence[0] == 0 and _auto.button_pressed: _sample.select_choice(1)
	_sample.set_time(_clock)
	_update_transport()

func _chosen(index: int) -> void:
	if _sequence[_sequence_index] != 0 or not _waiting_choice: return
	_sample.select_choice(index)
	_clock = _play_settings().selection_seconds
	_waiting_choice = false
	_sample.set_selecting(false)
	_playing = true
	_sample.set_time(_clock)
	_update_transport()

func _next() -> void:
	if _working.size() != 3 or _clock < _play_settings().motion_end_at(): return
	if _sequence_index + 1 >= _sequence.size():
		_playing = false
		_message = "再生完了。保持したまま調整するか、頭から再生できます。"
		return
	_sequence_index += 1
	_waiting_choice = false
	_sample.set_selecting(false)
	_clock = _play_settings().selection_seconds
	_sample.configure(_working, _sequence[_sequence_index])
	_sample.set_time(_clock)
	_playing = true
	_update_transport()

func _jump(phase: String) -> void:
	if _working.size() != 3: return
	var s := _play_settings()
	match phase:
		"dim": _clock = s.selection_seconds + s.dim_delay
		"opening": _clock = s.opening_at()
		"peak": _clock = s.card_at() + s.card_zoom_seconds
		"landing": _clock = s.landing_at()
		"hold": _clock = s.motion_end_at()
		"crack": _clock = s.opening_at() + s.opening_seconds * s.crack_fraction * 0.98
	_playing = false
	_waiting_choice = false
	_sample.set_selecting(false)
	_sample.set_time(_clock)
	_update_transport()

func _process(delta: float) -> void:
	if not _active or _working.size() != 3 or not _playing or _waiting_choice: return
	_clock = minf(_clock + delta * _play_settings().preview_speed, _play_settings().duration())
	_sample.set_time(_clock)
	_update_transport()
	if _clock >= _play_settings().duration():
		if _auto.button_pressed and _sequence_index + 1 < _sequence.size(): _next()
		else: _playing = false

func _update_transport() -> void:
	var s := _play_settings()
	_crack_jump.disabled = s.kind != 2
	_slider.set_block_signals(true)
	_slider.max_value = s.duration()
	_slider.set_value_no_signal(_clock)
	_slider.set_block_signals(false)
	var phase := "選択前"
	if _waiting_choice: phase = "カードを選択（1〜3）"
	elif _clock < s.selection_seconds + s.dim_delay: phase = "選択前 / 暗転待ち"
	elif _clock < s.selection_seconds + s.dim_delay + s.cover_seconds: phase = "暗転"
	elif _clock < s.opening_at(): phase = "暗いまま待機"
	elif _clock < s.card_at(): phase = "移行 / カード待ち"
	elif _clock < s.card_at() + s.card_zoom_seconds: phase = "移行 / ズーム"
	elif _clock < s.landing_at(): phase = "張り付き"
	elif _clock < s.flash_at() + s.flash_seconds: phase = "着地 / フラッシュ待ち"
	elif _clock < s.motion_end_at(): phase = "文字 / 移行の完了待ち"
	else: phase = "保持（クリックで次へ）"
	if _clock >= s.flash_at() and _clock < s.flash_at() + s.flash_seconds: phase += " ＋フラッシュ"
	_phase.text = "%s  %.2f / %.2fs · %s" % [NAMES[_sequence[_sequence_index]], _clock, s.duration(), phase]

func _open_normal_ui() -> void:
	if _working.size() != 3: return
	if is_instance_valid(_normal_window):
		_normal_window.show()
		return
	_normal_window = Window.new()
	_normal_window.title = "SPEED — 通常報酬UIで調整再生"
	_normal_window.force_native = true
	_normal_window.min_size = Vector2i(480, 300)
	_normal_window.theme = load("res://assets/ui/theme.tres")
	_normal_window.visible = false
	add_child(_normal_window)
	_normal_presentation = preload("res://scripts/ui/reward_presentation.gd").new()
	_normal_window.add_child(_normal_presentation)
	_sample.get_parent().remove_child(_sample)
	if not _normal_presentation.attach_authoring_surface(_sample):
		preview_host.add_child(_sample)
		_normal_window.queue_free()
		_normal_window = null
		_message = "通常報酬UIへ再生面を移せませんでした。"
		return
	_normal_window.close_requested.connect(_close_normal_ui)
	_window_open = true
	var usable := DisplayServer.screen_get_usable_rect(get_window().current_screen)
	_normal_window.min_size = _normal_window.min_size.min(usable.size)
	var target := Vector2i(get_window().size * 0.9).min(Vector2i(1280, 720)).min(usable.size)
	_normal_window.popup_centered(target.max(_normal_window.min_size))
	_start([0, 1, 2])

func _close_normal_ui() -> void:
	if not is_instance_valid(_normal_window): return
	_normal_presentation.detach_authoring_surface()
	_sample.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	preview_host.add_child(_sample)
	preview_host.move_child(_sample, 2)
	_normal_window.queue_free()
	_normal_window = null
	_normal_presentation = null
	_window_open = false

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
	_message = "制作データを保存しました。再読込で同じ演出を復元できます。まだ本番用へ定数化していません。"

func reload_current() -> void:
	if not _load(_editing_kind): return
	FIELDS.populate(_fields, _settings(), _changed)
	if _working.size() == 3:
		_sample.configure(_working, _sequence[_sequence_index])
		_clock = minf(_clock, _play_settings().duration())
		_sample.set_time(_clock)
		_update_transport()
	_message = "保存済みの制作データを再読込しました。"

func set_active(active: bool) -> void:
	_active = active
	if _sample != null: _sample.set_active(active)
	if is_instance_valid(_normal_window): _normal_window.visible = active and _window_open

func _exit_tree() -> void:
	if is_instance_valid(_normal_window): _normal_window.queue_free()
