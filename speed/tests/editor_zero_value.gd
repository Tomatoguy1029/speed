## 敵valueの入力欄が0を受け取り、微小な正値と通常値を保存できることを確認する。
## godot --headless --editor --path speed --script res://tests/editor_zero_value.gd
@tool
extends SceneTree

const Checks := preload("res://addons/spawn_timeline/type_checks.gd")
const Timeline := preload("res://addons/spawn_timeline/timeline.gd")
const PATH := "res://.godot/editor_zero_value_test.tres"

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func _find_property(root: Node, property_name: String) -> EditorProperty:
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is EditorProperty and node.get_edited_property() == property_name and node.get("_numbers") is Array:
			return node
		pending.append_array(node.get_children())
	return null

func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(2.0).timeout
	var stage := StageDef.new()
	stage.scene_path = "res://scenes/stages/stage_5.tscn"
	stage.enemies = [&"crow"]
	stage.enemy_attack_values = {"crow": 0.001}
	var clip := SpawnClip.new()
	clip.types = [&"crow"]
	clip.formations = [load("res://data/formations/crow.tscn") as PackedScene]
	clip.layouts = [&"crow/1群", &"crow/2群"]
	stage.clips = [clip]
	_check(ResourceSaver.save(stage, PATH) == OK, "initial stage saves")
	stage.take_over_path(PATH)
	EditorInterface.inspect_object(stage)
	await process_frame
	await process_frame
	var editor_inspector := EditorInterface.get_inspector()
	var field := _find_property(editor_inspector, "enemy_attack_values")
	_check(field != null, "stage value editor opens")
	if field != null:
		var numbers: Array = field.get("_numbers")
		if not numbers.is_empty():
			numbers[0].step = 0.5
		field._update_property()
		_check(numbers.size() == 1 and numbers[0].min_value == 0.0 and numbers[0].step == 0.0 and numbers[0].custom_arrow_step == 0.5, "input accepts zero without rounding saved values")
		if not numbers.is_empty():
			_check(numbers[0].value == 0.001 and numbers[0].get_line_edit().text == "0.001", "saved 0.001 remains visible instead of looking like zero")
			numbers[0].get_line_edit().text = "0"
			numbers[0].apply()
	await process_frame
	await process_frame
	_check(float(stage.enemy_attack_values.get("crow", -1.0)) == 0.0, "input commits exact zero to the stage")
	var saved_zero := ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageDef
	_check(saved_zero != null and float(saved_zero.enemy_attack_values.get("crow", -1.0)) == 0.0, "editor saves exact zero")
	EditorInterface.inspect_object(clip)
	await process_frame
	await process_frame
	var clip_field := _find_property(editor_inspector, "layouts")
	_check(clip_field != null, "clip Formations opens")
	if clip_field != null:
		var clip_options: Array = clip_field.get("_options")
		_check(clip_options.size() == 2 and float(clip_options[0][2]) == 0.0 and float(clip_options[1][2]) == 0.0, "clip Auto refreshes from committed zero")
		var overrides: Array = clip_field.get("_numbers")
		_check(overrides.size() == 2 and overrides[0].min_value == 0.0 and overrides[0].step == 0.0, "override editor accepts exact zero")
	var timeline := Timeline.new()
	timeline.stage = stage
	var inspector := Checks.new()
	inspector.timeline = timeline
	for value in [0.0, 0.00001, 2.5]:
		stage.enemy_attack_values["crow"] = value
		var options := inspector._layout_options(clip)
		_check(options.size() == 2 and float(options[0][2]) == value and float(options[1][2]) == value * 2.0, "clip Auto uses value %s" % value)
		_check(ResourceSaver.save(stage, PATH) == OK, "stage saves value %s" % value)
		var reopened := ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageDef
		_check(reopened != null and float(reopened.enemy_attack_values.get("crow", -1.0)) == value, "stage reopens value %s" % value)
	inspector = null
	timeline.free()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("[editor_zero_value] failures=%d" % failures)
	quit(1 if failures else 0)
