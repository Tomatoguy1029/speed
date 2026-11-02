## 開始時に一度だけ作る計測用の実行条件。ゲーム状態・乱数・読み込み済み資源を変更しない。
extends RefCounted

static func _scan(path: String, extensions: Array, files: Dictionary, loaded: Dictionary) -> void:
	for name in DirAccess.get_files_at(path):
		if not extensions.has(name.get_extension()): continue
		var file := path.path_join(name)
		files[file] = FileAccess.get_sha256(file)
		if name.ends_with(".gd") and ResourceLoader.has_cached(file):
			var script := load(file) as Script
			if script != null and script.has_source_code():
				loaded[file] = script.source_code.sha256_text()
	for name in DirAccess.get_directories_at(path):
		_scan(path.path_join(name), extensions, files, loaded)

## 録画開始時のディスク上のGodotプロジェクトだけを識別する。Gitが使えなければ未知にする。
static func git_state() -> Dictionary:
	var root := ProjectSettings.globalize_path("res://")
	var revision_out := []
	var revision_status := OS.execute("git", PackedStringArray(["-C", root, "rev-parse", "HEAD"]), revision_out)
	if revision_status != 0 or revision_out.is_empty():
		return {"revision": "", "dirty": null, "scope": "project_disk_at_recording_start"}
	var status_out := []
	var status_code := OS.execute("git", PackedStringArray(["-c", "core.optionalLocks=false", "-C", root,
		"status", "--porcelain=v1", "--untracked-files=all", "--", "."]), status_out)
	var dirty: Variant = null
	if status_code == 0:
		dirty = not String(status_out[0]).strip_edges().is_empty() if not status_out.is_empty() else false
	return {"revision": String(revision_out[0]).strip_edges(),
		"dirty": dirty,
		"scope": "project_disk_at_recording_start"}

static func digest(value: Variant) -> String:
	return JSON.stringify(value, "", true, true).sha256_text()

static func plain(value: Variant) -> Variant:
	# 画像の生バイトをJSONの数列へ展開しない。内容のSHA-256で識別する。
	if value is PackedByteArray:
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(value)
		return {"bytes": value.size(), "sha256": hash.finish().hex_encode()}
	if value is Resource:
		var out := {}
		for prop in value.get_property_list():
			if prop.usage & PROPERTY_USAGE_STORAGE and prop.name not in ["script", "resource_name", "resource_local_to_scene"]:
				out[String(prop.name)] = plain(value.get(prop.name))
		return out
	if value is Dictionary:
		var out := {}
		for key in value: out[str(key)] = plain(value[key])
		return out
	if value is Array or value is PackedFloat32Array or value is PackedFloat64Array or value is PackedInt32Array or value is PackedInt64Array or value is PackedStringArray or value is PackedVector2Array:
		var out := []
		for item in value: out.append(plain(item))
		return out
	return value
