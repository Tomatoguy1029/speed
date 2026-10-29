## 編成の保存・改名・再読込で、クリップの並び選択と共有valueを維持する。
## godot --headless --editor --path speed --script res://tests/formation_identity.gd
@tool
extends SceneTree

const Checks := preload("res://addons/spawn_timeline/type_checks.gd")
const Timeline := preload("res://addons/spawn_timeline/timeline.gd")
const DIR := "res://.godot/formation_identity_test"
const FIRST := DIR + "/before.tscn"
const RENAMED := DIR + "/after.tscn"
const CLIP := DIR + "/clip.tres"
const STAGE := DIR + "/stage.tres"
const FormationPaths := preload("res://tools/editor/formation_uid_paths.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _scene_text(uid_text: String, marker_x: int) -> String:
	return '''[gd_scene format=3 uid="%s"]

[ext_resource type="Script" path="res://scripts/encounters/enemy_formation.gd" id="1"]
[ext_resource type="Script" path="res://scripts/encounters/formation_layout.gd" id="2"]
[ext_resource type="Script" path="res://scripts/encounters/formation_marker.gd" id="3"]

[node name="Formation" type="Node2D" unique_id=100]
script = ExtResource("1")

[node name="Left" type="Node2D" parent="." unique_id=4242]
script = ExtResource("2")

[node name="Marker" type="Node2D" parent="Left" unique_id=5000]
position = Vector2(%d, 0)
script = ExtResource("3")
enemy = &"pump"
''' % [uid_text, marker_x]

func _write(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "fixture write: " + path)
		return
	file.store_string(contents)
	file.close()

func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for path in [FIRST, RENAMED, CLIP, STAGE]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var uid_text := ResourceUID.id_to_text(ResourceUID.create_id())
	_write(FIRST, _scene_text(uid_text, 10))
	var first := ResourceLoader.load(FIRST, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	_check(first != null, "saved scene loads")
	var clip := SpawnClip.new()
	clip.formations = [first]
	var key := SpawnClip.layout_key(FIRST, "Left")
	_check(String(key) == uid_text + "/4242", "scene UID and existing node ID form the key")
	clip.layouts = [key]
	clip.formation_values = {String(key): 2.5}
	var timeline := Timeline.new()
	timeline.stage = StageDef.new()
	var inspector := Checks.new()
	inspector.timeline = timeline
	var options := inspector._layout_options(clip)
	_check(options.size() == 1 and options[0][0] == key, "saved scene selection")
	_write(FIRST, _scene_text(uid_text, 25))
	options = inspector._layout_options(clip)
	_check(options.size() == 1 and options[0][0] == key and options[0][2] > 0.0, "content save rebuilds options without losing selection")
	DirAccess.rename_absolute(ProjectSettings.globalize_path(FIRST), ProjectSettings.globalize_path(RENAMED))
	var renamed := ResourceLoader.load(RENAMED, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	_check(renamed != null, "renamed scene loads")
	clip.formations = [renamed]
	_check(SpawnClip.layout_key(RENAMED, "Left") == key, "file rename keeps the key")
	options = inspector._layout_options(clip)
	_check(options.size() == 1 and options[0][0] == key and clip.allowed_layouts(RENAMED, {"layouts": inspector._layout_cache[RENAMED][1]}) == [0], "rename keeps inspector and runtime selection")
	_check(is_equal_approx(clip.formation_value(RENAMED, "Left"), 2.5), "rename keeps shared override")
	_check(ResourceSaver.save(clip, CLIP) == OK, "clip saves")
	var reopened := ResourceLoader.load(CLIP, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as SpawnClip
	_check(reopened != null and reopened.layouts == [key], "editor reopen keeps saved key")
	var next_inspector := Checks.new()
	next_inspector.timeline = timeline
	options = next_inspector._layout_options(reopened)
	_check(options.size() == 1 and options[0][0] == key, "new inspector rebuilds selected candidate")
	var legacy := SpawnClip.new()
	legacy.formations = [renamed]
	legacy.layouts = [&"before/Left"]
	legacy.formation_values = {"before/Left": 3.0}
	options = next_inspector._layout_options(legacy)
	_check(options.size() == 1 and options[0][0] == &"before/Left" and options[0][3] == key, "legacy key survives scene rename until explicit edit")
	_check(legacy.allowed_layouts(RENAMED, {"layouts": [{"name": "Left"}]}) == [0] and is_equal_approx(legacy.formation_value(RENAMED, "Left"), 3.0), "legacy selection and value remain effective")
	legacy.layouts = [&"missing/Other"]
	options = next_inspector._layout_options(legacy)
	_check(options.size() == 2 and options[1][5] == false and legacy.allowed_layouts(RENAMED, {"layouts": [{"name": "Left"}]}).is_empty(), "invalid reference remains visible without selecting another layout")
	_write(RENAMED, _scene_text(uid_text, 25).replace("Left", "Right"))
	var renamed_layout := ResourceLoader.load(RENAMED, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	clip.formations = [renamed_layout]
	_check(SpawnClip.layout_key(RENAMED, "Right") == key and clip.allowed_layouts(RENAMED, {"layouts": [{"name": "Right"}]}) == [0], "node rename keeps its existing node ID")
	options = next_inspector._layout_options(clip)
	_check(options.size() == 1 and options[0][0] == key, "node rename keeps inspector selection")
	var stage := StageDef.new()
	stage.clips = [clip]
	_check(ResourceSaver.save(stage, STAGE) == OK, "stage saves")
	var open_stage := ResourceLoader.load(STAGE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageDef
	var stale := PackedScene.new()
	stale.resource_path = FIRST
	open_stage.clips[0].formations = [stale]
	open_stage.clips[0].layouts = [&"before/Left"]
	open_stage.clips[0].time = 123.0
	var uid := ResourceUID.text_to_id(uid_text)
	if not ResourceUID.has_id(uid): ResourceUID.add_id(uid, FIRST)
	ResourceUID.set_id(uid, FIRST)
	FormationPaths.sync(DIR)
	_check(ResourceUID.get_id_path(uid) == RENAMED and FormationPaths.current_path(FIRST) == RENAMED, "stale UID cache points to the renamed scene")
	_check(FormationPaths.rebind_stage(open_stage), "open stage reconnects the same scene without replacing the stage")
	_check(open_stage.clips[0].formations[0].resource_path == RENAMED and open_stage.clips[0].time == 123.0, "rebind preserves other unsaved clip edits")
	_check(open_stage.clips[0].layouts.has(&"before/Left") and open_stage.clips[0].layouts.has(key), "rebind preserves old selection and restores the saved match")
	_check(ResourceSaver.save(open_stage, STAGE) == OK, "repaired stage saves")
	var restored := ResourceLoader.load(STAGE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageDef
	_check(restored.clips[0].formations[0].resource_path == RENAMED and restored.clips[0].allowed_layouts(RENAMED, {"layouts": [{"name": "Right"}]}) == [0], "reopen keeps the scene and selected layout")
	inspector = null
	next_inspector = null
	timeline.free()
	for path in [FIRST, RENAMED, CLIP, STAGE]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("[formation_identity] failures=%d" % failures)
	quit(1 if failures else 0)
