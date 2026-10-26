## 複製した素材で保存・競合・切替と、プレビューの停止・解放を確認する。
extends Node

const SCENE := preload("res://gyms/visual_editor.tscn")
const FIRE_COPY := "res://data/visuals/_visual_editor_test.tres"
var failures := 0
var checks := 0
var capture := ""

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture = arg.trim_prefix("--capture=")
	_run.call_deferred()

func _run() -> void:
	var hashes := {}
	var paths: Array[String] = ["res://data/visuals/pixel_fire.tres", "res://data/map_reveal_settings.tres"]
	for file in DirAccess.get_files_at("res://data/legendary_modules"):
		if file.ends_with(".tres"): paths.append("res://data/legendary_modules/" + file)
	for path in paths: hashes[path] = FileAccess.get_md5(path)
	var screen_before: int = GameManager.screen
	var boot_before: Callable = GameManager.boot_request
	var connections_before := GameManager.screen_changed.get_connections().size()
	var editor = SCENE.instantiate()
	add_child(editor)
	await get_tree().process_frame
	check(editor._sessions.size() == 1, "未選択のツールを生成しない")
	check(not ResourceLoader.has_cached("res://scenes/run/legendary_reveal.tscn"), "未選択のオーラ素材を読み込まない")
	var fire = editor._current()
	check(fire.stage.size.y > 200 and fire._panel.size.y > 200, "炎の描画と操作部に編集できる高さを確保")
	check(not fire.dirty and fire.settings != load(fire.DEFAULT_PRESET), "炎は保存値と独立した複製から始める")
	var source_birth: float = load(fire.DEFAULT_PRESET).birth_rate
	fire.settings.birth_rate = source_birth + 1.0
	check(fire.dirty and load(fire.DEFAULT_PRESET).birth_rate == source_birth, "炎の変更で共有Resourceを変更しない")
	editor._refresh()
	check(editor._dirty.text.begins_with("● 未保存") and editor._path.text == fire.DEFAULT_PRESET, "共通ヘッダーに未保存と完全な保存先を表示")
	editor.request_reload(fire.reload_current)
	check(editor._confirm.visible, "再読込は未保存値の破棄を確認する")
	editor._confirm.canceled.emit()
	editor._confirm.hide()
	check(fire.dirty and fire.settings.birth_rate == source_birth + 1, "再読込の取消で編集値を維持")
	check(not FileAccess.file_exists(FIRE_COPY), "テストの複製先は既存素材と衝突しない")
	if FileAccess.file_exists(FIRE_COPY):
		editor.free()
		get_tree().quit(1)
		return
	fire.copy_path = FIRE_COPY
	fire.save_copy()
	check(FileAccess.file_exists(FIRE_COPY) and not fire.dirty, "炎を新しいプリセットへ複製保存")
	var fire_uid := _stamp_uid(FIRE_COPY)
	fire.reload_preset()
	fire.settings.birth_rate += 1
	fire.save_current()
	fire.settings.birth_rate += 1
	fire.reload_current()
	check(not fire.dirty and fire.settings.birth_rate == source_birth + 2, "炎を保存して再読込できる")
	check(ResourceLoader.get_resource_uid(FIRE_COPY) == fire_uid, "炎の上書きでResource UIDを保持")
	fire.settings.birth_rate += 1
	var external := FileAccess.open(FIRE_COPY, FileAccess.READ_WRITE)
	external.seek_end()
	external.store_string("\n")
	external.close()
	var external_hash := FileAccess.get_md5(FIRE_COPY)
	fire.save_current()
	check(fire.dirty and FileAccess.get_md5(FIRE_COPY) == external_hash, "炎は外部変更を上書きしない")
	fire.reload_current()
	fire.settings.birth_rate += 1
	await _capture("fire")
	var fire_count: int = fire.fire.density_render_count
	editor.select_tool(1)
	await get_tree().process_frame
	var legendary = editor._current()
	check(editor._sessions.size() == 2 and fire.fire.density_render_count == fire_count, "非表示の炎のシミュレーションを停止")
	check(fire.stage.render_target_update_mode == SubViewport.UPDATE_DISABLED, "非表示の炎の描画を停止")
	check(legendary._aura_controls.visible and not legendary._rays_controls.visible and legendary._bake_controls.visible, "オーラに形状とベイク操作をまとめる")
	var source_path: String = legendary._selected
	var original = load(source_path)
	var original_offset: Vector2 = original.reveal_aura_offset
	var original_backlight: Dictionary = original.reveal_backlight_settings.duplicate(true)
	var module_copy := "user://visual_editor_module.tres"
	check(ResourceSaver.save(legendary._read(source_path).duplicate(true), module_copy) == OK, "モジュールの試験用複製を作る")
	legendary._paths.append(module_copy)
	legendary._modules.add_item("試験用モジュール")
	legendary._select_module(legendary._paths.size() - 1)
	var module_uid := _stamp_uid(module_copy)
	legendary._hashes[module_copy] = FileAccess.get_md5(module_copy)
	legendary._inputs.offset_x.value += 5
	var offset: Vector2 = legendary._read(module_copy).reveal_aura_offset
	await get_tree().process_frame
	check(legendary._aura_controls.size.y > 0 and legendary._stage.size.y > 200, "オーラの操作部とプレビューを配置")
	await _capture("aura")
	editor.select_tool(2)
	check(editor._current() == legendary and editor._sessions.size() == 2, "オーラと後光で同じ編集セッションを共有")
	check(not legendary._aura_controls.visible and legendary._rays_controls.visible and not legendary._bake_controls.visible, "後光では後光の設定を表示")
	var light_key: String = legendary._light_inputs.keys().filter(func(key): return key != "backlight_color")[0]
	legendary._light_inputs[light_key].value += legendary._light_inputs[light_key].step
	var light_value: float = legendary._light_inputs[light_key].value
	check(legendary._read(module_copy).reveal_aura_offset == offset, "後光の調整でオーラの調整値を保持")
	check(original.reveal_aura_offset == original_offset and original.reveal_backlight_settings == original_backlight, "モジュールの共有値を変更しない")
	legendary.save_current()
	legendary._inputs.offset_x.value += 4
	legendary.reload_current()
	check(legendary._read(module_copy).reveal_aura_offset == offset and not legendary._dirty.get(module_copy, false), "オーラの配置を保存して再読込")
	check(legendary._read(module_copy).reveal_backlight_settings[light_key] == light_value, "後光の設定を保存して再読込")
	check(ResourceLoader.get_resource_uid(module_copy) == module_uid, "モジュールのResource UIDを保持")
	legendary._inputs.offset_x.value += 3
	legendary._select_module(0)
	legendary._select_module(legendary._paths.size() - 1)
	check(legendary._dirty.get(module_copy, false) and legendary._inputs.offset_x.value == offset.x + 3, "モジュール切替後も未保存値を保持")
	external = FileAccess.open(module_copy, FileAccess.READ_WRITE)
	external.seek_end()
	external.store_string("\n")
	external.close()
	external_hash = FileAccess.get_md5(module_copy)
	legendary.save_current()
	check(legendary._dirty[module_copy] and FileAccess.get_md5(module_copy) == external_hash, "モジュールは外部変更を上書きしない")
	await _capture("rays")
	if DisplayServer.get_name() != "headless":
		legendary.reload_current()
		legendary._bake_folder = "user://visual_editor_bakes"
		editor.select_tool(1)
		await legendary._bake()
		await get_tree().process_frame
		check(not legendary._baking and legendary._source_mode.selected == 1, "ベイク完了でゲームと同じ再生へ切替")
		var definition = legendary._read(module_copy)
		check(legendary.AuraBake.valid(definition, legendary._reveal.aura_recipe()), "統合画面から有効なオーラを生成・保存")
		var signature: String = definition.reveal_aura_bake_signature
		legendary.reload_current()
		check(legendary._read(module_copy).reveal_aura_bake_signature == signature, "ベイクの参照と署名を再読込できる")
		check(legendary._stage.get_child_count() == 1, "ベイク用の一時プレビューを回収")
		legendary._inputs.offset_x.value += 1
	var clock: float = legendary._clock
	editor.select_tool(3)
	await get_tree().process_frame
	var map = editor._current()
	check(GameManager.screen == screen_before and GameManager.boot_request == boot_before, "埋込マップはアプリ全体の画面と起動予約を変更しない")
	check(legendary._clock == clock and legendary._reveal._viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "非表示のモジュールの時計と描画を停止")
	check(map._map._launch.disabled and map._map._back.disabled, "編集中のマップはゲームを開始・終了しない")
	map._map._start()
	check(GameManager.screen == screen_before, "キーボード決定と同じ経路でもマップから出撃しない")
	var map_copy := "user://visual_editor_map.tres"
	check(ResourceSaver.save(map._settings.duplicate(), map_copy) == OK, "マップの試験用複製を作る")
	map.settings_path = map_copy
	var map_uid := _stamp_uid(map_copy)
	map.reload_current()
	var duration: float = map._settings.line_duration
	map._fields.line_duration.value = duration + 0.1
	check(map.dirty, "マップの調整を未保存として扱う")
	map.save_current()
	map._fields.line_duration.value = duration + 0.2
	map.reload_current()
	check(not map.dirty and is_equal_approx(map._settings.line_duration, duration + 0.1), "マップを保存して再読込")
	check(ResourceLoader.get_resource_uid(map_copy) == map_uid, "マップのResource UIDを保持")
	map._fields.crt_strength.value += 0.01
	external = FileAccess.open(map_copy, FileAccess.READ_WRITE)
	external.seek_end()
	external.store_string("\n")
	external.close()
	external_hash = FileAccess.get_md5(map_copy)
	map.save_current()
	check(map.dirty and FileAccess.get_md5(map_copy) == external_hash, "マップは外部変更を上書きしない")
	await _capture("map")
	editor.select_tool(0)
	check(fire.dirty and map._viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "ツールを一巡して未保存値と描画停止を維持")
	check(editor.dirty_paths().size() == 3, "オーラと後光の重複を除いて全素材の未保存を集計")
	editor.request_close()
	check(editor._confirm.visible and editor._confirm.dialog_text.contains(module_copy) and editor._confirm.dialog_text.contains(map_copy), "終了時は他ツールの未保存値も確認する")
	editor._confirm.canceled.emit()
	editor._confirm.hide()
	legendary._set_busy(true)
	check(legendary._modules.disabled and not legendary._inputs.offset_x.editable, "ベイク中は埋込コントロールも編集を止める")
	editor.select_tool(3)
	check(editor._selected == 0, "ベイク中は他ツールへの切替を止める")
	editor.request_close()
	check(not editor._confirm.visible, "ベイク中は終了しない")
	legendary._set_busy(false)
	var references: Array[WeakRef] = [weakref(fire.settings), weakref(fire.stage), weakref(legendary._reveal), weakref(map._viewport)]
	editor.free()
	await get_tree().process_frame
	for reference in references: check(reference.get_ref() == null, "閉じた画面のプレビューと調整Resourceを解放")
	check(get_tree().auto_accept_quit, "終了イベントの扱いを画面を閉じた後に戻す")
	for iteration in 3:
		editor = SCENE.instantiate()
		add_child(editor)
		for index in [1, 2, 3, 0, 3, 1]: editor.select_tool(index)
		editor.free()
		await get_tree().process_frame
	check(GameManager.screen == screen_before, "繰り返し開閉してもゲーム画面を変えない")
	check(GameManager.screen_changed.get_connections().size() == connections_before, "繰り返し開閉で画面遷移の接続を残さない")
	for path in paths: check(FileAccess.get_md5(path) == hashes[path], "本番の素材を変更しない: " + path)
	DirAccess.remove_absolute(FIRE_COPY)
	for path in [module_copy, map_copy]: DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute("user://visual_editor_bakes"):
		for file in DirAccess.get_files_at("user://visual_editor_bakes"):
			DirAccess.remove_absolute("user://visual_editor_bakes/" + file)
		DirAccess.remove_absolute("user://visual_editor_bakes")
	print("[visual_editor] %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _capture(name: String) -> void:
	if capture.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture)
	for frame in (100 if name == "map" else 5): await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	check(image != null and not image.is_empty(), "描画画像を取得: " + name)
	check(image.save_png(capture.path_join(name + ".png")) == OK, "画面を保存: " + name)

# 本番の既存Resourceと同じく、UIDを持つファイルの上書きを確認する。
func _stamp_uid(path: String) -> int:
	var uid := ResourceUID.create_id()
	check(ResourceSaver.set_uid(path, uid) == OK, "試験用ResourceにUIDを設定")
	ResourceUID.add_id(uid, path)
	check(ResourceLoader.get_resource_uid(path) == uid, "試験用ResourceのUIDを読込")
	return uid
