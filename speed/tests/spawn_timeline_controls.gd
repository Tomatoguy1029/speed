## 曲線削除・境界リサイズの2操作を実エディターの履歴・Window入力で確認する。
## godot --headless --editor --path speed --script res://tests/spawn_timeline_controls.gd
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
	manager.clear_history()
	window.queue_free()
	await settle()
	plugin.free()
	DirAccess.remove_absolute(SAVE)
	print("[timeline_controls] 2 scenarios, %d failures" % failures)
	quit(1 if failures else 0)
