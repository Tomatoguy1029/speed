## 実行前・CLI・exportで共有する生成処理。
@tool
extends RefCounted
const ROOT := "res://.content"
static func _files(directory: String, result: PackedStringArray) -> void:
	for name in DirAccess.get_files_at(directory):
		var path := directory.path_join(name)
		if path == "res://data/content_catalog.tres": continue
		if path.begins_with("res://data/bosses/ai/") or "_moves/" in path: continue
		if path.get_extension() in ["gd", "tres", "tscn", "gdshader", "png", "svg", "jpg", "jpeg", "webp", "import"]: result.append(path)
	for name in DirAccess.get_directories_at(directory):
		if not name.begins_with("."): _files(directory.path_join(name), result)
static func signature() -> String:
	var files := PackedStringArray()
	for directory in ["res://data", "res://scripts", "res://scenes", "res://addons", "res://tools/content", "res://shaders", "res://assets"]: _files(directory, files)
	files.sort()
	var hashes := PackedStringArray(["res://project.godot:" + FileAccess.get_sha256("res://project.godot")])
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
	for id in ["hydra", "monoceros"]:
		var boss: Dictionary = preload("res://tools/content/build_boss_program.gd").build_boss(id, output.path_join("boss_" + id + ".tres"))
		if boss.error != OK: return boss.error
	if not force and is_current(output): return OK
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var catalog_path := "res://data/content_catalog.tres" if output == ROOT else output.path_join("catalog.tres")
	var error: Error = load("res://tools/content/build_catalog.gd").build(catalog_path)
	if error != OK: return error
	error = load("res://tools/content/build_audio.gd").build(output.path_join("audio.res"))
	if error != OK: return error
	error = load("res://tools/content/build_runtime_stage.gd").build_all(output)
	if error != OK: return error
	var outputs := [catalog_path]
	for file in DirAccess.get_files_at(output):
		if file.get_extension() in ["tres", "res"]: outputs.append(output.path_join(file))
	for file in DirAccess.get_files_at(output.path_join("dev")):
		if file.ends_with(".json"): outputs.append(output.path_join("dev").path_join(file))
	var stamp := FileAccess.open(output.path_join("stamp.json"), FileAccess.WRITE)
	if stamp == null: return FileAccess.get_open_error()
	stamp.store_string(JSON.stringify({"signature": signature(), "outputs": outputs}))
	return OK
