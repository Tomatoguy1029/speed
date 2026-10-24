## F6 で本番マップの出現・モニター・擬似信号を調整し、明示保存する。
extends Control

const SETTINGS_PATH := "res://data/map_reveal_settings.tres"
var _map: Control
var _settings: Resource = preload("res://data/map_reveal_settings.tres").duplicate()
var _viewport: SubViewport
var _source_hash := FileAccess.get_md5(SETTINGS_PATH)
var _status := Label.new()

func _ready() -> void:
	get_window().title = "SPEED — 周辺情報の出現演出・試作"
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var caption := Label.new()
	caption.text = "マップ演出・視覚調整用の試作 / 各項目にマウスを置くと説明 / 保存先: data/map_reveal_settings.tres"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(caption)
	var tabs := TabContainer.new()
	layout.add_child(tabs)
	for section: Array in [
		["接続線と点灯", "星座から線を伸ばし、その後に情報を点灯します。", [
		["線の秒数", "line_duration", 0.0, 2.0, 0.01, "線が伸び切るまでの秒数。0 で即時表示。"],
		["伸長の減速", "line_ease", 1.0, 4.0, 0.1, "1 は等速。大きいほど先端がゆっくり止まります。"],
		["点灯まで秒", "information_delay", 0.0, 1.0, 0.005, "線が伸び切ってから情報が点灯し始めるまでの秒数。"],
		["フェード秒", "fade_duration", 0.0, 2.0, 0.01, "情報が通常の明るさになるまでの秒数。"],
		["発光強度", "glow_strength", 0.0, 1.0, 0.01, "点灯途中の一時的な発光。0 で加えません。"],
		]],
		["波形", "持続するゴォーという信号に、ときどき大きな反応を重ねます。", [
		["棒の速さ", "spectrum_speed", 0.0, 5.0, 0.05, "アタック・保持・減衰の周期全体の速さ。0.1〜0.2 付近が目安です。"],
		["通常の高さ", "spectrum_base_height", 0.0, 1.0, 0.01, "持続するゴォーという音の高さの中心。振幅の変化量とは独立しています。"],
		["振幅の変化量", "spectrum_motion", 0.0, 1.0, 0.01, "通常の高さから変わる幅。全体・帯域・個々の強弱は別々の速さで変化します。"],
		["帯域の同期", "spectrum_correlation", 0.0, 1.0, 0.01, "隣り合う帯域の反応を混ぜる量。0 は個別、1 は帯域ごとに揃います。"],
		["大きい音/秒", "spectrum_peak_frequency", 0.0, 1.0, 0.01, "全体に大きな音が重なる頻度。1 は秒に1回程度、0 は無効です。"],
		["大きい音の強さ", "spectrum_peak_strength", 0.0, 1.0, 0.01, "大きな音が重なったときの高さ。頻度・同期度とは別に調整します。"],
		]],
		["天球図", "中心と軌道は固定し、軌道上の光だけをわずかに動かします。", [
		["天球の動き", "orbit_speed", 0.0, 0.2, 0.005, "中心と軌道を固定し、軌道上の光だけが異なる周期で少し巡ります。0 で静止。"],
		]],
		["モニター効果", "背景を含む画面の固定走査線・周辺減光・弱いにじみを調整します。", [
		["CRT", "crt_strength", 0.0, 1.0, 0.01, "固定走査線・画素マスク・周辺減光・弱い光のにじみ。"],
		]],
	]:
		var panel := VBoxContainer.new()
		panel.name = section[0]
		tabs.add_child(panel)
		var description := Label.new()
		description.text = section[1]
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(description)
		var fields := HFlowContainer.new()
		panel.add_child(fields)
		for field: Array in section[2]:
			_add_field(fields, field)
	var tools := HFlowContainer.new()
	layout.add_child(tools)
	var replay := Button.new()
	replay.text = "再生 / マップを開く"
	replay.pressed.connect(_replay)
	tools.add_child(replay)
	var save := Button.new()
	save.text = "調整値を保存"
	save.tooltip_text = "現在の値を data/map_reveal_settings.tres に保存します。次の本番起動から使います。"
	save.pressed.connect(_save)
	tools.add_child(save)
	_status.text = "変更は即反映。保存前の値は終了時に破棄します。"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_status)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	layout.add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	container.add_child(_viewport)
	# 本番と同じ入口・画面・入力を使う。
	GameManager.screen = GameManager.Screen.STAGE_SELECT
	GameManager.boot_request = Callable()
	var main := preload("res://scenes/app/main.tscn").instantiate()
	_viewport.add_child(main)
	_map = main._current._map
	_map.reveal_settings = _settings
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			# 連番の記録中だけ、別ウィンドウへのキー入力の混入を防ぐ。
			_viewport.gui_disable_input = true
			_map.set_process_input(false)
			main._current.set_process_input(false)
			main._current.set_process_unhandled_input(false)
			_capture.call_deferred(argument.trim_prefix("--capture="))

func _add_field(parent: Control, field: Array) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = field[0]
	label.tooltip_text = field[5]
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = field[2]
	spin.max_value = field[3]
	spin.step = field[4]
	spin.value = _settings.get(field[1])
	spin.custom_minimum_size.x = 100
	spin.tooltip_text = field[5]
	spin.get_line_edit().tooltip_text = field[5]
	spin.value_changed.connect(func(value: float):
		_settings.set(field[1], value)
		_status.text = "未保存。『調整値を保存』で本番用リソースへ反映します。"
		if is_instance_valid(_map) and (field[1].begins_with("spectrum_") or field[1] in ["crt_strength", "orbit_speed"]):
			_map._apply_reveal_settings()
		else:
			_replay()
	)
	row.add_child(spin)

func _replay() -> void:
	if is_instance_valid(_map) and _map.is_visible_in_tree():
		_map.select_constellation(_map._selected)
	else:
		GameManager.goto(GameManager.Screen.STAGE_SELECT)
		# Main が再生成した場合も試作値を使う。
		_map = _viewport.get_child(0)._current._map
		_map.reveal_settings = _settings

func _save() -> void:
	if FileAccess.get_md5(SETTINGS_PATH) != _source_hash:
		_status.text = "保存を止めました。別の場所で設定が変わっています。プレビューを開き直して確認してください。"
		return
	var error := ResourceSaver.save(_settings, SETTINGS_PATH)
	if error != OK:
		_status.text = "設定を保存できませんでした（%d）。" % error
		return
	_source_hash = FileAccess.get_md5(SETTINGS_PATH)
	_status.text = "保存済み。次の本番起動からこの値を使います。"

## --fixed-fps 30 -- --capture=/absolute/path で短い実描画連番を保存する。
func _capture(directory: String) -> void:
	if not directory.is_absolute_path() or DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("連番画像の保存先を作成できません: " + directory)
		return
	await get_tree().process_frame
	for frame in 900:
		# 一回の出現と、回転中に選択を変えたときの取り消しを記録する。
		if frame == 2:
			_map.select_constellation(0)
		elif frame == 55:
			_map.select_constellation(1)
		elif frame == 60:
			_map.select_constellation(2)
		await RenderingServer.frame_post_draw
		var error := _viewport.get_texture().get_image().save_png(directory.path_join("map_%03d.png" % frame))
		if error != OK:
			push_error("連番画像の保存に失敗: %d" % error)
			return
	print("[MapRevealPreview] 実描画連番を保存: " + directory)
	get_tree().quit()
