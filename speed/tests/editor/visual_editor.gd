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
	var fire = editor._current()
	check(fire.stage.size.y > 200 and fire._panel.size.y > 200, "炎の描画と操作部に編集できる高さを確保")
	check(fire._panel is VBoxContainer and fire._panel.get_parent() is ScrollContainer,
		"独立画面だけで操作部を外側スクロールに収める")
	check(not fire.dirty and fire.settings != load(fire.DEFAULT_PRESET), "炎は保存値と独立した複製から始める")
	var source_birth: float = load(fire.DEFAULT_PRESET).birth_rate
	fire.change_setting("birth_rate", source_birth + 8.0)
	check(fire.settings.birth_rate == source_birth + 8.0 and fire._history.has_undo(), "炎パラメータの変更を履歴に記録")
	fire._history.undo()
	check(fire.settings.birth_rate == source_birth, "炎パラメータを元に戻す")
	fire._history.redo()
	check(fire.settings.birth_rate == source_birth + 8.0, "炎パラメータをやり直す")
	fire._history.undo()
	fire.settings.birth_rate = source_birth + 1.0
	check(fire.dirty and load(fire.DEFAULT_PRESET).birth_rate == source_birth, "炎の変更で共有Resourceを変更しない")
	editor._refresh()
	check(editor._dirty.text.begins_with("● 未保存") and editor._path.text == fire.DEFAULT_PRESET.get_file()
		and editor._path.tooltip_text == fire.DEFAULT_PRESET, "共通ヘッダーに未保存と保存先を表示")
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
	var map = editor._current()
	check(editor._sessions.size() == 2 and fire.fire.density_render_count == fire_count, "非表示の炎のシミュレーションを停止")
	check(fire.stage.render_target_update_mode == SubViewport.UPDATE_DISABLED, "非表示の炎の描画を停止")
	check(GameManager.screen == screen_before and GameManager.boot_request == boot_before, "埋込マップはアプリ全体の画面と起動予約を変更しない")
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
	check(editor.dirty_paths().size() == 2, "全素材の未保存を集計")
	editor.request_close()
	check(editor._confirm.visible and editor._confirm.dialog_text.contains(map_copy), "終了時は他ツールの未保存値も確認する")
	editor._confirm.canceled.emit()
	editor._confirm.hide()
	var references: Array[WeakRef] = [weakref(fire.settings), weakref(fire.stage), weakref(map._viewport)]
	editor.free()
	await get_tree().process_frame
	for reference in references: check(reference.get_ref() == null, "閉じた画面のプレビューと調整Resourceを解放")
	check(get_tree().auto_accept_quit, "終了イベントの扱いを画面を閉じた後に戻す")
	for iteration in 3:
		editor = SCENE.instantiate()
		add_child(editor)
		for index in [1, 2, 3, 0, 2, 1]: editor.select_tool(index)
		editor.free()
		await get_tree().process_frame
	check(GameManager.screen == screen_before, "繰り返し開閉してもゲーム画面を変えない")
	check(GameManager.screen_changed.get_connections().size() == connections_before, "繰り返し開閉で画面遷移の接続を残さない")
	for path in paths: check(FileAccess.get_md5(path) == hashes[path], "本番の素材を変更しない: " + path)
	DirAccess.remove_absolute(FIRE_COPY)
	DirAccess.remove_absolute(map_copy)
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
