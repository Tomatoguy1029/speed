## /tmpの独立プロジェクトで、編集時の保存と実行前の生成を確認する。
## godot --headless --editor --path /tmp/<project> --script res://tests/timeline_edit_cost.gd
@tool
extends SceneTree

const Timeline := preload("res://addons/spawn_timeline/timeline.gd")
const Plugin := preload("res://addons/spawn_timeline/plugin.gd")
const BUILD := preload("res://addons/content_build/builder.gd")

class MeasuredTimeline extends Timeline:
	var diagnostics := 0
	func refresh_diagnostics() -> void:
		diagnostics += 1
		super.refresh_diagnostics()

var failed := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://")
	if not Engine.is_editor_hint() or not (directory.begins_with("/tmp/") or directory.begins_with("/private/tmp/")):
		push_error("この確認は/tmpへコピーしたプロジェクトだけで実行する")
		quit(1)
		return
	while EditorInterface.get_resource_filesystem().is_scanning(): await process_frame
	check(BUILD.build_all(true) == OK, "独立コピーの実行用データを準備する")
	var path := "res://data/stages/stage_4.tres"
	var original := FileAccess.get_file_as_string(path)
	var stage := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageDef
	var stamp := FileAccess.get_file_as_string("res://.content/stamp.json")
	var before := ResourceLoader.load("res://.content/stage_4.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RuntimeStage
	var original_time := before.boss_time
	var editor := EditorPlugin.new()
	var panel := MeasuredTimeline.new()
	panel.undo_redo = editor.get_undo_redo()
	root.add_child(panel)
	panel.set_stage(stage)
	var save_us := 0
	for i in 3:
		stage.boss_time += 1.0
		var started := Time.get_ticks_usec()
		panel._save()
		save_us += Time.get_ticks_usec() - started
	var saved := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageDef
	check(saved.boss_time == stage.boss_time, "編集確定でソースを保存する")
	check(FileAccess.get_file_as_string("res://.content/stamp.json") == stamp, "編集確定では実行データを再生成しない")
	var pending := ResourceLoader.load("res://.content/stage_4.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RuntimeStage
	check(pending.boss_time == original_time, "保存だけでは生成物を書き換えない")
	var plugin := Plugin.new()
	var has_build := false
	for method in plugin.get_script().get_script_method_list():
		if method.name == "_build": has_build = true
	check(has_build, "F5・F6・途中再生で使う実行前フックを持つ")
	if has_build:
		check(plugin._build(), "実行前フックで正規生成する")
		check(BUILD.is_current(), "実行前にソースと生成物を一致させる")
		var fresh := ResourceLoader.load("res://.content/stage_4.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RuntimeStage
		check(fresh.boss_time == stage.boss_time, "実行に最新の編集内容を渡す")
	var canvas: Control = panel.canvas
	canvas.size = Vector2(1600, 800)
	canvas.px_per_sec = 10.0
	var original_points := stage.zako_curves[0].points.duplicate()
	canvas._begin_point_drag(0, 1)
	panel.diagnostics = 0
	var started := Time.get_ticks_usec()
	for i in 50:
		canvas._move_drag(Vector2(canvas._x(10.0 + i * 0.01), 120), false)
	var drag_us := Time.get_ticks_usec() - started
	check(panel.diagnostics == 0, "ドラッグ中は全検証と詳細表示の再構築をしない")
	var during := panel.diagnostics
	canvas._end_drag()
	check(panel.diagnostics > 0, "確定時に検証と詳細表示を更新する")
	var history := panel.undo_redo.get_history_undo_redo(panel.undo_redo.get_object_history_id(stage))
	check(history.undo(), "ドラッグを取り消せる")
	saved = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageDef
	check(saved.zako_curves[0].points == original_points, "Undoでも編集データの保存を維持する")
	check(history.redo(), "ドラッグをやり直せる")
	stage.enemy_tuning = {"missing_fixture_enemy": {"hp": 1.0}}
	ResourceSaver.save(stage, path)
	if has_build: check(not plugin._build(), "生成失敗時は古いデータでの起動を拒否する")
	print("[timeline_edit_cost] save_mean_ms=", save_us / 3000.0, " drag_50_ms=", drag_us / 1000.0, " drag_diagnostics=", during, " failures=", failed)
	panel.undo_redo.clear_history()
	panel.free()
	editor.free()
	plugin.free()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	quit(1 if failed else 0)
