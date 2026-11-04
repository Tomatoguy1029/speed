## C++ソースの識別子。tools/build/runtime_id.py と同じ値を返す。
@tool
extends RefCounted
const FIXED_FILES := ["SConstruct","dependencies.json"]
const EXCLUDED_DIRECTORIES := ["godot-cpp"]

static func _collect(root: String, relative: String, result: PackedStringArray) -> void:
	var directory := root if relative.is_empty() else root.path_join(relative)
	for name in DirAccess.get_files_at(directory):
		if name.get_extension() in ["h","cpp"]:
			result.append(name if relative.is_empty() else relative.path_join(name))
	for name in DirAccess.get_directories_at(directory):
		if relative.is_empty() and name in EXCLUDED_DIRECTORIES: continue
		_collect(root,name if relative.is_empty() else relative.path_join(name),result)

static func _normalized(bytes: PackedByteArray) -> PackedByteArray:
	if bytes.find(13) < 0: return bytes
	var result := PackedByteArray()
	result.resize(bytes.size())
	var used := 0
	for index in bytes.size():
		if bytes[index] == 13 and index+1 < bytes.size() and bytes[index+1] == 10: continue
		result[used] = bytes[index]
		used += 1
	result.resize(used)
	return result

static func _hash(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

## cpp のフォルダがなければ空文字を返す。
static func compute(cpp: String) -> String:
	if not DirAccess.dir_exists_absolute(cpp): return ""
	var paths := PackedStringArray()
	_collect(cpp,"",paths)
	for name: String in FIXED_FILES:
		if FileAccess.file_exists(cpp.path_join(name)): paths.append(name)
	paths.sort()
	var manifest := PackedStringArray()
	for path in paths:
		manifest.append("%s:%s\n" % [path,_hash(_normalized(FileAccess.get_file_as_bytes(cpp.path_join(path))))])
	return _hash("".join(manifest).to_utf8_buffer())
