## 実行前・CLI・exportで共有する生成処理。
@tool
extends RefCounted
const ROOT := "res://.content"
static func _files(directory: String, result: PackedStringArray) -> void:
	for name in DirAccess.get_files_at(directory):
		var path := directory.path_join(name)
		if path == "res://data/content_catalog.tres": continue
		if path.begins_with("res://data/bosses/ai/") or "_moves/" in path: continue
		if path.get_extension() in ["gd", "tres", "res", "tscn", "gdshader", "gdshaderinc", "png", "svg", "jpg", "jpeg", "webp", "mp3", "wav", "ogg", "glsl", "import"] or path.ends_with(".regions.json"): result.append(path)
	for name in DirAccess.get_directories_at(directory):
		if not name.begins_with("."): _files(directory.path_join(name), result)
static func signature() -> String:
	var files := PackedStringArray()
	for directory in ["res://data", "res://scripts", "res://scenes", "res://addons", "res://tools/content", "res://shaders", "res://assets"]: _files(directory, files)
	files.append("res://tools/art/bake_burst_noise.py")
	files.append("res://tools/art/bake_burst_profiles.py")
	files.append("res://tools/art/bake_pump_shell.py")
	files.append("res://tools/art/bake_landmark_masks.py")
	files.append("res://tools/art/elite_contacts.py")
	files.append("res://tools/art/bake_elite_crackle.py")
	for path in preload("res://tools/content/build_attack_visuals.gd").input_paths():
		if not path in files and FileAccess.file_exists(path): files.append(path)
	files.sort()
	var hashes := PackedStringArray(["engine:" + str(Engine.get_version_info().string), "res://project.godot:" + FileAccess.get_sha256("res://project.godot")])
	for path in files: hashes.append(path + ":" + FileAccess.get_sha256(path))
	return "\n".join(hashes).sha256_text()
static func is_current(output := ROOT) -> bool:
	var stamp := output.path_join("stamp.json")
	if not FileAccess.file_exists(stamp): return false
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(stamp))
	if not saved is Dictionary or saved.get("signature", "") != signature(): return false
	for path in saved.get("outputs", []):
		if not FileAccess.file_exists(path): return false
	return true
static func build_all(force := false, output := ROOT) -> Error:
	for id in ["hydra", "monoceros", "draco", "centaurus", "canis_major"]:
		var boss: Dictionary = preload("res://tools/content/build_boss_program.gd").build_boss(id, output.path_join("boss_" + id + ".tres"))
		if boss.error != OK: return boss.error
	if not force and is_current(output): return OK
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.path_join("dev")))
	var visual_error: Error = load("res://tools/content/build_visuals.gd").build(output)
	if visual_error != OK: return visual_error
	var attack_error: Error = load("res://tools/content/build_attack_visuals.gd").build(output)
	if attack_error != OK: return attack_error
	var aura_error: Error = preload("res://tools/content/build_hero_aura.gd").build(output)
	if aura_error != OK: return aura_error
	var codex_error: Error = preload("res://tools/content/build_codex_thumbnails.gd").build(output)
	if codex_error != OK: return codex_error
	var catalog_path := "res://data/content_catalog.tres" if output == ROOT else output.path_join("catalog.tres")
	var error: Error = load("res://tools/content/build_catalog.gd").build(catalog_path)
	if error != OK: return error
	error = load("res://tools/content/build_audio.gd").build(output.path_join("audio.res"))
	if error != OK: return error
	error = load("res://tools/content/build_runtime_stage.gd").build_all(output)
	if error != OK: return error
	error = load("res://tools/content/build_native_data.gd").build_probe(output.path_join("dev/native_probe.json"))
	if error != OK: return error
	error = load("res://tools/content/build_native_data.gd").build_spawn_timelines(output)
	if error != OK: return error
	var run_outputs := []
	var input_signature := signature()
	for name in DirAccess.get_files_at("res://data/stages"):
		if not name.ends_with(".tres"): continue
		var source := ResourceLoader.load("res://data/stages/"+name,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageDef
		var stage := ResourceLoader.load(output.path_join("stage_%d.tres" % source.index),"",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RuntimeStage
		error = preload("res://tools/content/build_run_content.gd").build(stage,load("res://data/config.tres"),output.path_join("run"),input_signature)
		if error!=OK: return error
		var index_path := output.path_join("run/stage_%d.json" % source.index)
		var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(index_path))
		run_outputs.append_array([index_path,index.binary,index.resources])
	var intro: Dictionary = load("res://scripts/runtime/intro_sequence.gd").practice_package(load("res://data/config.tres"),load("res://data/visuals/intro_presentation.tres"))
	var intro_output := output.path_join("run/intro")
	error = load("res://tools/content/build_run_content.gd").build(intro.stage,intro.config,intro_output,"導入練習".sha256_text(),intro.definitions)
	if error!=OK: return error
	var intro_path := intro_output.path_join("stage_1.json")
	var intro_index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(intro_path))
	var outputs := [catalog_path,intro_path,intro_index.binary,intro_index.resources]
	outputs.append_array(run_outputs)
	var visual_index := ResourceLoader.load(output.path_join("visual_index.tres"), "", ResourceLoader.CACHE_MODE_IGNORE) as StageResources
	for file in DirAccess.get_files_at(output):
		if file.begins_with("look_") and not output.path_join(file) in visual_index.look_paths.values(): continue
		if file.get_extension() in ["tres", "res"]: outputs.append(output.path_join(file))
	for file in DirAccess.get_files_at(output.path_join("dev")):
		if file.get_extension() in ["json", "res", "bin"]: outputs.append(output.path_join("dev").path_join(file))
	var stamp := FileAccess.open(output.path_join("stamp.json"), FileAccess.WRITE)
	if stamp == null: return FileAccess.get_open_error()
	stamp.store_string(JSON.stringify({"signature": signature(), "outputs": outputs}))
	return OK

## 開発用C++入口。通常入口の切替までは明示して呼ぶ。
static func build_cpp_stage(source: StageDef, config: GameConfig, output := ROOT, definitions := {}) -> Error:
	var stage := preload("res://tools/content/build_runtime_stage.gd").compile(source,output,config)
	if stage == null: return ERR_INVALID_DATA
	return preload("res://tools/content/build_run_content.gd").build(stage,config,output.path_join("run"),signature(),definitions)
