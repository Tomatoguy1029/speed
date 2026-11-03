## 生成単位ごとの入力と出力を照合する。キャッシュは開発用で配布へ含めない。
@tool
extends RefCounted
const VERSION := 1
var entries: Dictionary = {}
var report: Array[Dictionary] = []
var _hashes: Dictionary = {}
var _dependencies: Dictionary = {}

func open(path: String) -> void:
	if not FileAccess.file_exists(path): return
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	if saved is Dictionary and saved.get("version") == VERSION and saved.get("entries") is Dictionary:
		entries = saved.entries

static func files(directory: String, paths: PackedStringArray) -> void:
	for name in DirAccess.get_files_at(directory):
		var path := directory.path_join(name)
		if path.get_extension() in ["gd","tres","res","tscn","gdshader","gdshaderinc","png","svg","jpg","jpeg","webp","wav","mp3","ogg","glsl","import","py"] or path.ends_with(".regions.json"): paths.append(path)
	for child in DirAccess.get_directories_at(directory):
		if not child.begins_with("."): files(directory.path_join(child),paths)

func digest(paths: PackedStringArray) -> String:
	var sorted := paths.duplicate()
	var visited := {}
	var cursor := 0
	while cursor < sorted.size():
		var path: String = sorted[cursor]
		cursor += 1
		if visited.has(path): continue
		visited[path] = true
		if not _dependencies.has(path):
			var targets := PackedStringArray()
			if path.get_extension() in ["tres","res","tscn"] and FileAccess.file_exists(path):
				for dependency in ResourceLoader.get_dependencies(path):
					var target: String = dependency.split("::")[-1]
					if target.begins_with("res://") and not target in targets: targets.append(target)
			_dependencies[path] = targets
		for target: String in _dependencies[path]:
			if not target in sorted: sorted.append(target)
		for companion in [path+".import",path.get_basename()+".regions.json"]:
			if FileAccess.file_exists(companion) and not companion in sorted: sorted.append(companion)
	sorted = PackedStringArray(visited.keys())
	sorted.sort()
	var rows := PackedStringArray(["engine:" + str(Engine.get_version_info().string)])
	for path in sorted:
		if not _hashes.has(path): _hashes[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
		rows.append(path + ":" + _hashes[path])
	return "\n".join(rows).sha256_text()

func run(key: String, inputs: PackedStringArray, build: Callable, force := false) -> Error:
	var started := Time.get_ticks_usec()
	var fingerprint := digest(inputs)
	var previous: Dictionary = entries.get(key, {})
	var current: bool = not force and previous.get("fingerprint") == fingerprint and not previous.get("outputs", []).is_empty()
	for path in previous.get("outputs", []):
		if not FileAccess.file_exists(path): current = false
	if current:
		report.append({"unit":key,"rebuilt":false,"ms":(Time.get_ticks_usec()-started)/1000.0})
		return OK
	var result: Dictionary = build.call()
	if result.error != OK: return result.error
	var outputs: PackedStringArray = result.outputs
	if outputs.is_empty(): return ERR_INVALID_DATA
	for path in outputs:
		if not FileAccess.file_exists(path): return ERR_FILE_NOT_FOUND
	entries[key] = {"fingerprint":fingerprint,"outputs":outputs}
	report.append({"unit":key,"rebuilt":true,"ms":(Time.get_ticks_usec()-started)/1000.0})
	return OK

func save(path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path + ".pending", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version":VERSION,"entries":entries}))
	file.close()
	return DirAccess.rename_absolute(path + ".pending", path)

func outputs() -> PackedStringArray:
	var paths := PackedStringArray()
	for entry: Dictionary in entries.values():
		for path in entry.outputs:
			if not path in paths: paths.append(path)
	paths.sort()
	return paths
