## 配置済みライブラリとC++ソースの対応を判定する。
@tool
extends RefCounted
enum State {CURRENT,STALE,MISSING,NO_SOURCE}
const IDENTITY := preload("res://addons/runtime_library/runtime_id.gd")
const BIN := "res://extensions/run/bin"

static func project_root() -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").simplify_path()

static func cpp_directory() -> String:
	return project_root().path_join("cpp")

static func library_name() -> String:
	var arch := Engine.get_architecture_name()
	if OS.get_name() == "Windows": return "speed_runtime.windows.template_release.%s.dll" % arch
	return "libspeed_runtime.macos.template_release.%s.dylib" % arch

static func bin_directory() -> String:
	return ProjectSettings.globalize_path(BIN)

static func library_path() -> String:
	return bin_directory().path_join(library_name())

static func record_path() -> String:
	return library_path()+".json"

static func installed_id() -> String:
	var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(record_path())) if FileAccess.file_exists(record_path()) else null
	return str(record.get("runtime_id","")) if record is Dictionary else ""

## current は計算済みのソース識別子。
static func state_of(current: String) -> State:
	if current.is_empty(): return State.NO_SOURCE
	if not FileAccess.file_exists(library_path()): return State.MISSING
	return State.CURRENT if installed_id() == current else State.STALE

static func replace_library(downloaded: String, runtime_id: String) -> Error:
	var destination := library_path()
	if OS.get_name() == "Windows" and FileAccess.file_exists(destination):
		# 読み込み中のDLLは上書きできないが、名前は変えられる。
		var retired := "%s.old-%d" % [destination,OS.get_process_id()]
		var moved := DirAccess.rename_absolute(destination,retired)
		if moved != OK: return moved
	var error := DirAccess.rename_absolute(downloaded,destination)
	if error != OK: return error
	var pending := record_path()+".pending"
	var file := FileAccess.open(pending,FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"runtime_id":runtime_id,"source":"ci"}))
	file.close()
	return DirAccess.rename_absolute(pending,record_path())

## 前回までに退避した使用済みのDLLを消す。
static func remove_retired() -> void:
	if not DirAccess.dir_exists_absolute(bin_directory()): return
	for name in DirAccess.get_files_at(bin_directory()):
		if name.begins_with(library_name()+".old-"):
			DirAccess.remove_absolute(bin_directory().path_join(name))
