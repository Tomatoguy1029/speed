## 短い出現タイムラインの編集テスト。保存先は user:// の fixture だけ。
## godot --headless --editor --path speed --script res://tests/spawn_timeline.gd
@tool
extends SceneTree

const Timeline := preload("res://addons/spawn_timeline/timeline.gd")
const SpawnCurveResource := preload("res://scripts/data_types/spawn_curve.gd")
const Clip := preload("res://scripts/data_types/spawn_clip.gd")
const Stage := preload("res://tests/fixtures/timeline_stage.gd")
const SAVE := "user://spawn_timeline_fixture.tres"
var panel
var canvas
var manager: EditorUndoRedoManager
var plugin: EditorPlugin
var failures := 0
var checks := 0
var completed_sections := 0

func _initialize() -> void:
	if not Engine.is_editor_hint():
		push_error("Run with --editor to verify the actual editor undo history")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	plugin = EditorPlugin.new()
	manager = plugin.get_undo_redo()
	panel = Timeline.new()
	panel.undo_redo = manager
	root.add_child(panel)
	canvas = panel.canvas
	# 敵の参照や共通値を読み込まず、fixture のプロパティだけで編集する。
	canvas.clocks.defaults = null
	_single_paste()
	_group_paste()
	_moves()
	_group_moves()
	_legacy_and_persistence()
	_check(completed_sections == 5, "All test sections completed")
	manager.clear_history()
	panel.free()
	plugin.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("[spawn_timeline] %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _clip(time: float, length: float, row: int, types: Array = [&"a"]) -> Resource:
	var c := Clip.new()
	c.label = "fixture"
	c.time = time
	c.length = length
	c.track = row
	c.types.assign(types)
	c.formation_values = {"fixture/line": 3}
	return c

func _fixture(clips: Array) -> void:
	manager.clear_history()
	var stage := Stage.new()
	var curve := SpawnCurveResource.new()
	curve.type = &"fixture_zako"
	curve.points = PackedVector2Array([Vector2(0, 2)])
	stage.zako_curves = [curve]
	stage.clips.assign(clips)
	stage.track_names = PackedStringArray(["A", "B", "A2", "空"])
	ResourceSaver.save(stage, SAVE)
	stage.take_over_path(SAVE)
	panel.set_stage(stage)
	canvas.view_start = 0.0
	canvas.px_per_sec = 10.0
	canvas.size = Vector2(2000, 800)
	canvas.playhead = 0.0

func _choose(index: int, toggle := false) -> void:
	canvas._select_hit({"kind": "time", "index": index}, toggle, true)

func _key(code: Key, command := false, meta := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.ctrl_pressed = command and not meta
	event.meta_pressed = command and meta
	canvas._gui_input(event)

func _point(index: int) -> Vector2:
	return Vector2(canvas._x(float(panel.clips()[index].get("time")) + 2.0),
		canvas._clips_top() + canvas.clip_track(index) * canvas.TRACK + canvas.TRACK / 2.0)

func _click(index: int, command := false) -> void:
	var event := InputEventMouseButton.new()
	event.position = _point(index)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.meta_pressed = command
	canvas._gui_input(event)
	if not canvas._drag.is_empty():
		canvas._end_drag()

func _drag(index: int, delta: float, row: int, fine := false) -> void:
	var start := _point(index)
	var button := InputEventMouseButton.new()
	button.position = start
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	canvas._gui_input(button)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(start.x + delta * canvas.px_per_sec,
		canvas._clips_top() + row * canvas.TRACK + canvas.TRACK / 2.0)
	motion.shift_pressed = fine
	canvas._gui_input(motion)
	button.position = motion.position
	button.pressed = false
	canvas._gui_input(button)

func _history() -> UndoRedo:
	return manager.get_history_undo_redo(manager.get_object_history_id(panel.stage))

func _undo() -> void:
	_check(_history().undo(), "Undo succeeds")

func _redo() -> void:
	_check(_history().redo(), "Redo succeeds")

func _menu_action(index: int, id: int) -> void:
	var event := InputEventMouseButton.new()
	event.position = _point(index)
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	canvas._gui_input(event)
	var menu: PopupMenu = canvas.get_child(canvas.get_child_count() - 1)
	menu.id_pressed.emit(id)

func _single_paste() -> void:
	var source := _clip(10, 10, 0)
	_fixture([source, _clip(0, 10, 1, [&"b"])])
	_choose(0)
	_key(KEY_C, true, true)
	_choose(1)
	_key(KEY_V, true, true)
	var copy: Resource = panel.clips().back()
	_check(copy.get("time") == 20.0 and copy.get("track") == 0, "Mac paste uses source end and source row, regardless of selection/playhead")
	_check(copy != source and copy.get("formation_values") == source.get("formation_values"), "Paste duplicates all clip settings")
	copy.get("formation_values")["fixture/line"] = 9
	_check(source.get("formation_values")["fixture/line"] == 3, "Pasted settings are independent")
	_undo()
	_check(panel.clips().size() == 2 and source.get("time") == 10.0, "Undo paste keeps source")
	_redo()
	_check(panel.clips().size() == 3 and panel.clips().back().get("time") == 20.0, "Redo paste")
	_key(KEY_V, true)
	_check(panel.clips().back().get("time") == 30.0 and panel.clips().back().get("track") == 0, "Repeated paste stays on source row and advances right")
	# 右クリックした別種類のクリップは貼り付け先を指定する UI ではない。
	_menu_action(1, 1)
	_check(panel.clips().back().get("time") == 40.0 and panel.clips().back().get("track") == 0, "Context paste shares keyboard destination")
	_menu_action(0, 0)
	_menu_action(1, 1)
	_check(panel.clips().back().get("time") == 50.0, "Context copy/paste uses source")
	_choose(0)
	_key(KEY_D, true)
	_check(panel.clips().back().get("time") == 60.0 and panel.clips().back().get("track") == 0, "Duplicate stays on row when immediate right is occupied")
	# 行の種類がコピー後に変わった場合、クリップを消したり別行へ送ったりしない。
	_choose(0)
	canvas.copy_clip()
	for c in panel.clips():
		if c.get("track") == 0:
			c.set("types", [&"b"] as Array[StringName])
	var count: int = panel.clips().size()
	canvas.paste_clip()
	_check(panel.clips().size() == count and panel.clips().has(source), "Incompatible paste is rejected without deleting source")

	completed_sections += 1

func _group_paste() -> void:
	_fixture([_clip(10, 10, 0), _clip(15, 10, 2), _clip(25, 15, 0)])
	_click(0)
	_click(1, true)
	_check(canvas.selection().size() == 2, "Command-click selects multiple clips")
	_key(KEY_C, true)
	_key(KEY_V, true)
	var copies: Array = panel.clips().slice(3)
	_check(copies.size() == 2 and copies[0].get("time") == 40.0 and copies[1].get("time") == 45.0, "Group paste shifts whole group past collision")
	_check(copies[0].get("track") == 0 and copies[1].get("track") == 2, "Group paste keeps rows")
	_check(canvas.selection().size() == 2, "Pasted group is selected")
	_undo()
	_check(panel.clips().size() == 3, "Undo group paste is atomic")
	_redo()
	_check(panel.clips().size() == 5, "Redo group paste is atomic")
	_key(KEY_D, true)
	_check(panel.clips().size() == 7 and panel.clips()[5].get("time") == 55.0 and panel.clips()[6].get("time") == 60.0, "Group duplicate preserves relative placement after group end")
	var reloaded: Resource = ResourceLoader.load(SAVE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	_check(reloaded.get("clips").size() == 7 and reloaded.get("clips")[5].get("time") == 55.0 and reloaded.get("clips")[6].get("track") == 2, "Save/reload preserves group placement")
	_key(KEY_DELETE)
	_check(panel.clips().size() == 5, "Delete removes whole selected group")
	_undo()
	_check(panel.clips().size() == 7, "Undo group delete")
	_choose(0)
	_choose(1, true)
	_menu_action(0, 0)
	_menu_action(1, 1)
	_check(panel.clips().size() == 9 and canvas.selection().size() == 2, "Context copy/paste preserves group selection")
	# 隣接するクリップ同士も一緒に動かせる。
	_fixture([_clip(0, 10, 0), _clip(10, 10, 0)])
	_choose(0)
	_choose(1, true)
	_key(KEY_C, true)
	_key(KEY_V, true)
	_check(panel.clips()[2].get("time") == 20.0 and panel.clips()[3].get("time") == 30.0, "Adjacent clips paste immediately after group")

	completed_sections += 1

func _moves() -> void:
	var source := _clip(10, 10, 0, [&"a", &"b"])
	_fixture([source, _clip(50, 10, 1, [&"b"]), _clip(50, 10, 2, [&"b", &"a"])])
	_choose(0)
	_drag(0, 5, 1)
	_check(source.get("time") == 10.0 and source.get("track") == 0 and panel.clips().has(source), "Different-type drag restores source")
	_drag(0, 5, -1)
	_check(source.get("time") == 10.0 and source.get("track") == 0, "Drag into curve area restores source")
	_check(not _history().has_undo(), "Rejected moves create no undo action")
	_drag(0, 5, 2)
	_check(source.get("time") == 15.0 and source.get("track") == 2, "Same type set allows move regardless of order")
	_undo()
	_check(source.get("time") == 10.0 and source.get("track") == 0, "Undo move restores time and track")
	_redo()
	_check(source.get("time") == 15.0 and source.get("track") == 2, "Redo move restores time and track")
	_drag(0, 40, 2)
	_check(source.get("time") == 15.0 and source.get("track") == 2, "Overlapping drag restores source")
	_drag(0, 0.1, 2, true)
	_check(is_equal_approx(source.get("time"), 15.1), "Shift drag retains fine time movement")
	_drag(0, 0, 3, true)
	_check(source.get("track") == 3, "Empty track accepts first type")
	_key(KEY_RIGHT)
	_check(is_equal_approx(source.get("time"), 16.1), "Arrow time movement retained")
	# 有効な場所を通ったあと不正な場所で放しても、元に戻る。
	var start := _point(0)
	canvas._begin_drag({"kind": "time", "index": 0}, start)
	canvas._move_drag(Vector2(start.x + 10, canvas._clips_top() + 2.5 * canvas.TRACK), false)
	canvas._move_drag(Vector2(start.x + 20, canvas._clips_top() + 1.5 * canvas.TRACK), false)
	canvas._end_drag()
	_check(source.get("track") == 3 and is_equal_approx(source.get("time"), 16.1), "Invalid final drop restores original, not last preview")

	completed_sections += 1

func _group_moves() -> void:
	var a := _clip(10, 10, 0)
	var b := _clip(25, 5, 1, [&"b"])
	_fixture([a, b, _clip(80, 10, 2), _clip(80, 10, 3, [&"b"])])
	_choose(0)
	_choose(1, true)
	_drag(0, 5, 1)
	_check(a.get("track") == 0 and b.get("track") == 1 and a.get("time") == 10.0 and b.get("time") == 25.0, "One incompatible destination rejects entire group")
	_drag(0, 5, 2)
	_check(a.get("track") == 2 and b.get("track") == 3 and a.get("time") == 15.0 and b.get("time") == 30.0, "Group move preserves relative rows and times")
	_undo()
	_check(a.get("track") == 0 and b.get("track") == 1, "Undo group move is atomic")
	_redo()
	_check(a.get("track") == 2 and b.get("track") == 3, "Redo group move is atomic")
	var reloaded: Resource = ResourceLoader.load(SAVE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	_check(reloaded.get("clips")[0].get("track") == 2 and reloaded.get("clips")[1].get("time") == 30.0, "Save/reload preserves group move")
	_key(KEY_RIGHT)
	_check(a.get("time") == 16.0 and b.get("time") == 31.0, "Group arrow movement")
	_fixture([_clip(0, 10, 0), _clip(10, 10, 0)])
	_choose(0)
	_choose(1, true)
	_drag(0, 5, 0)
	_check(panel.clips()[0].get("time") == 5.0 and panel.clips()[1].get("time") == 15.0, "Adjacent selected clips move together without self-collision")
	_drag(0, -20, 0)
	_check(panel.clips()[0].get("time") == 0.0 and panel.clips()[1].get("time") == 10.0, "Left boundary clamps whole group")

	completed_sections += 1

func _legacy_and_persistence() -> void:
	var a := _clip(10, 10, -1)
	var b := _clip(30, 10, -1, [&"b"])
	_fixture([a, b])
	_choose(1)
	_key(KEY_C, true)
	canvas._select_hit({})
	_key(KEY_V, true)
	_check(panel.clips().back().get("time") == 40.0 and panel.clips().back().get("track") == 1, "Legacy implicit source row survives deselection")
	_check(a.get("track") == 0 and b.get("track") == 1, "Existing implicit rows become explicit on insert")
	_undo()
	_check(a.get("track") == -1 and b.get("track") == -1, "Undo restores implicit rows")
	_redo()
	var reloaded: Resource = ResourceLoader.load(SAVE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	_check(reloaded.get("clips").size() == 3 and reloaded.get("clips")[2].get("time") == 40.0 and reloaded.get("clips")[2].get("track") == 1, "Save/reload persists pasted clip and row")
	_choose(0)
	_drag(0, 5, 3)
	reloaded = ResourceLoader.load(SAVE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	_check(reloaded.get("clips")[0].get("time") == 15.0 and reloaded.get("clips")[0].get("track") == 3, "Save/reload persists moved clip")
	_undo()
	reloaded = ResourceLoader.load(SAVE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	_check(reloaded.get("clips")[0].get("time") == 10.0 and reloaded.get("clips")[0].get("track") == 0, "Undo persists restored placement")
	canvas.copy_clip()
	var previous_history := _history()
	panel.set_stage(Stage.new())
	_check(canvas._clipboard.is_empty(), "Switching stage clears stale clipboard destinations")
	_check(previous_history.redo(), "Redo after switching stage succeeds")
	reloaded = ResourceLoader.load(SAVE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	_check(reloaded.get("clips")[0].get("time") == 15.0 and panel.clips().is_empty(), "Redo saves the edited stage after switching stage")

	completed_sections += 1
