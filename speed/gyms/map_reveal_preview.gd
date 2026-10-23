## F6 で本番マップの出現・モニター・擬似信号を調整する。変更はメモリ内だけ。
extends Control

var _map: Control
var _settings: Resource = preload("res://data/map_reveal_settings.tres").duplicate()
var _viewport: SubViewport

func _ready() -> void:
	get_window().title = "SPEED — 周辺情報の出現演出・試作"
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var caption := Label.new()
	caption.text = "GFX-002・視覚調整用の試作 / 値は終了時に破棄 / 基準値: data/map_reveal_settings.tres"
	layout.add_child(caption)
	var tools := HFlowContainer.new()
	layout.add_child(tools)
	for field: Array in [
		["線の秒数", "line_duration", 0.0, 2.0, 0.01],
		["伸長の減速", "line_ease", 1.0, 4.0, 0.1],
		["点灯まで秒", "information_delay", 0.0, 1.0, 0.01],
		["フェード秒", "fade_duration", 0.0, 2.0, 0.01],
		["発光強度", "glow_strength", 0.0, 1.0, 0.01],
		["CRT", "crt_strength", 0.0, 1.0, 0.01],
		["微量ノイズ", "noise_strength", 0.0, 0.1, 0.001],
		["棒の速さ", "spectrum_speed", 0.0, 5.0, 0.05],
		["棒の変動", "spectrum_motion", 0.0, 1.0, 0.01],
		["棒の相関", "spectrum_correlation", 0.0, 1.0, 0.01],
	]:
		var row := HBoxContainer.new()
		tools.add_child(row)
		var label := Label.new()
		label.text = field[0]
		row.add_child(label)
		var spin := SpinBox.new()
		spin.min_value = field[2]
		spin.max_value = field[3]
		spin.step = field[4]
		spin.value = _settings.get(field[1])
		spin.custom_minimum_size.x = 100
		spin.value_changed.connect(func(value: float):
			_settings.set(field[1], value)
			_replay()
		)
		row.add_child(spin)
	var replay := Button.new()
	replay.text = "再生 / マップを開く"
	replay.pressed.connect(_replay)
	tools.add_child(replay)
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

func _replay() -> void:
	if is_instance_valid(_map) and _map.is_visible_in_tree():
		_map.select_constellation(_map._selected)
	else:
		GameManager.goto(GameManager.Screen.STAGE_SELECT)
		# Main が再生成した場合も試作値を使う。
		_map = _viewport.get_child(0)._current._map
		_map.reveal_settings = _settings

## --fixed-fps 30 -- --capture=/absolute/path で短い実描画連番を保存する。
func _capture(directory: String) -> void:
	if not directory.is_absolute_path() or DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("連番画像の保存先を作成できません: " + directory)
		return
	await get_tree().process_frame
	for frame in 120:
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
