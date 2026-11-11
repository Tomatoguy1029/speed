## 曲線削除・境界リサイズ・区間削除を実エディターの履歴・Window入力で確認する。
## godot --headless --editor --path speed --script res://tests/editor/spawn_timeline_controls.gd
@tool
extends SceneTree

var panel
var canvas
var manager: EditorUndoRedoManager
var plugin: EditorPlugin
var window: Window
var failures := 0
const SAVE := "/tmp/speed-timeline-controls-fixture.tres"

func _initialize() -> void:
	if not Engine.is_editor_hint():
		push_error("Run with --editor for the actual editor undo history")
		quit(1)
		return
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	await process_frame
	await process_frame

func mouse(at: Vector2, button: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = canvas.get_global_transform_with_canvas() * at
	e.global_position = e.position + Vector2(window.position)
	e.button_index = button
	e.pressed = pressed
	window.push_input(e, true)

func motion(at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = canvas.get_global_transform_with_canvas() * at
	e.global_position = e.position + Vector2(window.position)
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	window.push_input(e, true)

func drag_width(to: float) -> void:
	var y: float = canvas.RULER * 0.5
	mouse(Vector2(canvas.GUTTER, y), MOUSE_BUTTON_LEFT, true)
	motion(Vector2(to, y))
	mouse(Vector2(to, y), MOUSE_BUTTON_LEFT, false)
	await settle()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capture" in OS.get_cmdline_user_args():return
	RenderingServer.force_draw()
	window.get_texture().get_image().save_png("/tmp/speed-timeline-" + label + ".png")

func reload_stage() -> Resource:
	return ResourceLoader.load(SAVE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)

func _run() -> void:
	while EditorInterface.get_resource_filesystem().is_scanning():await process_frame
	await create_timer(1.0).timeout
	plugin = EditorPlugin.new()
	manager = plugin.get_undo_redo()
	var script = load("res://addons/spawn_timeline/timeline.gd")
	panel = script.new()
	panel.undo_redo = manager
	canvas = panel.canvas
	canvas.clocks.defaults = null
	window = Window.new()
	window.title = "SPEED Timeline UI verification"
	window.size = Vector2i(1100, 700)
	window.position = Vector2i(20, 70)
	window.theme = EditorInterface.get_editor_theme()
	root.add_child(window)
	window.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.show()
	var stage := StageDef.new()
	var phase := PhaseDef.new()
	stage.phases = [phase]
	stage.time_limit = 660.0
	stage.enemies = [&"biter", &"bomber"]
	for id in stage.enemies:
		var curve := SpawnCurve.new()
		curve.type = id
		curve.points = PackedVector2Array([Vector2(0, 10), Vector2(120, 30), Vector2(480, 10)])
		stage.zako_curves.append(curve)
	var clip := SpawnClip.new()
	clip.label = "確認用クリップ"
	clip.time = 20.0
	clip.length = 80.0
	clip.track = 0
	stage.clips = [clip]
	stage.track_names = PackedStringArray(["確認用トラック"])
	ResourceSaver.save(stage, SAVE)
	stage.take_over_path(SAVE)
	panel.set_stage(stage)
	await settle()
	var first: Resource = stage.zako_curves[0]
	var second: Resource = stage.zako_curves[1]
	# 名前欄を右クリック。以前選んでいたクリップを削除しない。
	canvas._select_hit({"kind":"time", "index":0})
	mouse(Vector2(30 * canvas.ui, canvas._curves_top() + canvas.CURVE_ROW * 1.5), MOUSE_BUTTON_RIGHT, true)
	mouse(Vector2(30 * canvas.ui, canvas._curves_top() + canvas.CURVE_ROW * 1.5), MOUSE_BUTTON_RIGHT, false)
	await settle()
	var menu: PopupMenu = canvas.get_child(canvas.get_child_count() - 1)
	check(menu.get_item_text(0).contains("bomber") and menu.get_item_text(0).contains("削除"), "Menu explicitly identifies the clicked curve track")
	await capture("curve-menu")
	if menu.get_item_text(0).contains("削除"):
		menu.hide()
		menu.id_pressed.emit(0)
	else:menu.hide()
	await settle()
	check(stage.zako_curves == [first] and stage.clips == [clip] and stage.enemies == [&"biter", &"bomber"], "Delete removes only the targeted curve")
	check(reload_stage().zako_curves.size() == 1, "Deletion persists to disk")
	var history := manager.get_history_undo_redo(manager.get_object_history_id(stage))
	if history != null and history.has_undo():
		check(history.undo() and stage.zako_curves == [first, second], "Undo restores the original curve and order")
		check(reload_stage().zako_curves.size() == 2, "Undo is saved")
		check(history.redo() and stage.zako_curves == [first], "Redo removes the same curve")
		check(reload_stage().zako_curves.size() == 1, "Redo is saved")
		history.undo()
	else:check(false, "Deletion creates an editor undo entry")
	await settle()
	window.grab_focus()
	# 曲線の編集側でも同じ対象のメニューを出す。
	mouse(Vector2(canvas.GUTTER + 60 * canvas.ui, canvas._curves_top() + canvas.CURVE_ROW * 0.5), MOUSE_BUTTON_RIGHT, true)
	mouse(Vector2(canvas.GUTTER + 60 * canvas.ui, canvas._curves_top() + canvas.CURVE_ROW * 0.5), MOUSE_BUTTON_RIGHT, false)
	await settle()
	menu = canvas.get_child(canvas.get_child_count() - 1)
	check(menu.get_item_text(0).contains("biter"), "Curve body right-click targets its own track")
	menu.hide()
	await settle()
	var saved := FileAccess.get_file_as_string(SAVE)
	# 名前欄の狭幅・広幅、画面端の制限、ウィンドウ変更後の入力位置を確認。
	await drag_width(110 * canvas.ui)
	check(is_equal_approx(canvas.GUTTER, 110 * canvas.ui), "Divider can narrow the name column")
	await capture("narrow")
	await drag_width(340 * canvas.ui)
	check(is_equal_approx(canvas.GUTTER, 340 * canvas.ui), "Divider can widen the name column")
	await capture("wide")
	canvas.zoom(2.0)
	var scale_before: float = canvas.px_per_sec
	await drag_width(0)
	check(canvas.GUTTER > 0 and canvas.GUTTER < 110 * canvas.ui, "Name column keeps a nonzero minimum")
	check(is_equal_approx(canvas.px_per_sec, maxf(scale_before, canvas._min_px())), "Divider preserves user zoom within the visible range")
	await drag_width(canvas.size.x)
	check(canvas.size.x - canvas.GUTTER >= 159 * canvas.ui, "Editing region retains usable minimum width")
	window.size = Vector2i(720, 760)
	await settle()
	check(canvas.GUTTER >= 90 * canvas.ui and canvas.size.x - canvas.GUTTER >= 159 * canvas.ui, "Window resize preserves both minimum widths")
	await drag_width(110 * canvas.ui)
	# 幅変更中のパンで画面外へ出た点を対象にせず、座標の照合範囲をそろえる。
	canvas.fit()
	var c: Resource = stage.zako_curves[0]
	canvas.get_parent().scroll_vertical = 0
	await settle()
	var point := Vector2(canvas._x(120), canvas._curve_y(0, 30, canvas._curve_max(c)))
	check(canvas._hit(point).get("kind") == "point" and is_equal_approx(canvas._t(point.x), 120), "Curve point drawing and hit coordinates agree after resizing")
	canvas.fit()
	var first_point := Vector2(canvas._x(0), canvas._curve_y(0, 10, canvas._curve_max(c)))
	check(canvas._hit(first_point).get("kind") == "point", "Time-zero points remain editable on the divider")
	canvas.get_parent().scroll_vertical = int(canvas._clips_top() - canvas._tracks_top())
	await settle()
	var clip_point := Vector2(canvas._x(40), canvas._clips_top() + canvas.TRACK * 0.5)
	mouse(clip_point, MOUSE_BUTTON_LEFT, true)
	mouse(clip_point, MOUSE_BUTTON_LEFT, false)
	check(canvas.selected == 0, "Clip selection follows the new time origin")
	check(FileAccess.get_file_as_string(SAVE) == saved, "Resizing and selecting do not change stage data")
	await capture("small-window")
	# 指定区間を一括削除し、保存・1回のUndo・Redoまでを確認する。
	manager.clear_history()
	stage = StageDef.new()
	var defaults := StageDef.new()
	defaults.boss_time = 100.0
	defaults.surge_start = 40.0
	canvas.clocks.defaults = defaults
	stage.time_limit = 200.0
	stage.surge_end = 80.0
	for at in [0.0, 30.0, 50.0, 90.0]:
		var p := PhaseDef.new()
		p.start = at
		p.id = StringName("phase_%d" % int(at))
		p.attack_budget = int(at)
		stage.phases.append(p)
	stage.surge_phases = {"phase_30": true, "phase_50": false}
	for span in [Vector2(0, 10), Vector2(90, 20), Vector2(10, 100), Vector2(30, 15)]:
		var item := SpawnClip.new()
		item.time = span.x
		item.length = span.y
		stage.clips.append(item)
	var curve := SpawnCurve.new()
	curve.points = PackedVector2Array([Vector2(0, 10), Vector2(20, 20), Vector2(40, 50), Vector2(60, 80), Vector2(100, 120)])
	stage.zako_curves = [curve]
	ResourceSaver.save(stage, SAVE)
	stage.take_over_path(SAVE)
	panel.set_stage(stage)
	var original := FileAccess.get_file_as_string(SAVE)
	panel._show_cut_dialog()
	var dialog: ConfirmationDialog = panel.get_node("CutRange")
	check(dialog.get_ok_button().disabled, "時刻未指定では区間を削除できない")
	var from: LineEdit = dialog.find_child("StartTime", true, false)
	var to: LineEdit = dialog.find_child("EndTime", true, false)
	from.text = "1:00"
	to.text = "0:20"
	to.text_changed.emit(to.text)
	check(dialog.get_ok_button().disabled, "逆順の区間では削除できない")
	from.text = "0:20"
	to.text = "1:00"
	to.text_changed.emit(to.text)
	check(not dialog.get_ok_button().disabled, "開始と終了を時刻で指定できる")
	dialog.confirmed.emit()
	dialog.hide()
	check(stage.clips.size() == 3 and stage.clips[0].length == 10 and stage.clips[1].time == 50 and stage.clips[2].length == 60, "区間内のクリップを削除し、またぐクリップだけを短縮する")
	check(stage.clips[1].track == 1 and stage.clips[2].track == 2, "削除後も暗黙のトラック位置を保つ")
	check(stage.phases.size() == 3 and stage.phases[1].start == 20 and stage.phases[1].attack_budget == 50 and stage.phases[2].start == 50, "削除終了時点の時間帯を継ぎ目へ引き継ぐ")
	check(stage.surge_phases == {"phase_50": false}, "残る時間帯の強化設定を保つ")
	check(curve.points == PackedVector2Array([Vector2(0, 10), Vector2(20, 80), Vector2(60, 120)]), "曲線は削除終了時点の値につないで後ろを詰める")
	var cut_saved: Resource = reload_stage()
	check(cut_saved.clips.size() == 3 and cut_saved.boss_time == 60 and cut_saved.time_limit == 160 and cut_saved.surge_start == 20 and cut_saved.surge_end == 40, "継承した時刻を含めて進行時刻を動かし、保存する")
	history = manager.get_history_undo_redo(manager.get_object_history_id(stage))
	check(history.undo() and FileAccess.get_file_as_string(SAVE) == original, "1回の取り消しで保存内容と継承状態を全て復元する")
	check(history.redo() and reload_stage().clips.size() == 3, "やり直しも全体を保存する")
	manager.clear_history()
	window.queue_free()
	await settle()
	plugin.free()
	DirAccess.remove_absolute(SAVE)
	print("[timeline_controls] 3 scenarios, %d failures" % failures)
	quit(1 if failures else 0)
